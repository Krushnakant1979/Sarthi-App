export const FARE_RULES = {
  bike: { baseFare: 15, includedDistanceKm: 3, ratePerKm: 5, ratePerMinute: 1, minimumFare: 15 },
  auto: { baseFare: 30, includedDistanceKm: 2, ratePerKm: 12, ratePerMinute: 1.5, minimumFare: 30 },
  cab: { baseFare: 50, includedDistanceKm: 2, ratePerKm: 16, ratePerMinute: 2, minimumFare: 50 },
  parcel: { baseFare: 20, includedDistanceKm: 3, ratePerKm: 6, ratePerMinute: 1, minimumFare: 20 }
};

export function calculateFare(distanceMeters, durationSeconds, rules) {
  const totalDistanceKm = distanceMeters / 1000.0;
  const estimatedDurationMinutes = durationSeconds / 60.0;

  const extraDistance = Math.max(0, totalDistanceKm - rules.includedDistanceKm);
  const distanceCharge = extraDistance * rules.ratePerKm;
  const timeCharge = estimatedDurationMinutes * rules.ratePerMinute;

  let calculatedNormalFare = rules.baseFare + distanceCharge + timeCharge;
  let normalFare = Math.max(rules.minimumFare, calculatedNormalFare);

  return Math.ceil(normalFare);
}
