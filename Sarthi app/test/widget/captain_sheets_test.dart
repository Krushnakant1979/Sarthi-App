import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sarthi_app/core/design/theme.dart';
import 'package:sarthi_app/features/captain/presentation/widgets/offline_sheet_widget.dart';
import 'package:sarthi_app/features/captain/presentation/widgets/searching_sheet_widget.dart';
import 'package:sarthi_app/features/captain/presentation/widgets/incoming_request_sheet_widget.dart';

void main() {
  group('Captain App Bottom Sheet Widget Tests', () {
    testWidgets('OfflineSheetWidget displays offline status and prompts captain to go online',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const Scaffold(
            body: OfflineSheetWidget(
              dragHandle: SizedBox(key: Key('captain_drag_handle'), height: 4),
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('captain_drag_handle')), findsOneWidget);
      expect(find.text('You are Offline'), findsOneWidget);
      expect(find.text('Go online to start receiving\nride requests near you'), findsOneWidget);
      expect(find.text('Toggle the switch above to go online'), findsOneWidget);
    });

    testWidgets('SearchingSheetWidget displays searching state and online availability indicator',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const Scaffold(
            body: SearchingSheetWidget(
              dragHandle: SizedBox(key: Key('search_drag_handle'), height: 4),
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('search_drag_handle')), findsOneWidget);
      expect(find.text('Searching for Riders'), findsOneWidget);
      expect(find.text("You're online and available"), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('IncomingRequestSheetWidget renders ride request details, addresses, and handles actions',
        (tester) async {
      bool acceptTapped = false;
      bool skipTapped = false;

      final testRequest = {
        'id': 'ride_req_999',
        'fareEstimate': 120,
        'distanceMeters': 5400,
        'pickup': {'address': 'Indiranagar 100ft Road, Bengaluru'},
        'destination': {'address': 'HSR Layout Sector 2, Bengaluru'},
        'vehicleType': 'bike',
      };

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: IncomingRequestSheetWidget(
              request: testRequest,
              dragHandle: const SizedBox(height: 4),
              onAccept: () {
                acceptTapped = true;
              },
              onSkip: () {
                skipTapped = true;
              },
              isActionLoading: false,
            ),
          ),
        ),
      );

      // Verify fare display
      expect(find.text('₹120'), findsOneWidget);

      // Verify pickup & destination addresses appear
      expect(find.textContaining('Indiranagar 100ft Road'), findsWidgets);
      expect(find.textContaining('HSR Layout Sector 2'), findsWidgets);

      // Verify Accept action
      final acceptFinder = find.text('Accept ride');
      expect(acceptFinder, findsOneWidget);
      await tester.tap(acceptFinder);
      await tester.pump();
      expect(acceptTapped, isTrue);

      // Verify Skip action
      final skipFinder = find.text('Skip');
      expect(skipFinder, findsOneWidget);
      await tester.tap(skipFinder);
      await tester.pump();
      expect(skipTapped, isTrue);
    });
  });
}
