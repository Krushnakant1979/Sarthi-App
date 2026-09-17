import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

class LocationService {
  // ── Static in-memory position cache ─────────────────────────────────────
  // Shared across all LocationService instances so the first real fix is
  // immediately available to any part of the app (map, search, captain).
  static Position? _cachedPosition;
  static DateTime? _cacheTime;
  static const _cacheTtl = Duration(seconds: 20);

  /// Returns true if the cached position is still fresh enough to use.
  static bool get _cacheValid =>
      _cachedPosition != null &&
      _cacheTime != null &&
      DateTime.now().difference(_cacheTime!) < _cacheTtl;

  /// Call once at app startup (after Firebase.initializeApp) to prime the GPS
  /// chip so the first real [getCurrentPosition] call returns fast.
  static Future<void> warmUp() async {
    try {
      final svcOn = await Geolocator.isLocationServiceEnabled();
      if (!svcOn) return;
      final perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) return;

      // Fire-and-forget: just reading last-known is enough to prime the chip.
      final last = await Geolocator.getLastKnownPosition();
      if (last != null) {
        _cachedPosition = last;
        _cacheTime = DateTime.now();
      }
    } catch (_) {
      // Warm-up is best-effort; never throw.
    }
  }

  Future<bool> requestPermission() async {
    final status = await Permission.location.request();
    return status.isGranted || status.isLimited;
  }

  /// Returns a position as fast as possible:
  ///  1. Returns the in-memory cache immediately if fresh (< 20 s old).
  ///  2. Falls back to `getLastKnownPosition` (instant, no GPS fix needed).
  ///  3. Finally requests a fresh high-accuracy fix with a 6-second timeout.
  Future<Position?> getCurrentPosition() async {
    // 1. Fresh cache — return instantly
    if (_cacheValid) return _cachedPosition;

    final svcOn = await Geolocator.isLocationServiceEnabled();
    if (!svcOn) return null;

    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied) return null;
    }
    if (perm == LocationPermission.deniedForever) return null;

    // 2. Last-known is instant (no satellite fix required)
    final last = await Geolocator.getLastKnownPosition();
    if (last != null) {
      _cachedPosition = last;
      _cacheTime = DateTime.now();
    }

    // 3. Try a fresh high-accuracy fix with a hard 6-second timeout.
    //    If the device takes longer we return the last-known instead of hanging.
    try {
      final fresh = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      ).timeout(const Duration(seconds: 6), onTimeout: () {
        // Return last-known on timeout — caller gets stale-but-fast data
        return _cachedPosition ??
            Future.error(TimeoutException('GPS timeout'));
      });
      _cachedPosition = fresh;
      _cacheTime = DateTime.now();
      return fresh;
    } on TimeoutException {
      return _cachedPosition; // use last-known on timeout
    } catch (_) {
      return _cachedPosition; // any other failure → last-known
    }
  }

  /// Returns the last known device position instantly (no GPS satellite fix).
  Future<Position?> getLastKnownPosition() async {
    // Return cache immediately if available
    if (_cachedPosition != null) return _cachedPosition;

    final svcOn = await Geolocator.isLocationServiceEnabled();
    if (!svcOn) return null;

    final perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) return null;

    final pos = await Geolocator.getLastKnownPosition();
    if (pos != null) {
      _cachedPosition = pos;
      _cacheTime = DateTime.now();
    }
    return pos;
  }

  /// Real-time stream of device position updates. Used to track the user
  /// live on the map as they move around.
  Stream<Position> getPositionStream({int distanceFilter = 5}) {
    return Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: distanceFilter, // update every N metres of movement
      ),
    ).map((pos) {
      // Keep cache updated from stream so any caller benefits
      _cachedPosition = pos;
      _cacheTime = DateTime.now();
      return pos;
    });
  }
}
