import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'app/router.dart';
import 'app/app_config.dart';
import 'core/design/theme.dart';

void main() {
  // Default entry point, useful when running from an IDE without specific flavor configuration.
  runSarthiApp(AppType.user);
}

Future<void> runSarthiApp(AppType appType) async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  await Firebase.initializeApp();

  runApp(
    ProviderScope(
      overrides: [
        appConfigProvider.overrideWithValue(AppConfig(appType: appType)),
      ],
      child: const SarthiApp(),
    ),
  );
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
