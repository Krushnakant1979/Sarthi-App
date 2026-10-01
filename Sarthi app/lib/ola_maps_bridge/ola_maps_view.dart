import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:device_info_plus/device_info_plus.dart';

class OlaMapsView extends StatefulWidget {
  final Function(OlaMapsController) onMapCreated;
  final bool showUserDot;

  const OlaMapsView({
    super.key,
    required this.onMapCreated,
    this.showUserDot = true,
  });

  @override
  State<OlaMapsView> createState() => _OlaMapsViewState();
}

class _OlaMapsViewState extends State<OlaMapsView> {
  bool? _isEmulator;

  @override
  void initState() {
    super.initState();
    _checkEmulator();
  }

  Future<void> _checkEmulator() async {
    final deviceInfo = DeviceInfoPlugin();
    final androidInfo = await deviceInfo.androidInfo;
    setState(() {
      _isEmulator = !androidInfo.isPhysicalDevice;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isEmulator == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return PlatformViewLink(
      viewType: 'sarthi/ola_map',
      surfaceFactory: (context, controller) {
        return AndroidViewSurface(
          controller: controller as AndroidViewController,
          gestureRecognizers: const <Factory<OneSequenceGestureRecognizer>>{},
          hitTestBehavior: PlatformViewHitTestBehavior.opaque,
        );
      },
      onCreatePlatformView: (params) {
        // Physical devices (Impeller/Vulkan) crash with TLHC on MapLibre, so they need Expensive (SurfaceView)
        // Emulators show a pure black screen with Expensive, so they need Surface (TLHC)
        final controller = _isEmulator!
            ? PlatformViewsService.initSurfaceAndroidView(
                id: params.id,
                viewType: 'sarthi/ola_map',
                layoutDirection: TextDirection.ltr,
                creationParams: <String, dynamic>{
                  'showUserDot': widget.showUserDot,
                },
                creationParamsCodec: const StandardMessageCodec(),
                onFocus: () => params.onFocusChanged(true),
              )
            : PlatformViewsService.initExpensiveAndroidView(
                id: params.id,
                viewType: 'sarthi/ola_map',
                layoutDirection: TextDirection.ltr,
                creationParams: <String, dynamic>{
                  'showUserDot': widget.showUserDot,
                },
                creationParamsCodec: const StandardMessageCodec(),
                onFocus: () => params.onFocusChanged(true),
              );

        controller
          ..addOnPlatformViewCreatedListener(params.onPlatformViewCreated)
          ..addOnPlatformViewCreatedListener((id) {
            widget.onMapCreated(OlaMapsController(id));
          })
          ..create();

        return controller;
      },
    );
  }
}

class OlaMapsController {
  final MethodChannel _channel;
  final EventChannel _eventChannel;

  OlaMapsController(int id)
    : _channel = MethodChannel('sarthi/ola_map_$id'),
      _eventChannel = EventChannel('sarthi/ola_map_events_$id');

  Future<void> moveCamera(double lat, double lng, {double zoom = 14.0}) async {
    await _channel.invokeMethod('moveCamera', {
      'lat': lat,
      'lng': lng,
      'zoom': zoom,
    });
  }

  Future<void> fitBounds(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) async {
    await _channel.invokeMethod('fitBounds', {
      'lat1': lat1,
      'lng1': lng1,
      'lat2': lat2,
      'lng2': lng2,
    });
  }

  Future<bool> addMarker(
    double lat,
    double lng, {
    String? title,
    bool isPickup = false,
    bool isCaptain = false,
  }) async {
    final success = await _channel.invokeMethod<bool>('addMarker', {
      'lat': lat,
      'lng': lng,
      'title': title,
      'isPickup': isPickup,
      'isCaptain': isCaptain,
    });
    return success ?? false;
  }

  Future<void> updateUserLocation(
    double lat,
    double lng, {
    double? heading,
  }) async {
    await _channel.invokeMethod('updateUserLocation', {
      'lat': lat,
      'lng': lng,
      'heading': heading,
    });
  }

  Future<void> toggleNativeUserLocation(bool show) async {
    await _channel.invokeMethod('toggleNativeUserLocation', {'show': show});
  }

  Future<void> drawPolyline({
    String? polyline,
    List<Map<String, dynamic>>? points,
    String? color,
  }) async {
    await _channel.invokeMethod('drawPolyline', {
      'polyline': polyline,
      'points': points,
      'color': color,
    });
  }

  Future<void> clearRoute() async {
    await _channel.invokeMethod('clearRoute');
  }

  /// Shifts the map's camera focal point so the user marker appears
  /// above a bottom sheet. [bottom] is in logical pixels.
  Future<void> setPadding({
    double top = 0,
    double left = 0,
    double bottom = 0,
    double right = 0,
  }) async {
    try {
      await _channel.invokeMethod('setPadding', {
        'top': top,
        'left': left,
        'bottom': bottom,
        'right': right,
      });
    } catch (_) {
      // Silently ignore if native side doesn't support it yet
    }
  }

  Future<bool> callPhone(String phone) async {
    return await _channel.invokeMethod<bool>('callPhone', {'phone': phone}) ??
        false;
  }

  Stream<dynamic> get mapEvents {
    return _eventChannel.receiveBroadcastStream();
  }

}
