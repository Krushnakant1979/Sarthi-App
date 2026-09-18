import 'package:flutter_test/flutter_test.dart';
import 'package:sarthi_app/features/user/rides/domain/fare_calculator.dart';

void main() {
  group('FareCalculator Tests', () {
    test('calculateFare returns valid fare for positive distance and duration', () {
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
      expect(breakdown.finalFare > 0, true);
    });

    test('calculateFare handles zero distance correctly', () {
      final breakdown = FareCalculator.calculateFare(
        0, 
        300, // 5 mins
        baseFare: 40.0,
        includedDistanceKm: 2.0,
        ratePerKm: 12.0,
        ratePerMinute: 1.5,
        minimumFare: 50.0,
        dynamicPricingEnabled: false,
        surgeMultiplier: 1.0,
      );
      expect(breakdown.finalFare >= 0, true);
    });
  });
}
