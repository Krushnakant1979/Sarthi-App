import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:sarthi_app/app/router.dart';
import 'package:sarthi_app/app/app_config.dart';
import 'package:sarthi_app/core/utils/location_service.dart';
import 'package:sarthi_app/core/error/error_logger.dart';
import 'package:sarthi_app/main.dart'; 

Future<void> bootstrap({required String env, required AppType appType}) async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Load environment variables
  await dotenv.load(fileName: ".env");
  
  // Initialize Firebase
  await Firebase.initializeApp();

  // Initialize App Check (using debug for now, can be configured for prod)
  await FirebaseAppCheck.instance.activate(
    androidProvider: env == 'dev' ? AndroidProvider.debug : AndroidProvider.playIntegrity,
  );

  // Initialize Error Logger (Crashlytics)
  ErrorLogger.initialize();

  // Pre-warm the GPS chip so the first fix in map/search arrives instantly.
  unawaited(LocationService.warmUp());

  runApp(
    ProviderScope(
      overrides: [
        appConfigProvider.overrideWithValue(AppConfig(appType: appType)),
      ],
      child: const SarthiApp(), // SarthiApp is defined in main.dart
    ),
  );
}
