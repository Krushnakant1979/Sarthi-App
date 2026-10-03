import 'dart:async';
import 'dart:math' as math;
import '../../services/presentation/services_screen.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/utils/measure_size.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import '../../../../ola_maps_bridge/ola_maps_view.dart';
import '../../../../core/utils/location_service.dart';
import '../../../../core/design/tokens.dart';
import '../../../shared/auth/presentation/auth_providers.dart';
import '../../rides/domain/fare_calculator.dart';
import 'widgets/offers_bottom_sheet.dart';
import '../../rides/presentation/ride_providers.dart';
import '../../../admin/presentation/admin_providers.dart';
import '../data/ola_maps_repository.dart';
import '../../../captain/data/captain_repository.dart';
import '../../rides/presentation/ride_history_screen.dart';
import '../../profile/presentation/profile_tab.dart';
import '../../../../core/widgets/fade_indexed_stack.dart';
import 'package:url_launcher/url_launcher.dart';
import 'widgets/default_bottom_sheet.dart';
import 'widgets/searching_bottom_sheet.dart';
import 'widgets/captain_found_bottom_sheet.dart';
import 'widgets/in_progress_bottom_sheet.dart';
import 'widgets/map_top_navigation_bar.dart';
import 'widgets/completed_bottom_sheet.dart';
import 'widgets/selected_bottom_sheet.dart';
class MapHomeScreen extends ConsumerStatefulWidget {
  const MapHomeScreen({super.key});

  @override
  ConsumerState<MapHomeScreen> createState() => _MapHomeScreenState();
}

class _MapHomeScreenState extends ConsumerState<MapHomeScreen> {
  int _selectedNavIndex = 0;

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

  // Dispatch queueing logic
  Timer? _dispatchTimer;
  String? _dispatchRideId;
  int _dispatchIndex = 0;


