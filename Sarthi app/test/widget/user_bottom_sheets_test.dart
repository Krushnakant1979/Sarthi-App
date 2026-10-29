import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sarthi_app/core/design/theme.dart';
import 'package:sarthi_app/features/user/map/presentation/widgets/searching_bottom_sheet.dart';
import 'package:sarthi_app/features/user/map/presentation/widgets/completed_bottom_sheet.dart';
import 'package:sarthi_app/features/user/map/presentation/widgets/drag_handle.dart';

void main() {
  group('User App Bottom Sheet Widget Tests', () {
    testWidgets('DragHandle renders properly without layout exceptions', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const Scaffold(
            body: Center(
              child: DragHandle(),
            ),
          ),
        ),
      );

      expect(find.byType(DragHandle), findsOneWidget);
    });

    testWidgets('SearchingBottomSheet renders cancel action and fires callback on tap',
        (tester) async {
      bool cancelTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: SearchingBottomSheet(
              onCancelRequest: () {
                cancelTapped = true;
              },
            ),
          ),
        ),
      );

      // Verify Cancel Request button is present
      expect(find.text('Cancel Request'), findsOneWidget);
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);

      // Tap Cancel Request
      await tester.tap(find.text('Cancel Request'));
      await tester.pump();

      expect(cancelTapped, isTrue);
    });

    testWidgets('CompletedBottomSheet renders fare amount and Done / Rate buttons',
        (tester) async {
      bool doneTapped = false;
      String? ratedCaptainId;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: CompletedBottomSheet(
              fare: 154,
              paymentMethod: 'Cash',
              captainId: 'captain_test_123',
              onDone: () {
                doneTapped = true;
              },
              onRateCaptain: (id, {captainName, rideId}) {
                ratedCaptainId = id;
              },
            ),
          ),
        ),
      );

      // Verify ride completion headers
      expect(find.text('Ride completed!'), findsOneWidget);
      expect(find.text('Thanks for riding with Sarthi.'), findsOneWidget);
      expect(find.text('TOTAL PAID'), findsOneWidget);
      expect(find.text('₹154'), findsOneWidget);
      expect(find.text('Cash'), findsOneWidget);

      // Test Done button callback
      expect(find.text('Done'), findsOneWidget);
      await tester.tap(find.text('Done'));
      await tester.pump();
      expect(doneTapped, isTrue);

      // Test Rate captain button callback
      expect(find.text('Rate captain'), findsOneWidget);
      await tester.tap(find.text('Rate captain'));
      await tester.pump();
      expect(ratedCaptainId, 'captain_test_123');
    });
  });
}
