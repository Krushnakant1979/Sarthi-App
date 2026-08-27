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
import '../../map/data/ola_maps_repository.dart';

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
  final DraggableScrollableController _sheetController = DraggableScrollableController();
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
      Position? pos = _lastValidPosition ?? await _locationService.getLastKnownPosition();
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
        await ref.read(captainRepositoryProvider).setAvailability(
          uid,
          true,
          lat: pos.latitude,
          lng: pos.longitude,
          heading: pos.heading,
        );
      } catch (e) {
        if (!mounted) return;
        setState(() => _isOnline = false); // Revert
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not go online: $e')),
        );
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
          ref.read(captainRepositoryProvider).updateLiveLocation(
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
      _mapController?.clearRoute();
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
    final position = _lastValidPosition ??
        await _locationService.getCurrentPosition();
    if (lat == null || lng == null || position == null || !mounted) return;

    try {
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
      if (!mounted || _updateRouteSeq != currentSeq) return;
      final points = (route['points'] as List?)
          ?.map((point) => Map<String, dynamic>.from(point as Map))
          .toList();
      if (points == null || points.length < 2) return;

      await _mapController!.clearRoute();
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
        if (mounted && _updateRouteSeq == currentSeq) {
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
      if (mounted) {
        setState(() {
          _navigationDistanceMeters = route['distance_meters'] as int?;
          _navigationDurationSeconds = route['duration_seconds'] as int?;
        });
      }
    } catch (e) {
      if (mounted && showError) {
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
          SnackBar(content: Text(e.toString()), backgroundColor: context.colors.error),
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
    await _runRideAction(() => ref
        .read(captainRepositoryProvider)
        .reportRideIssue(
          rideId: rideId,
          captainId: captainId,
          issue: issue,
        ));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Issue reported to support.')),
      );
    }
  }

  Future<void> _recenter() async {
    if (_isRecentering) return;

    // 1. Fast fallback: immediately use cached or last known position
    Position? fastPos = _lastValidPosition ?? await _locationService.getLastKnownPosition();
    if (fastPos != null && _mapController != null && mounted) {
      _mapController!.moveCamera(fastPos.latitude, fastPos.longitude, zoom: 16.0);
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
            fastPos.latitude, fastPos.longitude,
            freshPos.latitude, freshPos.longitude,
          );
          if (distance < 10) shouldUpdate = false;
        }

        if (shouldUpdate) {
          _lastValidPosition = freshPos;
          _mapController!.moveCamera(freshPos.latitude, freshPos.longitude, zoom: 16.0);
          _mapController!.updateUserLocation(
            freshPos.latitude,
            freshPos.longitude,
            heading: freshPos.heading,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to get location: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isRecentering = false);
      }
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
        _mapController?.clearRoute();
      }
    });

    ref.listen(incomingRequestsProvider, (previous, next) {
      final requests = next.value;
      final nearby = requests == null ? const <Map<String, dynamic>>[] : _nearbyRequests(requests);
      if (_isOnline && nearby.isNotEmpty && activeRideAsync.value == null) {
        final pickup = nearby.first['pickup'];
        if (pickup is Map) {
          _renderRouteToTarget(
            Map<String, dynamic>.from(pickup),
            isPickup: true,
          );
        }
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
                  controller.moveCamera(
                    20.5937,
                    78.9629,
                    zoom: 4.5,
                  );

                  if (!mounted) return;

                  // 2. Try to get a fast last known location and animate there
                  final lastKnown = await _locationService.getLastKnownPosition();
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
                    if (requests.isNotEmpty && requests.first['pickup'] is Map) {
                      await _renderRouteToTarget(
                        Map<String, dynamic>.from(requests.first['pickup'] as Map),
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
                  // Menu button
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 8,
                          offset: Offset(0, 3),
                        ),
                      ],
                    ),
                    child: IconButton(
                      onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                      icon: Icon(
                        Icons.menu_rounded,
                        color: context.colors.primary,
                        size: 22,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Title card
                  Expanded(
                    child: Container(
                      height: 46,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 8,
                            offset: Offset(0, 3),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          Icon(
                            Icons.local_taxi_rounded,
                            color: context.colors.primary,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Captain Dashboard',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                                color: context.colors.primary,
                              ),
                            ),
                          ),
                          // Online toggle
                          Transform.scale(
                            scale: 0.8,
                            child: Switch(
                              value: _isOnline,
                              activeThumbColor: context.colors.liveTeal,
                              onChanged: activeRideAsync.value != null
                                  ? null
                                  : _toggleOnline,
                            ),
                          ),
                          Text(
                            activeRideAsync.value != null
                                ? 'On trip'
                                : _isOnline
                                    ? 'Online'
                                    : 'Offline',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: _isOnline
                                  ? context.colors.liveTeal
                                  : const Color(0xFF9CA3AF),
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
                color: context.colors.rapidoYellow,
                borderRadius: BorderRadius.circular(12),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 8,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: IconButton(
                onPressed: _isRecentering ? null : _recenter,
                icon: _isRecentering 
                  ? SizedBox(
                      width: 20, 
                      height: 20, 
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: context.colors.primary)
                    )
                  : Icon(
                      Icons.my_location_rounded,
                      color: context.colors.primary,
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
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 20,
                      offset: Offset(0, -4),
                    ),
                  ],
                ),
                child: activeRideAsync.when(
                  data: (activeRide) {
                    Widget sheetContent;
                    if (activeRide != null) {
                      sheetContent = _buildActiveRideSheet(context, ref, activeRide);
                    } else if (!_isOnline) {
                      sheetContent = _buildOfflineSheet();
                    } else {
                      sheetContent = incomingRequestsAsync.when(
                        data: (requests) {
                          final nearbyRequests = _nearbyRequests(requests);
                          if (nearbyRequests.isEmpty) {
                            return _buildSearchingSheet();
                          }
                          return _buildIncomingRequestSheet(context, ref, nearbyRequests.first);
                        },
                        loading: () => const Center(child: CircularProgressIndicator()),
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
                        layoutBuilder: (currentChild, previousChildren) => Stack(
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
                              final screenHeight = MediaQuery.of(context).size.height;
                              // Calculate exact fraction
                              final target = (size.height / screenHeight).clamp(0.25, 0.95);
                              if (_targetSheetFraction == null || (_targetSheetFraction! - target).abs() > 0.01) {
                                WidgetsBinding.instance.addPostFrameCallback((_) {
                                  if (mounted) {
                                    setState(() => _targetSheetFraction = target);
                                    if (_sheetController.isAttached) {
                                      _sheetController.animateTo(target, duration: const Duration(milliseconds: 250), curve: Curves.easeOutCubic);
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
                  loading: () => const Center(child: CircularProgressIndicator()),
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
      width: 44,
      height: 4,
      margin: const EdgeInsets.only(top: 12, bottom: 20),
      decoration: BoxDecoration(
        color: const Color(0xFFDDE3EA),
        borderRadius: BorderRadius.circular(12),
      ),
    ),
  );

  // ── Offline sheet ────────────────────────────────────────────
  Widget _buildOfflineSheet() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
        _dragHandle(),
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF9CA3AF).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFF9CA3AF).withValues(alpha: 0.3),
              ),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.wifi_off_rounded,
                  size: 16,
                  color: Color(0xFF9CA3AF),
                ),
                SizedBox(width: 8),
                Text(
                  'You are offline',
                  style: TextStyle(
                    color: Color(0xFF9CA3AF),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Go online to start\nreceiving ride requests',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: context.colors.primary,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Toggle the switch at the top to go online',
          textAlign: TextAlign.center,
          style: TextStyle(color: Color(0xFF6B7280), fontSize: 12),
        ),
        ],
      ),
    );
  }

  // ── Searching sheet ──────────────────────────────────────────
  Widget _buildSearchingSheet() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
        _dragHandle(),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: context.colors.liveTeal.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: context.colors.liveTeal.withValues(alpha: 0.25),
            ),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: context.colors.liveTeal,
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Searching for Users',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: context.colors.primary,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'You\'re online and available',
                      style: TextStyle(color: Color(0xFF6B7280), fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        ],
      ),
    );
  }

  // ── Incoming request sheet ───────────────────────────────────
  Widget _buildIncomingRequestSheet(
    BuildContext context,
    WidgetRef ref, Map<String, dynamic> request,
  ) {
    final fare = request['fareEstimate'];
    final dest = request['destination']?['address'] ?? 'Unknown';
    final distM = request['distanceMeters'] as int?;

    return SafeArea(
      top: false,
      child: Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
        _dragHandle(),

        // Alert header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF16A34A).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0xFF16A34A).withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.notifications_active_rounded,
                color: Color(0xFF16A34A),
                size: 18,
              ),
              SizedBox(width: 8),
              Text(
                'New Ride Request!',
                style: TextStyle(
                  color: context.colors.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Route card
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFD),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: context.colors.rapidoYellow,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Current Location',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Column(
                  children: List.generate(
                    3,
                    (_) => Container(
                      width: 2,
                      height: 6,
                      margin: const EdgeInsets.symmetric(vertical: 2),
                      color: const Color(0xFFD1D5DB),
                    ),
                  ),
                ),
              ),
              Row(
                children: [
                  Icon(
                    Icons.flag_rounded,
                    color: context.colors.error,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      dest,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
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
                          _runRideAction(() => ref
                              .read(captainRepositoryProvider)
                              .rejectRide(request['id'] as String, uid));
                        }
                      },
                style: OutlinedButton.styleFrom(
                  foregroundColor: context.colors.error,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Skip'),
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
                          _runRideAction(() => ref
                              .read(captainRepositoryProvider)
                              .acceptRide(request['id'] as String, uid));
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: context.colors.rapidoYellow,
                  foregroundColor: context.colors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isRideActionLoading
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: context.colors.primary,
                        ),
                      )
                    : const Text(
                        'Accept Ride',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
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
    WidgetRef ref, Map<String, dynamic> activeRide,
  ) {
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

    return SafeArea(
      top: false,
      child: Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
        _dragHandle(),

        // Status chip
        _captainStatusChip(status),
        const SizedBox(height: 12),

        // Ride info card
        if (status != 'in_progress') ...[
          Container(
            padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFD),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: context.colors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.person_rounded,
                      color: context.colors.primary,
                      size: 22,
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
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          riderPhone?.isNotEmpty == true
                              ? '$riderPhone • $targetAddress'
                              : targetAddress,
                          style: const TextStyle(
                            color: Color(0xFF6B7280),
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '₹$fare',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: context.colors.primary,
                    ),
                  ),
                ],
              ),
            ],
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (etaMinutes != null && navigationKm != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFBFDBFE)),
            ),
            child: Row(
              children: [
                const Icon(Icons.route_rounded, color: Color(0xFF2563EB)),
                const SizedBox(width: 10),
                Text(
                  '$etaMinutes min • $navigationKm km',
                  style: const TextStyle(
                    color: Color(0xFF1D4ED8),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                Text(
                  isHeadingToPickup ? 'to pickup' : 'to destination',
                  style: const TextStyle(
                    color: Color(0xFF1D4ED8),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 12),
        if (status != 'in_progress') ...[
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: riderPhone?.isNotEmpty == true
                      ? () => _callNumber(riderPhone!)
                      : null,
                  icon: const Icon(Icons.call_rounded, size: 18),
                  label: const Text('Call'),
                ),
              ),
              const SizedBox(width: 8),
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
                                TextButton(
                                  onPressed: () => Navigator.pop(dialogContext, false),
                                  child: const Text('No'),
                                ),
                                ElevatedButton(
                                  onPressed: () => Navigator.pop(dialogContext, true),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: context.colors.error,
                                    foregroundColor: Colors.white,
                                  ),
                                  child: const Text('Yes, Cancel'),
                                ),
                              ],
                            ),
                          );
                          if (confirmed != true) return;
                          await _runRideAction(() => ref
                              .read(captainRepositoryProvider)
                              .transitionRide(
                                rideId: rideId,
                                captainId: captainId,
                                fromStatus: status,
                                toStatus: 'cancelled',
                              ));
                        },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: context.colors.error,
                    side: BorderSide(color: context.colors.error),
                  ),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                tooltip: 'Report ride issue',
                onPressed: captainId == null
                    ? null
                    : () => _reportIssue(rideId, captainId),
                icon: const Icon(Icons.report_problem_outlined),
                style: IconButton.styleFrom(
                  backgroundColor: context.colors.rapidoYellow,
                  foregroundColor: Colors.black,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],

        // Action by status
        if (status == 'accepted')
          ElevatedButton.icon(
            onPressed: _isRideActionLoading || captainId == null
                ? null
                : () => _runRideAction(() => ref
                    .read(captainRepositoryProvider)
                    .transitionRide(
                      rideId: rideId,
                      captainId: captainId,
                      fromStatus: 'accepted',
                      toStatus: 'arrived',
                    )),
            icon: const Icon(Icons.location_on_rounded),
            label: const Text('Arrived at Pickup'),
            style: ElevatedButton.styleFrom(
              backgroundColor: context.colors.rapidoYellow,
              foregroundColor: context.colors.primary,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          )
        else if (status == 'arriving')
          ElevatedButton.icon(
            onPressed: _isRideActionLoading || captainId == null
                ? null
                : () => _runRideAction(() => ref
                    .read(captainRepositoryProvider)
                    .transitionRide(
                      rideId: rideId,
                      captainId: captainId,
                      fromStatus: 'arriving',
                      toStatus: 'arrived',
                    )),
            icon: const Icon(Icons.location_on_rounded),
            label: const Text('I have Arrived'),
            style: ElevatedButton.styleFrom(
              backgroundColor: context.colors.rapidoYellow,
              foregroundColor: context.colors.primary,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          )
        else if (status == 'arrived') ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: context.colors.primary.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: context.colors.primary.withValues(alpha: 0.2),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Enter User''s OTP',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: context.colors.primary,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Ask the user for their 4-digit OTP',
                  style: TextStyle(color: Color(0xFF6B7280), fontSize: 12),
                ),
                const SizedBox(height: 12),
                // Single OTP input, centered and reduced in size
                Center(
                  child: SizedBox(
                    width: 240,
                    child: TextField(
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
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 16.0,
                        color: context.colors.primary,
                      ),
                      decoration: InputDecoration(
                        hintText: 'OTP',
                        hintStyle: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0,
                          color: Color(0xFF9CA3AF),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(vertical: 8),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFFD1D5DB),
                            width: 1.5,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: context.colors.primary,
                            width: 2,
                          ),
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
                  ),
                ),
                const SizedBox(height: 12),
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
                      backgroundColor: context.colors.rapidoYellow,
                      foregroundColor: context.colors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text(
                      'Verify OTP',
                      style: TextStyle(fontWeight: FontWeight.w700),
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
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                        ),
                        content: const Text(
                          'Confirm only after reaching the destination and collecting the fare.',
                          style: TextStyle(fontSize: 14),
                        ),
                        actionsPadding: const EdgeInsets.only(left: 16, right: 16, bottom: 16, top: 8),
                        actions: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              ElevatedButton(
                                onPressed: () => Navigator.pop(dialogContext, false),
                                style: ElevatedButton.styleFrom(
                                  minimumSize: Size.zero,
                                  backgroundColor: const Color(0xFFEF4444), // Red color
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  elevation: 0,
                                ),
                                child: const Text(
                                  'Not yet',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton(
                                onPressed: () => Navigator.pop(dialogContext, true),
                                style: ElevatedButton.styleFrom(
                                  minimumSize: Size.zero,
                                  backgroundColor: context.colors.rapidoYellow,
                                  foregroundColor: Colors.black,
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  elevation: 0,
                                ),
                                child: const Text(
                                  'Complete trip',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                    if (confirmed != true) return;
                    await _runRideAction(() => ref
                        .read(captainRepositoryProvider)
                        .transitionRide(
                          rideId: rideId,
                          captainId: captainId,
                          fromStatus: 'in_progress',
                          toStatus: 'completed',
                        ));
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
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: context.colors.primary,
                ),
              ),
              Text(
                label,
                style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _captainStatusChip(String status) {
    Color color;
    String label;
    IconData icon;
    switch (status) {
      case 'accepted':
        color = const Color(0xFF2563EB);
        label = 'Navigate to Pickup';
        icon = Icons.route_rounded;
        break;
      case 'arriving':
        color = context.colors.warning;
        label = 'Arriving at Pickup';
        icon = Icons.near_me_rounded;
        break;
      case 'arrived':
        color = const Color(0xFF16A34A);
        label = 'Arrived — Verify OTP';
        icon = Icons.location_on_rounded;
        break;
      case 'in_progress':
        color = context.colors.liveTeal;
        label = 'Trip in Progress';
        icon = Icons.electric_moped_rounded;
        break;
      default:
        color = const Color(0xFF9CA3AF);
        label = status.toUpperCase();
        icon = Icons.info_outline_rounded;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

