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
      if (requests.isNotEmpty && requests.first['pickup'] is Map) {
        await _renderRouteToTarget(
          Map<String, dynamic>.from(requests.first['pickup'] as Map),
          isPickup: true,
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
      final lat = (pickup['lat'] as num?)?.toDouble();
      final lng = (pickup['lng'] as num?)?.toDouble();
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
        (aPickup['lat'] as num).toDouble(),
        (aPickup['lng'] as num).toDouble(),
      );
      final bDistance = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        (bPickup['lat'] as num).toDouble(),
        (bPickup['lng'] as num).toDouble(),
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
  }) async {
    _navigationTarget = target;
    _navigationTargetIsPickup = isPickup;
    _updateRouteSeq++;
    final currentSeq = _updateRouteSeq;
    if (!_mapReady || _mapController == null) return;
    final lat = (target['lat'] as num?)?.toDouble();
    final lng = (target['lng'] as num?)?.toDouble();
    final position =
        _lastValidPosition ?? await _locationService.getCurrentPosition();
    if (lat == null || lng == null || position == null || !mounted) return;

    try {
      if (_updateRouteSeq != currentSeq || _navigationTarget == null) return;

      // ALWAYS add the target marker immediately so it's visible even if routing fails
      await _mapController!.addMarker(
        lat,
        lng,
        title: target['address']?.toString() ?? 'Route target',
        isPickup: isPickup,
      );

      final route = await OlaMapsRepository().getDirections(
        position.latitude,
        position.longitude,
        lat,
        lng,
      );
      if (!mounted || _updateRouteSeq != currentSeq || _navigationTarget == null) return;
      final points = (route['points'] as List?)
          ?.map((point) => Map<String, dynamic>.from(point as Map))
          .toList();
      if (points == null || points.length < 2) return;

      await _mapController!.clearRoute();
      if (!mounted || _updateRouteSeq != currentSeq || _navigationTarget == null) return;

      // Re-add marker after clearRoute
      await _mapController!.addMarker(
        lat,
        lng,
        title: target['address']?.toString() ?? 'Route target',
        isPickup: isPickup,
      );
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
          position.latitude,
          position.longitude,
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
    if (target == null || !_mapReady) return;
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
    await _renderRouteToTarget(
      target,
      isPickup: _navigationTargetIsPickup,
      fitCamera: false,
      showError: false,
    );
  }

  Future<void> _renderActiveRide(Map<String, dynamic> ride) async {
    final status = ride['status'] as String?;
    final target = status == 'in_progress'
        ? ride['destination']
        : ride['pickup'];
    if (target is Map) {
      await _renderRouteToTarget(
        Map<String, dynamic>.from(target),
        isPickup: status != 'in_progress',
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
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
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

  String get _enteredOtp => _otpController.text;

  @override
  Widget build(BuildContext context) {
    final incomingRequestsAsync = ref.watch(incomingRequestsProvider);
    final activeRideAsync = ref.watch(currentCaptainRideProvider);

    // Drop a marker for the pickup location when active ride changes
    ref.listen(currentCaptainRideProvider, (previous, next) {
      final ride = next.value;
      if (ride != null) {
        _renderActiveRide(ride);
      } else if (previous?.value != null) {
        _clearNavigationTarget();
      }
    });

    ref.listen(incomingRequestsProvider, (previous, next) {
      final requests = next.value;
      final nearby = requests == null
          ? const <Map<String, dynamic>>[]
          : _nearbyRequests(requests);
      if (_isOnline && nearby.isNotEmpty && activeRideAsync.value == null) {
        final pickup = nearby.first['pickup'];
        if (pickup is Map) {
          _renderRouteToTarget(
            Map<String, dynamic>.from(pickup),
            isPickup: true,
          );
        }
      } else if (activeRideAsync.value == null) {
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
          OlaMapsView(
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
                    if (requests.isNotEmpty &&
                        requests.first['pickup'] is Map) {
                      await _renderRouteToTarget(
                        Map<String, dynamic>.from(
                          requests.first['pickup'] as Map,
                        ),
                        isPickup: true,
                      );
                    }
                  }
                }
              });
            },
          ),

          // ── Top bar ──────────────────────────────────────────────
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  // Menu button — navy gradient circle
                  GestureDetector(
                    onTap: () => _scaffoldKey.currentState?.openDrawer(),
                    child: Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF0B2144), Color(0xFF1A3A6B)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF0B2144).withValues(alpha: 0.35),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.menu_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Title card — matching user app pill style
                  Expanded(
                    child: Container(
                      height: 46,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: Row(
                        children: [
                          // Sarthi logo box
                          Container(
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF0B2144), Color(0xFF1A3A6B)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF0B2144).withValues(alpha: 0.25),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.electric_rickshaw_rounded,
                              color: Colors.white,
                              size: 14,
                            ),
                          ),
                          const SizedBox(width: 8),
                          ShaderMask(
                            shaderCallback: (bounds) => const LinearGradient(
                              colors: [Color(0xFF0B2144), Color(0xFF1A3A6B)],
                            ).createShader(bounds),
                            child: const Text(
                              'Captain',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 13,
                                color: Colors.white,
                                letterSpacing: -0.3,
                              ),
                            ),
                          ),
                          const Spacer(),
                          // Online/Offline status badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: activeRideAsync.value != null
                                  ? const Color(0xFF2563EB).withValues(alpha: 0.1)
                                  : _isOnline
                                  ? context.colors.liveTeal.withValues(alpha: 0.1)
                                  : const Color(0xFF9CA3AF).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: activeRideAsync.value != null
                                    ? const Color(0xFF2563EB).withValues(alpha: 0.3)
                                    : _isOnline
                                    ? context.colors.liveTeal.withValues(alpha: 0.3)
                                    : const Color(0xFF9CA3AF).withValues(alpha: 0.3),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: activeRideAsync.value != null
                                        ? const Color(0xFF2563EB)
                                        : _isOnline
                                        ? context.colors.liveTeal
                                        : const Color(0xFF9CA3AF),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  activeRideAsync.value != null
                                      ? 'On Trip'
                                      : _isOnline
                                      ? 'Online'
                                      : 'Offline',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: activeRideAsync.value != null
                                        ? const Color(0xFF2563EB)
                                        : _isOnline
                                        ? context.colors.liveTeal
                                        : const Color(0xFF9CA3AF),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 4),
                          // Online toggle
                          Transform.scale(
                            scale: 0.75,
                            child: Switch(
                              value: _isOnline,
                              activeThumbColor: context.colors.liveTeal,
                              onChanged: activeRideAsync.value != null
                                  ? null
                                  : _toggleOnline,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Recenter button ──────────────────────────────────────
          ValueListenableBuilder<double>(
            valueListenable: _sheetExtent,
            builder: (context, extent, child) {
              final screenHeight = MediaQuery.of(context).size.height;
              return Positioned(
                bottom: (screenHeight * extent) + 16,
                right: 16,
                child: child!,
              );
            },
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

          // -- Bottom Sheet -----------------------------------------
          DraggableScrollableSheet(
            controller: _sheetController,
            initialChildSize: (_targetSheetFraction ?? 0.45).clamp(0.25, 1.0),
            minChildSize: 0.25,
            maxChildSize: 0.95,
            builder: (context, scrollController) {
              return Container(
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
                child: activeRideAsync.when(
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
                        loading: () =>
                            const Center(child: CircularProgressIndicator()),
                        error: (e, s) => Center(child: Text('Error: $e')),
                      );
                    }

                    // Determine a key for the current state for AnimatedSwitcher
                    final stateKey = activeRide != null
                        ? 'active_${activeRide['status']}'
                        : _isOnline
                        ? 'searching_${incomingRequestsAsync.value?.isNotEmpty == true}'
                        : 'offline';

                    return SingleChildScrollView(
                      controller: scrollController,
                      physics: const ClampingScrollPhysics(),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 150),
                        switchInCurve: Curves.easeOut,
                        switchOutCurve: Curves.easeIn,
                        transitionBuilder: (child, animation) =>
                            FadeTransition(opacity: animation, child: child),
                        layoutBuilder: (currentChild, previousChildren) =>
                            Stack(
                              alignment: Alignment.topCenter,
                              children: <Widget>[
                                ...previousChildren,
                                ?currentChild,
                              ],
                            ),
                        child: KeyedSubtree(
                          key: ValueKey(stateKey),
                          child: MeasureSize(
                            onChange: (size) {
                              final screenHeight = MediaQuery.of(
                                context,
                              ).size.height;
                              // Calculate exact fraction matching content height
                              final target = (size.height / screenHeight).clamp(
                                0.25,
                                0.95,
                              );
                              if (_targetSheetFraction == null ||
                                  (_targetSheetFraction! - target).abs() >
                                      0.01) {
                                WidgetsBinding.instance.addPostFrameCallback((
                                  _,
                                ) {
                                  if (mounted) {
                                    setState(
                                      () => _targetSheetFraction = target,
                                    );
                                    if (_sheetController.isAttached) {
                                      _sheetController.animateTo(
                                        target,
                                        duration: const Duration(
                                          milliseconds: 250,
                                        ),
                                        curve: Curves.easeOutCubic,
                                      );
                                    }
                                  }
                                });
                              }
                            },
                            child: sheetContent,
                          ),
                        ),
                      ),
                    );
                  },
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, s) => Center(child: Text('Error: $e')),
                ),
              );
            },
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
    final bottomInset = MediaQuery.of(context).padding.bottom;
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + bottomInset),
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
    final bottomInset = MediaQuery.of(context).padding.bottom;
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + bottomInset),
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
    final fare = request['fareEstimate'];
    final dest = request['destination']?['address'] ?? 'Unknown';
    final distM = request['distanceMeters'] as int?;

    final bottomInset = MediaQuery.of(context).padding.bottom;
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, 24 + bottomInset),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _dragHandle(),

            // Alert header — blue gradient
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [context.colors.primary, context.colors.primary.withValues(alpha: 0.85)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: context.colors.primary.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.notifications_active_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'New Ride Request!',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      letterSpacing: -0.2,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Route card — premium with dotted connector
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFD),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE5E7EB)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: context.colors.rapidoYellow,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: context.colors.rapidoYellow.withValues(alpha: 0.4),
                            width: 3,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: context.colors.rapidoYellow.withValues(alpha: 0.4),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Pickup Location',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 5, top: 3, bottom: 3),
                    child: Column(
                      children: List.generate(
                        4,
                        (_) => Container(
                          width: 2,
                          height: 5,
                          margin: const EdgeInsets.symmetric(vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFCBD5E1),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: context.colors.error,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: context.colors.error.withValues(alpha: 0.4),
                            width: 3,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          dest,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: Color(0xFF0F172A),
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Metrics row
            Row(
              children: [
                Expanded(
                  child: _captainMetricCard(
                    icon: Icons.currency_rupee_rounded,
                    value: '₹$fare',
                    label: 'Fare',
                    color: context.colors.primary,
                  ),
                ),
                const SizedBox(width: 12),
                if (distM != null)
                  Expanded(
                    child: _captainMetricCard(
                      icon: Icons.straighten_rounded,
                      value: '${(distM / 1000).toStringAsFixed(1)} km',
                      label: 'Distance',
                      color: context.colors.rapidoYellow,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isRideActionLoading
                        ? null
                        : () {
                            final uid = FirebaseAuth.instance.currentUser?.uid;
                            if (uid != null) {
                              _runRideAction(
                                () => ref
                                    .read(captainRepositoryProvider)
                                    .rejectRide(request['id'] as String, uid),
                              );
                            }
                          },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: context.colors.error,
                      side: BorderSide(color: context.colors.error.withValues(alpha: 0.5)),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'Skip',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: _isRideActionLoading
                        ? null
                        : () {
                            final uid = FirebaseAuth.instance.currentUser?.uid;
                            if (uid != null) {
                              _runRideAction(
                                () => ref
                                    .read(captainRepositoryProvider)
                                    .acceptRide(request['id'] as String, uid),
                              );
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: context.colors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      shadowColor: context.colors.primary.withValues(alpha: 0.4),
                    ),
                    child: _isRideActionLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Accept Ride',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.1,
                            ),
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

  // ── Active ride sheet ────────────────────────────────────────
  Widget _buildActiveRideSheet(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> activeRide,
  ) {
    final colors = context.colors;
    const navy = Color(0xFF0B2545);
    const navyLight = Color(0xFF173E69);
    const blue = Color(0xFF2563EB);
    const green = Color(0xFF16B77A);
    const yellow = Color(0xFFFFD633);

    final status = activeRide['status'] as String;
    final rideId = activeRide['id'] as String;
    final fare = activeRide['fareEstimate'];
    final dest = activeRide['destination']?['address'] ?? 'Dropoff';
    final riderName = activeRide['riderName'] as String? ?? 'Rider';
    final riderPhone = activeRide['riderPhone'] as String?;
    final captainId = FirebaseAuth.instance.currentUser?.uid;
    final isHeadingToPickup = status != 'in_progress';
    final pickup = activeRide['pickup'] as Map?;
    final targetAddress = isHeadingToPickup
        ? (pickup == null
              ? 'User pickup location'
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
              backgroundColor: colors.error,
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

    // ── color scheme per status ──────────────────────────────────
    final Color statusColor;
    final String statusLabel;
    final IconData statusIcon;
    switch (status) {
      case 'accepted':
        statusColor = blue;
        statusLabel = 'Navigate to Pickup';
        statusIcon = Icons.route_rounded;
        break;
      case 'arriving':
        statusColor = colors.warning;
        statusLabel = 'Arriving at Pickup';
        statusIcon = Icons.near_me_rounded;
        break;
      case 'arrived':
        statusColor = green;
        statusLabel = 'Arrived — Verify OTP';
        statusIcon = Icons.location_on_rounded;
        break;
      case 'in_progress':
        statusColor = colors.liveTeal;
        statusLabel = 'Trip in Progress';
        statusIcon = Icons.electric_moped_rounded;
        break;
      default:
        statusColor = colors.textMuted;
        statusLabel = status.toUpperCase();
        statusIcon = Icons.info_outline_rounded;
    }

    final bottomInset = MediaQuery.of(context).padding.bottom;
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + bottomInset),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _dragHandle(),
            const SizedBox(height: 2),

            // ── Status banner ───────────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    statusColor.withValues(alpha: 0.12),
                    statusColor.withValues(alpha: 0.06),
                  ],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: statusColor.withValues(alpha: 0.25), width: 1.2),
              ),
              child: Row(
                children: [
                  Container(
                    width: 3.5,
                    height: 18,
                    decoration: BoxDecoration(
                      color: statusColor,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(statusIcon, color: statusColor, size: 13),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      statusLabel,
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.w800,
                        fontSize: 12.5,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                  // Fare badge in status bar
                  if (fare != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(7),
                        border: Border.all(
                          color: const Color(0xFFFCD34D),
                          width: 1.2,
                        ),
                      ),
                      child: Text(
                        '₹$fare',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          color: navy,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 6),

            // ── Rider info card — premium navy gradient ──────────────
            if (status != 'in_progress') ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [navy, navyLight],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: navy.withValues(alpha: 0.22),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    // Avatar circle with initials
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            yellow.withValues(alpha: 0.25),
                            yellow.withValues(alpha: 0.10),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: yellow.withValues(alpha: 0.5), width: 1.5),
                      ),
                      child: Center(
                        child: Text(
                          riderName.isNotEmpty
                              ? riderName[0].toUpperCase()
                              : 'R',
                          style: const TextStyle(
                            color: yellow,
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Name + phone
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            riderName,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                              color: Colors.white,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Icon(
                                Icons.phone_rounded,
                                size: 10,
                                color: Colors.white.withValues(alpha: 0.55),
                              ),
                              const SizedBox(width: 3),
                              Text(
                                riderPhone?.isNotEmpty == true
                                    ? riderPhone!
                                    : 'No phone',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.65),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Call button
                    if (riderPhone?.isNotEmpty == true)
                      GestureDetector(
                        onTap: () => _callNumber(riderPhone!),
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.2),
                            ),
                          ),
                          child: const Icon(
                            Icons.call_rounded,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 6),

              // ── Route / destination strip ─────────────────────────
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: colors.cardBorder.withValues(alpha: 0.7)),
                  boxShadow: [
                    BoxShadow(
                      color: navy.withValues(alpha: 0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: isHeadingToPickup
                            ? green.withValues(alpha: 0.12)
                            : yellow.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        isHeadingToPickup
                            ? Icons.my_location_rounded
                            : Icons.flag_rounded,
                        color: isHeadingToPickup ? green : const Color(0xFFF59E0B),
                        size: 14,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isHeadingToPickup ? 'PICKUP' : 'DROP-OFF',
                            style: TextStyle(
                              color: colors.textMuted,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.9,
                            ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            targetAddress,
                            style: TextStyle(
                              color: colors.text,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.1,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
            ],

            // ── ETA strip (blue pill) ───────────────────────────────
            if (etaMinutes != null && navigationKm != null) ...[
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [blue, Color(0xFF1D4ED8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: blue.withValues(alpha: 0.28),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    // ETA chip
                    _etaChip(
                      icon: Icons.timer_rounded,
                      value: '$etaMinutes min',
                    ),
                    const SizedBox(width: 6),
                    // Distance chip
                    _etaChip(
                      icon: Icons.straighten_rounded,
                      value: '$navigationKm km',
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(7),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.25)),
                      ),
                      child: Text(
                        isHeadingToPickup ? 'to pickup' : 'to drop',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
            ],

            // ── Action row: Cancel + Report ─────────────────────────
            if (status != 'in_progress') ...[
              Row(
                children: [
                  // Cancel
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isRideActionLoading || captainId == null
                          ? null
                          : () async {
                              final confirmed = await showDialog<bool>(
                                context: context,
                                builder: (dialogContext) => AlertDialog(
                                  title: const Text('Cancel Ride?'),
                                  content: const Text(
                                    'Are you sure you want to cancel this ride? This may negatively impact your rating.',
                                  ),
                                  actions: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: TextButton(
                                            onPressed: () => Navigator.pop(
                                                dialogContext, false),
                                            style: TextButton.styleFrom(
                                              foregroundColor: colors.text,
                                            ),
                                            child: const Text('No'),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: ElevatedButton(
                                            onPressed: () => Navigator.pop(
                                                dialogContext, true),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: colors.error,
                                              foregroundColor: Colors.white,
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
                                      fromStatus: status,
                                      toStatus: 'cancelled',
                                    ),
                              );
                            },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: colors.error,
                        side: BorderSide(
                            color: colors.error.withValues(alpha: 0.55),
                            width: 1.2),
                        padding: const EdgeInsets.symmetric(vertical: 9),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(11),
                        ),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Report issue
                  Container(
                    height: 38,
                    width: 38,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(11),
                      border: Border.all(
                        color: const Color(0xFFFCD34D).withValues(alpha: 0.7),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: yellow.withValues(alpha: 0.25),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      tooltip: 'Report ride issue',
                      onPressed: captainId == null
                          ? null
                          : () => _reportIssue(rideId, captainId),
                      icon: const Icon(Icons.report_problem_outlined, size: 18),
                      color: const Color(0xFFF59E0B),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
            ],

            // ── Primary CTA ─────────────────────────────────────────
            if (status == 'accepted')
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isRideActionLoading || captainId == null
                      ? null
                      : () => handleArrivedPress('accepted'),
                  icon: const Icon(Icons.location_on_rounded, size: 18),
                  label: const Text(
                    'Arrived at Pickup',
                    style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: yellow,
                    foregroundColor: navy,
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    elevation: 0,
                    shadowColor: yellow.withValues(alpha: 0.4),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              )
            else if (status == 'arriving')
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isRideActionLoading || captainId == null
                      ? null
                      : () => handleArrivedPress('arriving'),
                  icon: const Icon(Icons.location_on_rounded, size: 18),
                  label: const Text(
                    'I have Arrived',
                    style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: yellow,
                    foregroundColor: navy,
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              )
            else if (status == 'arrived') ...[
              // OTP verification card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      green.withValues(alpha: 0.06),
                      const Color(0xFF2563EB).withValues(alpha: 0.05),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                      color: green.withValues(alpha: 0.2), width: 1.5),
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
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Rider OTP',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                                color: colors.primary,
                                letterSpacing: -0.2,
                              ),
                            ),
                            Text(
                              'Ask the rider for their 4-digit code',
                              style: TextStyle(
                                color: colors.textMuted,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // OTP input — full width, large digits
                    TextField(
                      controller: _otpController,
                      focusNode: _otpFocusNode,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.done,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(4),
                      ],
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 20.0,
                        color: colors.primary,
                      ),
                      decoration: InputDecoration(
                        hintText: '• • • •',
                        hintStyle: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 10,
                          color: colors.hint,
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 14),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                              color: colors.cardBorder, width: 1.5),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                              color: colors.primary, width: 2),
                        ),
                      ),
                      onChanged: (val) {
                        setState(() {}); // Refresh button state
                        if (val.length == 4) {
                          FocusScope.of(context).unfocus();
                        }
                      },
                      onSubmitted: (_) => FocusScope.of(context).unfocus(),
                    ),
                    const SizedBox(height: 12),
                    // Verify button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _enteredOtp.length == 4 &&
                                !_isRideActionLoading &&
                                captainId != null
                            ? () => _runRideAction(() async {
                                FocusScope.of(context).unfocus();
                                try {
                                  await ref
                                      .read(captainRepositoryProvider)
                                      .verifyOtpAndStartRide(
                                        rideId: rideId,
                                        captainId: captainId,
                                        enteredOtp: _enteredOtp,
                                      );
                                  _otpController.clear();
                                } catch (error) {
                                  // Preserve the OTP for transient Firebase/network
                                  // failures; clear it only when validation failed.
                                  if (error is StateError) {
                                    _otpController.clear();
                                    _otpFocusNode.requestFocus();
                                  }
                                  rethrow;
                                }
                              })
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF16A34A),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text(
                          'Verify OTP & Start Ride',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ] else if (status == 'in_progress') ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFD),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.flag_rounded,
                      color: context.colors.error,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Drop-off Location',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            dest,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: Colors.black,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
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
                                      onPressed: () =>
                                          Navigator.pop(dialogContext, false),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: context.colors.text,
                                        side: BorderSide(
                                          color: context.colors.cardBorder,
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 12,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                      ),
                                      child: const Text(
                                        'No',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: ElevatedButton(
                                      onPressed: () =>
                                          Navigator.pop(dialogContext, true),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor:
                                            context.colors.rapidoYellow,
                                        foregroundColor:
                                            context.colors.primary,
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 12,
                                        ),
                                        elevation: 0,
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                      ),
                                      child: const Text(
                                        'Yes',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w800,
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
                                fromStatus: 'in_progress',
                                toStatus: 'completed',
                              ),
                        );
                      },
                icon: const Icon(Icons.check_circle_rounded),
                label: const Text('Complete Trip & Collect Cash'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: context.colors.rapidoYellow,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ],
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
