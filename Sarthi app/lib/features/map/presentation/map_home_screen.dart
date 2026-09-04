import 'dart:async';
import '../../services/presentation/services_screen.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/measure_size.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import '../../../ola_maps_bridge/ola_maps_view.dart';
import '../../../core/utils/location_service.dart';
import '../../../core/design/tokens.dart';
import '../../auth/presentation/auth_providers.dart';
import '../../rides/domain/fare_calculator.dart';
import 'widgets/offers_bottom_sheet.dart';
import '../../rides/presentation/ride_providers.dart';
import '../../admin/presentation/admin_providers.dart';
import '../data/ola_maps_repository.dart';
import '../../captain/data/captain_repository.dart';
import '../../rides/presentation/ride_history_screen.dart';
import '../../profile/presentation/profile_tab.dart';
import '../../../core/widgets/fade_indexed_stack.dart';

class MapHomeScreen extends ConsumerStatefulWidget {
  const MapHomeScreen({super.key});

  @override
  ConsumerState<MapHomeScreen> createState() => _MapHomeScreenState();
}

class _MapHomeScreenState extends ConsumerState<MapHomeScreen> {
  int _selectedNavIndex = 0;
  final bool _isNavVisible = true;
  OlaMapsController? _mapController;
  final LocationService _locationService = LocationService();
  bool _isLoadingLocation = true;
  bool _hasLocationPermission = false;

  // Live location tracking
  StreamSubscription<Position>? _locationSubscription;
  bool _followUser = true; // auto-pan to user while no destination is selected

  // Booking State
  Map<String, dynamic>? _destination;
  Map<String, dynamic>? _pickupLocation;
  int? _distanceMeters;
  int? _durationSeconds;
  FareBreakdown? _bikeFare;
  FareBreakdown? _autoFare;
  FareBreakdown? _parcelFare;
  FareBreakdown? _cabFare;
  String? _appliedOfferCode;
  double? _discountAmount;
  String? _routePolyline;
  List<Map<String, dynamic>>? _routePoints;
  String _bookingState = 'default';
  String _paymentMethod = 'Cash';
  String _vehicleType = 'bike';
  bool _isFetchingRoute = false;
  bool _isRecentering = false;
  Position? _lastValidPosition;
  String _currentCityState = 'Detecting...';

  final ValueNotifier<double> _sheetExtent = ValueNotifier(0.45);
  final DraggableScrollableController _sheetController =
      DraggableScrollableController();
  double? _targetSheetFraction;

  int _currentHeroIndex = 0;
  Timer? _heroImageTimer;
  final List<String> _heroImages = [
    'assets/images/3d_scooter_hero.jpg',
    'assets/images/3d_car_hero.jpg',
    'assets/images/3d_auto_hero.jpg',
  ];

