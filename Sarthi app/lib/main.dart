import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app/router.dart';
import 'app/app_config.dart';
import 'core/design/theme.dart';
import 'bootstrap.dart';

void main() {
  // Default entry point for DEVELOPMENT
  bootstrap(env: 'dev', appType: AppType.user);
}

class SarthiApp extends ConsumerWidget {
  const SarthiApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final appConfig = ref.watch(appConfigProvider);

    return MaterialApp.router(
      title: appConfig.appName,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      debugShowCheckedModeBanner: false,
      routerConfig: router,
    );
  }
}
