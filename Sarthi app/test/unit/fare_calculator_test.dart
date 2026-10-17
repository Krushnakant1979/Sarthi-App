import 'package:flutter_test/flutter_test.dart';
import 'package:sarthi_app/features/user/rides/domain/fare_calculator.dart';

void main() {
  group('FareCalculator Unit Tests', () {
    test('calculateFare returns correct base fare calculation for normal trip', () {
      final breakdown = FareCalculator.calculateFare(
        10000, // 10 km
        1200, // 20 mins
        baseFare: 40.0,
        includedDistanceKm: 2.0,
        ratePerKm: 12.0,
        ratePerMinute: 1.5,
        minimumFare: 50.0,
        dynamicPricingEnabled: false,
        surgeMultiplier: 1.0,
      );

      // Expected calculation:
      // totalDistance = 10.0 km
      // extraDistance = 10.0 - 2.0 = 8.0 km
      // distanceCharge = 8.0 * 12.0 = 96.0
      // durationMinutes = 20.0 min
      // timeCharge = 20.0 * 1.5 = 30.0
      // normalFare = 40.0 + 96.0 + 30.0 = 166.0
      // surge = inactive (1.0)
      // finalFare = ceil(166.0) = 166.0
      expect(breakdown.extraDistance, 8.0);
      expect(breakdown.distanceCharge, 96.0);
      expect(breakdown.timeCharge, 30.0);
      expect(breakdown.normalFare, 166.0);
      expect(breakdown.finalFare, 166.0);
    });

    test('calculateFare enforces minimumFare when normal calculation is lower', () {
      final breakdown = FareCalculator.calculateFare(
        500, // 0.5 km (within included 2.0 km)
        60, // 1 min
        baseFare: 30.0,
        includedDistanceKm: 2.0,
        ratePerKm: 10.0,
        ratePerMinute: 1.0,
        minimumFare: 50.0,
        dynamicPricingEnabled: false,
        surgeMultiplier: 1.0,
      );

      // extraDistance = 0.0
      // distanceCharge = 0.0
      // timeCharge = 1.0 * 1.0 = 1.0
      // calculated = 30.0 + 0 + 1.0 = 31.0
      // normalFare should be clamped to minimumFare = 50.0
      expect(breakdown.extraDistance, 0.0);
      expect(breakdown.normalFare, 50.0);
      expect(breakdown.finalFare, 50.0);
    });

    test('calculateFare handles active surge pricing and calculates surgeAmount', () {
      final breakdown = FareCalculator.calculateFare(
        5000, // 5 km
        600, // 10 mins
        baseFare: 40.0,
        includedDistanceKm: 2.0,
        ratePerKm: 10.0,
        ratePerMinute: 1.0,
        minimumFare: 40.0,
        dynamicPricingEnabled: true,
        surgeMultiplier: 1.4,
      );

      // extraDistance = 3.0 km -> 30.0
      // timeCharge = 10.0 min -> 10.0
      // normalFare = 40.0 + 30.0 + 10.0 = 80.0
      // surge = 1.4 -> fareAfterSurge = 80.0 * 1.4 = 112.0
      // surgeAmount = 112.0 - 80.0 = 32.0
      // finalFare = 112.0
      expect(breakdown.surgeMultiplier, 1.4);
      expect(breakdown.normalFare, 80.0);
      expect(breakdown.surgeAmount, 32.0);
      expect(breakdown.finalFare, 112.0);
    });

    test('calculateFare caps surge multiplier at maximum of 1.5x', () {
      final breakdown = FareCalculator.calculateFare(
        5000,
        600,
        baseFare: 40.0,
        includedDistanceKm: 2.0,
        ratePerKm: 10.0,
        ratePerMinute: 1.0,
        minimumFare: 40.0,
        dynamicPricingEnabled: true,
        surgeMultiplier: 2.5, // Excessive surge input
      );

      // activeMultiplier should be clamped to 1.5
      expect(breakdown.surgeMultiplier, 1.5);
      expect(breakdown.finalFare, 80.0 * 1.5);
    });

    test('calculateFare drops surge multiplier if surgeEndTime has passed', () {
      final pastTime = DateTime.now().subtract(const Duration(minutes: 5));
      final breakdown = FareCalculator.calculateFare(
        5000,
        600,
        baseFare: 40.0,
        includedDistanceKm: 2.0,
        ratePerKm: 10.0,
        ratePerMinute: 1.0,
        minimumFare: 40.0,
        dynamicPricingEnabled: true,
        surgeMultiplier: 1.4,
        surgeEndTime: pastTime,
      );

      // Surge has expired -> activeMultiplier should drop to 1.0
      expect(breakdown.surgeMultiplier, 1.0);
      expect(breakdown.surgeAmount, 0.0);
      expect(breakdown.finalFare, 80.0);
    });

    test('calculateFare rounds up fractional rupee fares with ceilToDouble', () {
      final breakdown = FareCalculator.calculateFare(
        1500, // 1.5 km
        90, // 1.5 mins
        baseFare: 40.0,
        includedDistanceKm: 1.0,
        ratePerKm: 11.5, // extra 0.5 * 11.5 = 5.75
        ratePerMinute: 1.3, // 1.5 * 1.3 = 1.95
        minimumFare: 40.0,
        dynamicPricingEnabled: false,
        surgeMultiplier: 1.0,
      );

      // normal = 40.0 + 5.75 + 1.95 = 47.70
      // ceil(47.70) = 48.0
      expect(breakdown.finalFare, 48.0);
    });

    test('calculateWaitingCharge returns 0 within free waiting window and charges excess', () {
      // 3 minutes waiting when 5 minutes is free -> 0
      final chargeFree = FareCalculator.calculateWaitingCharge(3, 5, 2.0);
      expect(chargeFree, 0.0);

      // 8 minutes waiting with 5 minutes free -> 3 chargeable minutes * ₹2/min = ₹6
      final chargeExcess = FareCalculator.calculateWaitingCharge(8, 5, 2.0);
      expect(chargeExcess, 6.0);
    });

    test('FareBreakdown toMap and fromMap serialization maintains accuracy', () {
      final original = FareBreakdown(
        baseFare: 40.0,
        includedDistance: 2.0,
        extraDistance: 5.0,
        distanceCharge: 60.0,
        estimatedDuration: 15.0,
        timeCharge: 22.5,
        normalFare: 122.5,
        surgeMultiplier: 1.2,
        surgeAmount: 24.5,
        waitingCharge: 10.0,
        tollAndParking: 15.0,
        discount: 20.0,
        finalFare: 152.0,
      );

      final map = original.toMap();
      final parsed = FareBreakdown.fromMap(map);

      expect(parsed.baseFare, original.baseFare);
      expect(parsed.extraDistance, original.extraDistance);
      expect(parsed.distanceCharge, original.distanceCharge);
      expect(parsed.timeCharge, original.timeCharge);
      expect(parsed.surgeMultiplier, original.surgeMultiplier);
      expect(parsed.surgeAmount, original.surgeAmount);
      expect(parsed.waitingCharge, original.waitingCharge);
      expect(parsed.tollAndParking, original.tollAndParking);
      expect(parsed.discount, original.discount);
      expect(parsed.finalFare, original.finalFare);
    });
  });
}
