import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/design/tokens.dart';
import 'search_provider.dart';

import '../../auth/presentation/auth_providers.dart';
import '../../../core/utils/location_service.dart';

class SearchScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic>? initialPickup;
  final Map<String, dynamic>? initialDestination;

  const SearchScreen({super.key, this.initialPickup, this.initialDestination});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  late final TextEditingController _pickupController;
  late final TextEditingController _destController;
  final _pickupFocus = FocusNode();
  final _destFocus = FocusNode();
  Timer? _debounce;
  bool _isGeocoding = false;

  Map<String, dynamic>? _pickup;
  Map<String, dynamic>? _destination;
  String _activeField = 'dest'; // 'pickup' or 'dest'

  final _locationService = LocationService();

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
      if (_pickup == null) {
        _autoDetectCurrentLocation();
      }
    });
  }

  @override
  void dispose() {
    _pickupController.dispose();
    _destController.dispose();
    _pickupFocus.dispose();
    _destFocus.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), () {
      ref.read(searchQueryProvider.notifier).state = query;
    });
  }

  Future<void> _recordSearchHistory(Map<String, dynamic> result) async {
    try {
      final user = await ref.read(currentUserProvider.future);
      if (user != null) {
        final currentRecent = List<Map<String, dynamic>>.from(
          user.recentSearches ?? [],
        );
        // Remove if already exists (by description)
        currentRecent.removeWhere(
          (element) => element['description'] == result['description'],
        );
        // Add to front
        currentRecent.insert(0, result);
        // Keep only 5
        if (currentRecent.length > 5) {
          currentRecent.removeRange(5, currentRecent.length);
        }
        await ref.read(userRepositoryProvider).updateUser(user.uid, {
          'recentSearches': currentRecent,
        });
        ref.invalidate(currentUserProvider);
      }
    } catch (e) {
      debugPrint('Failed to record search history: $e');
    }
  }

  Future<void> _autoDetectCurrentLocation() async {
    try {
      final pos = await _locationService.getCurrentPosition();
      if (pos != null && mounted) {
        // Reverse geocode to get name
        final repo = ref.read(olaMapsRepositoryProvider);
        final addressName = await repo.reverseGeocode(
          pos.latitude,
          pos.longitude,
        );

        if (mounted && _pickup == null) {
          setState(() {
            _pickup = {
              'lat': pos.latitude,
              'lng': pos.longitude,
              'description': addressName ?? 'Current Location',
              'placeId': null,
            };
            _pickupController.text = _pickup!['description'];
          });
        }
      }
    } catch (e) {
      debugPrint('Auto-detect location error: $e');
    }
  }

  Future<void> _selectPlace(Map<String, dynamic> place) async {
    final description = place['description'] ?? 'Unknown place';
    Map<String, dynamic>? resultData;

    // 1. Already resolved (e.g., from Recent Searches)
    if (place.containsKey('lat') && place.containsKey('lng')) {
      resultData = {
        'lat': place['lat'],
        'lng': place['lng'],
        'description': description,
        'placeId': place['placeId'] ?? place['place_id'],
      };
    }
    // 2. Contains geometry (sometimes returned directly)
    else if (place['geometry'] != null &&
        place['geometry']['location'] != null) {
      resultData = {
        'lat': place['geometry']['location']['lat'],
        'lng': place['geometry']['location']['lng'],
        'description': description,
        'placeId': place['place_id'] ?? place['placeId'],
      };
    }
    // 3. Needs geocoding via place_id
    else {
      final placeId =
          place['place_id'] ?? place['placeId'] ?? place['reference'];
      if (placeId == null) return;

      setState(() => _isGeocoding = true);
      try {
        final repo = ref.read(olaMapsRepositoryProvider);
        final coords = await repo.geocode(placeId);
        if (coords != null) {
          resultData = {
            'lat': coords['lat'],
            'lng': coords['lng'],
            'description': description,
            'placeId': placeId,
          };
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Could not fetch coordinates for this place.'),
              ),
            );
          }
          return;
        }
      } finally {
        if (mounted) setState(() => _isGeocoding = false);
      }
    }

    // Fire and forget so we don't block the UI pop
    _recordSearchHistory(resultData);

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
    final hasQuery = _activeField == 'pickup'
        ? _pickupController.text.isNotEmpty
        : _destController.text.isNotEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        children: [
          // ── Search header ─────────────────────────────────────────
          Container(
            padding: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(32),
                bottomRight: Radius.circular(32),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: SafeArea(
              top: true,
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        IconButton(
                          onPressed: () => context.pop(),
                          icon: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.arrow_back_ios_new_rounded,
                              size: 16,
                              color: Color(0xFF334155),
                            ),
                          ),
                          padding: EdgeInsets.zero,
                          alignment: Alignment.centerLeft,
                          splashRadius: 24,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Plan Your Ride',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF3B82F6).withValues(alpha: 0.08),
                            blurRadius: 24,
                            offset: const Offset(0, 12),
                          ),
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                        border: Border.all(color: const Color(0xFFF1F5F9), width: 1.5),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 14,
                      ),
                      child: Row(
                        children: [
                          // Dots and line
                          Column(
                            children: [
                              Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF10B981),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: const Color(0xFFD1FAE5), width: 3),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF10B981).withValues(alpha: 0.4),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                height: 26,
                                width: 2,
                                margin: const EdgeInsets.symmetric(vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE2E8F0),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF59E0B),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: const Color(0xFFFEF3C7), width: 3),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFFF59E0B).withValues(alpha: 0.4),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 14),
                          // Text fields
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                TextField(
                                  controller: _pickupController,
                                  focusNode: _pickupFocus,
                                  decoration: InputDecoration(
                                    hintText: 'Your current location',
                                    hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14, fontWeight: FontWeight.w400),
                                    isDense: true,
                                    contentPadding: EdgeInsets.zero,
                                    border: InputBorder.none,
                                    focusedBorder: InputBorder.none,
                                    enabledBorder: InputBorder.none,
                                    filled: false,
                                  ),
                                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                                  onChanged: _onSearchChanged,
                                ),
                                const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 10),
                                  child: Divider(height: 1, color: Color(0xFFF1F5F9), thickness: 1.5),
                                ),
                                TextField(
                                  controller: _destController,
                                  focusNode: _destFocus,
                                  decoration: InputDecoration(
                                    hintText: 'Where to?',
                                    hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14, fontWeight: FontWeight.w400),
                                    isDense: true,
                                    contentPadding: EdgeInsets.zero,
                                    border: InputBorder.none,
                                    focusedBorder: InputBorder.none,
                                    enabledBorder: InputBorder.none,
                                    filled: false,
                                  ),
                                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                                  onChanged: _onSearchChanged,
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
            ),
          ),

          // ── Body ─────────────────────────────────────────────────
          Expanded(
            child: _isGeocoding
                ? const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 12),
                        Text(
                          'Getting location...',
                          style: TextStyle(color: Color(0xFF6B7280)),
                        ),
                      ],
                    ),
                  )
                : hasQuery
                ? _buildSearchResults(searchResults)
                : _buildRecentSearches(),
          ),
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
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.search_off_rounded,
                  size: 48,
                  color: Colors.grey[300],
                ),
                const SizedBox(height: 12),
                const Text(
                  'No results found',
                  style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 15),
                ),
              ],
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 12),
          itemCount: results.length,
          separatorBuilder: (_, index) => const SizedBox.shrink(),
          itemBuilder: (context, index) {
            final place = results[index];
            final description =
                place['description'] as String? ?? 'Unknown place';
            final parts = description.split(',');
            final primary = parts.first.trim();
            final secondary = parts.length > 1
                ? parts.sublist(1).join(',').trim()
                : '';

            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
                border: Border.all(color: const Color(0xFFF8FAFC), width: 2),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.location_on_rounded,
                    size: 18,
                    color: Color(0xFF3B82F6),
                  ),
                ),
                title: Text(
                  primary,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: Color(0xFF1E293B),
                  ),
                ),
                subtitle: secondary.isNotEmpty
                    ? Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          secondary,
                          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      )
                    : null,
                onTap: () => _selectPlace(place),
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(
        child: Text(
          'Search error: $err',
          style: TextStyle(color: context.colors.error),
        ),
      ),
    );
  }

  Widget _buildRecentSearches() {
    final recentSearchesAsync = ref.watch(recentCompletedDropsProvider);

    return recentSearchesAsync.when(
      data: (recentSearches) {
        if (recentSearches.isEmpty) {
          return const Center(
            child: Text(
              'No recent drop locations',
              style: TextStyle(color: Color(0xFF9CA3AF)),
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 16, 8),
              child: Text(
                'Recent Drop Locations',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1E293B),
                  letterSpacing: -0.3,
                ),
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.only(top: 8, bottom: 20),
                itemCount: recentSearches.length,
                separatorBuilder: (context, index) => const SizedBox.shrink(),
                itemBuilder: (context, index) {
                  final place = recentSearches[index];
                  final description = place['description'] ?? 'Unknown place';
                  final parts = description.split(',');
                  final primary = parts.first.trim();
                  final secondary = parts.length > 1
                      ? parts.sublist(1).join(',').trim()
                      : '';

                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                      border: Border.all(color: const Color(0xFFF8FAFC), width: 2),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 6,
                      ),
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.history_rounded,
                          size: 18,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      title: Text(
                        primary,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      subtitle: secondary.isNotEmpty
                          ? Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                secondary,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF64748B),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            )
                          : null,
                      onTap: () => _selectPlace(place),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(
        child: Text(
          'Error loading history',
          style: TextStyle(color: context.colors.error),
        ),
      ),
    );
  }
}

class _DashedDivider extends StatelessWidget {
  const _DashedDivider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final boxWidth = constraints.constrainWidth();
          const dashWidth = 4.0;
          const dashHeight = 1.0;
          final dashCount = (boxWidth / (2 * dashWidth)).floor();
          return Flex(
            direction: Axis.horizontal,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(dashCount, (_) {
              return SizedBox(
                width: dashWidth,
                height: dashHeight,
                child: DecoratedBox(
                  decoration: BoxDecoration(color: Colors.grey[300]),
                ),
              );
            }),
          );
        },
      ),
    );
  }
}
