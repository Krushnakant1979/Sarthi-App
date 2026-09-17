import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/utils/location_service.dart';
import '../../../shared/auth/presentation/auth_providers.dart';
import 'search_provider.dart';

class SearchScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic>? initialPickup;
  final Map<String, dynamic>? initialDestination;

  const SearchScreen({super.key, this.initialPickup, this.initialDestination});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  static const _navy = Color(0xFF0B2545);
  static const _navyLight = Color(0xFF173E69);
  static const _yellow = Color(0xFFFFD633);
  static const _green = Color(0xFF16B77A);

  late final TextEditingController _pickupController;
  late final TextEditingController _destController;
  final _pickupFocus = FocusNode();
  final _destFocus = FocusNode();
  final _locationService = LocationService();

  Timer? _debounce;
  bool _isGeocoding = false;
  Map<String, dynamic>? _pickup;
  Map<String, dynamic>? _destination;
  String _activeField = 'dest';

  @override
  void initState() {
    super.initState();
    _pickup = widget.initialPickup;
    _destination = widget.initialDestination;
    _pickupController = TextEditingController(
      text: _pickup?['description'] ?? '',
    );
    _destController = TextEditingController(
      text: _destination?['description'] ?? '',
    );

    _pickupController.addListener(_refreshForInput);
    _destController.addListener(_refreshForInput);
    _pickupFocus.addListener(() {
      if (_pickupFocus.hasFocus) {
        setState(() => _activeField = 'pickup');
        _onSearchChanged(_pickupController.text);
      }
    });
    _destFocus.addListener(() {
      if (_destFocus.hasFocus) {
        setState(() => _activeField = 'dest');
        _onSearchChanged(_destController.text);
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _destFocus.requestFocus();
      if (_pickup == null) _autoDetectCurrentLocation();
    });
  }

  void _refreshForInput() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _pickupController.removeListener(_refreshForInput);
    _destController.removeListener(_refreshForInput);
    _pickupController.dispose();
    _destController.dispose();
    _pickupFocus.dispose();
    _destFocus.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    // 300 ms feels snappy while still batching rapid keystrokes
    _debounce = Timer(const Duration(milliseconds: 300), () {
      ref.read(searchQueryProvider.notifier).state = query.trim();
    });
  }

  Future<void> _recordSearchHistory(Map<String, dynamic> result) async {
    try {
      final user = await ref.read(currentUserProvider.future);
      if (user != null) {
        final currentRecent = List<Map<String, dynamic>>.from(
          user.recentSearches ?? [],
        );
        currentRecent.removeWhere(
          (element) => element['description'] == result['description'],
        );
        currentRecent.insert(0, result);
        if (currentRecent.length > 5) {
          currentRecent.removeRange(5, currentRecent.length);
        }
        await ref.read(userRepositoryProvider).updateUser(user.uid, {
          'recentSearches': currentRecent,
        });
        ref.invalidate(currentUserProvider);
      }
    } catch (error) {
      debugPrint('Failed to record search history: $error');
    }
  }

  Future<void> _autoDetectCurrentLocation({bool force = false}) async {
    try {
      // ── Step 1: show an instant placeholder from last-known position ──
      // getLastKnownPosition() never waits for a GPS satellite fix, so it
      // returns in milliseconds. This makes the pickup field feel instant.
      final lastKnown = await _locationService.getLastKnownPosition();
      if (lastKnown != null && mounted && (_pickup == null || force)) {
        setState(() {
          _pickup = {
            'lat': lastKnown.latitude,
            'lng': lastKnown.longitude,
            'description': 'Detecting location...',
            'placeId': null,
          };
          _pickupController.text = 'Detecting location...';
        });
      }

      // ── Step 2: get accurate position (cache + 6s timeout internally) ──
      final position = await _locationService.getCurrentPosition();
      if (position == null || !mounted) return;

      final repository = ref.read(olaMapsRepositoryProvider);
      // reverseGeocode now hits in-memory cache on repeat calls — instant.
      final addressName = await repository.reverseGeocode(
        position.latitude,
        position.longitude,
      );
      if (mounted && (_pickup == null || force ||
          _pickup!['description'] == 'Detecting location...')) {
        setState(() {
          _pickup = {
            'lat': position.latitude,
            'lng': position.longitude,
            'description': addressName ?? 'Current location',
            'placeId': null,
          };
          _pickupController.text = _pickup!['description'];
        });
      }
    } catch (error) {
      debugPrint('Auto-detect location error: $error');
    }
  }

  Future<void> _selectPlace(Map<String, dynamic> place) async {
    final description = place['description'] ?? 'Unknown place';
    Map<String, dynamic>? resultData;

    if (place.containsKey('lat') && place.containsKey('lng')) {
      resultData = {
        'lat': place['lat'],
        'lng': place['lng'],
        'description': description,
        'placeId': place['placeId'] ?? place['place_id'],
      };
    } else if (place['geometry'] != null &&
        place['geometry']['location'] != null) {
      resultData = {
        'lat': place['geometry']['location']['lat'],
        'lng': place['geometry']['location']['lng'],
        'description': description,
        'placeId': place['place_id'] ?? place['placeId'],
      };
    } else {
      final placeId =
          place['place_id'] ?? place['placeId'] ?? place['reference'];
      if (placeId == null) return;

      setState(() => _isGeocoding = true);
      try {
        final repository = ref.read(olaMapsRepositoryProvider);
        final coordinates = await repository.geocode(placeId);
        if (coordinates == null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Could not fetch coordinates for this place.'),
              ),
            );
          }
          return;
        }
        resultData = {
          'lat': coordinates['lat'],
          'lng': coordinates['lng'],
          'description': description,
          'placeId': placeId,
        };
      } finally {
        if (mounted) setState(() => _isGeocoding = false);
      }
    }

    _recordSearchHistory(resultData);
    if (!mounted) return;
    setState(() {
      if (_activeField == 'pickup') {
        _pickup = resultData;
        _pickupController.text = description;
        _destFocus.requestFocus();
      } else {
        _destination = resultData;
        _destController.text = description;
        context.pop({'pickup': _pickup, 'destination': _destination});
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final searchResults = ref.watch(searchResultsProvider);
    final colors = context.colors;
    final activeController = _activeField == 'pickup'
        ? _pickupController
        : _destController;
    final hasQuery = activeController.text.trim().isNotEmpty;

    return Scaffold(
      backgroundColor: colors.background,
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [colors.surfaceAlt, colors.background],
          ),
        ),
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: _isGeocoding
                    ? _buildLoadingState(
                        key: const ValueKey('geocoding'),
                        label: 'Pinning your location...',
                      )
                    : hasQuery
                    ? _buildSearchResults(searchResults)
                    : _buildRecentSearches(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final colors = context.colors;
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
        boxShadow: [
          BoxShadow(
            color: _navy.withValues(alpha: 0.10),
            blurRadius: 30,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 20),
          child: Column(
            children: [
              Row(
                children: [
                  _HeaderButton(
                    icon: Icons.arrow_back_rounded,
                    onPressed: () => context.pop(),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Plan your ride',
                          style: TextStyle(
                            color: colors.text,
                            fontSize: 19,
                            height: 1.15,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.45,
                          ),
                        ),
                        SizedBox(height: 3),
                        Text(
                          'Where should Sarthi take you?',
                          style: TextStyle(
                            color: colors.textMuted,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF8D6),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.shield_rounded, size: 13, color: _navy),
                        SizedBox(width: 4),
                        Text(
                          'Safe',
                          style: TextStyle(
                            color: _navy,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 15),
              _buildRouteCard(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRouteCard() {
    return Container(
      padding: const EdgeInsets.fromLTRB(13, 20, 10, 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_navyLight, _navy],
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: _navy.withValues(alpha: 0.24),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 23,
            child: Column(
              children: [
                const _RouteMarker(color: _green),
                Container(
                  width: 1.5,
                  height: 40,
                  margin: const EdgeInsets.symmetric(vertical: 3),
                  color: Colors.white.withValues(alpha: 0.28),
                ),
                const _RouteMarker(color: _yellow, isSquare: true),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              children: [
                _buildRouteField(
                  label: 'PICKUP',
                  hint: 'Use your current location',
                  controller: _pickupController,
                  focusNode: _pickupFocus,
                  active: _activeField == 'pickup',
                  trailing: IconButton(
                    tooltip: 'Use current location',
                    onPressed: () => _autoDetectCurrentLocation(force: true),
                    icon: const Icon(Icons.my_location_rounded, size: 17),
                    color: _activeField == 'pickup' ? _yellow : Colors.white70,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
                const SizedBox(height: 8),
                _buildRouteField(
                  label: 'DROP-OFF',
                  hint: 'Search destination',
                  controller: _destController,
                  focusNode: _destFocus,
                  active: _activeField == 'dest',
                  trailing: _destController.text.isEmpty
                      ? const SizedBox(width: 40)
                      : IconButton(
                          tooltip: 'Clear destination',
                          onPressed: () {
                            _destination = null;
                            _destController.clear();
                            _onSearchChanged('');
                            _destFocus.requestFocus();
                          },
                          icon: const Icon(Icons.close_rounded, size: 18),
                          color: Colors.white70,
                          visualDensity: VisualDensity.compact,
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRouteField({
    required String label,
    required String hint,
    required TextEditingController controller,
    required FocusNode focusNode,
    required bool active,
    required Widget trailing,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      height: 55,
      decoration: BoxDecoration(
        color: active
            ? Colors.white.withValues(alpha: 0.16)
            : Colors.white.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const SizedBox(width: 13),
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              cursorColor: _yellow,
              textInputAction: TextInputAction.search,
              onChanged: _onSearchChanged,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
              decoration: InputDecoration(
                isDense: true,
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                labelText: label,
                labelStyle: TextStyle(
                  color: active ? _yellow : Colors.white60,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.9,
                ),
                floatingLabelBehavior: FloatingLabelBehavior.always,
                hintText: hint,
                hintStyle: const TextStyle(
                  color: Colors.white54,
                  fontSize: 11.0,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          trailing,
        ],
      ),
    );
  }

  Widget _buildSearchResults(
    AsyncValue<List<Map<String, dynamic>>> searchResults,
  ) {
    return searchResults.when(
      data: (results) {
        if (results.isEmpty) {
          return _buildEmptyState(
            key: const ValueKey('no-results'),
            icon: Icons.travel_explore_rounded,
            title: 'No places found',
            message: 'Try a landmark, street, or a more specific area.',
          );
        }
        return _PlacesPanel(
          key: const ValueKey('search-results'),
          eyebrow: 'SEARCH RESULTS',
          title: _activeField == 'pickup'
              ? 'Choose your pickup point'
              : 'Choose your destination',
          subtitle: '${results.length} nearby places found',
          items: results,
          icon: Icons.location_on_rounded,
          iconColor: const Color(0xFF246BCE),
          iconBackground: const Color(0xFFEAF2FF),
          onTap: _selectPlace,
        );
      },
      loading: () => _buildLoadingState(
        key: const ValueKey('search-loading'),
        label: 'Finding the best matches...',
      ),
      error: (_, _) => _buildEmptyState(
        key: const ValueKey('search-error'),
        icon: Icons.wifi_off_rounded,
        title: 'Search is unavailable',
        message: 'Check your connection and try again.',
        isError: true,
      ),
    );
  }

  Widget _buildRecentSearches() {
    final recentSearches = ref.watch(recentCompletedDropsProvider);
    return recentSearches.when(
      data: (items) {
        if (items.isEmpty) {
          return _buildEmptyState(
            key: const ValueKey('no-history'),
            icon: Icons.route_rounded,
            title: 'Your next ride starts here',
            message: 'Search for a destination to begin planning your trip.',
          );
        }
        return _PlacesPanel(
          key: const ValueKey('recent-places'),
          eyebrow: 'QUICK PICK',
          title: 'Recent destinations',
          subtitle: 'Tap a place to plan your ride again',
          items: items,
          icon: Icons.history_rounded,
          iconColor: _navy,
          iconBackground: const Color(0xFFF0F4F8),
          onTap: _selectPlace,
        );
      },
      loading: () => _buildLoadingState(
        key: const ValueKey('history-loading'),
        label: 'Loading recent places...',
      ),
      error: (_, _) => _buildEmptyState(
        key: const ValueKey('history-error'),
        icon: Icons.history_toggle_off_rounded,
        title: 'Couldn’t load recent places',
        message: 'You can still search for a destination above.',
        isError: true,
      ),
    );
  }

  Widget _buildLoadingState({required Key key, required String label}) {
    return Center(
      key: key,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 30,
            height: 30,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: _navy,
              backgroundColor: Color(0xFFE2E8F0),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            label,
            style: TextStyle(
              color: context.colors.textMuted,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState({
    required Key key,
    required IconData icon,
    required String title,
    required String message,
    bool isError = false,
  }) {
    final colors = context.colors;
    final accent = isError ? colors.error : _navy;
    return Center(
      key: key,
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 66,
              height: 66,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: accent, size: 30),
            ),
            const SizedBox(height: 17),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colors.text,
                fontSize: 16,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colors.textMuted,
                fontSize: 12.5,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;

  const _HeaderButton({required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.colors.iconBg,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(
          width: 42,
          height: 42,
          child: Icon(icon, color: context.colors.text, size: 21),
        ),
      ),
    );
  }
}

class _RouteMarker extends StatelessWidget {
  final Color color;
  final bool isSquare;

  const _RouteMarker({required this.color, this.isSquare = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 13,
      height: 13,
      decoration: BoxDecoration(
        color: color,
        shape: isSquare ? BoxShape.rectangle : BoxShape.circle,
        borderRadius: isSquare ? BorderRadius.circular(3) : null,
        border: Border.all(color: Colors.white, width: 2.5),
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.38), blurRadius: 8),
        ],
      ),
    );
  }
}

class _PlacesPanel extends StatelessWidget {
  final String eyebrow;
  final String title;
  final String subtitle;
  final List<Map<String, dynamic>> items;
  final IconData icon;
  final Color iconColor;
  final Color iconBackground;
  final ValueChanged<Map<String, dynamic>> onTap;

  const _PlacesPanel({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    required this.items,
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(18, 22, 18, 28),
      children: [
        Text(
          eyebrow,
          style: const TextStyle(
            color: Color(0xFF8A6B00),
            fontSize: 9.5,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.35,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          title,
          style: TextStyle(
            color: colors.text,
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.45,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          subtitle,
          style: TextStyle(
            color: colors.textMuted,
            fontSize: 11.5,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 14),
        Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: colors.cardBorder.withValues(alpha: 0.8)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0B2545).withValues(alpha: 0.065),
                blurRadius: 22,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            children: List.generate(items.length, (index) {
              final place = items[index];
              final description =
                  place['description']?.toString() ?? 'Unknown place';
              final parts = description.split(',');
              final primary = parts.first.trim();
              final secondary = parts.length > 1
                  ? parts.sublist(1).join(',').trim()
                  : 'Saved location';

              return Column(
                children: [
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => onTap(place),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(13, 12, 11, 12),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: iconBackground,
                                borderRadius: BorderRadius.circular(13),
                              ),
                              child: Icon(icon, color: iconColor, size: 19),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    primary,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: colors.text,
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: -0.2,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    secondary,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: colors.textMuted,
                                      fontSize: 10.5,
                                      height: 1.2,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(
                              Icons.north_west_rounded,
                              color: colors.hint,
                              size: 17,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (index != items.length - 1)
                    Divider(
                      height: 1,
                      thickness: 1,
                      indent: 65,
                      color: colors.divider,
                    ),
                ],
              );
            }),
          ),
        ),
      ],
    );
  }
}