  final ValueNotifier<double> _sheetExtent = ValueNotifier(0.45);
  final DraggableScrollableController _sheetController =
      DraggableScrollableController();
  double? _targetSheetFraction;


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
    _dispatchTimer?.cancel();
    _locationSubscription?.cancel();
    _sheetController.dispose();
    _sheetExtent.dispose();
    super.dispose();
  }

  void _manageDispatchTimer(Map<String, dynamic>? rideData) {
    if (rideData == null || rideData['status'] != 'searching') {
      _dispatchTimer?.cancel();
      _dispatchTimer = null;
      _dispatchRideId = null;
      return;
    }
    
    if (rideData['id'] != _dispatchRideId) {
      _dispatchTimer?.cancel();
      _dispatchRideId = rideData['id'];
      _dispatchIndex = rideData['currentRouteIndex'] ?? 0;
      
      _dispatchTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
        if (!mounted) {
           timer.cancel();
           return;
        }
        final routingQueue = (rideData['routingQueue'] as List?)?.cast<String>();
        if (routingQueue != null && routingQueue.isNotEmpty) {
           _dispatchIndex++;
           if (_dispatchIndex < routingQueue.length) {
              FirebaseFirestore.instance.collection('ride_requests').doc(_dispatchRideId).update({
                'currentRouteIndex': _dispatchIndex,
                'routeStartedAt': FieldValue.serverTimestamp(),
              }).catchError((_) {});
           } else {
              timer.cancel();
           }
        }
      });
    }
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

    // ── Fast path: use last-known position immediately (no satellite fix) ──
    // This snaps the camera before the full GPS fix arrives, so the map
    // feels responsive from the first frame.
    final lastKnown = await _locationService.getLastKnownPosition();
    if (!context.mounted) return;
    if (lastKnown != null && _mapController != null) {
      _lastValidPosition = lastKnown;
      _mapController!.moveCamera(lastKnown.latitude, lastKnown.longitude,
          zoom: 16.0);
      _mapController!.updateUserLocation(
          lastKnown.latitude, lastKnown.longitude);
      // Start city label fetch immediately — hits cache if available
      unawaited(_updateCityStateText(lastKnown.latitude, lastKnown.longitude));
    }

    // ── Accurate fix: refine position (6s timeout, cached internally) ──
    final pos = await _locationService.getCurrentPosition();
    if (!context.mounted) return;
    if (pos != null) {
      // Only re-fetch city label if location changed significantly
      unawaited(_updateCityStateText(pos.latitude, pos.longitude));
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
    // Uses the singleton OlaMapsRepository — hits in-memory cache instantly
    // on repeat calls (e.g., recenter to same area).
    final repo = OlaMapsRepository();
    final cityState = await repo.getCityAndState(lat, lng);
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

  Future<void> _handleConfirmRide(WidgetRef ref) async {
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
          distanceMeters: _distanceMeters?.toInt() ?? 0,
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
  }

  Future<void> _handleOfferTap() async {
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
  }

  void _handlePaymentTap() {
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
      
      final rideData = next.value?.data();
      if (rideData != null) {
        rideData['id'] = next.value?.id;
      }
      _manageDispatchTimer(rideData);

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
        _mapController?.toggleNativeUserLocation(true);
        if (newStatus == 'cancelled') {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ref.read(currentRideIdProvider.notifier).state = null;
          });
        }
      } else if (newStatus == 'accepted' ||
          newStatus == 'arriving' ||
          newStatus == 'arrived' ||
          newStatus == 'in_progress') {
        
        // Show native blue tracking dot instead of green pickup bullseye
        if (oldStatus != newStatus) {
            _mapController?.toggleNativeUserLocation(true);
        }

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

    final canPop = _selectedNavIndex == 0 &&
        _bookingState == 'default' &&
        _destination == null &&
        !_isFetchingRoute;

    return PopScope(
      canPop: canPop,
      onPopInvokedWithResult: (bool didPop, dynamic result) {
        if (didPop) return;

        if (_selectedNavIndex != 0) {
          setState(() {
            _selectedNavIndex = 0;
          });
          return;
        }

        if (_destination != null ||
            _bookingState != 'default' ||
            _isFetchingRoute) {
          setState(() {
            _destination = null;
            _routePolyline = null;
            _routePoints = null;
            _bookingState = 'default';
            _isFetchingRoute = false;
            _followUser = true;
          });
          _mapController?.clearRoute();
          _mapController?.toggleNativeUserLocation(true);
          return;
        }
      },
      child: Scaffold(
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
                  RepaintBoundary(
                    child: Listener(
                      onPointerDown: (_) {
                        if (_followUser) {
                          setState(() => _followUser = false);
                        }
                      },
                      child: OlaMapsView(
                      showUserDot: true,
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
                ), // Close RepaintBoundary
                
                  // Safe area aware top location/search shell
                  Consumer(
                    builder: (context, ref, child) {
                      final rideStream = ref.watch(currentRideStreamProvider);
                      final status = rideStream.value?.data()?['status'];
                      final isTripActive = status == 'accepted' || 
                                           status == 'arriving' || 
                                           status == 'arrived' || 
                                           status == 'in_progress';
                      final showBackButton = _destination != null && !isTripActive;
                      
                      return MapTopNavigationBar(
                        showBackButton: showBackButton,
                        currentCityState: _currentCityState,
                        onBack: () {
                          setState(() {
                            _destination = null;
                            _bookingState = 'default';
                            _followUser = true;
                            _mapController?.clearRoute();
                          });
                        },
                        onProfileTap: () => _onNavTapped(3),
                      );
                    },
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
                              width: 44,
                              height: 44,
                              margin: const EdgeInsets.only(bottom: 10),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(15),
                                border: Border.all(
                                  color: const Color(0xFFE4EAF1),
                                ),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x1F0B2545),
                                    blurRadius: 14,
                                    offset: Offset(0, 5),
                                  ),
                                ],
                              ),
                              child: IconButton(
                                onPressed: () {},
                                icon: const Icon(
                                  Icons.layers_rounded,
                                  size: 20,
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
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(
                          color: const Color(0xFFE4EAF1),
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x1F0B2545),
                            blurRadius: 14,
                            offset: Offset(0, 5),
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
                            : const Icon(Icons.my_location_rounded, size: 22, color: Color(0xFF0F172A)),
                        splashRadius: 22,
                      ),
                    ),
                  ),

                  // Bottom sheet draggable shell
                  Consumer(
                    builder: (context, ref, _) {
                      final rideStream = ref.watch(currentRideStreamProvider);
                      final rideSnapshot = rideStream.valueOrNull;
                      final rideData = rideSnapshot?.data();
                      final status = rideData?['status'];
                      final otp = rideData?['otp'];
                      final fare = rideData?['fareEstimate'];
                      final rideId = rideSnapshot?.id;
                      String displayState = _bookingState;
                      if (status != null) displayState = status;
                          
                          final isDefault = displayState == 'default';

                          return DraggableScrollableSheet(
                            controller: _sheetController,
                            snap: isDefault,
                            snapSizes: isDefault ? const [0.38, 0.65, 1.0] : null,
                            snapAnimationDuration: const Duration(milliseconds: 280),
                            initialChildSize: (_targetSheetFraction ?? 0.38).clamp(
                              0.38,
                              1.0,
                            ),
                            minChildSize: 0.38,
                            maxChildSize: 1.0,
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
                                child: () {
                                  // Build the content for the current state
                                  Widget stateContent;
                                  if (displayState == 'searching') {
                                    stateContent = SearchingBottomSheet(
                                      onCancelRequest: () {
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
                                        _mapController?.toggleNativeUserLocation(true);
                                      },
                                    );
                                  } else if (displayState == 'accepted' ||
                                      displayState == 'arriving' ||
                                      displayState == 'arrived') {
                                    stateContent = CaptainFoundBottomSheet(
                                      otp: otp,
                                      fare: fare,
                                      status: displayState,
                                      captainId: rideData?['assignedCaptainId'],
                                    );
                                  } else if (displayState == 'in_progress') {
                                    stateContent = const InProgressBottomSheet();
                                  } else if (displayState == 'completed') {
                                    stateContent = CompletedBottomSheet(
                                      fare: fare,
                                      paymentMethod: _paymentMethod,
                                      captainId: rideData?['assignedCaptainId'],
                                      onDone: () {
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
                                        _mapController?.toggleNativeUserLocation(true);
                                      },
                                      onRateCaptain: (captainId) {
                                        _showRatingSheet(context, captainId, ref);
                                      },
                                    );
                                  } else if (displayState == 'selected' &&
                                      _destination != null) {
                                    stateContent = SelectedBottomSheet(
                                      vehicleType: _vehicleType,
                                      autoFare: _autoFare,
                                      parcelFare: _parcelFare,
                                      cabFare: _cabFare,
                                      bikeFare: _bikeFare,
                                      discountAmount: _discountAmount?.toInt(),
                                      appliedOfferCode: _appliedOfferCode,
                                      isFetchingRoute: _isFetchingRoute,
                                      durationSeconds: _durationSeconds?.toInt(),
                                      distanceMeters: _distanceMeters?.toInt(),
                                      destination: _destination!,
                                      paymentMethod: _paymentMethod,
                                      onVehicleTypeChanged: (type) => setState(() => _vehicleType = type),
                                      onOfferTap: _handleOfferTap,
                                      onPaymentTap: _handlePaymentTap,
                                      onConfirmRide: () => _handleConfirmRide(ref),
                                    );
                                  } else {
                                    stateContent = DefaultBottomSheet(
                                      onDestinationSelected: (dest) {
                                        _processDestination(context, dest);
                                      },
                                      onLocationPermissionRequested: _checkLocation,
                                      hasLocationPermission: _hasLocationPermission,
                                      isLoadingLocation: _isLoadingLocation,
                                    );
                                  }

                                  return SingleChildScrollView(
                                    controller: scrollController,
                                    physics: const AlwaysScrollableScrollPhysics(),
                                    child: AnimatedSwitcher(
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
                                              if (currentChild != null) currentChild,
                                            ],
                                          ),
                                      child: KeyedSubtree(
                                        key: ValueKey(displayState),
                                        child: MeasureSize(
                                          onChange: (size) {
                                            final screenHeight = MediaQuery.of(context).size.height;
                                            final safeBottom = MediaQuery.of(context).padding.bottom;
                                            final target = ((size.height + 24 + safeBottom) / screenHeight).clamp(
                                              0.38,
                                              isDefault ? 0.70 : 0.95,
                                            );
                                            if (_targetSheetFraction == null ||
                                                (_targetSheetFraction! - target).abs() > 0.01) {
                                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                                if (mounted) {
                                                  setState(() => _targetSheetFraction = target);
                                                  if (_sheetController.isAttached) {
                                                    _sheetController.animateTo(
                                                      target,
                                                      duration: const Duration(milliseconds: 250),
                                                      curve: Curves.easeOutCubic,
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
                                }(),
                              );
                            },
                          );
                    },
                  ),
                ],
              ),
              ServicesScreen(onProfileTap: () => _onNavTapped(3)),
              RideHistoryScreen(
                onBack: () => _onNavTapped(3),
                onProfileTap: () => _onNavTapped(3),
              ),
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
    ),
  );
}

  // Delegates to _initLocation — kept so existing references compile
  Future<void> _checkLocation() async => _initLocation();

  Widget _buildFloatingNavBar() {
    final screenWidth = MediaQuery.of(context).size.width;
    final tabWidth = screenWidth / 4;

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
      child: Stack(
        alignment: Alignment.centerLeft,
        children: [
          // Smooth sliding background indicator
          AnimatedPositioned(
            duration: const Duration(milliseconds: 200),
            curve: Curves.fastOutSlowIn,
            left: tabWidth * _selectedNavIndex,
            width: tabWidth,
            top: 0,
            bottom: 0,
            child: RepaintBoundary(
              child: Align(
                alignment: Alignment.topCenter,
                child: Container(
                  width: 40,
                  height: 40,
                  margin: const EdgeInsets.only(top: 4),
                  decoration: BoxDecoration(
                    color: context.colors.rapidoYellow,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ),
          Row(
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
        ],
      ),
    );
  }

  void _onNavTapped(int index) {
    if (_selectedNavIndex == index) return;
    setState(() => _selectedNavIndex = index);
  }



  void _showRatingSheet(BuildContext context, String captainId, WidgetRef ref) {
    int selectedStars = 0;

    String getRatingLabel() {
      switch (selectedStars) {
        case 1:
          return 'Terrible ride';
        case 2:
          return 'Bad ride';
        case 3:
          return 'Okay ride';
        case 4:
          return 'Good ride';
        case 5:
          return 'Excellent ride';
        default:
          return '';
      }
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const _DragHandle(),
                    const SizedBox(height: 12),
                    
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        const Align(
                          alignment: Alignment.center,
                          child: Text(
                            'Rate your captain',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF0F172A),
                              letterSpacing: -0.5,
                            ),
                          ),
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: IconButton(
                            onPressed: () => Navigator.pop(ctx),
                            icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 4),
                    const Text(
                      'How was your ride?',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(5, (index) {
                        final isSelected = index < selectedStars;
                        return GestureDetector(
                          onTap: () {
                            setModalState(() => selectedStars = index + 1);
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            child: Icon(
                              isSelected ? Icons.star_rounded : Icons.star_border_rounded,
                              size: 44,
                              color: isSelected ? const Color(0xFFFBBF24) : const Color(0xFF94A3B8),
                            ),
                          ),
                        );
                      }),
                    ),
                    
                    const SizedBox(height: 24),
                    
                    if (selectedStars > 0) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE0E7FF),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          getRatingLabel(),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF3730A3),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ] else ...[
                      const SizedBox(height: 38),
                    ],
                    
                    Text(
                      selectedStars > 0 ? '$selectedStars out of 5' : 'Select a rating',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 8),
                    
                    const Text(
                      'Your feedback helps us improve.',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                    
                    const SizedBox(height: 28),
                    
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF005AFE),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
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
                                        content: Text('Rating submitted! Thank you.'),
                                        backgroundColor: Color(0xFF16A34A),
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Failed to submit rating: $e'),
                                      ),
                                    );
                                  }
                                }
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
                        child: const Text(
                          'Submit rating',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
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
      backgroundColor: Colors.transparent,
      barrierColor: const Color(0xFF0B2144).withValues(alpha: 0.32),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            Widget buildSectionHeader(String title) {
              return Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 9),
                child: Row(
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
                    Text(
                      title.toUpperCase(),
                      style: const TextStyle(
                        color: Color(0xFF475569),
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.45,
                      ),
                    ),
                  ],
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
              return Container(
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFFF1F6FF) : Colors.white,
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFF60A5FA)
                        : const Color(0xFFE7ECF3),
                    width: isSelected ? 1.4 : 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: isSelected
                          ? const Color(0xFF2563EB).withValues(alpha: 0.10)
                          : const Color(0xFF0B2545).withValues(alpha: 0.035),
                      blurRadius: isSelected ? 14 : 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(15),
                    onTap: () {
                      setState(() => _paymentMethod = title);
                      setModalState(() {});
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 13,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: iconColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(11),
                            ),
                            child: Icon(iconData, color: iconColor, size: 19),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: isSelected
                                        ? FontWeight.w800
                                        : FontWeight.w700,
                                    color: const Color(0xFF0F172A),
                                  ),
                                ),
                                if (subtitle != null) ...[
                                  const SizedBox(height: 3),
                                  Text(
                                    subtitle,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 9.5,
                                      height: 1.3,
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color(0xFF2563EB)
                                  : Colors.transparent,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSelected
                                    ? const Color(0xFF2563EB)
                                    : const Color(0xFFCBD5E1),
                                width: 1.3,
                              ),
                            ),
                            child: isSelected
                                ? const Icon(
                                    Icons.check_rounded,
                                    color: Colors.white,
                                    size: 15,
                                  )
                                : null,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }

            return SafeArea(
              top: false,
              child: Container(
                height: MediaQuery.of(context).size.height * 0.88,
                decoration: const BoxDecoration(
                  color: Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    const SizedBox(height: 10),
                    Container(
                      width: 38,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFCBD5E1),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 11),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: const Color(
                                0xFF2563EB,
                              ).withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(11),
                            ),
                            child: const Icon(
                              Icons.account_balance_wallet_rounded,
                              color: Color(0xFF2563EB),
                              size: 19,
                            ),
                          ),
                          const SizedBox(width: 11),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Choose payment',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF0F172A),
                                    letterSpacing: -0.25,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Select your preferred payment method',
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.close_rounded,
                              color: Color(0xFF475569),
                              size: 19,
                            ),
                            style: IconButton.styleFrom(
                              backgroundColor: const Color(0xFFEEF2F7),
                              minimumSize: const Size(36, 36),
                              maximumSize: const Size(36, 36),
                              padding: EdgeInsets.zero,
                            ),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF0B2144), Color(0xFF1A3A6B)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(
                              0xFF2563EB,
                            ).withValues(alpha: 0.24),
                            blurRadius: 18,
                            offset: const Offset(0, 7),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'AMOUNT TO BE PAID',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.8,
                                    color: Colors.white.withValues(alpha: 0.72),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '₹$amount',
                                  style: const TextStyle(
                                    fontSize: 26,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                    letterSpacing: -0.6,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  'Your final trip fare',
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    color: Colors.white.withValues(alpha: 0.68),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(15),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.18),
                              ),
                            ),
                            child: const Icon(
                              Icons.receipt_long_rounded,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.only(bottom: 8),
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
                    Container(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: const Border(
                          top: BorderSide(color: Color(0xFFE7ECF3)),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(
                              0xFF0B2545,
                            ).withValues(alpha: 0.06),
                            blurRadius: 14,
                            offset: const Offset(0, -3),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          minimumSize: const Size(double.infinity, 54),
                          elevation: 5,
                          shadowColor: const Color(
                            0xFF2563EB,
                          ).withValues(alpha: 0.34),
                        ),
                        onPressed: () => Navigator.pop(context),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.shield_rounded, size: 17),
                            const SizedBox(width: 8),
                            Text(
                              'Book Taxi  •  ₹$amount',
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.1,
                              ),
                            ),
                          ],
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

    // Hide native blue dot, switch to green pickup bullseye for vehicle selection
    _mapController?.toggleNativeUserLocation(false);
    double? destLat = double.tryParse(destResult['lat']?.toString() ?? '');
    double? destLng = double.tryParse(destResult['lng']?.toString() ?? '');
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

    double? pickupLat = double.tryParse(pickupResult?['lat']?.toString() ?? '');
    double? pickupLng = double.tryParse(pickupResult?['lng']?.toString() ?? '');
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
        if (mounted) {
          setState(() {
            _destination = null;
            _pickupLocation = null;
            _bookingState = 'default';
            _isFetchingRoute = false;
            _followUser = true;
          });
          _mapController?.clearRoute();
        }
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not determine pickup location.'),
            ),
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
              ?.map((p) => Map<String, dynamic>.from(p as Map))
              .toList();

          if (pointsList == null || pointsList.length < 2) {
            throw Exception(
              'Could not resolve the road route for this destination.',
            );
          }

          final rulesList = await Future.wait([
            ref.read(fareRulesProvider('bike').future),
            ref.read(fareRulesProvider('auto').future),
            ref.read(fareRulesProvider('parcel').future),
            ref.read(fareRulesProvider('cab').future),
          ]);
          final bikeRules = rulesList[0];
          final autoRules = rulesList[1];
          final parcelRules = rulesList[2];
          final cabRules = rulesList[3];

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

// -- Captain status chip ---------------------------------------


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
            Padding(
              padding: const EdgeInsets.all(8),
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




