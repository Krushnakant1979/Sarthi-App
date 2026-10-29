import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/foundation.dart';
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
    // Check if platform operations are temporarily suspended
    try {
      final configDoc = await _firestore.collection('config').doc('global_settings').get();
      if (configDoc.exists && configDoc.data()?['isPlatformActive'] == false) {
        throw Exception('Platform is temporarily paused for maintenance. Please check back shortly.');
      }
    } catch (e) {
      if (e.toString().contains('Platform is temporarily paused')) rethrow;
    }

    // Double safety check: prevent duplicate bookings for the same user
    final existingRide = await getActiveRide(userId);
    if (existingRide != null) {
      throw Exception('An active ride is already in progress');
    }

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
          const activeStatuses = [
            'searching',
            'pending',
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

            // Handle expired search (older than 120s without captain acceptance)
            if (data['status'] == 'searching') {
              final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
              if (createdAt != null &&
                  DateTime.now().difference(createdAt).inSeconds > 120) {
                updateRideStatus(
                  doc.id,
                  'cancelled',
                  extraData: {
                    'cancelledBy': 'system',
                    'cancelReason': 'No captain available in your area',
                    'updatedAt': FieldValue.serverTimestamp(),
                  },
                );
                return null;
              }
            }

            return data;
          }
          return null;
        });
  }

  // One-shot fetch for active ride (used on app open/resume and duplicate prevention)
  Future<Map<String, dynamic>?> getActiveRide(String userId) async {
    const activeStatuses = [
      'searching',
      'pending',
      'accepted',
      'arriving',
      'arrived',
      'in_progress',
    ];

    QuerySnapshot<Map<String, dynamic>> snapshot;
    try {
      snapshot = await _firestore
          .collection('ride_requests')
          .where('userId', isEqualTo: userId)
          .get();
    } catch (serverError) {
      debugPrint('Server fetch failed for active ride, falling back to cache: $serverError');
      try {
        snapshot = await _firestore
            .collection('ride_requests')
            .where('userId', isEqualTo: userId)
            .get(const GetOptions(source: Source.cache));
      } catch (cacheError) {
        debugPrint('Cache fetch also failed for active ride: $cacheError');
        // Rethrow network exception so caller knows NOT to clear local active state
        throw serverError;
      }
    }

    final docs = snapshot.docs.where((doc) {
      final data = doc.data();
      return activeStatuses.contains(data['status']);
    }).toList();

    if (docs.isNotEmpty) {
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

      // Auto-cancel if searching has expired (> 120s)
      if (data['status'] == 'searching') {
        final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
        if (createdAt != null &&
            DateTime.now().difference(createdAt).inSeconds > 120) {
          try {
            await updateRideStatus(
              doc.id,
              'cancelled',
              extraData: {
                'cancelledBy': 'system',
                'cancelReason': 'No captain available in your area',
                'updatedAt': FieldValue.serverTimestamp(),
              },
            );
          } catch (_) {}
          return null;
        }
      }

      return data;
    }
    return null;
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
    if (newStatus == 'completed' || newStatus == 'cancelled') {
      try {
        final doc = await _firestore.collection('ride_requests').doc(rideId).get();
        final capId = doc.data()?['assignedCaptainId'] as String?;
        if (capId != null) {
          _rtdb.ref().child('live/captains/$capId/isBusy').set(false);
        }
      } catch (_) {}
    }
  }

  final Map<String, Map<String, dynamic>> _captainProfileCache = {};

  static bool matchesVehicleType(String captainVehicleType, String requestedVehicleType) {
    final cap = captainVehicleType.toLowerCase().trim();
    final req = requestedVehicleType.toLowerCase().trim();
    if (req == 'bike') return cap == 'bike';
    if (req == 'auto') return cap == 'auto';
    if (req == 'cab') return cap == 'cab' || cap == 'car';
    if (req == 'parcel') return cap == 'parcel' || cap == 'bike';
    return cap == req;
  }

  /// Streams nearest online, available captains matching [vehicleType] around [pickupLat, pickupLng]
  /// directly from Firebase Realtime Database in real time.
  Stream<List<Map<String, dynamic>>> streamNearbyAvailableCaptains({
    required double pickupLat,
    required double pickupLng,
    required String vehicleType,
    double radiusMeters = 6000,
  }) {
    return _rtdb.ref().child('live/captains').onValue.asyncMap((event) async {
      if (!event.snapshot.exists || event.snapshot.value == null) {
        return <Map<String, dynamic>>[];
      }

      final rawData = event.snapshot.value;
      if (rawData is! Map) {
        return <Map<String, dynamic>>[];
      }

      final nowMs = DateTime.now().millisecondsSinceEpoch;
      final List<Map<String, dynamic>> nearbyList = [];

      for (final entry in rawData.entries) {
        final captainId = entry.key.toString();
        final capData = entry.value;
        if (capData is! Map) continue;

        // Verify captain is online
        final isOnline = capData['online'] == true;
        if (!isOnline) continue;

        // Verify captain is not busy on an ongoing trip
        final isBusy = capData['isBusy'] == true;
        if (isBusy) continue;

        // Discard stale locations (> 10 mins without update)
        final updatedAt = capData['updatedAt'];
        if (updatedAt is num && (nowMs - updatedAt) > 10 * 60 * 1000) {
          continue;
        }

        final lat = (capData['lat'] as num?)?.toDouble();
        final lng = (capData['lng'] as num?)?.toDouble();
        final heading = (capData['heading'] as num?)?.toDouble() ?? 0.0;
        if (lat == null || lng == null) continue;

        // Distance check
        final distance = Geolocator.distanceBetween(pickupLat, pickupLng, lat, lng);
        if (distance > radiusMeters) continue;

        // Resolve vehicle type
        String? cVehicleType = capData['vehicleType']?.toString().toLowerCase().trim();
        if (cVehicleType == null || cVehicleType.isEmpty) {
          if (_captainProfileCache.containsKey(captainId)) {
            final profile = _captainProfileCache[captainId];
            if (profile?['isVerified'] != true) continue;
            cVehicleType = profile?['vehicleType'];
          } else {
            try {
              final userDoc = await _firestore.collection('users').doc(captainId).get();
              if (!userDoc.exists) continue;
              final uData = userDoc.data()!;
              final isVerified = uData['role'] == 'captain' && uData['verificationStatus'] == 'verified';
              cVehicleType = (uData['vehicleType'] as String?)?.toLowerCase().trim() ?? 'bike';
              _captainProfileCache[captainId] = {
                'isVerified': isVerified,
                'vehicleType': cVehicleType,
              };
              if (!isVerified) continue;
            } catch (_) {
              continue;
            }
          }
        }

        if (cVehicleType == null) continue;

        // Only display vehicles matching selected ride type
        if (!matchesVehicleType(cVehicleType, vehicleType)) continue;

        nearbyList.add({
          'id': captainId,
          'lat': lat,
          'lng': lng,
          'heading': heading,
          'vehicleType': cVehicleType,
          'distance': distance,
        });
      }

      // Sort nearest first
      nearbyList.sort((a, b) => (a['distance'] as double).compareTo(b['distance'] as double));
      return nearbyList;
    });
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
