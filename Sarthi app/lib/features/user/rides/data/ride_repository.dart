import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:geolocator/geolocator.dart';
import '../../../../core/analytics/analytics_logger.dart';

class RideRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseDatabase _rtdb = FirebaseDatabase.instanceFor(
    app: Firebase.app(),
    databaseURL:
        'https://rapido-app-8745a-default-rtdb.asia-southeast1.firebasedatabase.app',
  );

  Future<String> createRideRequest({
    required String userId,
    required double startLat,
    required double startLng,
    required double endLat,
    required double endLng,
    required String destinationName,
    required int estimatedFare,
    required int distanceMeters,
    String? riderName,
    String? riderPhone,
    String? pickupAddress,
    String vehicleType = 'bike',
    String? appliedOfferCode,
    double? discountAmount,
    Map<String, dynamic>? fareBreakdown,
  }) async {
    final docRef = _firestore.collection('ride_requests').doc();

    // Generate a random 4-digit OTP
    final random = Random();
    final otp = (1000 + random.nextInt(9000)).toString();

    // ── Generate sequential routing queue ──
    List<String> routingQueue = [];
    try {
      final liveSnapshot = await _rtdb.ref().child('live/captains').get();
      if (liveSnapshot.exists && liveSnapshot.value != null) {
        final data = liveSnapshot.value as Map<dynamic, dynamic>;
        List<Map<String, dynamic>> nearby = [];
        
        data.forEach((key, value) {
          final captainData = value as Map<dynamic, dynamic>;
          final lat = captainData['lat'] as double?;
          final lng = captainData['lng'] as double?;
          if (lat != null && lng != null) {
            final dist = Geolocator.distanceBetween(startLat, startLng, lat, lng);
            // Search radius: up to 6km
            if (dist <= 6000) {
              nearby.add({'id': key.toString(), 'distance': dist});
            }
          }
        });
        
        // Sort nearest first (Layer 1 -> Layer 2 -> Layer 3)
        nearby.sort((a, b) => (a['distance'] as double).compareTo(b['distance'] as double));
        
        // Take top 20 nearest to avoid excessive Firestore reads
        final topNearest = nearby.take(20).toList();
        for (var cap in topNearest) {
          final cDoc = await _firestore.collection('users').doc(cap['id'] as String).get();
          if (cDoc.exists) {
            final cData = cDoc.data()!;
            if (cData['role'] == 'captain' &&
                cData['vehicleType'] == vehicleType &&
                cData['verificationStatus'] == 'verified') {
              routingQueue.add(cap['id'] as String);
            }
          }
        }
      }
    } catch (e) {
      // Fallback to empty queue if location matching fails
    }

    await docRef.set({
      'userId': userId,
      'riderName': riderName,
      'riderPhone': riderPhone,
      'status': 'searching',
      'otp': otp,
      'routingQueue': routingQueue,
      'currentRouteIndex': 0,
      'routeStartedAt': FieldValue.serverTimestamp(),
      'pickup': {
        'lat': startLat,
        'lng': startLng,
        'address': pickupAddress ?? 'User pickup location',
      },
      'destination': {'lat': endLat, 'lng': endLng, 'address': destinationName},
      'distanceMeters': distanceMeters,
      'fareEstimate': estimatedFare,
      'fareBreakdown': fareBreakdown,
      'vehicleType': vehicleType,
      'appliedOfferCode': appliedOfferCode,
      'discountAmount': discountAmount,
      'createdAt': FieldValue.serverTimestamp(),
    });

    AnalyticsLogger.logRideRequested(
      rideId: docRef.id,
      vehicleType: vehicleType,
      estimatedFare: estimatedFare.toDouble(),
      distanceMeters: distanceMeters.toDouble(),
    );

    return docRef.id;
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> streamRideRequest(
    String rideId,
  ) {
    return _firestore.collection('ride_requests').doc(rideId).snapshots();
  }

  // Watch active ride for a user
  Stream<Map<String, dynamic>?> streamActiveRide(String userId) {
    return _firestore
        .collection('ride_requests')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
          final activeStatuses = [
            'searching',
            'accepted',
            'arriving',
            'arrived',
            'in_progress',
          ];

          final docs = snapshot.docs.where((doc) {
            final data = doc.data();
            return activeStatuses.contains(data['status']);
          }).toList();

          if (docs.isNotEmpty) {
            // Sort by createdAt descending to get the latest active ride
            docs.sort((a, b) {
              final aTime =
                  (a.data()['createdAt'] as Timestamp?)?.toDate() ??
                  DateTime.fromMillisecondsSinceEpoch(0);
              final bTime =
                  (b.data()['createdAt'] as Timestamp?)?.toDate() ??
                  DateTime.fromMillisecondsSinceEpoch(0);
              return bTime.compareTo(aTime);
            });
            final doc = docs.first;
            final data = doc.data();
            data['id'] = doc.id;
            return data;
          }
          return null;
        });
  }

  // Stream live location of the assigned captain from Realtime Database
  Stream<Map<String, dynamic>?> streamCaptainLiveLocation(String captainId) {
    return _rtdb.ref().child('live/captains/$captainId').onValue.map((event) {
      if (event.snapshot.exists) {
        final data = event.snapshot.value as Map<dynamic, dynamic>;
        return Map<String, dynamic>.from(data);
      }
      return null;
    });
  }

  Future<void> updateRideStatus(
    String rideId,
    String newStatus, {
    Map<String, dynamic>? extraData,
  }) async {
    final updates = <String, dynamic>{'status': newStatus};
    if (extraData != null) {
      updates.addAll(extraData);
    }
    await _firestore.collection('ride_requests').doc(rideId).update(updates);

    if (newStatus == 'completed') {
      AnalyticsLogger.logRideCompleted(rideId: rideId);
    }
  }

  Future<List<Map<String, dynamic>>> getActiveOffers() async {
    final snapshot = await _firestore
        .collection('offers')
        .where('isActive', isEqualTo: true)
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id;
      return data;
    }).toList();
  }
}
