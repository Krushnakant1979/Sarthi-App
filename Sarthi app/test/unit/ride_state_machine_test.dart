import 'package:flutter_test/flutter_test.dart';

enum RideStatus {
  searching,
  accepted,
  arriving,
  arrived,
  inProgress,
  completed,
  cancelled,
}

class RideStateMachine {
  static const allowedUserCancellations = {'searching', 'accepted', 'arriving'};

  static bool canUserCancel(String currentStatus) {
    return allowedUserCancellations.contains(currentStatus);
  }

  static bool canCaptainTransition(String fromStatus, String toStatus) {
    switch (fromStatus) {
      case 'accepted':
        return toStatus == 'arriving' || toStatus == 'arrived';
      case 'arriving':
        return toStatus == 'arrived';
      case 'arrived':
        return toStatus == 'in_progress';
      case 'in_progress':
        return toStatus == 'completed';
      default:
        return false;
    }
  }

  static bool verifyOtp({
    required String enteredOtp,
    required String actualOtp,
  }) {
    if (enteredOtp.length != 4) return false;
    if (int.tryParse(enteredOtp) == null) return false;
    return enteredOtp == actualOtp;
  }
}

void main() {
  group('Ride State Machine & Transition Tests', () {
    test('Sequential happy path transitions pass validation', () {
      expect(RideStateMachine.canCaptainTransition('accepted', 'arriving'), isTrue);
      expect(RideStateMachine.canCaptainTransition('arriving', 'arrived'), isTrue);
      expect(RideStateMachine.canCaptainTransition('arrived', 'in_progress'), isTrue);
      expect(RideStateMachine.canCaptainTransition('in_progress', 'completed'), isTrue);
    });

    test('Direct jump from accepted to arrived is supported for close pickups', () {
      expect(RideStateMachine.canCaptainTransition('accepted', 'arrived'), isTrue);
    });

    test('Illegal backward or skipped transitions are rejected', () {
      // Cannot jump directly from accepted to completed
      expect(RideStateMachine.canCaptainTransition('accepted', 'completed'), isFalse);
      // Cannot jump directly from arriving to in_progress (must mark arrived and verify OTP first)
      expect(RideStateMachine.canCaptainTransition('arriving', 'in_progress'), isFalse);
      // Cannot revert from completed to in_progress
      expect(RideStateMachine.canCaptainTransition('completed', 'in_progress'), isFalse);
      // Cannot revert from in_progress to searching
      expect(RideStateMachine.canCaptainTransition('in_progress', 'searching'), isFalse);
      // Cannot transition from cancelled
      expect(RideStateMachine.canCaptainTransition('cancelled', 'accepted'), isFalse);
    });

    test('User cancellation permissions adhere to safety and commitment policies', () {
      // Allowed before captain arrives
      expect(RideStateMachine.canUserCancel('searching'), isTrue);
      expect(RideStateMachine.canUserCancel('accepted'), isTrue);
      expect(RideStateMachine.canUserCancel('arriving'), isTrue);

      // Disallowed once captain has arrived or ride is in progress
      expect(RideStateMachine.canUserCancel('arrived'), isFalse);
      expect(RideStateMachine.canUserCancel('in_progress'), isFalse);
      expect(RideStateMachine.canUserCancel('completed'), isFalse);
    });

    test('OTP Verification requires exact 4-digit matching before starting trip', () {
      const generatedOtp = '4829';

      // Correct OTP
      expect(
        RideStateMachine.verifyOtp(enteredOtp: '4829', actualOtp: generatedOtp),
        isTrue,
      );

      // Wrong OTP digits
      expect(
        RideStateMachine.verifyOtp(enteredOtp: '1234', actualOtp: generatedOtp),
        isFalse,
      );

      // Incomplete OTP
      expect(
        RideStateMachine.verifyOtp(enteredOtp: '482', actualOtp: generatedOtp),
        isFalse,
      );

      // Non-numeric characters
      expect(
        RideStateMachine.verifyOtp(enteredOtp: '482a', actualOtp: generatedOtp),
        isFalse,
      );
    });
  });
}
