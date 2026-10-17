import 'package:flutter_test/flutter_test.dart';

bool shouldShowRequestToCaptain({
  required Map<String, dynamic> request,
  required String captainId,
  required String captainVehicleType,
}) {
  // 1. Vehicle type matching
  if (request['vehicleType'] != captainVehicleType) return false;

  // 2. Declined check
  final declinedBy = (request['declinedBy'] as List?) ?? const [];
  if (declinedBy.contains(captainId)) return false;

  // 3. Sequential routing check
  final routingQueue = (request['routingQueue'] as List?)?.cast<String>();
  if (routingQueue != null && routingQueue.isNotEmpty) {
    final currentIndex = request['currentRouteIndex'] as int? ?? 0;

    // Check if captain is in queue
    final indexOfCaptain = routingQueue.indexOf(captainId);
    if (indexOfCaptain == -1) return false;

    // If current index hasn't reached this captain yet
    if (currentIndex < indexOfCaptain) return false;

    // We only show it to the currently targeted captain (index == indexOfCaptain)
    // Or, if the timer exhausted the whole queue (index >= length), show to all in queue
    if (currentIndex != indexOfCaptain && currentIndex < routingQueue.length) {
      return false;
    }
  }

  return true;
}

void main() {
  group('Sequential Dispatch & Captain Incoming Request Filtering Tests', () {
    const captainA = 'captain_alpha';
    const captainB = 'captain_beta';
    const captainC = 'captain_gamma';
    const outsiderCaptain = 'captain_omega';

    test('Filters out requests if vehicle type does not match captain', () {
      final request = {
        'vehicleType': 'auto',
        'routingQueue': [captainA],
        'currentRouteIndex': 0,
        'declinedBy': [],
      };

      // Bike captain should not see auto request
      final shouldShow = shouldShowRequestToCaptain(
        request: request,
        captainId: captainA,
        captainVehicleType: 'bike',
      );
      expect(shouldShow, isFalse);

      // Auto captain should see auto request
      final shouldShowAuto = shouldShowRequestToCaptain(
        request: request,
        captainId: captainA,
        captainVehicleType: 'auto',
      );
      expect(shouldShowAuto, isTrue);
    });

    test('Filters out request if captain has previously declined it', () {
      final request = {
        'vehicleType': 'bike',
        'routingQueue': [captainA, captainB],
        'currentRouteIndex': 0,
        'declinedBy': [captainA],
      };

      final shouldShow = shouldShowRequestToCaptain(
        request: request,
        captainId: captainA,
        captainVehicleType: 'bike',
      );
      expect(shouldShow, isFalse);
    });

    test('Sequentially targets Captain A at index 0, hiding from Captain B and C', () {
      final request = {
        'vehicleType': 'bike',
        'routingQueue': [captainA, captainB, captainC],
        'currentRouteIndex': 0,
        'declinedBy': [],
      };

      // Index 0 -> Captain A sees it
      expect(
        shouldShowRequestToCaptain(
          request: request,
          captainId: captainA,
          captainVehicleType: 'bike',
        ),
        isTrue,
      );

      // Captain B does not see it yet
      expect(
        shouldShowRequestToCaptain(
          request: request,
          captainId: captainB,
          captainVehicleType: 'bike',
        ),
        isFalse,
      );

      // Captain C does not see it yet
      expect(
        shouldShowRequestToCaptain(
          request: request,
          captainId: captainC,
          captainVehicleType: 'bike',
        ),
        isFalse,
      );
    });

    test('Advances to Captain B when index becomes 1', () {
      final request = {
        'vehicleType': 'bike',
        'routingQueue': [captainA, captainB, captainC],
        'currentRouteIndex': 1,
        'declinedBy': [],
      };

      // Captain A no longer sees it (moved to next)
      expect(
        shouldShowRequestToCaptain(
          request: request,
          captainId: captainA,
          captainVehicleType: 'bike',
        ),
        isFalse,
      );

      // Captain B now sees it
      expect(
        shouldShowRequestToCaptain(
          request: request,
          captainId: captainB,
          captainVehicleType: 'bike',
        ),
        isTrue,
      );

      // Captain C still waiting
      expect(
        shouldShowRequestToCaptain(
          request: request,
          captainId: captainC,
          captainVehicleType: 'bike',
        ),
        isFalse,
      );
    });

    test('Exhausted queue falls back to broadcasting to all queued non-declined captains', () {
      final request = {
        'vehicleType': 'bike',
        'routingQueue': [captainA, captainB, captainC],
        'currentRouteIndex': 3, // Exhausted (index >= queue.length)
        'declinedBy': [captainA], // Alpha explicitly declined
      };

      // Alpha declined -> False
      expect(
        shouldShowRequestToCaptain(
          request: request,
          captainId: captainA,
          captainVehicleType: 'bike',
        ),
        isFalse,
      );

      // Beta and Gamma both receive fallback broadcast
      expect(
        shouldShowRequestToCaptain(
          request: request,
          captainId: captainB,
          captainVehicleType: 'bike',
        ),
        isTrue,
      );
      expect(
        shouldShowRequestToCaptain(
          request: request,
          captainId: captainC,
          captainVehicleType: 'bike',
        ),
        isTrue,
      );

      // Outsider not in queue does not receive
      expect(
        shouldShowRequestToCaptain(
          request: request,
          captainId: outsiderCaptain,
          captainVehicleType: 'bike',
        ),
        isFalse,
      );
    });
  });
}
