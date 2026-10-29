import 'package:flutter_test/flutter_test.dart';
import 'package:sarthi_app/features/user/rides/data/ride_repository.dart';
import 'package:sarthi_app/features/user/rides/presentation/ride_providers.dart';
import 'package:geolocator/geolocator.dart';

void main() {
  group('Nearby Captains Unit Tests', () {
    group('RideRepository.matchesVehicleType', () {
      test('matches exact ride types', () {
        expect(RideRepository.matchesVehicleType('bike', 'bike'), isTrue);
        expect(RideRepository.matchesVehicleType('auto', 'auto'), isTrue);
        expect(RideRepository.matchesVehicleType('cab', 'cab'), isTrue);
        expect(RideRepository.matchesVehicleType('parcel', 'parcel'), isTrue);
      });

      test('matches cab aliases (car)', () {
        expect(RideRepository.matchesVehicleType('car', 'cab'), isTrue);
        expect(RideRepository.matchesVehicleType('cab', 'cab'), isTrue);
        expect(RideRepository.matchesVehicleType('bike', 'cab'), isFalse);
        expect(RideRepository.matchesVehicleType('auto', 'cab'), isFalse);
      });

      test('matches parcel eligibility (bikes can deliver parcels)', () {
        expect(RideRepository.matchesVehicleType('bike', 'parcel'), isTrue);
        expect(RideRepository.matchesVehicleType('parcel', 'parcel'), isTrue);
        expect(RideRepository.matchesVehicleType('auto', 'parcel'), isFalse);
        expect(RideRepository.matchesVehicleType('cab', 'parcel'), isFalse);
      });

      test('is case-insensitive and trims whitespace', () {
        expect(RideRepository.matchesVehicleType(' Bike ', 'bike'), isTrue);
        expect(RideRepository.matchesVehicleType('AUTO', 'auto'), isTrue);
        expect(RideRepository.matchesVehicleType(' Car ', 'CAB'), isTrue);
      });

      test('rejects mismatched vehicle types', () {
        expect(RideRepository.matchesVehicleType('auto', 'bike'), isFalse);
        expect(RideRepository.matchesVehicleType('cab', 'bike'), isFalse);
        expect(RideRepository.matchesVehicleType('bike', 'auto'), isFalse);
        expect(RideRepository.matchesVehicleType('car', 'auto'), isFalse);
      });
    });

    group('NearbyCaptainsQuery Equality & HashCode', () {
      test('equal instances produce equal hashCodes and equality', () {
        const query1 = NearbyCaptainsQuery(
          pickupLat: 12.9716,
          pickupLng: 77.5946,
          vehicleType: 'bike',
          radiusMeters: 5000,
        );

        const query2 = NearbyCaptainsQuery(
          pickupLat: 12.9716,
          pickupLng: 77.5946,
          vehicleType: 'bike',
          radiusMeters: 5000,
        );

        expect(query1, equals(query2));
        expect(query1.hashCode, equals(query2.hashCode));
      });

      test('different vehicle types or locations are not equal', () {
        const query1 = NearbyCaptainsQuery(
          pickupLat: 12.9716,
          pickupLng: 77.5946,
          vehicleType: 'bike',
        );

        const query2 = NearbyCaptainsQuery(
          pickupLat: 12.9716,
          pickupLng: 77.5946,
          vehicleType: 'auto',
        );

        const query3 = NearbyCaptainsQuery(
          pickupLat: 12.9720,
          pickupLng: 77.5946,
          vehicleType: 'bike',
        );

        expect(query1, isNot(equals(query2)));
        expect(query1, isNot(equals(query3)));
      });
    });

    group('Proximity & Freshness Filtering Logic', () {
      test('computes distance and sorts nearest vehicles first', () {
        const pickupLat = 12.9715987;
        const pickupLng = 77.5945627;

        // Vehicle A: ~110m away
        const latA = 12.9725987;
        const lngA = 77.5945627;
        final distA = Geolocator.distanceBetween(pickupLat, pickupLng, latA, lngA);

        // Vehicle B: ~550m away
        const latB = 12.9765987;
        const lngB = 77.5945627;
        final distB = Geolocator.distanceBetween(pickupLat, pickupLng, latB, lngB);

        // Vehicle C: ~2200m away
        const latC = 12.9915987;
        const lngC = 77.5945627;
        final distC = Geolocator.distanceBetween(pickupLat, pickupLng, latC, lngC);

        final vehicles = [
          {'id': 'c', 'distance': distC},
          {'id': 'a', 'distance': distA},
          {'id': 'b', 'distance': distB},
        ];

        vehicles.sort((x, y) => (x['distance'] as double).compareTo(y['distance'] as double));

        expect(vehicles[0]['id'], 'a');
        expect(vehicles[1]['id'], 'b');
        expect(vehicles[2]['id'], 'c');
      });

      test('discards timestamps older than 10 minutes', () {
        final nowMs = DateTime.now().millisecondsSinceEpoch;
        final recentTimestamp = nowMs - (2 * 60 * 1000); // 2 minutes ago
        final staleTimestamp = nowMs - (11 * 60 * 1000); // 11 minutes ago

        bool isFresh(num updatedAt) => (nowMs - updatedAt) <= 10 * 60 * 1000;

        expect(isFresh(recentTimestamp), isTrue);
        expect(isFresh(staleTimestamp), isFalse);
      });
    });
  });
}
