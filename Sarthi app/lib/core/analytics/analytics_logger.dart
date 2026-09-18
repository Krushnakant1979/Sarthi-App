import 'package:firebase_analytics/firebase_analytics.dart';

class AnalyticsLogger {
  static final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  static Future<void> logAuthSuccess(String userId, String method) async {
    try {
      await _analytics.logLogin(loginMethod: method);
      await _analytics.setUserId(id: userId);
    } catch (e) {
      // Ignore analytics errors
    }
  }

  static Future<void> logRideRequested({
    required String rideId,
    required String vehicleType,
    required double estimatedFare,
    required double distanceMeters,
  }) async {
    try {
      await _analytics.logEvent(
        name: 'ride_requested',
        parameters: {
          'ride_id': rideId,
          'vehicle_type': vehicleType,
          'estimated_fare': estimatedFare,
          'distance_meters': distanceMeters,
        },
      );
    } catch (e) {
      // Ignore analytics errors
    }
  }

  static Future<void> logRideCompleted({
    required String rideId,
  }) async {
    try {
      await _analytics.logEvent(
        name: 'ride_completed',
        parameters: {
          'ride_id': rideId,
        },
      );
    } catch (e) {
      // Ignore analytics errors
    }
  }
}
