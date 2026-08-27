import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../data/captain_repository.dart';

final captainRepositoryProvider = Provider<CaptainRepository>((ref) {
  return CaptainRepository();
});

// Provides a list of incoming ride requests (where status == 'searching')
final incomingRequestsProvider = StreamProvider<List<Map<String, dynamic>>>((
  ref,
) {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return Stream.value(const []);
  return ref
      .watch(captainRepositoryProvider)
      .streamIncomingRequests(user.uid);
});

// Provides the current active ride for the captain
final currentCaptainRideProvider = StreamProvider<Map<String, dynamic>?>((ref) {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return Stream.value(null);
  return ref
      .watch(captainRepositoryProvider)
      .streamCurrentCaptainRide(user.uid);
});

// Provides aggregated stats for trips
final captainTripStatsProvider =
    FutureProvider.family<Map<String, dynamic>, ({DateTime start, DateTime end})>((
      ref,
      args,
    ) async {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        return {'count': 0, 'totalIncome': 0.0, 'totalDistance': 0.0};
      }

      return ref
          .watch(captainRepositoryProvider)
          .getTripAggregations(user.uid, args.start, args.end);
    });
