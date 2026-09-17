import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../shared/auth/domain/app_user.dart';

class AdminRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Stream<List<AppUser>> streamAllUsers() {
    return _firestore.collection('users').snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => AppUser.fromMap(doc.data(), doc.id))
          .toList();
    });
  }

  Stream<List<Map<String, dynamic>>> streamAllRides() {
    return _firestore
        .collection('ride_requests')
        .orderBy('createdAt', descending: true)
        .limit(500)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            final data = doc.data();
            data['id'] = doc.id;
            return data;
          }).toList();
        });
  }

  Stream<Map<String, dynamic>?> streamFareRules(String vehicleType) {
    return _firestore
        .collection('fare_rules')
        .doc('${vehicleType}_default')
        .snapshots()
        .map((doc) {
          if (doc.exists) {
            return doc.data();
          }
          return null;
        });
  }

  Future<Map<String, dynamic>> getFareRules(String vehicleType) async {
    final doc = await _firestore
        .collection('fare_rules')
        .doc('${vehicleType}_default')
        .get();
    if (doc.exists && doc.data() != null) {
      final d = doc.data()!;
      return {
        'baseFare': d['baseFare']?.toDouble() ?? 15.0,
        'includedDistance': d['includedDistance']?.toDouble() ?? 3.0,
        'perKmFare': d['perKm']?.toDouble() ?? 5.0,
        'perMinuteFare': d['perMin']?.toDouble() ?? 1.0,
        'minimumFare': d['minimumFare']?.toDouble() ?? 15.0,
        'freeWaitingTime': d['freeWaitingTime']?.toDouble() ?? 3.0,
        'waitingChargePerMin': d['waitingChargePerMin']?.toDouble() ?? 1.0,
        'dynamicPricingEnabled': d['dynamicPricingEnabled'] ?? false,
        'surgeMultiplier': d['surgeMultiplier']?.toDouble() ?? 1.0,
        'surgeReason': d['surgeReason'] ?? '',
        'surgeStartTime': (d['surgeStartTime'] as Timestamp?)?.toDate(),
        'surgeEndTime': (d['surgeEndTime'] as Timestamp?)?.toDate(),
      };
    }
    return {
      'baseFare': 15.0,
      'includedDistance': 3.0,
      'perKmFare': 5.0,
      'perMinuteFare': 1.0,
      'minimumFare': 15.0,
      'freeWaitingTime': 3.0,
      'waitingChargePerMin': 1.0,
      'dynamicPricingEnabled': false,
      'surgeMultiplier': 1.0,
      'surgeReason': '',
      'surgeStartTime': null,
      'surgeEndTime': null,
    };
  }

  Future<void> updateUserRole(String uid, String role) async {
    if (!const {'user', 'captain', 'admin'}.contains(role)) {
      throw ArgumentError.value(role, 'role');
    }
    if (_auth.currentUser?.uid == uid && role != 'admin') {
      throw StateError('You cannot remove your own admin access.');
    }
    await _firestore.collection('users').doc(uid).update({'role': role});
    await _writeAudit('user_role_changed', uid, {'role': role});
  }

  Future<void> updateCaptainVerification(String uid, String status) async {
    if (!const {'verified', 'rejected'}.contains(status)) {
      throw ArgumentError.value(status, 'status');
    }
    await _firestore.collection('users').doc(uid).update({
      'verificationStatus': status,
      'verificationUpdatedAt': FieldValue.serverTimestamp(),
    });
    await _writeAudit('captain_verification_changed', uid, {'status': status});
  }

  Future<void> updateFareRules(
    String vehicleType,
    double baseFare,
    double includedDistanceKm,
    double perKm,
    double perMin,
    double minimumFare,
    double freeWaitingMinutes,
    double waitingPerMin,
    bool surgeEnabled,
    double surgeMultiplier,
    String? surgeReason,
    DateTime? surgeStartAt,
    DateTime? surgeEndAt,
  ) async {
    final payload = {
      'baseFare': baseFare,
      'includedDistanceKm': includedDistanceKm,
      'perKm': perKm,
      'perMin': perMin,
      'minimumFare': minimumFare,
      'freeWaitingMinutes': freeWaitingMinutes,
      'waitingPerMin': waitingPerMin,
      'surgeEnabled': surgeEnabled,
      'surgeMultiplier': surgeMultiplier,
      'surgeReason': surgeReason,
      'surgeStartAt': surgeStartAt != null
          ? Timestamp.fromDate(surgeStartAt)
          : null,
      'surgeEndAt': surgeEndAt != null ? Timestamp.fromDate(surgeEndAt) : null,
      'pricingVersion': FieldValue.increment(1),
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': _auth.currentUser?.uid ?? 'unknown',
    };
    await _firestore
        .collection('fare_rules')
        .doc('${vehicleType}_default')
        .set(payload, SetOptions(merge: true));

    // Write audit logic
    final auditPayload = Map<String, dynamic>.from(payload);
    auditPayload.remove('updatedAt');
    auditPayload.remove('pricingVersion');
    await _writeAudit(
      'fare_rules_changed',
      '${vehicleType}_default',
      auditPayload,
    );
  }

  Future<void> settleCaptainPayout(
    String captainId,
    List<String> rideIds,
    double amount,
  ) async {
    final batch = _firestore.batch();
    for (final rideId in rideIds) {
      batch.update(_firestore.collection('ride_requests').doc(rideId), {
        'isSettled': true,
      });
    }

    final payoutRef = _firestore.collection('payout_history').doc();
    batch.set(payoutRef, {
      'captainId': captainId,
      'amount': amount,
      'rideIds': rideIds,
      'status': 'completed',
      'settledAt': FieldValue.serverTimestamp(),
      'settledBy': _auth.currentUser?.uid,
    });

    await batch.commit();
    await _writeAudit('payout_settled', captainId, {
      'amount': amount,
      'ridesCount': rideIds.length,
    });
  }

  Stream<List<Map<String, dynamic>>> streamPayoutHistory() {
    return _firestore
        .collection('payout_history')
        .orderBy('settledAt', descending: true)
        .limit(100)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            final data = doc.data();
            data['id'] = doc.id;
            return data;
          }).toList();
        });
  }

  Stream<List<Map<String, dynamic>>> streamOffers() {
    return _firestore
        .collection('offers')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            final data = doc.data();
            data['id'] = doc.id;
            return data;
          }).toList();
        });
  }

  Future<void> createOffer(Map<String, dynamic> offerData) async {
    offerData['createdAt'] = FieldValue.serverTimestamp();
    offerData['createdBy'] = _auth.currentUser?.uid;
    if (!offerData.containsKey('status')) offerData['status'] = 'published';
    final ref = await _firestore.collection('offers').add(offerData);
    await _writeAudit('offer_created', ref.id, offerData);
  }

  Future<void> updateOffer(String id, Map<String, dynamic> updates) async {
    updates['updatedAt'] = FieldValue.serverTimestamp();
    await _firestore.collection('offers').doc(id).update(updates);
    await _writeAudit('offer_updated', id, updates);
  }

  Future<void> deleteOffer(String id) async {
    await _firestore.collection('offers').doc(id).delete();
    await _writeAudit('offer_deleted', id, {});
  }

  Future<Map<String, dynamic>> fetchAnalyticsData() async {
    final snapshot = await _firestore
        .collection('ride_requests')
        .where('status', isEqualTo: 'completed')
        .get();

    double totalRevenue = 0;
    int totalRides = snapshot.docs.length;
    Map<String, int> locationCounts = {};
    Map<int, double> weeklyRevenue = {for (var i = 0; i < 7; i++) i: 0.0};

    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);

    for (var doc in snapshot.docs) {
      final data = doc.data();
      final fare = (data['fareEstimate'] as num?)?.toDouble() ?? 0.0;
      totalRevenue += fare;

      final pickupAddress = data['pickup']?['address'] as String?;
      if (pickupAddress != null &&
          pickupAddress.isNotEmpty &&
          pickupAddress != 'User pickup location') {
        final parts = pickupAddress.split(',').map((e) => e.trim()).toList();
        String city = parts.first;

        int offset = parts.length - 1;
        if (offset >= 0 && parts[offset].toLowerCase() == 'india') {
          offset--;
        }
        if (offset >= 0 && RegExp(r'^\d+$').hasMatch(parts[offset])) {
          offset--;
        }
        if (offset - 1 >= 0) {
          city = parts[offset - 1].replaceAll(RegExp(r'\d'), '').trim();
        }

        if (city.isNotEmpty) {
          locationCounts[city] = (locationCounts[city] ?? 0) + 1;
        }
      }

      final createdAt = data['createdAt'];
      if (createdAt is Timestamp) {
        final date = createdAt.toDate();
        final diffDays = startOfToday
            .difference(DateTime(date.year, date.month, date.day))
            .inDays;
        if (diffDays >= 0 && diffDays < 7) {
          weeklyRevenue[diffDays] = (weeklyRevenue[diffDays] ?? 0.0) + fare;
        }
      }
    }

    final topLocations = locationCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final activeCaptainsQuery = await _firestore
        .collection('users')
        .where('role', isEqualTo: 'captain')
        .get();

    return {
      'totalRevenue': totalRevenue,
      'totalRides': totalRides,
      'averageFare': totalRides > 0 ? totalRevenue / totalRides : 0.0,
      'weeklyRevenue': weeklyRevenue.values.toList(),
      'topLocations': topLocations
          .take(5)
          .map((e) => {'name': e.key, 'count': e.value})
          .toList(),
      'activeCaptains': activeCaptainsQuery.docs.length,
    };
  }

  Stream<List<Map<String, dynamic>>> streamAnalyticsRides(
    DateTime start,
    DateTime end,
  ) {
    return _firestore
        .collection('ride_requests')
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('createdAt', isLessThan: Timestamp.fromDate(end))
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) {
                final data = doc.data();
                data['id'] = doc.id;
                return data;
              })
              .where((data) => data['status'] == 'completed')
              .toList();
        });
  }

  Stream<int> streamActiveCaptainsCount() {
    return _firestore
        .collection('users')
        .where('role', isEqualTo: 'captain')
        .snapshots()
        .map((snap) => snap.docs.length);
  }

  Stream<Map<String, dynamic>> streamGlobalSettings() {
    return _firestore
        .collection('config')
        .doc('global_settings')
        .snapshots()
        .map((doc) {
          if (!doc.exists) {
            return {
              'isPlatformActive': true,
              'supportEmail': 'support@rapido.com',
              'supportPhone': '1800-000-000',
              'activeZones': <String>[],
            };
          }
          return doc.data() as Map<String, dynamic>;
        });
  }

  Future<void> updateGlobalSettings(Map<String, dynamic> updates) async {
    await _firestore
        .collection('config')
        .doc('global_settings')
        .set(updates, SetOptions(merge: true));
    await _writeAudit('settings_updated', 'global_settings', updates);
  }

  Future<void> addActiveZone(String city) async {
    if (city.trim().isEmpty) return;
    await _firestore.collection('config').doc('global_settings').set({
      'activeZones': FieldValue.arrayUnion([city.trim()]),
    }, SetOptions(merge: true));
    await _writeAudit('zone_added', city, {});
  }

  Future<void> removeActiveZone(String city) async {
    await _firestore.collection('config').doc('global_settings').set({
      'activeZones': FieldValue.arrayRemove([city]),
    }, SetOptions(merge: true));
    await _writeAudit('zone_removed', city, {});
  }

  Stream<List<Map<String, dynamic>>> streamSupportTickets() {
    return _firestore
        .collection('support_tickets')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            final data = doc.data();
            data['id'] = doc.id;
            return data;
          }).toList();
        });
  }

  Future<void> resolveTicket(String ticketId, String resolutionMessage) async {
    await _firestore.collection('support_tickets').doc(ticketId).update({
      'status': 'resolved',
      'resolutionMessage': resolutionMessage,
      'resolvedAt': FieldValue.serverTimestamp(),
      'resolvedBy': _auth.currentUser?.uid,
    });
    await _writeAudit('ticket_resolved', ticketId, {
      'resolutionMessage': resolutionMessage,
    });
  }

  Future<void> _writeAudit(
    String action,
    String targetId,
    Map<String, dynamic> changes,
  ) async {
    final actor = _auth.currentUser;
    await _firestore.collection('admin_audit_logs').add({
      'action': action,
      'targetId': targetId,
      'changes': changes,
      'adminUid': actor?.uid,
      'adminEmail': actor?.email,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}
