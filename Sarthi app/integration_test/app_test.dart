import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:sarthi_app/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('App starts and shows Login or Home Screen', (WidgetTester tester) async {
    app.main();
    await tester.pumpAndSettle();

    // Verify that the app renders without crashing.
    // The exact widget depends on auth state, but we ensure no exceptions occur during startup.
    expect(find.byType(app.SarthiApp), findsOneWidget);
  });
}
