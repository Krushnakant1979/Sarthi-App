import 'dart:math' as math;
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class OlaMapsRepository {
  // ── Singleton Dio ──────────────────────────────────────────────────────
  // One connection pool shared across the entire app — no TLS handshake
  // overhead on every call, and keeps HTTP/2 connections alive.
  static final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 5),
      receiveTimeout: const Duration(seconds: 8),
      sendTimeout: const Duration(seconds: 5),
    ),
  );

  String get _apiKey =>
      dotenv.env['OLA_MAPS_API_KEY'] ?? 'x6L9aB9eM6V9x1vJ3uG7t';

  // ── In-memory TTL caches ───────────────────────────────────────────────
  // reverseGeocode: keyed by "lat4dp,lng4dp" — 10-minute TTL
  static final Map<String, _CacheEntry<String?>> _revGeoCache = {};
  static const _revGeoCacheTtl = Duration(minutes: 10);

  // autocomplete: keyed by lowercased query — 2-minute TTL
  static final Map<String, _CacheEntry<List<Map<String, dynamic>>>> _acCache =
      {};
  static const _acCacheTtl = Duration(minutes: 2);

  // geocode (place details): keyed by placeId — 30-minute TTL
  static final Map<String, _CacheEntry<Map<String, double>?>> _geocodeCache =
      {};
  static const _geocodeCacheTtl = Duration(minutes: 30);

  // ── Autocomplete ───────────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> autocomplete(String input) async {
    if (input.trim().isEmpty) return [];
    final key = input.trim().toLowerCase();

    // Return cached result instantly if still fresh
    final cached = _acCache[key];
    if (cached != null && !cached.isExpired(_acCacheTtl)) return cached.value;

    try {
      final response = await _dio.get(
        'https://api.olamaps.io/places/v1/autocomplete',
        queryParameters: {'input': input, 'api_key': _apiKey},
      );

      if (response.statusCode == 200) {
        final data = response.data;
        if (data != null && data['predictions'] != null) {
          final results =
              List<Map<String, dynamic>>.from(data['predictions']);
          _acCache[key] = _CacheEntry(results);
          return results;
        }
      }
      return [];
    } catch (e) {
      debugPrint('Autocomplete Error: $e');
      return cached?.value ?? []; // Return stale cache on error
    }
  }

  // ── Geocode (place details → lat/lng) ──────────────────────────────────
  Future<Map<String, double>?> geocode(String placeId) async {
    final cached = _geocodeCache[placeId];
    if (cached != null && !cached.isExpired(_geocodeCacheTtl)) {
      return cached.value;
    }

    try {
      final response = await _dio.get(
        'https://api.olamaps.io/places/v1/details',
        queryParameters: {'place_id': placeId, 'api_key': _apiKey},
      );

      if (response.statusCode == 200) {
        final data = response.data;
        if (data != null &&
            data['result'] != null &&
            data['result']['geometry'] != null &&
            data['result']['geometry']['location'] != null) {
          final loc = data['result']['geometry']['location'];
          final result = {
            'lat': (loc['lat'] as num).toDouble(),
            'lng': (loc['lng'] as num).toDouble(),
          };
          _geocodeCache[placeId] = _CacheEntry(result);
          return result;
        }
      }
      _geocodeCache[placeId] = _CacheEntry(null);
      return null;
    } catch (e) {
      debugPrint('Geocode Error: $e');
      return cached?.value;
    }
  }

  // ── Reverse Geocode ────────────────────────────────────────────────────
  Future<String?> reverseGeocode(double lat, double lng) async {
    // Round to 4 decimal places (~11 m precision) to maximise cache hits
    final key =
        '${lat.toStringAsFixed(4)},${lng.toStringAsFixed(4)}';

    final cached = _revGeoCache[key];
    if (cached != null && !cached.isExpired(_revGeoCacheTtl)) {
      return cached.value;
    }

    try {
      final response = await _dio.get(
        'https://api.olamaps.io/places/v1/reverse-geocode',
        queryParameters: {'latlng': '$lat,$lng', 'api_key': _apiKey},
      );
      if (response.statusCode != 200 || response.data == null) return null;
      final data = response.data;
      String? address;
      if (data['result'] is Map) {
        address = data['result']['formatted_address']?.toString() ??
            data['result']['name']?.toString();
      } else if (data['results'] is List &&
          (data['results'] as List).isNotEmpty) {
        final first = (data['results'] as List).first;
        if (first is Map) address = first['formatted_address']?.toString();
      }
      _revGeoCache[key] = _CacheEntry(address);
      return address;
    } catch (e) {
      debugPrint('Reverse Geocode Error: $e');
      return cached?.value; // Return stale cache on network error
    }
  }

  // ── City + State label ─────────────────────────────────────────────────
  Future<String> getCityAndState(double lat, double lng) async {
    final address = await reverseGeocode(lat, lng);
    if (address == null || address.isEmpty) return 'Locating...';

    final parts = address.split(',').map((e) => e.trim()).toList();
    final textParts = parts
        .where((p) =>
            p.isNotEmpty &&
            p.toLowerCase() != 'india' &&
            int.tryParse(p.replaceAll(' ', '')) == null)
        .toList();

    if (textParts.length >= 2) {
      return '${textParts[textParts.length - 2]}, ${textParts.last}';
    } else if (textParts.isNotEmpty) {
      return textParts.last;
    }
    return 'Unknown Location';
  }

  // ── Directions ─────────────────────────────────────────────────────────
  /// Fetches real road-following directions using Ola Maps Directions API,
  /// falling back to OSRM road routing API if Ola API quota/network fails.
  Future<Map<String, dynamic>> getDirections(
    double startLat,
    double startLng,
    double endLat,
    double endLng,
  ) async {
    // 1. Try Ola Maps Directions API (GET request)
    try {
      final response = await _dio.get(
        'https://api.olamaps.io/routing/v1/directions',
        queryParameters: {
          'origin': '$startLat,$startLng',
          'destination': '$endLat,$endLng',
          'api_key': _apiKey,
        },
      );

      if (response.statusCode == 200) {
        final data = response.data;
        List? routes;
        if (data != null) {
          if (data['routes'] is List && (data['routes'] as List).isNotEmpty) {
            routes = data['routes'];
          } else if (data['result'] != null &&
              data['result']['routes'] is List &&
              (data['result']['routes'] as List).isNotEmpty) {
            routes = data['result']['routes'];
          }
        }

        if (routes != null && routes.isNotEmpty) {
          final route = routes[0];
          final legs = (route['legs'] as List)[0];

          int distanceMeters = 0;
          if (legs['distance'] is num) {
            distanceMeters = (legs['distance'] as num).toInt();
          } else if (legs['distance'] is Map &&
              legs['distance']['value'] is num) {
            distanceMeters = (legs['distance']['value'] as num).toInt();
          }

          int durationSeconds = 0;
          if (legs['duration'] is num) {
            durationSeconds = (legs['duration'] as num).toInt();
          } else if (legs['duration'] is Map &&
              legs['duration']['value'] is num) {
            durationSeconds = (legs['duration']['value'] as num).toInt();
          }

          final polylineStr = route['overview_polyline'] as String? ?? '';
          final decodedPoints = decodePolyline(polylineStr);

          List steps = [];
          if (legs['steps'] is List) {
            steps = legs['steps'];
          }

          if (decodedPoints.isNotEmpty) {
            return {
              'distance_meters': distanceMeters > 0
                  ? distanceMeters
                  : _calculateDistanceMeters(
                      startLat, startLng, endLat, endLng),
              'duration_seconds': durationSeconds > 0
                  ? durationSeconds
                  : (distanceMeters / 8.33).round(),
              'polyline': polylineStr,
              'points': decodedPoints,
              'steps': steps,
            };
          }
        }
      }
    } catch (e) {
      debugPrint('Ola Directions API Error: $e');
    }

    // 2. Fallback: Free OSRM Public Driving Routing API for exact road geometry
    try {
      final osrmUrl =
          'https://router.project-osrm.org/route/v1/driving/'
          '$startLng,$startLat;$endLng,$endLat?overview=full&geometries=polyline&steps=true';
      final osrmResponse = await _dio.get(
        osrmUrl,
        options: Options(
          headers: {
            'User-Agent': 'Sarthi App/1.0 (Contact: admin@sarthiapp.com)',
          },
        ),
      );

      if (osrmResponse.statusCode == 200 && osrmResponse.data != null) {
        final data = osrmResponse.data;
        if (data['routes'] != null && (data['routes'] as List).isNotEmpty) {
          final route = data['routes'][0];
          final distanceMeters = (route['distance'] is num)
              ? (route['distance'] as num).toInt()
              : 0;
          final durationSeconds = (route['duration'] is num)
              ? (route['duration'] as num).toInt()
              : 0;
          final polylineStr = route['geometry'] as String? ?? '';
          final points = decodePolyline(polylineStr);
          
          List steps = [];
          if (route['legs'] is List && (route['legs'] as List).isNotEmpty) {
             final osrmLegs = route['legs'][0];
             if (osrmLegs['steps'] is List) {
               steps = osrmLegs['steps'];
             }
          }

          if (points.isNotEmpty) {
            return {
              'distance_meters': distanceMeters,
              'duration_seconds': durationSeconds,
              'polyline': polylineStr,
              'points': points,
              'steps': steps,
            };
          }
        }
      }
    } catch (e) {
      debugPrint('OSRM Routing Error: $e');
    }

    // 3. Last fallback
    throw Exception(
      'Failed to retrieve road route from both Ola and OSRM APIs.',
    );
  }

  // ── Polyline decoder ───────────────────────────────────────────────────
  /// Standard Google / Mapbox Polyline Algorithm Decoder
  List<Map<String, double>> decodePolyline(String encoded) {
    if (encoded.isEmpty) return [];

    List<Map<String, double>> points = [];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;

    try {
      while (index < len) {
        int b, shift = 0, result = 0;
        do {
          b = encoded.codeUnitAt(index++) - 63;
          result |= (b & 0x1f) << shift;
          shift += 5;
        } while (b >= 0x20);
        int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
        lat += dlat;

        shift = 0;
        result = 0;
        do {
          b = encoded.codeUnitAt(index++) - 63;
          result |= (b & 0x1f) << shift;
          shift += 5;
        } while (b >= 0x20);
        int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
        lng += dlng;

        points.add({'lat': lat / 1E5, 'lng': lng / 1E5});
      }
    } catch (e) {
      debugPrint('Polyline Decode Error: $e');
    }
    return points;
  }

  int _calculateDistanceMeters(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const p = 0.017453292519943295;
    final a = 0.5 -
        math.cos((lat2 - lat1) * p) / 2 +
        math.cos(lat1 * p) *
            math.cos(lat2 * p) *
            (1 - math.cos((lon2 - lon1) * p)) /
            2;
    return (12742 * math.asin(math.sqrt(a)) * 1000).round();
  }
}

// ── TTL cache entry helper ───────────────────────────────────────────────────
class _CacheEntry<T> {
  final T value;
  final DateTime createdAt;
  _CacheEntry(this.value) : createdAt = DateTime.now();
  bool isExpired(Duration ttl) => DateTime.now().difference(createdAt) > ttl;
}
