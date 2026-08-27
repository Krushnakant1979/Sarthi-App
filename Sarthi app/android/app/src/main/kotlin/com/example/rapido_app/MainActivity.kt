package com.example.rapido_app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity: FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        flutterEngine.platformViewsController.registry.registerViewFactory(
            "sarthi/ola_map",
            OlaMapPlatformViewFactory(flutterEngine.dartExecutor.binaryMessenger)
        )
    }
}
