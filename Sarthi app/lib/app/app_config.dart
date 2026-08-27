import 'package:flutter_riverpod/flutter_riverpod.dart';

enum AppType { user, captain, admin }

class AppConfig {
  final AppType appType;

  const AppConfig({required this.appType});

  String get appName =>
      appType == AppType.admin ? 'Sarthi App Admin' : 'Sarthi App';
}

/// Provider to hold the current app's configuration.
/// This will be overridden in the ProviderScope in each main_*.dart file.
final appConfigProvider = Provider<AppConfig>((ref) {
  throw UnimplementedError('appConfigProvider must be overridden');
});