  @override
  void initState() {
    super.initState();
    _sheetController.addListener(() {
      if (_sheetController.isAttached) {
        _sheetExtent.value = _sheetController.size;
      }
    });
    _initLocation();

    _heroImageTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (mounted) {
        setState(() {
          _currentHeroIndex = (_currentHeroIndex + 1) % _heroImages.length;
        });
      }
    });
  }

  @override
  void dispose() {
    _heroImageTimer?.cancel();
    _locationSubscription?.cancel();
    _sheetController.dispose();
    _sheetExtent.dispose();
    super.dispose();
  }

  /// Request permission, snap the camera to the device's current position,
  /// then subscribe to a live stream so the map tracks the user as they walk.
  Future<void> _initLocation() async {
    final granted = await _locationService.requestPermission();
    // Guard: widget may have been disposed while awaiting the permission dialog
    if (!context.mounted) return;
    setState(() {
      _hasLocationPermission = granted;
      _isLoadingLocation = false;
    });

    if (!granted) return;

    // Snap to current position immediately
    final pos = await _locationService.getCurrentPosition();
    if (!context.mounted) return; // guard after second await
    if (pos != null) {
      _updateCityStateText(pos.latitude, pos.longitude);
      if (_mapController != null) {
        _lastValidPosition = pos;
        _mapController!.moveCamera(pos.latitude, pos.longitude, zoom: 16.0);
        _mapController!.updateUserLocation(pos.latitude, pos.longitude);
      }
    }

    // Subscribe to live stream — update user dot and auto-pan while following
    _locationSubscription = _locationService.getPositionStream().listen((
      position,
    ) {
      if (!mounted || _mapController == null) return;
      _lastValidPosition = position;
      _mapController!.updateUserLocation(position.latitude, position.longitude);
      
      // Periodically update the city/state string (e.g., if we moved significantly)
      // but for now, we just rely on the initial fetch and recenter events.

      if (_followUser) {
        _mapController!.moveCamera(
          position.latitude,
          position.longitude,
          zoom: 16.0,
        );
      }
    });
  }

  Future<void> _updateCityStateText(double lat, double lng) async {
    final cityState = await OlaMapsRepository().getCityAndState(lat, lng);
    if (mounted) {
      setState(() {
        _currentCityState = cityState;
      });
    }
  }

  Future<void> _recenter() async {
    if (_isRecentering) return;

    // 1. Fast fallback: immediately use cached or last known position
    Position? fastPos =
        _lastValidPosition ?? await _locationService.getLastKnownPosition();
    if (fastPos != null && _mapController != null && context.mounted) {
      setState(() => _followUser = true);
      _mapController!.moveCamera(
        fastPos.latitude,
        fastPos.longitude,
        zoom: 16.0,
      );
      _mapController!.updateUserLocation(fastPos.latitude, fastPos.longitude);
    }

    setState(() => _isRecentering = true);

    try {
      // 2. Fetch fresh high-accuracy position in background
      final freshPos = await _locationService.getCurrentPosition();
      if (freshPos != null && _mapController != null && context.mounted) {
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
          _updateCityStateText(freshPos.latitude, freshPos.longitude);
          _mapController!.moveCamera(
            freshPos.latitude,
            freshPos.longitude,
            zoom: 16.0,
          );
          _mapController!.updateUserLocation(
            freshPos.latitude,
            freshPos.longitude,
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

  @override
  Widget build(BuildContext context) {
    // Listen for captain's live location updates to move their marker on the map!
    ref.listen(assignedCaptainLocationProvider, (previous, next) {
      final loc = next.value;
      if (loc != null && _mapController != null) {
        final lat = (loc['lat'] as num).toDouble();
        final lng = (loc['lng'] as num).toDouble();
        _mapController!.addMarker(lat, lng, isCaptain: true);
      }
    });

    // Listen for ride state changes to automatically clear the map when a ride ends
    ref.listen(currentRideStreamProvider, (previous, next) {
      final oldStatus = previous?.value?.data()?['status'];
      final newStatus = next.value?.data()?['status'];

      if (oldStatus != newStatus &&
          (newStatus == 'completed' ||
              newStatus == 'cancelled' ||
              (oldStatus != null && newStatus == null))) {
        setState(() {
          _destination = null;
          _routePolyline = null;
          _routePoints = null;
          _bookingState = 'default';
          _followUser = true;
        });
        _mapController?.clearRoute();
      } else if (newStatus == 'accepted' ||
          newStatus == 'arriving' ||
          newStatus == 'arrived' ||
          newStatus == 'in_progress') {
        // If route was lost (e.g. app restart), try to restore it
        if (_routePolyline == null && _mapController != null) {
          final rideData = next.value?.data();
          if (rideData != null &&
              rideData['destination'] != null &&
              rideData['pickup'] != null) {
            final destMap = rideData['destination'] as Map<String, dynamic>;
            final pickupMap = rideData['pickup'] as Map<String, dynamic>;

            // Only recalculate route if we have valid coordinates
            if (destMap['lat'] != null && pickupMap['lat'] != null) {
              _restoreRoute(pickupMap, destMap);
            }
          }
        }
      }
    });

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: _selectedNavIndex == 3
          ? const Color(0xFFF3F4F6)
          : Colors.white,
      body: Stack(
        children: [
          FadeIndexedStack(
            index: _selectedNavIndex,
            children: [
              Stack(
                children: [
                  // Background Ola Map
                  Listener(
                    onPointerDown: (_) {
                      if (_followUser) {
                        setState(() => _followUser = false);
                      }
                    },
                    child: OlaMapsView(
                      onMapCreated: (controller) {
                        _mapController = controller;
                        controller.mapEvents.listen((event) async {
                          if (event is Map && event['event'] == 'mapReady') {
                            // 1. Immediately jump to India to avoid showing the whole world map
                            controller.moveCamera(20.5937, 78.9629, zoom: 4.5);

                            if (!context.mounted) return;

                            // 2. Try to get a fast last known location and animate there
                            final lastKnown = await _locationService
                                .getLastKnownPosition();
                            if (lastKnown != null && context.mounted) {
                              controller.moveCamera(
                                lastKnown.latitude,
                                lastKnown.longitude,
                                zoom: 14.0,
                              );
                            }

                            // 3. Fetch the accurate current location
                            final pos = await _locationService
                                .getCurrentPosition();
                            if (pos != null && context.mounted) {
                              // Apply bottom padding first so the camera centres
                              // the blue dot in the visible area above the sheet
                              await controller.setPadding(bottom: 300);
                              controller.moveCamera(
                                pos.latitude,
                                pos.longitude,
                                zoom: 16.0,
                              );
                              // Only drop the blue dot when we have the accurate GPS fix
                              controller.updateUserLocation(
                                pos.latitude,
                                pos.longitude,
                              );
                            }
                          }
                        });
                      },
                    ),
                  ),
                  // Safe area aware top location/search shell
                  SafeArea(
                    top: true,
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          if (_destination != null) ...[
                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  _destination = null;
                                  _bookingState = 'default';
                                  _followUser = true;
                                  _mapController?.clearRoute();
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                margin: const EdgeInsets.only(right: 12),
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black12,
                                      blurRadius: 4,
                                      offset: Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.arrow_back_rounded,
                                  size: 20,
                                ),
                              ),
                            ),
                          ],
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 14,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Colors.black12,
                                    blurRadius: 8,
                                    offset: Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  // ── Logo ─────────────────────────────
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          gradient: const LinearGradient(
                                            colors: [
                                              Color(0xFF0B2144),
                                              Color(0xFF1A3A6B),
                                            ],
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: const Color(
                                                0xFF0B2144,
                                              ).withValues(alpha: 0.3),
                                              blurRadius: 8,
                                              offset: const Offset(0, 3),
                                            ),
                                          ],
                                        ),
                                        child: const SarthiLogo(size: 16),
                                      ),
                                      const SizedBox(width: 8),
                                      ShaderMask(
                                        shaderCallback: (bounds) =>
                                            const LinearGradient(
                                              colors: [
                                                Color(0xFF0B2144),
                                                Color(0xFF1A3A6B),
                                              ],
                                            ).createShader(bounds),
                                        child: const Text(
                                          'Sarthi',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w900,
                                            fontSize: 17,
                                            color: Colors.white,
                                            letterSpacing: -0.5,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const Spacer(),

                                  // ── Location pill ────────────────────
                                  GestureDetector(
                                    onTap: () {},
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            const Color(
                                              0xFF2563EB,
                                            ).withValues(alpha: 0.08),
                                            const Color(
                                              0xFF3B82F6,
                                            ).withValues(alpha: 0.04),
                                          ],
                                        ),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: const Color(
                                            0xFF2563EB,
                                          ).withValues(alpha: 0.25),
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Container(
                                            width: 6,
                                            height: 6,
                                            decoration: const BoxDecoration(
                                              color: Color(0xFF22C55E),
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                          const SizedBox(width: 5),
                                          Text(
                                            _currentCityState,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 10,
                                              color: Color(0xFF0F172A),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const Spacer(),

                                  // ── Notification Bell ─────────────────
                                  Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      GestureDetector(
                                        onTap: () =>
                                            context.push('/notifications'),
                                        child: Container(
                                          width: 36,
                                          height: 36,
                                          decoration: BoxDecoration(
                                            color: const Color(
                                              0xFF0F172A,
                                            ).withValues(alpha: 0.06),
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: const Color(
                                                0xFF0F172A,
                                              ).withValues(alpha: 0.08),
                                            ),
                                          ),
                                          child: const Icon(
                                            Icons.notifications_none_rounded,
                                            size: 18,
                                            color: Color(0xFF0F172A),
                                          ),
                                        ),
                                      ),
                                      Positioned(
                                        top: 2,
                                        right: 2,
                                        child: Container(
                                          width: 9,
                                          height: 9,
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFEF4444),
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: Colors.white,
                                              width: 1.5,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(width: 10),

                                  // ── Profile Avatar ────────────────────
                                  GestureDetector(
                                    onTap: () => _onNavTapped(3),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: const LinearGradient(
                                          colors: [
                                            Color(0xFF0B2144),
                                            Color(0xFF3B82F6),
                                          ],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: const Color(
                                              0xFF0B2144,
                                            ).withValues(alpha: 0.3),
                                            blurRadius: 8,
                                            offset: const Offset(0, 3),
                                          ),
                                        ],
                                      ),
                                      child: const CircleAvatar(
                                        radius: 17,
                                        backgroundColor: Colors.transparent,
                                        child: Icon(
                                          Icons.person_rounded,
                                          color: Colors.white,
                                          size: 20,
                                        ),
                                      ),
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

                  // Map Layers and Recenter Buttons
                  ValueListenableBuilder<double>(
                    valueListenable: _sheetExtent,
                    builder: (context, extent, child) {
                      final screenHeight = MediaQuery.of(context).size.height;
                      return Positioned(
                        bottom: (screenHeight * extent) + 16,
                        right: 16,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 46,
                              height: 46,
                              margin: const EdgeInsets.only(bottom: 12),
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
                                onPressed: () {},
                                icon: const Icon(
                                  Icons.layers_outlined,
                                  size: 22,
                                ),
                                splashRadius: 22,
                                color: context.colors.primary,
                              ),
                            ),
                            child!,
                          ],
                        ),
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
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: context.colors.primary,
                                ),
                              )
                            : const Icon(Icons.my_location_rounded, size: 22),
                        splashRadius: 22,
                      ),
                    ),
                  ),

                  // Bottom sheet draggable shell
                  DraggableScrollableSheet(
                    controller: _sheetController,
                    initialChildSize: (_targetSheetFraction ?? 0.38).clamp(
                      0.15,
                      1.0,
                    ),
                    minChildSize: 0.15,
                    maxChildSize: 1.0,
                    builder: (context, scrollController) {
                      return Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
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
                        child: Consumer(
                          builder: (context, ref, _) {
                            final rideStream = ref.watch(
                              currentRideStreamProvider,
                            );
                            return rideStream.when(
                              data: (rideSnapshot) {
                                final rideData = rideSnapshot?.data();
                                final status = rideData?['status'];
                                final otp = rideData?['otp'];
                                final fare = rideData?['fareEstimate'];
                                final rideId = rideSnapshot?.id;
                                String displayState = _bookingState;
                                if (status != null) displayState = status;

                                // Build the content for the current state
                                Widget stateContent;
                                if (displayState == 'searching') {
                                  stateContent = _buildSearchingContent(
                                    context,
                                    ref,
                                    rideId,
                                  );
                                } else if (displayState == 'accepted' ||
                                    displayState == 'arriving' ||
                                    displayState == 'arrived') {
                                  stateContent = _buildCaptainFoundContent(
                                    context,
                                    otp,
                                    fare,
                                    displayState,
                                  );
                                } else if (displayState == 'in_progress') {
                                  stateContent = _buildInProgressContent(
                                    context,
                                  );
                                } else if (displayState == 'completed') {
                                  stateContent = _buildCompletedContent(
                                    context,
                                    ref,
                                    fare,
                                  );
                                } else if (displayState == 'selected' &&
                                    _destination != null) {
                                  stateContent = _buildSelectedContent(
                                    context,
                                    ref,
                                  );
                                } else {
                                  stateContent = _buildDefaultContent(
                                    context,
                                    ref,
                                  );
                                }

                                return AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 100),
                                  switchInCurve: Curves.easeOut,
                                  switchOutCurve: Curves.easeIn,
                                  transitionBuilder: (child, animation) =>
                                      FadeTransition(
                                        opacity: animation,
                                        child: child,
                                      ),
                                  layoutBuilder:
                                      (currentChild, previousChildren) => Stack(
                                        alignment: Alignment.topCenter,
                                        children: <Widget>[
                                          ...previousChildren,
                                          ?currentChild,
                                        ],
                                      ),
                                  child: KeyedSubtree(
                                    key: ValueKey(displayState),
                                    child: SingleChildScrollView(
                                      controller: scrollController,
                                      physics: const ClampingScrollPhysics(),
                                      child: MeasureSize(
                                        onChange: (size) {
                                          final screenHeight = MediaQuery.of(
                                            context,
                                          ).size.height;
                                          final safeBottom = MediaQuery.of(
                                            context,
                                          ).padding.bottom;
                                          // Calculate the exact fraction needed for this content
                                          final target =
                                              ((size.height + 24 + safeBottom) /
                                                      screenHeight)
                                                  .clamp(
                                                    0.15,
                                                    displayState == 'default'
                                                        ? 0.70
                                                        : 0.95,
                                                  );
                                          if (_targetSheetFraction == null ||
                                              (_targetSheetFraction! - target)
                                                      .abs() >
                                                  0.01) {
                                            WidgetsBinding.instance
                                                .addPostFrameCallback((_) {
                                                  if (mounted) {
                                                    setState(
                                                      () =>
                                                          _targetSheetFraction =
                                                              target,
                                                    );
                                                    if (_sheetController
                                                        .isAttached) {
                                                      _sheetController
                                                          .animateTo(
                                                            target,
                                                            duration:
                                                                const Duration(
                                                                  milliseconds:
                                                                      250,
                                                                ),
                                                            curve: Curves
                                                                .easeOutCubic,
                                                          );
                                                    }
                                                  }
                                                });
                                          }
                                        },
                                        child: stateContent,
                                      ),
                                    ),
                                  ),
                                );
                              },
                              loading: () => const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(32),
                                  child: CircularProgressIndicator(),
                                ),
                              ),
                              error: (err, stack) =>
                                  Center(child: Text('Error: $err')),
                            );
                          },
                        ),
                      );
                    },
                  ),
                ],
              ),
              const ServicesScreen(),
              RideHistoryScreen(onBack: () => _onNavTapped(3)),
              ProfileTab(onNavTapped: _onNavTapped),
            ],
          ),
          if (_selectedNavIndex != 0 || _destination == null)
            AnimatedPositioned(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              bottom: 0,
              left: 0,
              right: 0,
              child: _buildFloatingNavBar(),
            ),
        ],
      ),
    );
  }

  // Delegates to _initLocation — kept so existing references compile
  Future<void> _checkLocation() async => _initLocation();

  // ── Sheet content builders ────────────────────────────────
  Widget _buildDefaultContent(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);
    final homeAddress = userAsync.value?.homeAddress;
    final workAddress = userAsync.value?.workAddress;
    final userName = userAsync.value?.name.split(' ').first ?? 'User';

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag handle — centered
              const Center(child: _DragHandle()),
              const SizedBox(height: 16),

              Text(
                'Good evening, $userName',
                style: const TextStyle(
                  fontSize: 8,
                  color: Color(0xFF6B7280),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Where are you going?',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: context.colors.primary,
                ),
              ),
              const SizedBox(height: 12),

              // ── 3D Hero Banner ───────────────────────────────────
              Container(
                height: 110,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0B2144), Color(0xFF1A3A6B)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0B2144).withValues(alpha: 0.45),
                      blurRadius: 24,
                      spreadRadius: 2,
                      offset: const Offset(0, 8),
                    ),
                    BoxShadow(
                      color: const Color(0xFF1A3A6B).withValues(alpha: 0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // Background decorative circles
                    Positioned(
                      right: -10,
                      top: -20,
                      child: Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.04),
                        ),
                      ),
                    ),
                    Positioned(
                      right: 60,
                      bottom: -30,
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.04),
                        ),
                      ),
                    ),
                    // Text content
                    Positioned(
                      left: 16,
                      top: 16,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Live badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFBBF24),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 5,
                                  height: 5,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF0B2144),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Text(
                                  'Live drivers nearby',
                                  style: TextStyle(
                                    color: Color(0xFF0B2144),
                                    fontSize: 8,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Book your ride',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Fast. Safe. Affordable.',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.65),
                              fontSize: 9,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // 3D scooter image — positioned to overflow top
                    Positioned(
                      right: 0,
                      top: -12,
                      bottom: -4,
                      child: ClipRRect(
                        borderRadius: const BorderRadius.only(
                          topRight: Radius.circular(18),
                          bottomRight: Radius.circular(18),
                        ),
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 600),
                          transitionBuilder:
                              (Widget child, Animation<double> animation) {
                                return FadeTransition(
                                  opacity: animation,
                                  child: child,
                                );
                              },
                          child: Image.asset(
                            _heroImages[_currentHeroIndex],
                            key: ValueKey<int>(_currentHeroIndex),
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) =>
                                const Icon(
                                  Icons.directions_car_rounded,
                                  color: Colors.white54,
                                  size: 80,
                                ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Search destination bar inside bottom sheet
              GestureDetector(
                onTap: () async {
                  final result = await context.push('/search');
                  if (result != null && result is Map<String, dynamic>) {
                    if (!context.mounted) return;
                    await _processDestination(context, result);
                  }
                },
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2563EB).withValues(alpha: 0.07),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xFF3B82F6).withValues(alpha: 0.5),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(
                              0xFF2563EB,
                            ).withValues(alpha: 0.12),
                            blurRadius: 14,
                            spreadRadius: 1,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: const Color(
                                0xFF2563EB,
                              ).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.route_outlined,
                              size: 18,
                              color: Color(0xFF2563EB),
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'Search destination',
                              style: TextStyle(
                                fontSize: 11,
                                color: Color(0xFF6B7280),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          Container(
                            width: 1,
                            height: 22,
                            color: const Color(
                              0xFF3B82F6,
                            ).withValues(alpha: 0.25),
                            margin: const EdgeInsets.symmetric(horizontal: 12),
                          ),
                          const Icon(
                            Icons.mic_none_rounded,
                            color: Color(0xFF3B82F6),
                            size: 22,
                          ),
                        ],
                      ),
                    ),
                    // Floating label — like the design reference
                    Positioned(
                      top: -9,
                      left: 20,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'Where to?',
                          style: TextStyle(
                            fontSize: 9,
                            color: Color(0xFF3B82F6),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Pickup Location Row
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Color(0xFF2563EB),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Pickup: ',
                      style: TextStyle(fontSize: 9, color: Color(0xFF6B7280)),
                    ),
                    const Expanded(
                      child: Text(
                        'Current location',
                        style: TextStyle(
                          fontSize: 9,
                          color: Color(0xFF2563EB),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.edit_outlined,
                      size: 16,
                      color: Color(0xFF6B7280),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Quick destinations — premium header row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 3,
                        height: 14,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF2563EB), Color(0xFF60A5FA)],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Quick destinations',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                          letterSpacing: -0.2,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'Saved places',
                      style: TextStyle(
                        fontSize: 9,
                        color: Color(0xFF2563EB),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Home & Work cards
              Row(
                children: [
                  Expanded(
                    child: _buildQuickRideCard(
                      context,
                      Icons.home_rounded,
                      'Home',
                      homeAddress?['description'] ?? 'Add home address',
                      onTap: () {
                        if (homeAddress != null) {
                          _processDestination(context, homeAddress);
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Please add a Home Address in your profile first.',
                              ),
                            ),
                          );
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildQuickRideCard(
                      context,
                      Icons.work_rounded,
                      'Work',
                      workAddress?['description'] ?? 'Add work address',
                      onTap: () {
                        if (workAddress != null) {
                          _processDestination(context, workAddress);
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Please add a Work Address in your profile first.',
                              ),
                            ),
                          );
                        }
                      },
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Vehicle carousel (Static Mock)
              Row(
                children: [
                  Expanded(
                    child: _buildMockVehicleCard(
                      context,
                      'Bike',
                      '3 min away',
                      Icons.motorcycle_rounded,
                      false,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildMockVehicleCard(
                      context,
                      'Auto',
                      '2 min away',
                      Icons.electric_rickshaw_rounded,
                      false,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildMockVehicleCard(
                      context,
                      'Cab',
                      '4 min away',
                      Icons.directions_car_rounded,
                      false,
                    ),
                  ),
                ],
              ),

              // Location permission banner
              if (!_hasLocationPermission && !_isLoadingLocation) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: context.colors.error.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: context.colors.error.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.location_off_rounded,
                        color: context.colors.error,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Location permission required.',
                          style: TextStyle(
                            color: context.colors.error,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: _checkLocation,
                        child: const Text('Grant'),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 150),
            ],
          ),
        ),

        Image.asset(
          'assets/images/promo_banner.png',
          width: double.infinity,
          fit: BoxFit.cover,
        ),

        const SizedBox(
          height: 115,
        ), // Added padding at the bottom so elements don't get covered by nav bar
      ],
    );
  }

  Widget _buildMockVehicleCard(
    BuildContext context,
    String title,
    String eta,
    IconData icon,
    bool isSelected,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected ? context.colors.primary : const Color(0xFFE5E7EB),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 20, color: context.colors.primary),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 10,
                    color: context.colors.primary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        eta,
                        style: const TextStyle(
                          fontSize: 7,
                          color: Color(0xFF6B7280),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 2),
                    Container(
                      width: 4,
                      height: 4,
                      decoration: const BoxDecoration(
                        color: Color(0xFF16A34A),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickRideCard(
    BuildContext context,
    IconData icon,
    String title,
    String subtitle, {
    required VoidCallback onTap,
  }) {
    final isHome = title.toLowerCase() == 'home';
    final gradientColors = isHome
        ? [const Color(0xFF1D4ED8), const Color(0xFF3B82F6)]
        : [const Color(0xFF374151), const Color(0xFF6B7280)];
    final bgColor = isHome ? const Color(0xFFEFF6FF) : const Color(0xFFF9FAFB);
    final iconColor = isHome
        ? const Color(0xFF2563EB)
        : const Color(0xFF4B5563);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isHome
                ? const Color(0xFF2563EB).withValues(alpha: 0.2)
                : const Color(0xFFE5E7EB),
          ),
          boxShadow: [
            BoxShadow(
              color: isHome
                  ? const Color(0xFF2563EB).withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            // Gradient icon container
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: gradientColors,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: gradientColors[0].withValues(alpha: 0.3),
                    blurRadius: 6,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Icon(icon, size: 18, color: Colors.white),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 8,
                      color: Color(0xFF9CA3AF),
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
    );
  }

  Widget _buildFloatingNavBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      padding: EdgeInsets.only(
        top: 8,
        bottom: MediaQuery.of(context).padding.bottom,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Expanded(
            child: _NavItem(
              selectedIcon: Icons.home_filled,
              unselectedIcon: Icons.home_outlined,
              label: 'Home',
              isSelected: _selectedNavIndex == 0,
              onTap: () => _onNavTapped(0),
            ),
          ),
          Expanded(
            child: _NavItem(
              selectedIcon: Icons.grid_view_rounded,
              unselectedIcon: Icons.grid_view_outlined,
              label: 'Services',
              isSelected: _selectedNavIndex == 1,
              onTap: () => _onNavTapped(1),
            ),
          ),
          Expanded(
            child: _NavItem(
              selectedIcon: Icons.work_rounded,
              unselectedIcon: Icons.work_outline_rounded,
              label: 'Trips',
              isSelected: _selectedNavIndex == 2,
              onTap: () => _onNavTapped(2),
            ),
          ),
          Expanded(
            child: _NavItem(
              selectedIcon: Icons.person,
              unselectedIcon: Icons.person_outline,
              label: 'Profile',
              isSelected: _selectedNavIndex == 3,
              onTap: () => _onNavTapped(3),
            ),
          ),
        ],
      ),
    );
  }

  void _onNavTapped(int index) {
    if (_selectedNavIndex == index) return;
    setState(() => _selectedNavIndex = index);
  }

  Widget _buildSelectedContent(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _DragHandle(),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: context.colors.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.flag_rounded,
                  color: context.colors.error,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _destination!['description'] ?? 'Destination',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),
          if (_isFetchingRoute)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_bikeFare != null &&
              _autoFare != null &&
              _parcelFare != null &&
              _cabFare != null) ...[
            Container(
              height:
                  240, // increased height slightly to account for extra padding
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Scrollbar(
                  thickness: 4,
                  radius: const Radius.circular(8),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16), // increased padding
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildVehicleOption(
                          'bike',
                          'Bike',
                          Icons.electric_moped_rounded,
                          _bikeFare!,
                        ),
                        const SizedBox(height: 8),
                        _buildVehicleOption(
                          'auto',
                          'Auto Rickshaw',
                          Icons.local_taxi_rounded,
                          _autoFare!,
                        ),
                        const SizedBox(height: 8),
                        _buildVehicleOption(
                          'parcel',
                          'Send a Parcel',
                          Icons.local_shipping_rounded,
                          _parcelFare!,
                        ),
                        const SizedBox(height: 8),
                        _buildVehicleOption(
                          'cab',
                          'Cab',
                          Icons.directions_car_rounded,
                          _cabFare!,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () async {
                      final currentFare =
                          (_vehicleType == 'auto'
                                  ? _autoFare!
                                  : _vehicleType == 'parcel'
                                  ? _parcelFare!
                                  : _vehicleType == 'cab'
                                  ? _cabFare!
                                  : _bikeFare!)
                              .finalFare
                              .toInt();
                      final result =
                          await showModalBottomSheet<Map<String, dynamic>>(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (_) => OffersBottomSheet(
                              currentFare: currentFare,
                              currentlyAppliedCode: _appliedOfferCode,
                            ),
                          );

                      if (result != null && mounted) {
                        setState(() {
                          if (result['remove'] == true) {
                            _appliedOfferCode = null;
                            _discountAmount = null;
                          } else {
                            _appliedOfferCode = result['code'];
                            _discountAmount = result['discountAmount'];
                          }
                        });
                      }
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: _appliedOfferCode != null
                            ? const Color(0xFF10B981).withValues(alpha: 0.1)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _appliedOfferCode != null
                              ? const Color(0xFF10B981)
                              : const Color(0xFFE5E7EB),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.local_offer_rounded,
                            color: _appliedOfferCode != null
                                ? const Color(0xFF10B981)
                                : const Color(0xFF6B7280),
                            size: 18,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _appliedOfferCode != null
                                  ? '$_appliedOfferCode Applied (-₹${_discountAmount?.toInt()})'
                                  : 'Offer',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: _appliedOfferCode != null
                                    ? const Color(0xFF10B981)
                                    : context.colors.primary,
                              ),
                            ),
                          ),
                          Icon(
                            Icons.chevron_right_rounded,
                            color: _appliedOfferCode != null
                                ? const Color(0xFF10B981)
                                : const Color(0xFF6B7280),
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: InkWell(
                    onTap: () {
                      final currentFare =
                          (_vehicleType == 'bike'
                                  ? _bikeFare!
                                  : _vehicleType == 'auto'
                                  ? _autoFare!
                                  : _vehicleType == 'parcel'
                                  ? _parcelFare!
                                  : _cabFare!)
                              .finalFare
                              .toInt();
                      _showPaymentSelectionSheet(
                        context,
                        (currentFare - (_discountAmount ?? 0)).toInt().clamp(
                          0,
                          999999,
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.payments_rounded,
                            color: Color(0xFF10B981),
                            size: 18,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _paymentMethod,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: context.colors.primary,
                              ),
                            ),
                          ),
                          const Icon(
                            Icons.chevron_right_rounded,
                            color: Color(0xFF6B7280),
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: context.colors.rapidoYellow,
                foregroundColor: context.colors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                minimumSize: const Size(double.infinity, 48),
                elevation: 0,
              ),
              onPressed: () async {
                final uid = FirebaseAuth.instance.currentUser?.uid;
                if (uid != null) {
                  double? pLat = (_pickupLocation?['lat'] as num?)?.toDouble();
                  double? pLng = (_pickupLocation?['lng'] as num?)?.toDouble();
                  if (pLat == null || pLng == null) {
                    final pos = await _locationService.getCurrentPosition();
                    if (pos != null) {
                      pLat = pos.latitude;
                      pLng = pos.longitude;
                    }
                  }

                  if (pLat == null || pLng == null) return;

                  setState(() => _bookingState = 'searching');

                  // Explicitly restore the route when the ride is confirmed. This
                  // keeps the road guidance visible while a captain is being found,
                  // even if the native map/style refreshed during the state change.
                  final routePoints = _routePoints;
                  if (_mapController != null &&
                      routePoints != null &&
                      routePoints.length >= 2) {
                    await _mapController!.drawPolyline(
                      polyline: _routePolyline,
                      points: routePoints,
                      color: '#2563EB',
                    );
                    await _mapController!.fitBounds(
                      pLat,
                      pLng,
                      (_destination!['lat'] as num).toDouble(),
                      (_destination!['lng'] as num).toDouble(),
                    );
                  }

                  try {
                    final repo = ref.read(rideRepositoryProvider);
                    final rider = ref.read(currentUserProvider).value;
                    final pickupAddress =
                        _pickupLocation?['description'] ??
                        await OlaMapsRepository().reverseGeocode(pLat, pLng);
                    final currentFareObj = _vehicleType == 'auto'
                        ? _autoFare!
                        : _vehicleType == 'parcel'
                        ? _parcelFare!
                        : _vehicleType == 'cab'
                        ? _cabFare!
                        : _bikeFare!;

                    final discountedFare =
                        (currentFareObj.finalFare.toInt() -
                                (_discountAmount ?? 0))
                            .toInt()
                            .clamp(0, 999999);

                    final newRideId = await repo.createRideRequest(
                      userId: uid,
                      startLat: pLat,
                      startLng: pLng,
                      endLat: _destination!['lat'],
                      endLng: _destination!['lng'],
                      destinationName: _destination!['description'] ?? '',
                      estimatedFare: discountedFare,
                      distanceMeters: _distanceMeters!,
                      riderName: rider?.name,
                      riderPhone: rider?.phone,
                      pickupAddress: pickupAddress,
                      vehicleType: _vehicleType,
                      appliedOfferCode: _appliedOfferCode,
                      discountAmount: _discountAmount,
                      fareBreakdown: currentFareObj.toMap(),
                    );
                    ref.read(currentRideIdProvider.notifier).state = newRideId;
                  } catch (e) {
                    if (!context.mounted) return;
                    setState(() => _bookingState = 'selected');
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to request ride: $e')),
                    );
                  }
                }
              },
              child: const Text(
                'Confirm Ride',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSearchingContent(
    BuildContext context,
    WidgetRef ref,
    String? rideId,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _DragHandle(),
          const SizedBox(height: 12),
          const SizedBox(height: 12),
          const _SearchingState(),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () {
              if (rideId != null) {
                ref
                    .read(rideRepositoryProvider)
                    .updateRideStatus(rideId, 'cancelled');
                ref.read(currentRideIdProvider.notifier).state = null;
              }
              setState(() {
                _bookingState = 'default';
                _destination = null;
                _pickupLocation = null;
                _routePolyline = null;
                _routePoints = null;
                _followUser = true;
              });
              _mapController?.clearRoute();
            },
            icon: const Icon(Icons.close_rounded, size: 18),
            label: const Text('Cancel Request'),
            style: OutlinedButton.styleFrom(
              foregroundColor: context.colors.error,
              side: BorderSide(color: context.colors.error),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCaptainFoundContent(
    BuildContext context,
    dynamic otp,
    dynamic fare,
    String status,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _DragHandle(),
          const SizedBox(height: 12),
          _StatusChip(status: status),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFD),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: context.colors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.person_rounded,
                    color: context.colors.primary,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Your Captain',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'On the way',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: context.colors.rapidoYellow,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.phone_rounded,
                    color: context.colors.primary,
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
          if (status == 'arrived') ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: context.colors.rapidoYellow,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Your OTP',
                    style: TextStyle(
                      color: context.colors.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '$otp',
                    style: TextStyle(
                      color: context.colors.primary,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 8,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInProgressContent(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _DragHandle(),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: context.colors.rapidoYellow,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.electric_moped_rounded,
                  color: context.colors.primary,
                  size: 32,
                ),
                SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ride in Progress',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: context.colors.primary,
                      ),
                    ),
                    Text(
                      'Enjoy your ride!',
                      style: TextStyle(
                        fontSize: 12,
                        color: context.colors.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    // Simulate sharing a link via clipboard
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Trip tracking link copied to clipboard!',
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.share_rounded, size: 18),
                  label: const Text('Share Trip'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF3F4F6),
                    foregroundColor: context.colors.primary,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    // Simulate SOS Shield action
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'SOS Alert sent to Admin & Emergency Contacts!',
                        ),
                        backgroundColor: context.colors.error,
                      ),
                    );
                  },
                  icon: const Icon(Icons.shield_rounded, size: 18),
                  label: const Text('SOS Shield'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: context.colors.error,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCompletedContent(
    BuildContext context,
    WidgetRef ref,
    dynamic fare,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        20,
        0,
        20,
        100,
      ), // Extra padding for bottom nav bar
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _DragHandle(),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFBBF7D0)),
            ),
            child: Column(
              children: [
                const Icon(
                  Icons.check_circle_rounded,
                  color: Color(0xFF16A34A),
                  size: 44,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Ride Completed!',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF16A34A),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  fare != null
                      ? 'Total Paid: ₹$fare • Thank you for riding.'
                      : 'Thank you for riding with Sarthi App.',
                  style: const TextStyle(
                    color: Color(0xFF4B5563),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF16A34A),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    ref.read(currentRideIdProvider.notifier).state = null;
                    setState(() {
                      _destination = null;
                      _bookingState = 'default';
                      _bikeFare = null;
                      _autoFare = null;
                      _parcelFare = null;
                      _cabFare = null;
                      _appliedOfferCode = null;
                      _discountAmount = null;
                      _followUser = true;
                    });
                    _mapController?.clearRoute();
                  },
                  child: const Text('Done'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: context.colors.rapidoYellow,
                    foregroundColor: context.colors.primary,
                  ),
                  onPressed: () {
                    final rideState = ref.read(currentRideStreamProvider).value;
                    final captainId =
                        rideState?.data()?['assignedCaptainId'] as String?;
                    if (captainId != null) {
                      _showRatingSheet(context, captainId, ref);
                    } else {
                      ref.read(currentRideIdProvider.notifier).state = null;
                      setState(() {
                        _destination = null;
                        _pickupLocation = null;
                        _bookingState = 'default';
                        _bikeFare = null;
                        _autoFare = null;
                        _parcelFare = null;
                        _cabFare = null;
                        _appliedOfferCode = null;
                        _discountAmount = null;
                        _followUser = true;
                      });
                      _mapController?.clearRoute();
                    }
                  },
                  icon: const Icon(Icons.star_rounded),
                  label: const Text('Rate Captain'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVehicleOption(
    String type,
    String title,
    IconData icon,
    FareBreakdown fare,
  ) {
    final isSelected = _vehicleType == type;
    return InkWell(
      onTap: () => setState(() => _vehicleType = type),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFF8FAFD) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? context.colors.primary
                : const Color(0xFFE5E7EB),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: isSelected
                    ? context.colors.rapidoYellow
                    : const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: isSelected
                    ? context.colors.primary
                    : const Color(0xFF6B7280),
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${(_durationSeconds! / 60).round()} min • ${(_distanceMeters! / 1000).toStringAsFixed(1)} km',
                    style: const TextStyle(
                      color: Color(0xFF6B7280),
                      fontSize: 11,
                    ),
                  ),
                  if (fare.surgeMultiplier > 1.0) ...[
                    const SizedBox(height: 2),
                    Text(
                      'High demand pricing applied',
                      style: TextStyle(
                        color: context.colors.warning,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Text(
              '₹${fare.finalFare.toInt()}',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: isSelected
                    ? context.colors.primary
                    : const Color(0xFF4B5563),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showRatingSheet(BuildContext context, String captainId, WidgetRef ref) {
    int selectedStars = 0;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Rate your Captain',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(5, (index) {
                        return IconButton(
                          iconSize: 48,
                          onPressed: () {
                            setModalState(() => selectedStars = index + 1);
                          },
                          icon: Icon(
                            index < selectedStars
                                ? Icons.star_rounded
                                : Icons.star_outline_rounded,
                            color: context.colors.rapidoYellow,
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: context.colors.primary,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: selectedStars == 0
                            ? null
                            : () async {
                                Navigator.pop(ctx);
                                try {
                                  await CaptainRepository().rateCaptain(
                                    captainId,
                                    selectedStars,
                                  );
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Rating submitted! Thank you.',
                                        ),
                                        backgroundColor: Color(0xFF16A34A),
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Failed to submit rating: $e',
                                        ),
                                      ),
                                    );
                                  }
                                }
                                ref.read(currentRideIdProvider.notifier).state =
                                    null;
                                setState(() {
                                  _destination = null;
                                  _bookingState = 'default';
                                  _bikeFare = null;
                                  _autoFare = null;
                                  _parcelFare = null;
                                  _cabFare = null;
                                  _appliedOfferCode = null;
                                  _discountAmount = null;
                                  _followUser = true;
                                });
                                _mapController?.clearRoute();
                              },
                        child: const Text(
                          'Submit Rating',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showPaymentSelectionSheet(BuildContext context, int amount) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            Widget buildSectionHeader(String title) {
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                color: const Color(0xFFF3F4F6),
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF6B7280),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              );
            }

            Widget buildPaymentOption({
              required String title,
              required IconData iconData,
              required Color iconColor,
              String? subtitle,
            }) {
              final isSelected = _paymentMethod == title;
              return InkWell(
                onTap: () {
                  setState(() => _paymentMethod = title);
                  setModalState(() {});
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: iconColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(iconData, color: iconColor, size: 18),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: isSelected
                                    ? context.colors.primary
                                    : const Color(0xFF4B5563),
                              ),
                            ),
                            if (subtitle != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                subtitle,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF9CA3AF),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (isSelected)
                        const Icon(
                          Icons.check_circle,
                          color: Color(0xFF2563EB),
                          size: 20,
                        )
                      else
                        Icon(
                          Icons.radio_button_unchecked,
                          color: Colors.grey[300],
                          size: 20,
                        ),
                    ],
                  ),
                ),
              );
            }

            return SizedBox(
              height: MediaQuery.of(context).size.height * 0.85,
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Amount to be paid',
                              style: TextStyle(
                                fontSize: 14,
                                color: Color(0xFF4B5563),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '₹$amount',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: context.colors.primary,
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.close,
                            color: Color(0xFF6B7280),
                          ),
                          style: IconButton.styleFrom(
                            backgroundColor: const Color(0xFFF3F4F6),
                          ),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          buildSectionHeader('Other Payment Methods'),
                          buildPaymentOption(
                            title: 'Cash',
                            iconData: Icons.payments_rounded,
                            iconColor: const Color(0xFF10B981),
                          ),
                          buildSectionHeader('Personal Wallet'),
                          buildPaymentOption(
                            title: 'Rapido Wallet',
                            iconData: Icons.account_balance_wallet_rounded,
                            iconColor: const Color(0xFFF59E0B),
                          ),
                          buildPaymentOption(
                            title: 'Amazon Pay',
                            iconData: Icons.shopping_cart_rounded,
                            iconColor: const Color(0xFF6366F1),
                          ),
                          buildPaymentOption(
                            title: 'QR Pay',
                            iconData: Icons.qr_code_rounded,
                            iconColor: const Color(0xFF8B5CF6),
                          ),
                          buildSectionHeader('UPI - Pay by any UPI app'),
                          buildPaymentOption(
                            title: 'Paytm UPI',
                            subtitle: 'Flat ₹30 Cashback | Min. payment ₹35',
                            iconData: Icons.mobile_friendly_rounded,
                            iconColor: const Color(0xFF3B82F6),
                          ),
                          buildPaymentOption(
                            title: 'Gpay UPI',
                            iconData: Icons.g_mobiledata_rounded,
                            iconColor: const Color(0xFFEA4335),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: context.colors.rapidoYellow,
                        foregroundColor: context.colors.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        minimumSize: const Size(double.infinity, 54),
                        elevation: 0,
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: const Text(
                        'Book Taxi',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _processDestination(
    BuildContext context,
    Map<String, dynamic> result,
  ) async {
    final bool isDual = result.containsKey('destination');
    final Map<String, dynamic> destResult = isDual
        ? (result['destination'] as Map<String, dynamic>)
        : result;
    final Map<String, dynamic>? pickupResult = isDual
        ? (result['pickup'] as Map<String, dynamic>?)
        : null;

    setState(() {
      _destination = destResult;
      _pickupLocation = pickupResult;
      _routePolyline = null;
      _routePoints = null;
      _bookingState = 'selected';
      _followUser = false; // stop auto-panning to GPS when a destination is set
      _isFetchingRoute = true;
      _appliedOfferCode = null;
      _discountAmount = null;
    });
    double? destLat = (destResult['lat'] as num?)?.toDouble();
    double? destLng = (destResult['lng'] as num?)?.toDouble();
    final placeId = destResult['placeId'] as String?;
    final destName = destResult['description'] as String? ?? 'Destination';

    if ((destLat == null || destLng == null) && placeId != null) {
      final repo = OlaMapsRepository();
      final coords = await repo.geocode(placeId);
      if (coords != null) {
        destLat = coords['lat'];
        destLng = coords['lng'];
        if (mounted) {
          setState(() {
            _destination!['lat'] = destLat;
            _destination!['lng'] = destLng;
          });
        }
      }
    }

    double? pickupLat = (pickupResult?['lat'] as num?)?.toDouble();
    double? pickupLng = (pickupResult?['lng'] as num?)?.toDouble();
    final pickupPlaceId = pickupResult?['placeId'] as String?;

    if ((pickupLat == null || pickupLng == null) && pickupPlaceId != null) {
      final repo = OlaMapsRepository();
      final coords = await repo.geocode(pickupPlaceId);
      if (coords != null) {
        pickupLat = coords['lat'];
        pickupLng = coords['lng'];
        if (mounted) {
          setState(() {
            _pickupLocation!['lat'] = pickupLat;
            _pickupLocation!['lng'] = pickupLng;
          });
        }
      }
    }

    if (destLat == null || destLng == null) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not find exact location for this destination.'),
          backgroundColor: context.colors.error,
        ),
      );
      setState(() {
        _destination = null;
        _pickupLocation = null;
        _bookingState = 'default';
        _isFetchingRoute = false;
        _followUser = true;
      });
      return;
    }

    debugPrint(
      'MapHomeScreen: Selected destination lat=$destLat, lng=$destLng',
    );
    debugPrint(
      'MapHomeScreen: Calling _mapController?.addMarker for destination...',
    );

    // Add Destination marker
    final destSuccess = await _mapController?.addMarker(
      destLat,
      destLng,
      title: destName,
      isPickup: false,
    );

    debugPrint(
      'MapHomeScreen: _mapController?.addMarker returned $destSuccess',
    );
    if (destSuccess == false && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Native map engine failed to render the destination marker.',
          ),
        ),
      );
    }

    double pLat;
    double pLng;
    if (pickupLat != null && pickupLng != null) {
      pLat = pickupLat;
      pLng = pickupLng;
    } else {
      final pos = await _locationService.getCurrentPosition();
      if (pos == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not determine pickup location.')),
          );
        }
        return;
      }
      pLat = pos.latitude;
      pLng = pos.longitude;
    }

    if (true) {
      // Add Pickup marker
      final pickupName =
          pickupResult?['description'] as String? ?? 'My Location';
      final pickupSuccess = await _mapController?.addMarker(
        pLat,
        pLng,
        title: pickupName,
        isPickup: true,
      );
      if (pickupSuccess == false && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Native map engine failed to render the pickup marker.',
            ),
          ),
        );
      }

      // Fit camera bounds so both pickup and destination pins are visible!
      _mapController?.fitBounds(pLat, pLng, destLat, destLng);

      final repo = OlaMapsRepository();
      try {
        final route = await repo.getDirections(pLat, pLng, destLat, destLng);
        if (mounted) {
          final polyStr = route['polyline'] as String?;
          final pointsList = (route['points'] as List?)
              ?.cast<Map<String, dynamic>>();

          if (pointsList == null || pointsList.length < 2) {
            throw Exception(
              'Could not resolve the road route for this destination.',
            );
          }

          final bikeRules = ref.read(fareRulesProvider('bike')).value;
          final autoRules = ref.read(fareRulesProvider('auto')).value;
          final parcelRules = ref.read(fareRulesProvider('parcel')).value;

          setState(() {
            _distanceMeters = route['distance_meters'] as int;
            _durationSeconds = route['duration_seconds'] as int;
            _routePolyline = polyStr;
            _routePoints = pointsList;
            FareBreakdown getFare(Map<String, dynamic>? rules) {
              return FareCalculator.calculateFare(
                _distanceMeters!,
                _durationSeconds!,
                baseFare: (rules?['baseFare'] ?? 15).toDouble(),
                includedDistanceKm:
                    (rules?['includedDistanceKm'] ??
                            rules?['includedDistance'] ??
                            3)
                        .toDouble(),
                ratePerKm: (rules?['perKm'] ?? 5).toDouble(),
                ratePerMinute: (rules?['perMin'] ?? 1).toDouble(),
                minimumFare: (rules?['minimumFare'] ?? 15).toDouble(),
                dynamicPricingEnabled:
                    rules?['surgeEnabled'] ??
                    rules?['dynamicPricingEnabled'] ??
                    false,
                surgeMultiplier: (rules?['surgeMultiplier'] ?? 1.0).toDouble(),
                surgeEndTime:
                    (rules?['surgeEndAt'] as Timestamp?)?.toDate() ??
                    (rules?['surgeEndTime'] as Timestamp?)?.toDate(),
              );
            }

            _bikeFare = getFare(bikeRules);
            _autoFare = getFare(autoRules);
            _parcelFare = getFare(parcelRules);
            final cabRules = ref.read(fareRulesProvider('cab')).value;
            _cabFare = getFare(cabRules);
            _isFetchingRoute = false;
          });

          _mapController?.drawPolyline(
            polyline: polyStr,
            points: pointsList,
            color: '#2563EB',
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to calculate route: $e'),
              backgroundColor: context.colors.error,
              duration: const Duration(seconds: 4),
            ),
          );
          setState(() {
            _destination = null;
            _routePolyline = null;
            _routePoints = null;
            _bookingState = 'default';
            _isFetchingRoute = false;
            _followUser = true;
          });
          _mapController?.clearRoute();
        }
      }
    }
  }

  Future<void> _restoreRoute(
    Map<String, dynamic> pickup,
    Map<String, dynamic> dest,
  ) async {
    try {
      final pickupLat = (pickup['lat'] as num).toDouble();
      final pickupLng = (pickup['lng'] as num).toDouble();
      final destLat = (dest['lat'] as num).toDouble();
      final destLng = (dest['lng'] as num).toDouble();

      final repo = OlaMapsRepository();
      final routeData = await repo.getDirections(
        pickupLat,
        pickupLng,
        destLat,
        destLng,
      );

      final polyStr = routeData['polyline'] as String?;
      final pts = routeData['points'] as List<dynamic>?;

      if (polyStr != null && pts != null && context.mounted) {
        final pointsList = pts.cast<Map<String, dynamic>>();
        setState(() {
          _routePolyline = polyStr;
          _routePoints = pointsList;
          _destination = dest;
        });

        await _mapController?.drawPolyline(
          polyline: polyStr,
          points: pointsList,
          color: '#2563EB',
        );
      }
    } catch (e) {
      debugPrint('Failed to restore route: $e');
    }
  }
}

