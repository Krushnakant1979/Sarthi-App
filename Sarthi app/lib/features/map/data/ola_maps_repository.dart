import 'dart:math' as math;
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class OlaMapsRepository {
  final Dio _dio = Dio();
  final String _apiKey =
      dotenv.env['OLA_MAPS_API_KEY'] ?? 'x6L9aB9eM6V9x1vJ3uG7t';

  Future<List<Map<String, dynamic>>> autocomplete(String input) async {
    if (input.trim().isEmpty) return [];

    try {
      final response = await _dio.get(
        'https://api.olamaps.io/places/v1/autocomplete',
        queryParameters: {'input': input, 'api_key': _apiKey},
      );

      if (response.statusCode == 200) {
        final data = response.data;
        if (data != null && data['predictions'] != null) {
          return List<Map<String, dynamic>>.from(data['predictions']);
        }
      }
      return [];
    } catch (e) {
      debugPrint('Autocomplete Error: $e');
      return [];
    }
  }

  Future<Map<String, double>?> geocode(String placeId) async {
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
          return {
            'lat': (loc['lat'] as num).toDouble(),
            'lng': (loc['lng'] as num).toDouble(),
          };
        }
      }
      return null;
    } catch (e) {
      debugPrint('Geocode Error: $e');
      return null;
    }
  }

  Future<String?> reverseGeocode(double lat, double lng) async {
    try {
      final response = await _dio.get(
        'https://api.olamaps.io/places/v1/reverse-geocode',
        queryParameters: {'latlng': '$lat,$lng', 'api_key': _apiKey},
      );
      if (response.statusCode != 200 || response.data == null) return null;
      final data = response.data;
      if (data['result'] is Map) {
        return data['result']['formatted_address']?.toString() ??
            data['result']['name']?.toString();
      }
      if (data['results'] is List && (data['results'] as List).isNotEmpty) {
        final first = (data['results'] as List).first;
        if (first is Map) return first['formatted_address']?.toString();
      }
    } catch (e) {
      debugPrint('Reverse Geocode Error: $e');
    }
    return null;
  }

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
              legs['distance']['value'] != null) {
            distanceMeters = (legs['distance']['value'] as num).toInt();
          }

          int durationSeconds = 0;
          if (legs['duration'] is num) {
            durationSeconds = (legs['duration'] as num).toInt();
          } else if (legs['duration'] is Map &&
              legs['duration']['value'] != null) {
            durationSeconds = (legs['duration']['value'] as num).toInt();
          }

          final polylineStr = route['overview_polyline'] as String? ?? '';
          final decodedPoints = decodePolyline(polylineStr);

          if (decodedPoints.isNotEmpty) {
            return {
              'distance_meters': distanceMeters > 0
                  ? distanceMeters
                  : _calculateDistanceMeters(
                      startLat,
                      startLng,
                      endLat,
                      endLng,
                    ),
              'duration_seconds': durationSeconds > 0
                  ? durationSeconds
                  : (distanceMeters / 8.33).round(),
              'polyline': polylineStr,
              'points': decodedPoints,
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
          '$startLng,$startLat;$endLng,$endLat?overview=full&geometries=polyline';
      final osrmResponse = await _dio.get(
        osrmUrl,
        options: Options(
          headers: {'User-Agent': 'Sarthi App/1.0 (Contact: admin@sarthiapp.com)'},
        ),
      );

      if (osrmResponse.statusCode == 200 && osrmResponse.data != null) {
        final data = osrmResponse.data;
        if (data['routes'] != null && (data['routes'] as List).isNotEmpty) {
          final route = data['routes'][0];
          final distanceMeters = (route['distance'] as num).toInt();
          final durationSeconds = (route['duration'] as num).toInt();
          final polylineStr = route['geometry'] as String? ?? '';
          final points = decodePolyline(polylineStr);

          if (points.isNotEmpty) {
            return {
              'distance_meters': distanceMeters,
              'duration_seconds': durationSeconds,
              'polyline': polylineStr,
              'points': points,
            };
          }
        }
      }
    } catch (e) {
      debugPrint('OSRM Routing Error: $e');
    }

    // 3. Last fallback: Throw an exception to prevent drawing a straight line
    throw Exception('Failed to retrieve road route from both Ola and OSRM APIs.');
  }

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
    final a =
        0.5 -
        math.cos((lat2 - lat1) * p) / 2 +
        math.cos(lat1 * p) *
            math.cos(lat2 * p) *
            (1 - math.cos((lon2 - lon1) * p)) /
            2;
    return (12742 * math.asin(math.sqrt(a)) * 1000).round();
  }
}
