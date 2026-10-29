import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../data/ride_repository.dart';

final rideRepositoryProvider = Provider<RideRepository>((ref) {
  return RideRepository();
});

final currentRideIdProvider = StateProvider<String?>((ref) => null);

final activeRideProvider = StreamProvider<Map<String, dynamic>?>((ref) {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return Stream.value(null);
  return ref.watch(rideRepositoryProvider).streamActiveRide(user.uid);
});

final currentRideStreamProvider =
    StreamProvider<DocumentSnapshot<Map<String, dynamic>>?>((ref) {
      String? rideId = ref.watch(currentRideIdProvider);

      // If in-memory ride ID is not set (e.g. app reopened, resumed, or cold start),
      // seamlessly fall back to the active ride discovered from the backend
      if (rideId == null) {
        final activeRide = ref.watch(activeRideProvider).valueOrNull;
        rideId = activeRide?['id'] as String?;
      }

      if (rideId == null) {
        return Stream.value(null);
      }
      final repo = ref.watch(rideRepositoryProvider);
      return repo.streamRideRequest(rideId);
    });

// Family provider to listen to a specific captain's live location
final captainLiveLocationProvider =
    StreamProvider.family<Map<String, dynamic>?, String>((ref, captainId) {
      return ref
          .watch(rideRepositoryProvider)
          .streamCaptainLiveLocation(captainId);
    });

// Provides the live location of the captain assigned to the current user's active ride
final assignedCaptainLocationProvider =
    Provider<AsyncValue<Map<String, dynamic>?>>((ref) {
      final activeRide = ref.watch(activeRideProvider).value;
      final captainId = activeRide?['assignedCaptainId'] as String?;
      if (captainId == null) {
        return const AsyncValue.data(null);
      }
      return ref.watch(captainLiveLocationProvider(captainId));
    });

class NearbyCaptainsQuery {
  final double pickupLat;
  final double pickupLng;
  final String vehicleType;
  final double radiusMeters;

  const NearbyCaptainsQuery({
    required this.pickupLat,
    required this.pickupLng,
    required this.vehicleType,
    this.radiusMeters = 6000,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NearbyCaptainsQuery &&
          runtimeType == other.runtimeType &&
          pickupLat == other.pickupLat &&
          pickupLng == other.pickupLng &&
          vehicleType == other.vehicleType &&
          radiusMeters == other.radiusMeters;

  @override
  int get hashCode =>
      pickupLat.hashCode ^
      pickupLng.hashCode ^
      vehicleType.hashCode ^
      radiusMeters.hashCode;
}

final nearbyAvailableCaptainsProvider =
    StreamProvider.family<List<Map<String, dynamic>>, NearbyCaptainsQuery>((ref, query) {
  return ref.watch(rideRepositoryProvider).streamNearbyAvailableCaptains(
        pickupLat: query.pickupLat,
        pickupLng: query.pickupLng,
        vehicleType: query.vehicleType,
        radiusMeters: query.radiusMeters,
      );
});
