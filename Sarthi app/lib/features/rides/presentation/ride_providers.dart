import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../data/ride_repository.dart';

final rideRepositoryProvider = Provider<RideRepository>((ref) {
  return RideRepository();
});

final currentRideIdProvider = StateProvider<String?>((ref) => null);

final currentRideStreamProvider =
    StreamProvider.autoDispose<DocumentSnapshot<Map<String, dynamic>>?>((ref) {
      final rideId = ref.watch(currentRideIdProvider);
      if (rideId == null) {
        return Stream.value(null);
      }
      final repo = ref.watch(rideRepositoryProvider);
      return repo.streamRideRequest(rideId);
    });

final activeRideProvider = StreamProvider<Map<String, dynamic>?>((ref) {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return Stream.value(null);
  return ref.watch(rideRepositoryProvider).streamActiveRide(user.uid);
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
