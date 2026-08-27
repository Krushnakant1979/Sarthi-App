import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart' hide Query;
import 'package:firebase_core/firebase_core.dart';

class CaptainRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseDatabase _rtdb = FirebaseDatabase.instanceFor(
    app: Firebase.app(),
    databaseURL:
        'https://rapido-app-8745a-default-rtdb.asia-southeast1.firebasedatabase.app',
  );

  Future<T> _withFirestoreRetry<T>(Future<T> Function() operation) async {
    const retryableCodes = {
      'unavailable',
      'aborted',
      'deadline-exceeded',
      'network-request-failed',
    };

    for (var attempt = 1; attempt <= 3; attempt++) {
      try {
        return await operation();
      } on FirebaseException catch (error) {
        if (!retryableCodes.contains(error.code) || attempt == 3) rethrow;
        await Future<void>.delayed(Duration(milliseconds: 400 * attempt));
      }
    }
    throw StateError('Firestore operation could not be completed.');
  }

  // Listen for rides that are searching for a captain
  Stream<List<Map<String, dynamic>>> streamIncomingRequests(String captainId) async* {
    final userDoc = await _firestore.collection('users').doc(captainId).get();
    final captainVehicleType = userDoc.data()?['vehicleType'] ?? 'bike';

    yield* _firestore
        .collection('ride_requests')
        .where('status', isEqualTo: 'searching')
        .where('vehicleType', isEqualTo: captainVehicleType)
        .snapshots()
        .map((snapshot) {
          final requests = snapshot.docs.map((doc) {
            final data = doc.data();
            data['id'] = doc.id;
            return data;
          }).where((data) {
            final declinedBy = (data['declinedBy'] as List?) ?? const [];
            return !declinedBy.contains(captainId);
          }).toList();
          requests.sort((a, b) {
            final aTime = a['createdAt'] as Timestamp?;
            final bTime = b['createdAt'] as Timestamp?;
            return (bTime?.millisecondsSinceEpoch ?? 0)
                .compareTo(aTime?.millisecondsSinceEpoch ?? 0);
          });
          return requests;
        });
  }

  // Captain accepts a ride
  Future<void> acceptRide(String rideId, String captainId) async {
    final rideRef = _firestore.collection('ride_requests').doc(rideId);
    final captainRef = _firestore.collection('users').doc(captainId);
    await _withFirestoreRetry(() => _firestore.runTransaction((transaction) async {
      final captain = await transaction.get(captainRef);
      if (!captain.exists ||
          captain.data()?['role'] != 'captain' ||
          captain.data()?['verificationStatus'] != 'verified') {
        throw StateError('Only a verified captain can accept rides.');
      }

      final ride = await transaction.get(rideRef);
      if (!ride.exists || ride.data()?['status'] != 'searching') {
        throw StateError('This ride has already been accepted or cancelled.');
      }

      transaction.update(rideRef, {
        'status': 'accepted',
        'assignedCaptainId': captainId,
        'acceptedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }));
  }

  Future<void> rejectRide(String rideId, String captainId) async {
    await _firestore.collection('ride_requests').doc(rideId).update({
      'declinedBy': FieldValue.arrayUnion([captainId]),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // Stream current active ride for captain
  Stream<Map<String, dynamic>?> streamCurrentCaptainRide(String captainId) {
    return _firestore
        .collection('ride_requests')
        .where('assignedCaptainId', isEqualTo: captainId)
        .where(
          'status',
          whereIn: ['accepted', 'arriving', 'arrived', 'in_progress'],
        )
        .snapshots()
        .map((snapshot) {
          if (snapshot.docs.isNotEmpty) {
            final docs = snapshot.docs.toList()
              ..sort((a, b) {
                final aTime = a.data()['updatedAt'] as Timestamp?;
                final bTime = b.data()['updatedAt'] as Timestamp?;
                return (bTime?.millisecondsSinceEpoch ?? 0)
                    .compareTo(aTime?.millisecondsSinceEpoch ?? 0);
              });
            final doc = docs.first;
            final data = doc.data();
            data['id'] = doc.id;
            return data;
          }
          return null;
        });
  }

  // Broadcast live location to Realtime Database
  Future<void> updateLiveLocation(
    String captainId,
    double lat,
    double lng,
    double heading,
  ) async {
    final liveRef = _rtdb.ref().child('live/captains/$captainId');
    await liveRef.onDisconnect().remove();
    await liveRef.set({
      'lat': lat,
      'lng': lng,
      'heading': heading,
      'online': true,
      'updatedAt': ServerValue.timestamp,
    });
  }

  Future<void> setAvailability(
    String captainId,
    bool isOnline, {
    double? lat,
    double? lng,
    double heading = 0,
  }) async {
    final firestoreUpdate = _firestore.collection('users').doc(captainId).update({
      'isOnline': isOnline,
      'availabilityUpdatedAt': FieldValue.serverTimestamp(),
    });

    final liveRef = _rtdb.ref().child('live/captains/$captainId');
    Future<void> rtdbUpdate;
    if (!isOnline) {
      rtdbUpdate = liveRef.remove();
    } else if (lat != null && lng != null) {
      rtdbUpdate = updateLiveLocation(captainId, lat, lng, heading);
    } else {
      rtdbUpdate = Future.value();
    }

    await Future.wait([firestoreUpdate, rtdbUpdate]);
  }

  Future<bool> getAvailability(String captainId) async {
    final snapshot = await _firestore.collection('users').doc(captainId).get();
    return snapshot.data()?['isOnline'] == true;
  }

  Future<void> transitionRide({
    required String rideId,
    required String captainId,
    required String fromStatus,
    required String toStatus,
  }) async {
    final rideRef = _firestore.collection('ride_requests').doc(rideId);
    await _withFirestoreRetry(() => _firestore.runTransaction((transaction) async {
      final ride = await transaction.get(rideRef);
      final data = ride.data();
      if (!ride.exists || data?['assignedCaptainId'] != captainId) {
        throw StateError('This ride is not assigned to you.');
      }
      if (data?['status'] != fromStatus) {
        throw StateError('Ride status changed. Please refresh and try again.');
      }
      transaction.update(rideRef, {
        'status': toStatus,
        '${toStatus}At': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }));
  }

  Future<void> verifyOtpAndStartRide({
    required String rideId,
    required String captainId,
    required String enteredOtp,
  }) async {
    final rideRef = _firestore.collection('ride_requests').doc(rideId);
    await _withFirestoreRetry(() async {
      await _firestore.runTransaction((transaction) async {
        final ride = await transaction.get(rideRef);
        final data = ride.data();
        if (!ride.exists || data?['assignedCaptainId'] != captainId) {
          throw StateError('This ride is not assigned to you.');
        }
        if (data?['status'] != 'arrived') {
          throw StateError('Ride is not ready to start.');
        }
        if (data?['otp']?.toString() != enteredOtp) {
          throw StateError('Incorrect OTP. Please try again.');
        }
        transaction.update(rideRef, {
          'status': 'in_progress',
          'startedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });
    });
  }

  Future<void> reportRideIssue({
    required String rideId,
    required String captainId,
    required String issue,
  }) async {
    await _firestore
        .collection('ride_requests')
        .doc(rideId)
        .collection('issues')
        .add({
      'reportedBy': captainId,
      'reporterRole': 'captain',
      'issue': issue,
      'createdAt': FieldValue.serverTimestamp(),
      'status': 'open',
    });
  }

  // Fetch paginated completed rides
  Future<Map<String, dynamic>> getPaginatedTrips(
    String captainId,
    DateTime startDate,
    DateTime endDate, {
    DocumentSnapshot? startAfter,
    int limit = 10,
  }) async {
    Query query = _firestore
        .collection('ride_requests')
        .where('assignedCaptainId', isEqualTo: captainId)
        .where('status', isEqualTo: 'completed')
        .where('updatedAt', isGreaterThanOrEqualTo: startDate)
        .where('updatedAt', isLessThanOrEqualTo: endDate)
        .orderBy('updatedAt', descending: true)
        .limit(limit);

    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }

    final snapshot = await query.get();

    final trips = snapshot.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      data['id'] = doc.id;
      return data;
    }).toList();

    return {
      'trips': trips,
      'lastDocument': snapshot.docs.isNotEmpty ? snapshot.docs.last : null,
      'hasMore': snapshot.docs.length == limit,
    };
  }

  // Get aggregated statistics for a time period
  Future<Map<String, dynamic>> getTripAggregations(
    String captainId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    final query = _firestore
        .collection('ride_requests')
        .where('assignedCaptainId', isEqualTo: captainId)
        .where('status', isEqualTo: 'completed')
        .where('updatedAt', isGreaterThanOrEqualTo: startDate)
        .where('updatedAt', isLessThanOrEqualTo: endDate)
        .orderBy('updatedAt', descending: true);

    final snapshot = await query.get();

    int count = snapshot.docs.length;
    double totalIncome = 0.0;
    double totalDistance = 0.0;

    for (var doc in snapshot.docs) {
      final data = doc.data();
      totalIncome += (data['fareEstimate'] as num?)?.toDouble() ?? 0.0;
      totalDistance += (data['distanceMeters'] as num?)?.toDouble() ?? 0.0;
    }

    return {
      'count': count,
      'totalIncome': totalIncome,
      'totalDistance': totalDistance,
    };
  }

  // Submit a rating for a captain
  Future<void> rateCaptain(String captainId, int stars) async {
    final captainRef = _firestore.collection('users').doc(captainId);
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(captainRef);
      if (!snapshot.exists) {
        throw StateError('Captain not found.');
      }
      
      final data = snapshot.data()!;
      final currentScore = (data['ratingScore'] as num?) ?? 0;
      final currentCount = (data['ratingCount'] as int?) ?? 0;
      
      transaction.update(captainRef, {
        'ratingScore': currentScore + stars,
        'ratingCount': currentCount + 1,
      });
    });
  }
}
