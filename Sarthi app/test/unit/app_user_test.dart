import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sarthi_app/features/shared/auth/domain/app_user.dart';

void main() {
  group('AppUser Domain Model Tests', () {
    test('publicId and shortId format correctly for long and short uids', () {
      final userLong = AppUser(
        uid: 'user_abcdef123456789',
        name: 'John Doe',
        email: 'john@example.com',
        createdAt: DateTime(2026, 1, 1),
      );
      expect(userLong.publicId, 'USER_ABC');
      expect(AppUser.shortId('user_abcdef123456789'), 'USER_ABC');

      final userShort = AppUser(
        uid: 'usr123',
        name: 'Jane Doe',
        email: 'jane@example.com',
        createdAt: DateTime(2026, 1, 1),
      );
      expect(userShort.publicId, 'USR123');
      expect(AppUser.shortId('usr123'), 'USR123');
    });

    test('AppUser initializes with default values for standard user', () {
      final user = AppUser(
        uid: 'user_1',
        name: 'Test Rider',
        email: 'rider@example.com',
        createdAt: DateTime(2026, 1, 1),
      );

      expect(user.role, 'user');
      expect(user.verificationStatus, 'pending');
      expect(user.ratingScore, 0);
      expect(user.ratingCount, 0);
      expect(user.phone, isNull);
      expect(user.aadhaarCardUrl, isNull);
      expect(user.drivingLicenceUrl, isNull);
    });

    test('AppUser toMap and fromMap serialization preserves user and captain fields', () {
      final captain = AppUser(
        uid: 'captain_99',
        name: 'Speedy Captain',
        email: 'captain@sarthi.app',
        phone: '+919876543210',
        role: 'captain',
        verificationStatus: 'verified',
        vehicleType: 'bike',
        vehicleNumber: 'KA-01-AB-1234',
        registrationNumber: 'KA-01-AB-1234',
        aadhaarCardUrl: 'https://cdn.example.com/aadhaar.jpg',
        drivingLicenceUrl: 'https://cdn.example.com/dl.jpg',
        rcBookUrl: 'https://cdn.example.com/rc.jpg',
        insuranceUrl: 'https://cdn.example.com/ins.jpg',
        ratingScore: 4.8,
        ratingCount: 120,
        createdAt: DateTime(2026, 3, 15, 10, 30),
      );

      final map = captain.toMap();
      final parsed = AppUser.fromMap(map, 'captain_99');

      expect(parsed.uid, 'captain_99');
      expect(parsed.name, 'Speedy Captain');
      expect(parsed.email, 'captain@sarthi.app');
      expect(parsed.phone, '+919876543210');
      expect(parsed.role, 'captain');
      expect(parsed.verificationStatus, 'verified');
      expect(parsed.vehicleType, 'bike');
      expect(parsed.vehicleNumber, 'KA-01-AB-1234');
      expect(parsed.registrationNumber, 'KA-01-AB-1234');
      expect(parsed.aadhaarCardUrl, 'https://cdn.example.com/aadhaar.jpg');
      expect(parsed.drivingLicenceUrl, 'https://cdn.example.com/dl.jpg');
      expect(parsed.rcBookUrl, 'https://cdn.example.com/rc.jpg');
      expect(parsed.insuranceUrl, 'https://cdn.example.com/ins.jpg');
      expect(parsed.ratingScore, 4.8);
      expect(parsed.ratingCount, 120);
    });

    test('fromMap handles Timestamp date object and null fallbacks gracefully', () {
      final now = DateTime.now();
      final firestoreTimestamp = Timestamp.fromDate(now);

      final map = {
        'name': 'Fallback Rider',
        'email': 'fallback@rider.com',
        'createdAt': firestoreTimestamp,
        'homeAddress': {'title': 'Home', 'lat': 12.9716, 'lng': 77.5946},
        'workAddress': {'title': 'Work', 'lat': 12.9352, 'lng': 77.6245},
        'recentSearches': [
          {'name': 'Metro Station', 'lat': 12.9750, 'lng': 77.6000}
        ],
      };

      final parsed = AppUser.fromMap(map, 'uid_fallback');

      expect(parsed.name, 'Fallback Rider');
      expect(parsed.email, 'fallback@rider.com');
      expect(parsed.homeAddress?['title'], 'Home');
      expect(parsed.workAddress?['title'], 'Work');
      expect(parsed.recentSearches?.length, 1);
      expect(parsed.recentSearches?.first['name'], 'Metro Station');
      expect(parsed.createdAt.millisecondsSinceEpoch ~/ 1000,
          now.millisecondsSinceEpoch ~/ 1000);
    });
  });
}
