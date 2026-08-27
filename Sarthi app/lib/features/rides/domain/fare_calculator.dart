class FareCalculator {
  static int calculateFare(
    int distanceMeters,
    int durationSeconds, {
    double baseFare = 15.0,
    double perKm = 5.0,
    double perMin = 1.0,
  }) {
    double distanceKm = distanceMeters / 1000.0;
    double durationMinutes = durationSeconds / 60.0;

    double distanceFare = distanceKm * perKm;
    double durationFare = durationMinutes * perMin;

    double totalFare = baseFare + distanceFare + durationFare;

    return totalFare.round();
  }
}
