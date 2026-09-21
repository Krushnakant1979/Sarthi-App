import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/measure_size.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'captain_providers.dart';
import '../../../ola_maps_bridge/ola_maps_view.dart';
import '../../../core/utils/location_service.dart';
import '../../../core/design/tokens.dart';
import '../../user/map/data/ola_maps_repository.dart';

import 'widgets/captain_drawer.dart';

class CaptainMapScreen extends ConsumerStatefulWidget {
  const CaptainMapScreen({super.key});

  @override
  ConsumerState<CaptainMapScreen> createState() => _CaptainMapScreenState();
}

class _CaptainMapScreenState extends ConsumerState<CaptainMapScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _isOnline = false;
  OlaMapsController? _mapController;
  final LocationService _locationService = LocationService();
  bool _isRecentering = false;
  bool _isRideActionLoading = false;
  bool _mapReady = false;
  Position? _lastValidPosition;
  StreamSubscription<Position>? _liveLocationSub;
  StreamSubscription<dynamic>? _mapEventSub;
  Map<String, dynamic>? _navigationTarget;
  bool _navigationTargetIsPickup = true;
  Position? _lastRouteOrigin;
  DateTime? _lastRouteAt;
  int _updateRouteSeq = 0;
  int? _navigationDistanceMeters;
  int? _navigationDurationSeconds;
  final DraggableScrollableController _sheetController =
      DraggableScrollableController();
  final ValueNotifier<double> _sheetExtent = ValueNotifier<double>(0.45);
  double? _targetSheetFraction;

  // OTP input state — single 4-digit field
  final TextEditingController _otpController = TextEditingController();
  final FocusNode _otpFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _sheetController.addListener(() {
      if (_sheetController.isAttached) {
        _sheetExtent.value = _sheetController.size;
      }
    });
    _initLocation();
  }

  @override
  void dispose() {
    _liveLocationSub?.cancel();
    _mapEventSub?.cancel();
    _sheetController.dispose();
    _sheetExtent.dispose();
    _otpController.dispose();
    _otpFocusNode.dispose();
    super.dispose();
  }

  Future<void> _initLocation() async {
    final granted = await _locationService.requestPermission();
    if (!granted) return;

    // ── Fast path: snap camera to last-known instantly (no satellite fix) ──
    final lastKnown = await _locationService.getLastKnownPosition();
    if (lastKnown != null) {
      _lastValidPosition = lastKnown;
      _mapController?.moveCamera(lastKnown.latitude, lastKnown.longitude,
          zoom: 16.0);
      _mapController?.updateUserLocation(
        lastKnown.latitude,
        lastKnown.longitude,
        heading: lastKnown.heading,
      );
    }

    // ── Accurate fix: refine position (6s timeout, cached internally) ──
    final pos = await _locationService.getCurrentPosition();
    if (pos != null) {
      _lastValidPosition = pos;
      _mapController?.moveCamera(pos.latitude, pos.longitude, zoom: 16.0);
      _mapController?.updateUserLocation(
        pos.latitude,
        pos.longitude,
        heading: pos.heading,
      );
    }

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      // Always start offline so the captain can manually manage their status
      await ref.read(captainRepositoryProvider).setAvailability(uid, false);
      if (mounted) {
        setState(() => _isOnline = false);
      }
    }

    _liveLocationSub = _locationService.getPositionStream().listen((position) {
      _lastValidPosition = position;
      _mapController?.updateUserLocation(
        position.latitude,
        position.longitude,
        heading: position.heading,
      );
      unawaited(_maybeReroute(position));
    });
  }

  Future<void> _toggleOnline(bool val) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    // Optimistically update the UI so the toggle doesn't feel laggy
    setState(() => _isOnline = val);

    if (val) {
      // Fast fallback to last known if possible to avoid waiting for GPS lock
      Position? pos =
          _lastValidPosition ?? await _locationService.getLastKnownPosition();
      pos ??= await _locationService.getCurrentPosition();

      if (!mounted) return;
      if (pos == null) {
        setState(() => _isOnline = false); // Revert
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enable location to go online.')),
        );
        return;
      }
      _lastValidPosition = pos;
      try {
        await ref
            .read(captainRepositoryProvider)
            .setAvailability(
              uid,
              true,
              lat: pos.latitude,
              lng: pos.longitude,
              heading: pos.heading,
            );
      } catch (e) {
        if (!mounted) return;
        setState(() => _isOnline = false); // Revert
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not go online: $e')));
        return;
      }
      if (!mounted) return;

      // Stream-based location updates: fires only when position changes by >=10m
      _liveLocationSub?.cancel();
      _liveLocationSub = _locationService
          .getPositionStream(distanceFilter: 10)
          .listen((position) {
            _lastValidPosition = position;
            final uid = FirebaseAuth.instance.currentUser?.uid;
            if (uid != null) {
              ref
                  .read(captainRepositoryProvider)
                  .updateLiveLocation(
                    uid,
                    position.latitude,
                    position.longitude,
                    position.heading,
                  );
              _mapController?.updateUserLocation(
                position.latitude,
                position.longitude,
                heading: position.heading,
              );
              unawaited(_maybeReroute(position));
            }
          });

      final requests = _nearbyRequests(
        ref.read(incomingRequestsProvider).value ?? const [],
      );
      if (requests.isNotEmpty && requests.first['destination'] is Map) {
        await _renderRouteToTarget(
          Map<String, dynamic>.from(requests.first['destination'] as Map),
          isPickup: false,
        );
      }
    } else {
      _liveLocationSub?.cancel();
      try {
        await ref.read(captainRepositoryProvider).setAvailability(uid, false);
      } catch (e) {
        if (mounted) setState(() => _isOnline = true); // Revert on failure
      }
      if (!mounted) return;
      _clearNavigationTarget();
    }
  }

  List<Map<String, dynamic>> _nearbyRequests(
    List<Map<String, dynamic>> requests,
  ) {
    final position = _lastValidPosition;
    if (position == null) return requests;

    final nearby = requests.where((request) {
      final pickup = request['pickup'];
      if (pickup is! Map) return false;
      final lat = double.tryParse(pickup['lat']?.toString() ?? '');
      final lng = double.tryParse(pickup['lng']?.toString() ?? '');
      if (lat == null || lng == null) return false;
      return Geolocator.distanceBetween(
            position.latitude,
            position.longitude,
            lat,
            lng,
          ) <=
          15000;
    }).toList();

    nearby.sort((a, b) {
      final aPickup = a['pickup'] as Map;
      final bPickup = b['pickup'] as Map;
      final aDistance = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
            double.tryParse(aPickup['lat']?.toString() ?? '') ?? 0.0,
            double.tryParse(aPickup['lng']?.toString() ?? '') ?? 0.0,
      );
      final bDistance = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
            double.tryParse(bPickup['lat']?.toString() ?? '') ?? 0.0,
            double.tryParse(bPickup['lng']?.toString() ?? '') ?? 0.0,
      );
      return aDistance.compareTo(bDistance);
    });
    return nearby;
  }

  Future<void> _renderRouteToTarget(
    Map<String, dynamic> target, {
    required bool isPickup,
    bool fitCamera = true,
    bool showError = true,
    bool force = false,
    Map<String, dynamic>? originData,
  }) async {
    final lat = double.tryParse(target['lat']?.toString() ?? '');
    final lng = double.tryParse(target['lng']?.toString() ?? '');
    final originLat = originData != null ? double.tryParse(originData['lat']?.toString() ?? '') : null;
    final originLng = originData != null ? double.tryParse(originData['lng']?.toString() ?? '') : null;

    if (lat == null || lng == null || !mounted) return;

    if (!force && _navigationTarget != null) {
      final oldLat = double.tryParse(_navigationTarget!['lat']?.toString() ?? '');
      final oldLng = double.tryParse(_navigationTarget!['lng']?.toString() ?? '');
      if (oldLat == lat && oldLng == lng && _navigationTargetIsPickup == isPickup) {
        return; // Already rendering this exact route
      }
    }

    _navigationTarget = target;
    _navigationTargetIsPickup = isPickup;
    _updateRouteSeq++;
    final currentSeq = _updateRouteSeq;
    if (!_mapReady || _mapController == null) return;

    final position = _lastValidPosition ?? await _locationService.getCurrentPosition();
    final startLat = originLat ?? position?.latitude;
    final startLng = originLng ?? position?.longitude;
    
    if (startLat == null || startLng == null) return;

    try {
      if (_updateRouteSeq != currentSeq || _navigationTarget == null) return;

      // ALWAYS add the target marker immediately so it's visible even if routing fails
      await _mapController!.addMarker(
        lat,
        lng,
        title: target['address']?.toString() ?? 'Route target',
        isPickup: isPickup,
      );
      
      if (originLat != null && originLng != null) {
        await _mapController!.addMarker(
          originLat,
          originLng,
          title: originData!['address']?.toString() ?? 'Pickup',
          isPickup: true,
        );
      }

      final route = await OlaMapsRepository().getDirections(
        startLat,
        startLng,
        lat,
        lng,
      );
      if (!mounted || _updateRouteSeq != currentSeq || _navigationTarget == null) return;
      final points = (route['points'] as List?)
          ?.map((point) => Map<String, dynamic>.from(point as Map))
          .toList();
      if (points == null || points.length < 2) return;

      if (!mounted || _updateRouteSeq != currentSeq || _navigationTarget == null) return;

      await _mapController!.clearRoute();

      // Re-add marker after clearRoute
      await _mapController!.addMarker(
        lat,
        lng,
        title: target['address']?.toString() ?? 'Route target',
        isPickup: isPickup,
      );
      if (originLat != null && originLng != null) {
        await _mapController!.addMarker(
          originLat,
          originLng,
          title: originData!['address']?.toString() ?? 'Pickup',
          isPickup: true,
        );
      }
      await _mapController!.drawPolyline(
        polyline: route['polyline'] as String?,
        points: points,
        color: '#2563EB',
      );
      // Fallback redraw after 500ms to ensure it wasn't swallowed by a style reload
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted && _updateRouteSeq == currentSeq && _navigationTarget != null) {
          _mapController?.drawPolyline(
            polyline: route['polyline'] as String?,
            points: points,
            color: '#2563EB',
          );
        }
      });
      if (fitCamera) {
        await _mapController!.fitBounds(
          startLat,
          startLng,
          lat,
          lng,
        );
      }
      _lastRouteOrigin = position;
      _lastRouteAt = DateTime.now();
      if (mounted && _updateRouteSeq == currentSeq && _navigationTarget != null) {
        setState(() {
          _navigationDistanceMeters = route['distance_meters'] as int?;
          _navigationDurationSeconds = route['duration_seconds'] as int?;
        });
      }
    } catch (e) {
      if (mounted && showError && _updateRouteSeq == currentSeq && _navigationTarget != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not load navigation route: $e')),
        );
      }
    }
  }

  Future<void> _maybeReroute(Position position) async {
    final target = _navigationTarget;
    final lastOrigin = _lastRouteOrigin;
    final lastAt = _lastRouteAt;
    final activeRide = ref.read(currentCaptainRideProvider).value;
    
    if (target == null || !_mapReady) return;
    if (activeRide == null) return; // Do not dynamically reroute static incoming requests
    
    if (lastOrigin != null &&
        Geolocator.distanceBetween(
              lastOrigin.latitude,
              lastOrigin.longitude,
              position.latitude,
              position.longitude,
            ) <
            30) {
      return;
    }
    if (lastAt != null &&
        DateTime.now().difference(lastAt) < const Duration(seconds: 20)) {
      return;
    }

    // Set this immediately to debounce rapid calls from live location stream!
    _lastRouteOrigin = position;
    _lastRouteAt = DateTime.now();

    await _renderRouteToTarget(
      target,
      isPickup: _navigationTargetIsPickup,
      fitCamera: false,
      showError: false,
      force: true,
    );
  }

  Future<void> _renderActiveRide(Map<String, dynamic> ride) async {
    final status = ride['status'] as String?;
    final isGoingToDestination = status == 'in_progress' || status == 'arrived';
    final target = isGoingToDestination
        ? ride['destination']
        : ride['pickup'];
    if (target is Map) {
      await _renderRouteToTarget(
        Map<String, dynamic>.from(target),
        isPickup: !isGoingToDestination,
      );
    }
  }

  Future<void> _runRideAction(Future<void> Function() action) async {
    if (_isRideActionLoading) return;
    setState(() => _isRideActionLoading = true);
    try {
      await action();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: context.colors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isRideActionLoading = false);
    }
  }

  Future<void> _callNumber(String number) async {
    final opened = await _mapController?.callPhone(number) ?? false;
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the phone dialer.')),
      );
    }
  }

  Future<void> _reportIssue(String rideId, String captainId) async {
    final issue = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 48),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Report a ride issue',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              for (final issue in const [
                'User is not responding',
                'Pickup location is incorrect',
                'Vehicle or safety issue',
                'Payment issue',
              ])
                ListTile(
                  title: Text(issue),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.pop(sheetContext, issue),
                ),
            ],
          ),
        ),
      ),
    );
    if (issue == null) return;
    await _runRideAction(
      () => ref
          .read(captainRepositoryProvider)
          .reportRideIssue(rideId: rideId, captainId: captainId, issue: issue),
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Issue reported to support.')),
      );
    }
  }

  Future<void> _recenter() async {
    if (_isRecentering) return;

    // 1. Fast fallback: immediately use cached or last known position
    Position? fastPos =
        _lastValidPosition ?? await _locationService.getLastKnownPosition();
    if (fastPos != null && _mapController != null && mounted) {
      _mapController!.moveCamera(
        fastPos.latitude,
        fastPos.longitude,
        zoom: 16.0,
      );
      _mapController!.updateUserLocation(
        fastPos.latitude,
        fastPos.longitude,
        heading: fastPos.heading,
      );
    }

    setState(() => _isRecentering = true);

    try {
      // 2. Fetch fresh high-accuracy position in background
      final freshPos = await _locationService.getCurrentPosition();
      if (freshPos != null && _mapController != null && mounted) {
        bool shouldUpdate = true;

        // 3. Prevent micro-jitters by only updating if moved > 10 meters
        if (fastPos != null) {
          final distance = Geolocator.distanceBetween(
            fastPos.latitude,
            fastPos.longitude,
            freshPos.latitude,
            freshPos.longitude,
          );
          if (distance < 10) shouldUpdate = false;
        }

        if (shouldUpdate) {
          _lastValidPosition = freshPos;
          _mapController!.moveCamera(
            freshPos.latitude,
            freshPos.longitude,
            zoom: 16.0,
          );
          _mapController!.updateUserLocation(
            freshPos.latitude,
            freshPos.longitude,
            heading: freshPos.heading,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to get location: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isRecentering = false);
      }
    }
  }

  void _clearNavigationTarget() {
    _navigationTarget = null;
    _lastRouteOrigin = null;
    _lastRouteAt = null;
    _updateRouteSeq++;
    _mapController?.clearRoute();
    if (mounted) {
      setState(() {
        _navigationDistanceMeters = null;
        _navigationDurationSeconds = null;
      });
    }
  }

  String _enteredOtp = '';

  @override
  Widget build(BuildContext context) {
    ref.listen(currentCaptainRideProvider, (previous, next) {
      if (next.isLoading && !next.hasValue) return; // Ignore initial load
      
      final ride = next.value;

      if (ride == null || ride['id'] != previous?.value?['id'] || ride['status'] != 'arrived') {
        if (_enteredOtp.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() { _enteredOtp = ''; });
          });
        }
      }

      if (ride != null) {
        _renderActiveRide(ride);
      } else if (previous?.value != null && !next.isLoading) {
        _clearNavigationTarget();
      }
    });

    ref.listen(incomingRequestsProvider, (previous, next) {
      if (next.isLoading && !next.hasValue) return;
      
      final requests = next.value;
      final nearby = requests == null
          ? const <Map<String, dynamic>>[]
          : _nearbyRequests(requests);
          
      final activeRide = ref.read(currentCaptainRideProvider).value;
          
      if (_isOnline && nearby.isNotEmpty && activeRide == null) {
        final req = nearby.first;
        final pickup = req['pickup'];
        final destination = req['destination'];
        if (pickup is Map && destination is Map) {
          _renderRouteToTarget(
            Map<String, dynamic>.from(destination),
            isPickup: false,
            originData: Map<String, dynamic>.from(pickup),
          );
        }
      } else if (activeRide == null && !next.isLoading) {
        // Clear route if no incoming requests and no active ride
        _clearNavigationTarget();
      }
    });

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: context.colors.background,
      drawer: CaptainDrawer(onCallNumber: _callNumber),
      body: Stack(
        children: [
          // ── Full-screen Ola Map ──────────────────────────────────
          RepaintBoundary(
            child: OlaMapsView(
              onMapCreated: (controller) {
                _mapController = controller;
                _mapEventSub?.cancel();
                _mapEventSub = controller.mapEvents.listen((event) async {
                  if (event is Map && event['event'] == 'mapReady') {
                    _mapReady = true;
                    // 1. Immediately jump to India to avoid showing the whole world map
                    controller.moveCamera(20.5937, 78.9629, zoom: 4.5);

                    if (!mounted) return;

                    // 2. Try to get a fast last known location and animate there
                    final lastKnown = await _locationService
                        .getLastKnownPosition();
                    if (lastKnown != null && mounted) {
                      controller.moveCamera(
                        lastKnown.latitude,
                        lastKnown.longitude,
                        zoom: 14.0,
                      );
                    }

                    // 3. Fetch the accurate current location
                    final pos = await _locationService.getCurrentPosition();
                    if (pos != null && mounted) {
                      _lastValidPosition = pos;
                      controller.moveCamera(
                        pos.latitude,
                        pos.longitude,
                        zoom: 16.0,
                      );
                      // Only drop the blue dot when we have the accurate GPS fix
                      controller.updateUserLocation(
                        pos.latitude,
                        pos.longitude,
                        heading: pos.heading,
                      );
                    }

                    final activeRide = ref.read(currentCaptainRideProvider).value;
                    if (activeRide != null) {
                      await _renderActiveRide(activeRide);
                    } else if (_isOnline) {
                      final requests = _nearbyRequests(
                        ref.read(incomingRequestsProvider).value ?? const [],
                      );
                      if (requests.isNotEmpty) {
                        final req = requests.first;
                        final pickup = req['pickup'];
                        final destination = req['destination'];
                        if (pickup is Map && destination is Map) {
                          await _renderRouteToTarget(
                            Map<String, dynamic>.from(destination),
                            isPickup: false,
                            originData: Map<String, dynamic>.from(pickup),
                          );
                        }
                      }
                    }
                  }
                });
              },
            ),
          ),

          // ── Top bar ──────────────────────────────────────────────
          SafeArea(
            child: RepaintBoundary(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Container(
                  height: 56,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Consumer(
                    builder: (context, ref, child) {
                      final activeRideAsync = ref.watch(currentCaptainRideProvider);
                      return Row(
                        children: [
                    // Menu button
                    GestureDetector(
                      onTap: () => _scaffoldKey.currentState?.openDrawer(),
                      child: Container(
                        color: Colors.transparent, // expand hit area
                        padding: const EdgeInsets.all(4),
                        child: const Icon(
                          Icons.menu_rounded,
                          color: Colors.black87,
                          size: 26,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Sarthi CAPTAIN Logo
                    const Icon(
                      Icons.electric_rickshaw_rounded,
                      color: Color(0xFF3B82F6),
                      size: 26,
                    ),
                    const SizedBox(width: 6),
                    const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Sarthi',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                            color: Colors.black87,
                            height: 1.1,
                            letterSpacing: -0.5,
                          ),
                        ),
                        Text(
                          'CAPTAIN',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 8,
                            color: Color(0xFF64748B),
                            letterSpacing: 1.5,
                            height: 1,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    // Online indicator
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: activeRideAsync.valueOrNull != null
                            ? const Color(0xFFEFF6FF)
                            : _isOnline
                                ? const Color(0xFFDCFCE7)
                                : const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: activeRideAsync.valueOrNull != null
                                  ? const Color(0xFF3B82F6)
                                  : _isOnline
                                      ? const Color(0xFF16A34A)
                                      : const Color(0xFF9CA3AF),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            activeRideAsync.valueOrNull != null
                                ? 'On Trip'
                                : _isOnline
                                    ? 'Online'
                                    : 'Offline',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: activeRideAsync.valueOrNull != null
                                  ? const Color(0xFF3B82F6)
                                  : _isOnline
                                      ? const Color(0xFF16A34A)
                                      : const Color(0xFF9CA3AF),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Online toggle
                    Transform.scale(
                      scale: 0.8,
                      child: Switch(
                        value: _isOnline,
                        activeColor: Colors.white,
                        activeTrackColor: const Color(0xFF22C55E),
                        inactiveThumbColor: Colors.white,
                        inactiveTrackColor: const Color(0xFFD1D5DB),
                        onChanged: activeRideAsync.valueOrNull != null ? null : _toggleOnline,
                      ),
                    ),
                  ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ),

          // ── Bottom Sheet & Recenter button ────────────────────────
          Align(
            alignment: Alignment.bottomCenter,
            child: RepaintBoundary(
              child: Consumer(
                builder: (context, ref, child) {
                  final activeRideAsync = ref.watch(currentCaptainRideProvider);
                  final incomingRequestsAsync = ref.watch(incomingRequestsProvider);
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // Recenter button
                      Padding(
                        padding: const EdgeInsets.only(right: 16, bottom: 16),
                        child: Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: context.colors.primary,
                            borderRadius: BorderRadius.circular(15),
                            boxShadow: [
                              BoxShadow(
                                color: context.colors.primary.withValues(alpha: 0.45),
                                blurRadius: 14,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: IconButton(
                            onPressed: _isRecentering ? null : _recenter,
                            icon: _isRecentering
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(
                                    Icons.my_location_rounded,
                                    color: Colors.white,
                                    size: 22,
                                  ),
                          ),
                        ),
                      ),

                      // Bottom Sheet Content
                      activeRideAsync.when(
                        data: (activeRide) {
                          Widget sheetContent;
                          if (activeRide != null) {
                            sheetContent = _buildActiveRideSheet(
                              context,
                              ref,
                              activeRide,
                            );
                          } else if (!_isOnline) {
                            sheetContent = _buildOfflineSheet(context);
                          } else {
                            sheetContent = incomingRequestsAsync.when(
                              data: (requests) {
                                final nearbyRequests = _nearbyRequests(requests);
                                if (nearbyRequests.isEmpty) {
                                  return _buildSearchingSheet(context);
                                }
                                return _buildIncomingRequestSheet(
                                  context,
                                  ref,
                                  nearbyRequests.first,
                                );
                              },
                              loading: () => const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(24.0),
                                  child: CircularProgressIndicator(),
                                ),
                              ),
                              error: (e, s) => Center(
                                child: Padding(
                                  padding: EdgeInsets.all(24.0),
                                  child: Text('Error: $e'),
                                ),
                              ),
                            );
                          }

                          return Container(
                            constraints: BoxConstraints(
                              maxHeight: MediaQuery.of(context).size.height * 0.90,
                            ),
                            width: double.infinity,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.vertical(
                                top: Radius.circular(30),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Color(0x260B2545),
                                  blurRadius: 28,
                                  offset: Offset(0, -8),
                                ),
                              ],
                            ),
                            child: SingleChildScrollView(
                              physics: const ClampingScrollPhysics(),
                              child: sheetContent,
                            ),
                          );
                        },
                        loading: () => const Padding(
                          padding: EdgeInsets.all(24.0),
                          child: CircularProgressIndicator(),
                        ),
                        error: (e, s) => Padding(
                          padding: EdgeInsets.all(24.0),
                          child: Text('Error: $e'),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Drag handle ─────────────────────────────────────────────
  Widget _dragHandle() => Center(
    child: Container(
      width: 48,
      height: 4,
      margin: const EdgeInsets.only(top: 14, bottom: 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFCBD5E1), Color(0xFFE2E8F0)],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
    ),
  );

  // ── Offline sheet ────────────────────────────────────────────
  Widget _buildOfflineSheet(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
          _dragHandle(),
          // Hero dark card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0B2144), Color(0xFF1A3A6B)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0B2144).withValues(alpha: 0.3),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.2),
                      width: 1.5,
                    ),
                  ),
                  child: const Icon(
                    Icons.electric_rickshaw_rounded,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'You are Offline',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Go online to start receiving\nride requests near you',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.65),
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF9CA3AF).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFF9CA3AF).withValues(alpha: 0.2),
              ),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.info_outline_rounded, size: 14, color: Color(0xFF9CA3AF)),
                SizedBox(width: 6),
                Text(
                  'Toggle the switch above to go online',
                  style: TextStyle(
                    color: Color(0xFF9CA3AF),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

  // ── Searching sheet ──────────────────────────────────────────
  Widget _buildSearchingSheet(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
          _dragHandle(),
          // Searching card with gradient border effect
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  context.colors.liveTeal.withValues(alpha: 0.15),
                  context.colors.liveTeal.withValues(alpha: 0.05),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: context.colors.liveTeal.withValues(alpha: 0.35),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: context.colors.liveTeal.withValues(alpha: 0.1),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: context.colors.liveTeal.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: context.colors.liveTeal.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: context.colors.liveTeal,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Searching for Riders',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          color: context.colors.primary,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'You\'re online and available',
                        style: TextStyle(
                          color: context.colors.liveTeal.withValues(alpha: 0.8),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: context.colors.liveTeal,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: context.colors.liveTeal.withValues(alpha: 0.5),
                        blurRadius: 6,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

  // ── Incoming request sheet ───────────────────────────────────
  Widget _buildIncomingRequestSheet(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> request,
  ) {
    return IncomingRequestSheetWidget(
      request: request,
      dragHandle: _dragHandle(),
      isActionLoading: _isRideActionLoading,
      onSkip: () {
        final uid = FirebaseAuth.instance.currentUser?.uid;
        if (uid != null) {
          _runRideAction(
            () => ref
                .read(captainRepositoryProvider)
                .rejectRide(request['id'] as String, uid),
          );
        }
      },
      onAccept: () {
        final uid = FirebaseAuth.instance.currentUser?.uid;
        if (uid != null) {
          _runRideAction(
            () => ref
                .read(captainRepositoryProvider)
                .acceptRide(request['id'] as String, uid),
          );
        }
      },
    );
  }

  // ── Active ride sheet ────────────────────────────────────────
  Widget _buildActiveRideSheet(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> activeRide,
  ) {
    final status = (activeRide['status'] as String?) ?? 'accepted';
    final rideId = (activeRide['id'] as String?) ?? '';
    final fare = activeRide['fareEstimate'] ?? activeRide['estimatedFare'];
    
    // Safely extract destination
    final destObj = activeRide['destination'];
    final dest = destObj is Map ? (destObj['address']?.toString() ?? 'Dropoff') : (destObj?.toString() ?? 'Dropoff');
    
    final riderName = activeRide['riderName'] as String? ?? 'Rider';
    final riderPhone = activeRide['riderPhone'] as String?;
    final captainId = FirebaseAuth.instance.currentUser?.uid;
    final isHeadingToPickup = status != 'in_progress';
    
    // Safely extract pickup
    final pickupObj = activeRide['pickup'];
    final pickup = pickupObj is Map ? pickupObj : null;
    
    final targetAddress = isHeadingToPickup
        ? (pickup == null
              ? (pickupObj is String ? pickupObj : 'User pickup location')
              : pickup['address']?.toString() ?? 'User pickup location')
        : dest;
    final etaMinutes = _navigationDurationSeconds == null
        ? null
        : (_navigationDurationSeconds! / 60).ceil();
    final navigationKm = _navigationDistanceMeters == null
        ? null
        : (_navigationDistanceMeters! / 1000).toStringAsFixed(1);

    void handleArrivedPress(String fromStatus) {
      final pickupLat = pickup?['lat'];
      final pickupLng = pickup?['lng'];
      
      final double? pLat = pickupLat is double ? pickupLat : (pickupLat is int ? pickupLat.toDouble() : null);
      final double? pLng = pickupLng is double ? pickupLng : (pickupLng is int ? pickupLng.toDouble() : null);

      if (pLat != null && pLng != null && _lastValidPosition != null) {
        final distance = Geolocator.distanceBetween(
          _lastValidPosition!.latitude,
          _lastValidPosition!.longitude,
          pLat,
          pLng,
        );

        if (distance > 150) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('You must be near the pickup location (within 150m) to mark as arrived.'),
              backgroundColor: context.colors.error,
              behavior: SnackBarBehavior.floating,
            ),
          );
          return;
        }
      }

      _runRideAction(
        () => ref.read(captainRepositoryProvider).transitionRide(
              rideId: rideId,
              captainId: captainId!,
              fromStatus: fromStatus,
              toStatus: 'arrived',
            ),
      );
    }

    final bottomInset = MediaQuery.of(context).padding.bottom;
    
    // Split targetAddress into main and sub
    final List<String> addressParts = targetAddress.split(',');
    final mainAddress = addressParts.first;
    final subAddress = addressParts.length > 1 ? addressParts.sublist(1).join(',').trim() : '';

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _dragHandle(),
            const SizedBox(height: 12),

            // Header Row (Heading to pickup / ETA / Fare)
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isHeadingToPickup ? 'Heading to pickup' : 'Heading to drop-off',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: Colors.black87,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (etaMinutes != null && navigationKm != null)
                        Text(
                          '$etaMinutes min away · $navigationKm km',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF64748B),
                          ),
                        ),
                    ],
                  ),
                ),
                if (fare != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEBF5FF),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Text(
                          '₹$fare',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Colors.black87,
                          ),
                        ),
                        const Text(
                          'Ride fare',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 24),

            // Rider info card
            if (status != 'in_progress')
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9), 
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: const BoxDecoration(
                        color: Color(0xFFDBEAFE),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          riderName.isNotEmpty ? riderName[0].toUpperCase() : 'R',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            riderName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Colors.black87,
                            ),
                          ),
                          const Text(
                            'Your rider',
                            style: TextStyle(
                              fontSize: 13,
                              color: Color(0xFF64748B),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (riderPhone?.isNotEmpty == true)
                      OutlinedButton.icon(
                        onPressed: () => _callNumber(riderPhone!),
                        icon: const Icon(Icons.phone, size: 16),
                        label: const Text('Call'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF3B82F6),
                          side: const BorderSide(color: Color(0xFF3B82F6), width: 1.5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  minimumSize: Size.zero,
                        ),
                      ),
                  ],
                ),
              ),
            
            if (status != 'in_progress')
              const SizedBox(height: 20),

            // Location
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 2),
                  child: const Icon(
                    Icons.location_on,
                    color: Color(0xFF10B981),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isHeadingToPickup ? 'PICKUP LOCATION' : 'DROP-OFF LOCATION',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF64748B),
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        mainAddress,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: Colors.black87,
                        ),
                      ),
                      if (subAddress.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          subAddress,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF64748B),
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ]
                    ],
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 20),
            const Divider(color: Color(0xFFF1F5F9), height: 1, thickness: 1),
            const SizedBox(height: 16),

            // Action row: Cancel + Help
            if (status != 'in_progress')
              Row(
                children: [
                  Expanded(
                    child: TextButton.icon(
                      onPressed: _isRideActionLoading || captainId == null
                          ? null
                          : () async {
                              final confirmed = await showDialog<bool>(
                                context: context,
                                builder: (dialogContext) => AlertDialog(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(24),
                                  ),
                                  titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
                                  contentPadding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                                  actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                                  title: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: Colors.red.withValues(alpha: 0.1),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.warning_amber_rounded,
                                          color: Colors.red,
                                          size: 24,
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      const Expanded(
                                        child: Text(
                                          'Cancel Ride?',
                                          style: TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.w800,
                                            color: Colors.black87,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  content: const Text(
                                    'Are you sure you want to cancel this ride? This action cannot be undone and may affect your cancellation rate.',
                                    style: TextStyle(
                                      fontSize: 15,
                                      color: Colors.black54,
                                      height: 1.5,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  actions: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: TextButton(
                                            onPressed: () => Navigator.pop(dialogContext, false),
                                            style: TextButton.styleFrom(
                                              padding: const EdgeInsets.symmetric(vertical: 14),
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(14),
                                              ),
                                              backgroundColor: const Color(0xFFF1F5F9),
                                            ),
                                            child: const Text(
                                              'No, Keep It',
                                              style: TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w700,
                                                color: Colors.black87,
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: ElevatedButton(
                                            onPressed: () => Navigator.pop(dialogContext, true),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.red,
                                              foregroundColor: Colors.white,
                                              elevation: 0,
                                              padding: const EdgeInsets.symmetric(vertical: 14),
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(14),
                                              ),
                                            ),
                                            child: const Text(
                                              'Yes, Cancel',
                                              style: TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                              if (confirmed != true) return;
                              await _runRideAction(
                                () => ref
                                    .read(captainRepositoryProvider)
                                    .transitionRide(
                                      rideId: rideId,
                                      captainId: captainId,
                                      fromStatus: status,
                                      toStatus: 'cancelled',
                                    ),
                              );
                            },
                      icon: const Icon(Icons.cancel_outlined, size: 18),
                      label: const Text(
                        'Cancel ride',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFFEF4444),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 24,
                    color: const Color(0xFFE2E8F0),
                  ),
                  Expanded(
                    child: TextButton.icon(
                      onPressed: () => _reportIssue(rideId, captainId ?? ''),
                      icon: const Icon(Icons.health_and_safety_outlined, size: 18),
                      label: const Text(
                        'Help & safety',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF3B82F6),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            
            if (status != 'in_progress')
              const SizedBox(height: 16),

            // OTP Block (if arrived)
            if (status == 'arrived') ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF16B77A).withValues(alpha: 0.06),
                      const Color(0xFF2563EB).withValues(alpha: 0.05),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                      color: const Color(0xFF16B77A).withValues(alpha: 0.2), width: 1.5),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF16A34A), Color(0xFF15803D)],
                            ),
                            borderRadius: BorderRadius.circular(11),
                          ),
                          child: const Icon(
                            Icons.lock_open_rounded,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                        const SizedBox(width: 11),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Rider OTP',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                  color: context.colors.primary,
                                  letterSpacing: -0.2,
                                ),
                              ),
                              Text(
                                'Ask the rider for their 4-digit code',
                                style: TextStyle(
                                  color: context.colors.textMuted,
                                  fontSize: 11,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    StatefulBuilder(
                      builder: (ctx, setInnerState) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: List.generate(4, (index) {
                              final isFilled = index < _enteredOtp.length;
                              final isCurrent = index == _enteredOtp.length;

                              return InkWell(
                                onTap: () async {
                                  final entered = await showModalBottomSheet<String>(
                                    context: context,
                                    isScrollControlled: true,
                                    builder: (bctx) {
                                      return Padding(
                                        padding: EdgeInsets.only(
                                            bottom: MediaQuery.of(bctx).viewInsets.bottom),
                                        child: Container(
                                          padding: const EdgeInsets.all(24),
                                          child: TextField(
                                            keyboardType: TextInputType.number,
                                            maxLength: 4,
                                            autofocus: true,
                                            decoration: const InputDecoration(
                                              hintText: 'Enter 4-digit OTP',
                                            ),
                                            onChanged: (v) {
                                              if (v.length == 4) {
                                                Navigator.pop(bctx, v);
                                              }
                                            },
                                          ),
                                        ),
                                      );
                                    },
                                  );

                                  if (entered != null && entered.length == 4) {
                                    setInnerState(() {
                                      _enteredOtp = entered;
                                    });
                                    if (_enteredOtp == activeRide['otp']) {
                                      _runRideAction(
                                        () => ref.read(captainRepositoryProvider).transitionRide(
                                              rideId: rideId,
                                              captainId: captainId!,
                                              fromStatus: 'arrived',
                                              toStatus: 'in_progress',
                                            ),
                                      );
                                    } else {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: const Text('Incorrect OTP! Please check with rider.'),
                                          backgroundColor: context.colors.error,
                                        ),
                                      );
                                      setInnerState(() {
                                        _enteredOtp = '';
                                      });
                                    }
                                  }
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  width: 48,
                                  height: 56,
                                  decoration: BoxDecoration(
                                    color: isFilled ? const Color(0xFFF0FDF4) : Colors.white,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: isFilled
                                          ? const Color(0xFF16B77A)
                                          : isCurrent
                                              ? const Color(0xFF2563EB).withValues(alpha: 0.6)
                                              : context.colors.cardBorder,
                                      width: isFilled || isCurrent ? 2.0 : 1.0,
                                    ),
                                    boxShadow: isCurrent
                                        ? [
                                            BoxShadow(
                                              color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                                              blurRadius: 10,
                                              spreadRadius: 2,
                                            )
                                          ]
                                        : [],
                                  ),
                                  child: Center(
                                    child: Text(
                                      isFilled ? _enteredOtp[index] : '',
                                      style: TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.w800,
                                        color: isFilled ? const Color(0xFF16B77A) : Colors.transparent,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Primary CTA
            if (status == 'accepted' || status == 'arriving')
              ElevatedButton.icon(
                onPressed: _isRideActionLoading || captainId == null
                    ? null
                    : () => handleArrivedPress(status),
                icon: const Icon(Icons.location_on, size: 18, color: Colors.white),
                label: Text(
                  status == 'accepted' ? 'Arrived at pickup' : 'I have Arrived',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),

            if (status == 'in_progress')
              ElevatedButton.icon(
                onPressed: _isRideActionLoading || captainId == null
                    ? null
                    : () async {
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (dialogContext) => AlertDialog(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            title: const Text(
                              'Complete this trip?',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            content: const Text(
                              'Confirm only after reaching the destination and collecting the fare.',
                              style: TextStyle(fontSize: 14),
                            ),
                            actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                            actions: [
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: () => Navigator.pop(dialogContext, false),
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                      ),
                                      child: const Text('No'),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: ElevatedButton(
                                      onPressed: () => Navigator.pop(dialogContext, true),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF10B981),
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                        elevation: 0,
                                        minimumSize: Size.zero,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                      ),
                                      child: const Text('Yes'),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                        if (confirmed != true) return;
                        
                        await _runRideAction(
                          () => ref
                              .read(captainRepositoryProvider)
                              .transitionRide(
                                rideId: rideId,
                                captainId: captainId,
                                fromStatus: 'in_progress',
                                toStatus: 'completed',
                              ),
                        );
                      },
                icon: const Icon(Icons.check_circle_rounded, size: 18, color: Colors.white),
                label: const Text(
                  'End Trip',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _etaChip({required IconData icon, required String value}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 12),
          const SizedBox(width: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 11.5,
              letterSpacing: -0.1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _captainMetricCard({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  color.withValues(alpha: 0.15),
                  color.withValues(alpha: 0.08),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: context.colors.primary,
                  letterSpacing: -0.2,
                ),
              ),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF9CA3AF),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── IncomingRequestSheetWidget ───────────────────────────────────────────
class IncomingRequestSheetWidget extends StatefulWidget {
  final Map<String, dynamic> request;
  final Widget dragHandle;
  final VoidCallback onSkip;
  final VoidCallback onAccept;
  final bool isActionLoading;

  const IncomingRequestSheetWidget({
    Key? key,
    required this.request,
    required this.dragHandle,
    required this.onSkip,
    required this.onAccept,
    required this.isActionLoading,
  }) : super(key: key);

  @override
  State<IncomingRequestSheetWidget> createState() => _IncomingRequestSheetWidgetState();
}

class _IncomingRequestSheetWidgetState extends State<IncomingRequestSheetWidget> {
  Timer? _timer;
  int _secondsLeft = 30;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_secondsLeft > 0) {
        setState(() => _secondsLeft--);
      } else {
        _timer?.cancel();
        if (!widget.isActionLoading) {
          widget.onSkip();
        }
      }
    });
  }

  @override
  void didUpdateWidget(IncomingRequestSheetWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.request['id'] != widget.request['id']) {
      _timer?.cancel();
      setState(() => _secondsLeft = 30);
      _startTimer();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fare = widget.request['fareEstimate']?.toString() ?? '0';
    final pickup = widget.request['pickup']?['address'] ?? 'Unknown location';
    final distM = widget.request['distanceMeters'] as int?;

    final List<String> pickupParts = pickup.split(',');
    final mainPickup = pickupParts.first;
    final subPickup = pickupParts.length > 1 ? pickupParts.sublist(1).join(',').trim() : '';

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            widget.dragHandle,
            const SizedBox(height: 12),

            // Title Row
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                    color: Color(0xFFEBF5FF),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.person_pin,
                    color: Color(0xFF3B82F6),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Text(
                    'New ride request',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Colors.black87,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
                // Timer circle
                Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 44,
                      height: 44,
                      child: CircularProgressIndicator(
                        value: _secondsLeft / 30.0,
                        backgroundColor: const Color(0xFFE2E8F0),
                        color: const Color(0xFF3B82F6),
                        strokeWidth: 3,
                      ),
                    ),
                    Text(
                      '${_secondsLeft}s',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Metrics Row
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: const Color(0xFFF1F5F9)),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.02),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: const BoxDecoration(
                            color: Color(0xFFEBF5FF),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.currency_rupee_rounded,
                            color: Color(0xFF3B82F6),
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '₹$fare',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: Colors.black87,
                              ),
                            ),
                            const Text(
                              'Estimated fare',
                              style: TextStyle(
                                fontSize: 11,
                                color: Color(0xFF64748B),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                if (distM != null)
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: const Color(0xFFF1F5F9)),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.02),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: const BoxDecoration(
                              color: Color(0xFFEBF5FF),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.location_on_rounded,
                              color: Color(0xFF3B82F6),
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${(distM / 1000).toStringAsFixed(1)} km',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.black87,
                                ),
                              ),
                              const Text(
                                'Ride distance',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF64748B),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            
            // Divider
            const Divider(color: Color(0xFFF1F5F9), height: 1, thickness: 1),
            const SizedBox(height: 20),

            // Location
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  children: [
                    const SizedBox(height: 2),
                    const Icon(
                      Icons.circle,
                      color: Color(0xFF3B82F6),
                      size: 12,
                    ),
                    const SizedBox(height: 4),
                    Column(
                      children: List.generate(
                        4,
                        (_) => Container(
                          width: 2,
                          height: 4,
                          margin: const EdgeInsets.symmetric(vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFCBD5E1),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'PICKUP LOCATION',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF64748B),
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        mainPickup,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Colors.black87,
                        ),
                      ),
                      if (subPickup.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          subPickup,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF64748B),
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ]
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),

            // Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: widget.isActionLoading ? null : widget.onSkip,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF3B82F6),
                      side: const BorderSide(color: Color(0xFF3B82F6), width: 1.5),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Skip',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: widget.isActionLoading ? null : widget.onAccept,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3B82F6),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      elevation: 0,
                      minimumSize: Size.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      shadowColor: const Color(0xFF3B82F6).withValues(alpha: 0.4),
                    ),
                    child: widget.isActionLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Accept ride',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              SizedBox(width: 8),
                              Icon(Icons.arrow_forward_rounded, size: 20),
                            ],
                          ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
