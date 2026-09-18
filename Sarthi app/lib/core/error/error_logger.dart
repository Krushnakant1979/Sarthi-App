import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

class ErrorLogger {
  static void initialize() {
    // Pass all uncaught "fatal" errors from the framework to Crashlytics
    FlutterError.onError = (errorDetails) {
      FirebaseCrashlytics.instance.recordFlutterFatalError(errorDetails);
    };

    // Pass all uncaught asynchronous errors that aren't handled by the Flutter framework to Crashlytics
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };
  }

  static Future<void> logError(dynamic exception, StackTrace? stack, {String? reason}) async {
    if (kDebugMode) {
      print('Caught Error: $exception');
      if (reason != null) print('Reason: $reason');
      if (stack != null) print(stack);
    }
    await FirebaseCrashlytics.instance.recordError(exception, stack, reason: reason);
  }
}
