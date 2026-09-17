import 'dart:math' as math;

class FareBreakdown {
  final double baseFare;
  final double includedDistance;
  final double extraDistance;
  final double distanceCharge;
  final double estimatedDuration;
  final double timeCharge;
  final double normalFare;
  final double surgeMultiplier;
  final double surgeAmount;
  final double waitingCharge;
  final double tollAndParking;
  final double discount;
  final double finalFare;

  FareBreakdown({
    required this.baseFare,
    required this.includedDistance,
    required this.extraDistance,
    required this.distanceCharge,
    required this.estimatedDuration,
    required this.timeCharge,
    required this.normalFare,
    required this.surgeMultiplier,
    required this.surgeAmount,
    required this.waitingCharge,
    required this.tollAndParking,
    required this.discount,
    required this.finalFare,
  });

  Map<String, dynamic> toMap() {
    return {
      'baseFare': baseFare,
      'includedDistance': includedDistance,
      'extraDistance': extraDistance,
      'distanceCharge': distanceCharge,
      'estimatedDuration': estimatedDuration,
      'timeCharge': timeCharge,
      'normalFare': normalFare,
      'surgeMultiplier': surgeMultiplier,
      'surgeAmount': surgeAmount,
      'waitingCharge': waitingCharge,
      'tollAndParking': tollAndParking,
      'discount': discount,
      'finalFare': finalFare,
    };
  }

  factory FareBreakdown.fromMap(Map<String, dynamic> map) {
    return FareBreakdown(
      baseFare: (map['baseFare'] ?? 0.0).toDouble(),
      includedDistance: (map['includedDistance'] ?? 0.0).toDouble(),
      extraDistance: (map['extraDistance'] ?? 0.0).toDouble(),
      distanceCharge: (map['distanceCharge'] ?? 0.0).toDouble(),
      estimatedDuration: (map['estimatedDuration'] ?? 0.0).toDouble(),
      timeCharge: (map['timeCharge'] ?? 0.0).toDouble(),
      normalFare: (map['normalFare'] ?? 0.0).toDouble(),
      surgeMultiplier: (map['surgeMultiplier'] ?? 1.0).toDouble(),
      surgeAmount: (map['surgeAmount'] ?? 0.0).toDouble(),
      waitingCharge: (map['waitingCharge'] ?? 0.0).toDouble(),
      tollAndParking: (map['tollAndParking'] ?? 0.0).toDouble(),
      discount: (map['discount'] ?? 0.0).toDouble(),
      finalFare: (map['finalFare'] ?? 0.0).toDouble(),
    );
  }
}

class FareCalculator {
  static FareBreakdown calculateFare(
    int distanceMeters,
    int durationSeconds, {
    required double baseFare,
    required double includedDistanceKm,
    required double ratePerKm,
    required double ratePerMinute,
    required double minimumFare,
    required bool dynamicPricingEnabled,
    required double surgeMultiplier,
    DateTime? surgeEndTime,
  }) {
    double totalDistanceKm = distanceMeters / 1000.0;
    double estimatedDurationMinutes = durationSeconds / 60.0;

    double extraDistance = math.max(0.0, totalDistanceKm - includedDistanceKm);
    double distanceCharge = extraDistance * ratePerKm;
    double timeCharge = estimatedDurationMinutes * ratePerMinute;

    double calculatedNormalFare = baseFare + distanceCharge + timeCharge;
    double normalFare = math.max(minimumFare, calculatedNormalFare);

    bool surgeActive = dynamicPricingEnabled;
    if (surgeActive && surgeEndTime != null) {
      if (DateTime.now().isAfter(surgeEndTime)) {
        surgeActive = false;
      }
    }

    double activeMultiplier = surgeActive ? surgeMultiplier : 1.0;
    if (activeMultiplier > 1.5) activeMultiplier = 1.5;

    double fareAfterSurge = normalFare * activeMultiplier;
    double surgeAmount = fareAfterSurge - normalFare;

    // Tolls, parking, discounts, waiting charges are usually applied later in the actual ride lifecycle,
    // but for the initial estimate, we set them to 0.0
    double waitingCharge = 0.0;
    double tollAndParking = 0.0;
    double discount = 0.0;

    double finalFare =
        fareAfterSurge + waitingCharge + tollAndParking - discount;
    finalFare = math
        .max(0.0, finalFare)
        .ceilToDouble(); // round up to next whole rupee

    return FareBreakdown(
      baseFare: baseFare,
      includedDistance: includedDistanceKm,
      extraDistance: extraDistance,
      distanceCharge: distanceCharge,
      estimatedDuration: estimatedDurationMinutes,
      timeCharge: timeCharge,
      normalFare: normalFare,
      surgeMultiplier: activeMultiplier,
      surgeAmount: surgeAmount,
      waitingCharge: waitingCharge,
      tollAndParking: tollAndParking,
      discount: discount,
      finalFare: finalFare,
    );
  }

  static double calculateWaitingCharge(
    int actualWaitingMinutes,
    int freeWaitingMinutes,
    double waitingRatePerMinute,
  ) {
    int chargeableWaitingMinutes = math.max(
      0,
      actualWaitingMinutes - freeWaitingMinutes,
    );
    return chargeableWaitingMinutes * waitingRatePerMinute;
  }
}