// -- Searching animation widget --------------------------------
class _SearchingState extends StatelessWidget {
  const _SearchingState();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.rapidoYellow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: context.colors.primary,
            ),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Searching for nearby Captains...',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: context.colors.primary,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'This usually takes about 10-30 seconds',
                  style: TextStyle(
                    color: context.colors.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// -- Captain status chip ---------------------------------------
class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    Color textColor;
    IconData icon;
    String label;
    if (status == 'accepted') {
      color = context.colors.rapidoYellow;
      textColor = Colors.black;
      icon = Icons.local_taxi_rounded;
      label = 'Captain is on the way';
    } else if (status == 'arriving') {
      color = context.colors.warning;
      textColor = color;
      icon = Icons.near_me_rounded;
      label = 'Captain is arriving now!';
    } else {
      color = const Color(0xFF16A34A);
      textColor = color;
      icon = Icons.check_circle_rounded;
      label = 'Captain has arrived';
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
              color: textColor,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

class _DragHandle extends StatelessWidget {
  const _DragHandle();
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 44,
        height: 4,
        margin: const EdgeInsets.only(top: 12, bottom: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFDDE3EA),
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}

// -- Bottom Nav Item ------------------------------------------------
class _NavItem extends StatelessWidget {
  final IconData selectedIcon;
  final IconData unselectedIcon;
  final String label;
  final bool isError;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavItem({
    required this.selectedIcon,
    required this.unselectedIcon,
    required this.label,
    required this.onTap,
    this.isSelected = false,
  }) : isError = false;

  @override
  Widget build(BuildContext context) {
    final color = isError
        ? context.colors.error
        : (isSelected ? context.colors.primary : const Color(0xFF9CA3AF));

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isSelected
                    ? context.colors.rapidoYellow
                    : Colors.transparent,
                shape: BoxShape.circle,
              ),
              child: Icon(
                isSelected ? selectedIcon : unselectedIcon,
                size: 24,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                maxLines: 1,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FadeIndexedStack extends StatelessWidget {
  final int index;
  final List<Widget> children;

  const _FadeIndexedStack({required this.index, required this.children});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: List.generate(children.length, (i) {
        return IgnorePointer(
          ignoring: index != i,
          child: AnimatedOpacity(
            opacity: index == i ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            child: children[i],
          ),
        );
      }),
    );
  }
}

class SarthiLogo extends StatelessWidget {
  final double size;
  const SarthiLogo({super.key, this.size = 24});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size * (26 / 24)),
      painter: _SarthiLogoPainter(),
    );
  }
}

class _SarthiLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double sw = size.width / 24;
    final double sh = size.height / 26;

    final paintDark = Paint()
      ..color = const Color(0xFF0F172A)
      ..strokeWidth = 4 * sw
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final paintYellow = Paint()
      ..color = const Color(0xFFEAB308)
      ..strokeWidth = 4 * sw
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final topPath = Path()
      ..moveTo(20 * sw, 11 * sh)
      ..lineTo(8 * sw, 11 * sh)
      ..arcToPoint(
        Offset(8 * sw, 5 * sh),
        radius: Radius.circular(3 * sw),
        clockwise: true,
      )
      ..lineTo(20 * sw, 5 * sh);

    final bottomPath = Path()
      ..moveTo(5 * sw, 15 * sh)
      ..lineTo(17 * sw, 15 * sh)
      ..arcToPoint(
        Offset(17 * sw, 21 * sh),
        radius: Radius.circular(3 * sw),
        clockwise: true,
      )
      ..lineTo(5 * sw, 21 * sh);

    canvas.drawPath(topPath, paintDark);
    canvas.drawPath(bottomPath, paintYellow);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

