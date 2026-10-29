import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';

enum RideFilter { today, last30Days, allTime }

enum RideStatusFilter { all, completed, cancelled }

enum RideSortOrder { newestFirst, oldestFirst }

final rideFilterProvider = StateProvider<RideFilter>((ref) => RideFilter.allTime);
final rideStatusFilterProvider = StateProvider<RideStatusFilter>(
  (ref) => RideStatusFilter.all,
);
final rideSortOrderProvider = StateProvider<RideSortOrder>(
  (ref) => RideSortOrder.newestFirst,
);

class PaginatedRideHistoryState {
  final List<Map<String, dynamic>> rides;
  final bool isLoading;
  final bool hasMore;
  final String? error;

  PaginatedRideHistoryState({
    required this.rides,
    this.isLoading = false,
    this.hasMore = true,
    this.error,
  });

  PaginatedRideHistoryState copyWith({
    List<Map<String, dynamic>>? rides,
    bool? isLoading,
    bool? hasMore,
    String? error,
    bool clearError = false,
  }) {
    return PaginatedRideHistoryState(
      rides: rides ?? this.rides,
      isLoading: isLoading ?? this.isLoading,
      hasMore: hasMore ?? this.hasMore,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class PaginatedRideHistoryNotifier
    extends StateNotifier<PaginatedRideHistoryState> {
  final Ref ref;
  DocumentSnapshot? _lastDoc;
  int _fetchId = 0;
  static const int maxRides = 30;

  PaginatedRideHistoryNotifier(this.ref)
    : super(PaginatedRideHistoryState(rides: [])) {
    ref.listen(rideFilterProvider, (previous, next) {
      if (previous != next) refresh();
    });
    ref.listen(rideSortOrderProvider, (previous, next) {
      if (previous != next) refresh();
    });
    refresh();
  }

  Future<void> refresh() async {
    _lastDoc = null;
    state = PaginatedRideHistoryState(rides: [], isLoading: true);
    await loadMore(fromRefresh: true);
  }

  Future<void> loadMore({bool fromRefresh = false}) async {
    if (state.isLoading && !fromRefresh) return;
    if (!state.hasMore) return;
    if (!fromRefresh && state.rides.length >= maxRides) {
      state = state.copyWith(isLoading: false, hasMore: false);
      return;
    }

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      state = state.copyWith(isLoading: false, hasMore: false);
      return;
    }

    state = state.copyWith(isLoading: true, clearError: true);
    final currentFetchId = ++_fetchId;

    try {
      final filter = ref.read(rideFilterProvider);
      final sortOrder = ref.read(rideSortOrderProvider);
      DateTime startDate;
      final now = DateTime.now();
      if (filter == RideFilter.today) {
        startDate = DateTime(now.year, now.month, now.day);
      } else {
        startDate = now.subtract(const Duration(days: 30));
      }

      final remainingNeeded = maxRides - (fromRefresh ? 0 : state.rides.length);
      if (remainingNeeded <= 0) {
        state = state.copyWith(isLoading: false, hasMore: false);
        return;
      }

      bool keepFetching = true;
      List<Map<String, dynamic>> accumulatedRides = [];
      bool hasMoreData = true;
      
      // We wrap the fetching in a loop to handle client-side filtering.
      // If we fetch rides and none of them are completed/cancelled,
      // we need to keep fetching until we find some to display,
      // capped at the last 30 rides.
      while (keepFetching && currentFetchId == _fetchId) {
        Query query = FirebaseFirestore.instance
            .collection('ride_requests')
            .where('userId', isEqualTo: uid);

        if (filter != RideFilter.allTime) {
          query = query.where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate));
        }

        final fetchLimit = math.min(20, remainingNeeded - accumulatedRides.length);
        if (fetchLimit <= 0) {
          keepFetching = false;
          hasMoreData = false;
          break;
        }

        query = query.orderBy('createdAt', descending: sortOrder == RideSortOrder.newestFirst).limit(fetchLimit);

        if (_lastDoc != null) {
          query = query.startAfterDocument(_lastDoc!);
        }

        // Cache-first approach for instant loading on initial fetch
        if (_lastDoc == null && accumulatedRides.isEmpty && state.rides.isEmpty) {
          try {
            final cacheSnap = await query.get(const GetOptions(source: Source.cache));
            if (cacheSnap.docs.isNotEmpty) {
              final cacheRides = cacheSnap.docs
                  .map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    data['id'] = doc.id;
                    return data;
                  })
                  .where((ride) {
                    final status = ride['status'] as String? ?? '';
                    return status == 'completed' || status == 'cancelled';
                  })
                  .take(maxRides)
                  .toList();
              
              if (cacheRides.isNotEmpty) {
                // Instantly show cached rides while server query runs
                state = state.copyWith(rides: cacheRides, isLoading: true, clearError: true);
              }
            }
          } catch (_) {
            // Ignore cache errors
          }
        }

        final snapshot = await query.get(const GetOptions(source: Source.serverAndCache));

        if (currentFetchId != _fetchId) return;

        if (snapshot.docs.isNotEmpty) {
          _lastDoc = snapshot.docs.last;
          hasMoreData = snapshot.docs.length == fetchLimit;
          
          final newRides = snapshot.docs
              .map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                data['id'] = doc.id;
                return data;
              })
              .where((ride) {
                final status = ride['status'] as String? ?? '';
                return status == 'completed' || status == 'cancelled';
              })
              .toList();
              
          accumulatedRides.addAll(newRides);
          
          // Stop fetching if we have accumulated enough valid rides for this page
          // or reached the cap of 30 rides or the end of the collection
          if (accumulatedRides.length >= remainingNeeded || !hasMoreData) {
            keepFetching = false;
          }
        } else {
          hasMoreData = false;
          keepFetching = false;
        }
      }

      if (currentFetchId != _fetchId) return;

      List<Map<String, dynamic>> finalRides = _lastDoc == null && state.rides.isNotEmpty 
          ? accumulatedRides // If it was a refresh, replace the cached items
          : [...state.rides, ...accumulatedRides];

      if (finalRides.length >= maxRides) {
        finalRides = finalRides.take(maxRides).toList();
        hasMoreData = false;
      }

      state = state.copyWith(
        rides: finalRides,
        isLoading: false,
        hasMore: hasMoreData && finalRides.length < maxRides,
      );
    } catch (e) {
      if (currentFetchId != _fetchId) return;
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
}

final paginatedRideHistoryProvider =
    StateNotifierProvider<
      PaginatedRideHistoryNotifier,
      PaginatedRideHistoryState
    >((ref) {
      return PaginatedRideHistoryNotifier(ref);
    });

class RideHistoryScreen extends ConsumerStatefulWidget {
  final VoidCallback? onBack;
  final VoidCallback? onProfileTap;
  const RideHistoryScreen({super.key, this.onBack, this.onProfileTap});

  @override
  ConsumerState<RideHistoryScreen> createState() => _RideHistoryScreenState();
}

class _RideHistoryScreenState extends ConsumerState<RideHistoryScreen> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      ref.read(paginatedRideHistoryProvider.notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final historyState = ref.watch(paginatedRideHistoryProvider);
    final activeFilter = ref.watch(rideFilterProvider);
    final activeStatusFilter = ref.watch(rideStatusFilterProvider);
    final activeSortOrder = ref.watch(rideSortOrderProvider);

    final cappedRides = historyState.rides
        .take(PaginatedRideHistoryNotifier.maxRides)
        .toList();

    final displayedRides = cappedRides.where((ride) {
      final status = ride['status'] as String? ?? '';
      if (activeStatusFilter == RideStatusFilter.completed) {
        return status == 'completed';
      }
      if (activeStatusFilter == RideStatusFilter.cancelled) {
        return status == 'cancelled';
      }
      return true;
    }).toList();

    final completedCount = cappedRides
        .where((r) => r['status'] == 'completed')
        .length;
    final cancelledCount = cappedRides
        .where((r) => r['status'] == 'cancelled')
        .length;
    final totalFare = cappedRides
        .where((r) => r['status'] == 'completed')
        .fold<double>(0, (acc, r) {
          final f = r['fareEstimate'];
          if (f is num) return acc + f.toDouble();
          if (f is String) return acc + (double.tryParse(f) ?? 0);
          return acc;
        });

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          SliverAppBar(
            floating: false,
            pinned: true,
            backgroundColor: const Color(0xFFF8FAFC),
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            automaticallyImplyLeading: false,
            titleSpacing: 16,
            toolbarHeight: 56,
            title: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.asset(
                    'assets/app-logo/Sarthi app user logo.png',
                    width: 32,
                    height: 32,
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Trips',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 22,
                    color: Color(0xFF0F172A),
                    letterSpacing: -0.5,
                  ),
                ),
                const Spacer(),
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    _Bounceable(
                      onTap: () => context.push('/notifications'),
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFFE2E8F0),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.notifications_none_rounded,
                          size: 20,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE11D48),
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
                _Bounceable(
                  onTap: () {
                    if (widget.onProfileTap != null) {
                      widget.onProfileTap!();
                    } else if (widget.onBack != null) {
                      widget.onBack!();
                    } else {
                      context.push('/profile');
                    }
                  },
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [Color(0xFF0B2144), Color(0xFF1A3A6B)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0B2144).withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.person_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _build3DStatCard(
                    context,
                    completedCount,
                    cancelledCount,
                    totalFare,
                  ),
                  const SizedBox(height: 18),
                  Container(
                    height: 42,
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE2E8F0).withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(21),
                    ),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final tabWidth = constraints.maxWidth / 3;
                        final activeIndex = activeFilter == RideFilter.today
                            ? 0
                            : activeFilter == RideFilter.last30Days
                                ? 1
                                : 2;
                        return Stack(
                          children: [
                            AnimatedPositioned(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeOutCubic,
                              left: activeIndex * tabWidth,
                              top: 0,
                              bottom: 0,
                              width: tabWidth,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.06),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            Row(
                              children: [
                                _buildDateFilterTab(
                                  'Today',
                                  RideFilter.today,
                                  activeFilter,
                                ),
                                _buildDateFilterTab(
                                  'Last 30 days',
                                  RideFilter.last30Days,
                                  activeFilter,
                                ),
                                _buildDateFilterTab(
                                  'All time',
                                  RideFilter.allTime,
                                  activeFilter,
                                ),
                              ],
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    height: 38,
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final tabWidth = constraints.maxWidth / 3;
                        final activeIndex = activeStatusFilter == RideStatusFilter.all
                            ? 0
                            : activeStatusFilter == RideStatusFilter.completed
                                ? 1
                                : 2;
                        return Stack(
                          children: [
                            AnimatedPositioned(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeOutCubic,
                              left: activeIndex * tabWidth,
                              top: 0,
                              bottom: 0,
                              width: tabWidth,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.04),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            Row(
                              children: [
                                _buildStatusTab(
                                  'All',
                                  RideStatusFilter.all,
                                  activeStatusFilter,
                                ),
                                _buildStatusTab(
                                  'Completed',
                                  RideStatusFilter.completed,
                                  activeStatusFilter,
                                ),
                                _buildStatusTab(
                                  'Cancelled',
                                  RideStatusFilter.cancelled,
                                  activeStatusFilter,
                                ),
                              ],
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 250),
                        transitionBuilder: (child, animation) {
                          return FadeTransition(
                            opacity: animation,
                            child: SlideTransition(
                              position: Tween<Offset>(
                                begin: const Offset(0, 0.2),
                                end: Offset.zero,
                              ).animate(CurvedAnimation(
                                parent: animation,
                                curve: Curves.easeOutCubic,
                              )),
                              child: child,
                            ),
                          );
                        },
                        child: Text(
                          '${displayedRides.length} trips found',
                          key: ValueKey<int>(displayedRides.length),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF475569),
                          ),
                        ),
                      ),
                      _Bounceable(
                        scaleFactor: 0.95,
                        child: PopupMenuButton<RideSortOrder>(
                          initialValue: activeSortOrder,
                          onSelected: (order) => ref.read(rideSortOrderProvider.notifier).state = order,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          color: Colors.white,
                          elevation: 4,
                          offset: const Offset(0, 30),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFCBD5E1)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  activeSortOrder == RideSortOrder.newestFirst ? 'Newest first' : 'Oldest first',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF0B2144),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                  size: 16,
                                  color: Color(0xFF0B2144),
                                ),
                              ],
                            ),
                          ),
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: RideSortOrder.newestFirst,
                              child: Text('Newest first', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                            ),
                            const PopupMenuItem(
                              value: RideSortOrder.oldestFirst,
                              child: Text('Oldest first', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),

          if (historyState.rides.isEmpty)
            if (historyState.isLoading)
              const _RideHistorySkeletonList()
            else if (historyState.error != null)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: const BoxDecoration(
                          color: Color(0xFFFEE2E2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.error_outline,
                          color: Color(0xFFDC2626),
                          size: 36,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        historyState.error ?? 'Could not load rides',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () => ref
                            .read(paginatedRideHistoryProvider.notifier)
                            .refresh(),
                        child: const Text(
                          'Retry',
                          style: TextStyle(color: Color(0xFF0B2144)),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              SliverFillRemaining(
                hasScrollBody: false,
                child: _buildEmpty(context),
              )
          else if (displayedRides.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: _buildEmpty(context),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 160),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    if (index == displayedRides.length) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(
                          child: CircularProgressIndicator(
                            color: Color(0xFF0B2144),
                          ),
                        ),
                      );
                    }
                    return _RideCard(
                      key: ValueKey(displayedRides[index]['id'] ?? index),
                      ride: displayedRides[index],
                      index: index,
                    );
                  },
                  childCount:
                      displayedRides.length +
                      (historyState.isLoading && historyState.hasMore ? 1 : 0),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _build3DStatCard(
    BuildContext context,
    int completed,
    int cancelled,
    double totalFare,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildStatColumn(
            countWidget: _AnimatedCounterText(
              value: completed,
              style: const TextStyle(
                color: Color(0xFF0F172A),
                fontSize: 19,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
                height: 1.1,
              ),
            ),
            label: 'Completed',
            labelColor: const Color(0xFF059669),
            labelBg: const Color(0xFFECFDF5),
          ),
          Container(width: 1, height: 36, color: const Color(0xFFF1F5F9)),
          _buildStatColumn(
            countWidget: _AnimatedCounterText(
              value: cancelled,
              style: const TextStyle(
                color: Color(0xFF0F172A),
                fontSize: 19,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
                height: 1.1,
              ),
            ),
            label: 'Cancelled',
            labelColor: const Color(0xFFE11D48),
            labelBg: const Color(0xFFFEE2E2),
          ),
          Container(width: 1, height: 36, color: const Color(0xFFF1F5F9)),
          _buildStatColumn(
            countWidget: _AnimatedCounterText(
              value: totalFare.toInt(),
              prefix: '₹',
              style: const TextStyle(
                color: Color(0xFF0F172A),
                fontSize: 19,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
                height: 1.1,
              ),
            ),
            label: 'Total Spent',
            labelColor: const Color(0xFF64748B),
            labelBg: const Color(0xFFF1F5F9),
          ),
        ],
      ),
    );
  }

  Widget _buildStatColumn({
    required Widget countWidget,
    required String label,
    required Color labelColor,
    required Color labelBg,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        countWidget,
        const SizedBox(height: 5),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
          decoration: BoxDecoration(
            color: labelBg,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: labelColor,
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.1,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDateFilterTab(
    String text,
    RideFilter filter,
    RideFilter activeFilter,
  ) {
    final isActive = filter == activeFilter;
    return Expanded(
      child: GestureDetector(
        onTap: () => ref.read(rideFilterProvider.notifier).state = filter,
        behavior: HitTestBehavior.opaque,
        child: Container(
          height: double.infinity,
          color: Colors.transparent,
          child: Center(
            child: AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              style: TextStyle(
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                fontSize: 12,
                color: isActive ? const Color(0xFF0F172A) : const Color(0xFF64748B),
                fontFamily: 'Inter',
              ),
              child: Text(text),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusTab(
    String text,
    RideStatusFilter filter,
    RideStatusFilter activeFilter,
  ) {
    final isActive = filter == activeFilter;
    
    Color dotColor = Colors.transparent;
    if (filter == RideStatusFilter.completed) dotColor = const Color(0xFF22C55E);
    if (filter == RideStatusFilter.cancelled) dotColor = const Color(0xFFEF4444);
    if (filter == RideStatusFilter.all) dotColor = const Color(0xFF0B2144);

    return Expanded(
      child: GestureDetector(
        onTap: () => ref.read(rideStatusFilterProvider.notifier).state = filter,
        behavior: HitTestBehavior.opaque,
        child: Container(
          height: double.infinity,
          color: Colors.transparent,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (dotColor != Colors.transparent)
                AnimatedScale(
                  scale: isActive ? 1.25 : 1.0,
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOutBack,
                  child: Container(
                    margin: const EdgeInsets.only(right: 6),
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: dotColor,
                      shape: BoxShape.circle,
                      boxShadow: isActive
                          ? [
                              BoxShadow(
                                color: dotColor.withValues(alpha: 0.35),
                                blurRadius: 4,
                                spreadRadius: 0.5,
                              ),
                            ]
                          : null,
                    ),
                  ),
                ),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                style: TextStyle(
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                  fontSize: 10.5,
                  color: isActive ? const Color(0xFF0F172A) : const Color(0xFF64748B),
                  fontFamily: 'Inter',
                ),
                child: Text(text),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(top: 40),
      alignment: Alignment.topCenter,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _FloatingEmptyState(
            child: SizedBox(
              height: 110,
              width: 110,
              child: Image.asset(
                'assets/images/sarthi-scooter-transparent.png',
                fit: BoxFit.contain,
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'No trips yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: Color(0xFF0F172A),
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Your completed rides will\nappear here.',
            style: TextStyle(
              fontSize: 12,
              color: Color(0xFF94A3B8),
              fontWeight: FontWeight.w500,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _RideCard extends StatefulWidget {
  final Map<String, dynamic> ride;
  final int index;
  const _RideCard({super.key, required this.ride, this.index = 0});

  @override
  State<_RideCard> createState() => _RideCardState();
}

class _RideCardState extends State<_RideCard> {
  bool _pressed = false;
  bool _detailsPressed = false;

  @override
  Widget build(BuildContext context) {
    final ride = widget.ride;
    final status = ride['status'] as String? ?? 'unknown';
    final fare = ride['fareEstimate'];
    final dest = ride['destination']?['address'] ?? 'Unknown destination';
    final destName = ride['destination']?['name'] ?? dest.split(',').first;
    final createdAt = ride['createdAt'];
    final distM = ride['distanceMeters'] as int?;
    final vehicleType = ride['vehicleType']?.toString().toLowerCase() ?? 'cab';

    final pickup = ride['pickup'] as Map<String, dynamic>?;
    final pickupFull = pickup != null ? (pickup['address'] as String? ?? 'Your Location') : 'Unknown pickup';
    final pickupName = pickup != null ? (pickup['name'] ?? pickupFull.split(',').first) : 'Unknown pickup';

    String formattedDate = '';
    if (createdAt != null) {
      formattedDate = DateFormat('MMM d • h:mm a').format(createdAt.toDate());
    }

    final bool isCancelled = status == 'cancelled';
    final bool isCompleted = status == 'completed';

    final statusColor = isCompleted
        ? const Color(0xFF059669)
        : (isCancelled ? const Color(0xFFE11D48) : const Color(0xFFD97706));
    final statusBg = isCompleted
        ? const Color(0xFFECFDF5)
        : (isCancelled ? const Color(0xFFFEE2E2) : const Color(0xFFFEF3C7));
    
    final statusLabel = isCompleted ? 'Completed' : (isCancelled ? 'Cancelled' : status.toUpperCase());
    final statusIcon = isCompleted ? Icons.check_circle_rounded : (isCancelled ? Icons.cancel_rounded : Icons.info_rounded);

    String durationText = '--';
    String distText = '--';
    if (distM != null) {
      final mins = (distM / 1000 * 3).round();
      durationText = '$mins min';
      distText = '${(distM / 1000).toStringAsFixed(1)} km';
    }

    final vehicleLabel = vehicleType == 'bike' ? 'Bike' : (vehicleType == 'cab' ? 'Cab' : 'Auto');
    final vehicleIcon = vehicleType == 'bike' ? Icons.two_wheeler_rounded : (vehicleType == 'cab' ? Icons.directions_car_rounded : Icons.electric_rickshaw_rounded);

    final staggerMs = math.min(widget.index, 6) * 45;

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 320 + staggerMs),
      curve: Curves.easeOutCubic,
      builder: (context, animValue, child) {
        return Opacity(
          opacity: animValue.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, 16 * (1.0 - animValue)),
            child: child,
          ),
        );
      },
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: () => _showRideDetail(context, ride), 
        child: AnimatedScale(
          scale: _pressed ? 0.985 : 1.0,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOutCubic,
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0F172A).withValues(alpha: 0.04),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                // Top Row
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E60F6).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(vehicleIcon, color: const Color(0xFF1E60F6), size: 20),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(vehicleLabel, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5, color: Color(0xFF0F172A))),
                          Text(formattedDate, style: const TextStyle(fontSize: 10, color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusBg,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(statusIcon, size: 11, color: statusColor),
                          const SizedBox(width: 4),
                          Text(
                            statusLabel,
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: statusColor),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                // Timeline
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                      children: [
                        const SizedBox(height: 4),
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFF1E60F6),
                            border: Border.all(color: Colors.white, width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF1E60F6).withValues(alpha: 0.35),
                                blurRadius: 6,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                        ),
                        Container(
                          width: 2,
                          height: 26,
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          color: const Color(0xFFCBD5E1),
                        ),
                        const Icon(Icons.location_on_rounded, size: 14, color: Color(0xFF0F172A)),
                      ],
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(pickupName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: Color(0xFF0F172A)), maxLines: 1, overflow: TextOverflow.ellipsis),
                          Text(pickupFull, style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)), maxLines: 1, overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 12),
                          Text(destName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: Color(0xFF0F172A)), maxLines: 1, overflow: TextOverflow.ellipsis),
                          Text(dest, style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)), maxLines: 1, overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(color: Color(0xFFF1F5F9), height: 1),
                const SizedBox(height: 12),
                // Bottom Row
                Row(
                  children: [
                    Text(isCompleted ? 'Paid ' : 'Est. ', style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
                    Text(fare != null ? '₹$fare' : '₹--', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                    Container(width: 1, height: 12, color: const Color(0xFFE2E8F0), margin: const EdgeInsets.symmetric(horizontal: 8)),
                    const Icon(Icons.route_outlined, size: 12, color: Color(0xFF64748B)),
                    const SizedBox(width: 4),
                    Text(distText, style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
                    Container(width: 1, height: 12, color: const Color(0xFFE2E8F0), margin: const EdgeInsets.symmetric(horizontal: 8)),
                    const Icon(Icons.schedule_rounded, size: 12, color: Color(0xFF64748B)),
                    const SizedBox(width: 4),
                    Text(durationText, style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
                    const Spacer(),
                    GestureDetector(
                      onTapDown: (_) => setState(() => _detailsPressed = true),
                      onTapUp: (_) => setState(() => _detailsPressed = false),
                      onTapCancel: () => setState(() => _detailsPressed = false),
                      onTap: () => _showRideDetail(context, ride),
                      behavior: HitTestBehavior.opaque,
                      child: AnimatedScale(
                        scale: _detailsPressed ? 0.92 : 1.0,
                        duration: const Duration(milliseconds: 100),
                        curve: Curves.easeOutCubic,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E60F6),
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF1E60F6).withValues(alpha: 0.25),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Text(
                            'Details',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showRideDetail(BuildContext context, Map<String, dynamic> ride) {
    final status = ride['status'] as String? ?? 'unknown';
    final fare = ride['fareEstimate'];
    final dest = ride['destination']?['address'] ?? 'Unknown destination';
    final destName = ride['destination']?['name'] ?? dest.split(',').first;
    final createdAt = ride['createdAt'];
    final distM = ride['distanceMeters'] as int?;
    final vehicleType = ride['vehicleType']?.toString().toLowerCase() ?? 'cab';
    final paymentMethod = ride['paymentMethod'] ?? 'Cash';

    final pickup = ride['pickup'] as Map<String, dynamic>?;
    final pickupFull = pickup != null ? (pickup['address'] as String? ?? 'Your Location') : 'Unknown pickup';
    final pickupName = pickup != null ? (pickup['name'] ?? pickupFull.split(',').first) : 'Unknown pickup';

    String durationText = '--';
    if (distM != null) {
      final mins = (distM / 1000 * 3).round();
      durationText = '$mins min';
    }

    final vehicleLabel = vehicleType == 'bike' ? 'Bike' : (vehicleType == 'cab' ? 'Cab' : 'Auto');
    final vehicleIcon = vehicleType == 'bike' ? Icons.two_wheeler_rounded : (vehicleType == 'cab' ? Icons.directions_car_rounded : Icons.electric_rickshaw_rounded);
    
    String formattedDate = '';
    if (createdAt != null) {
      formattedDate = DateFormat('d Sep • h:mm a').format(createdAt.toDate());
    }

    final bool isCancelled = status == 'cancelled';
    final bool isCompleted = status == 'completed';

    final statusColor = isCompleted ? const Color(0xFF22C55E) : (isCancelled ? const Color(0xFFEF4444) : const Color(0xFFF59E0B));
    final statusBg = isCompleted ? const Color(0xFFDCFCE7) : (isCancelled ? const Color(0xFFFEE2E2) : const Color(0xFFFEF3C7));
    
    final statusLabel = isCompleted ? 'Completed' : (isCancelled ? 'Cancelled' : status.toUpperCase());
    final statusIcon = isCompleted ? Icons.check_circle_rounded : (isCancelled ? Icons.cancel_rounded : Icons.info_rounded);

    final rideId = (ride['id'] as String?)?.substring(0, 8).toUpperCase() ?? '--';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.only(top: 12, left: 24, right: 24, bottom: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),
              
              // Header
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0B2144).withValues(alpha: 0.06), // Light blue
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(vehicleIcon, color: const Color(0xFF0B2144), size: 28),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$vehicleLabel ride',
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          formattedDate,
                          style: const TextStyle(fontSize: 13, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: statusBg,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(statusIcon, size: 14, color: statusColor),
                        const SizedBox(width: 6),
                        Text(
                          statusLabel,
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: statusColor),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Locations
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                      children: [
                        const SizedBox(height: 6),
                        Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: const Color(0xFF0B2144), width: 3.5),
                          ),
                        ),
                        Container(
                          width: 2,
                          height: 40,
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          color: const Color(0xFFCBD5E1), // Dashed line effect
                        ),
                        const Icon(Icons.location_on_rounded, size: 18, color: Color(0xFF0F172A)),
                      ],
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('PICKUP', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF94A3B8), letterSpacing: 0.5)),
                          const SizedBox(height: 2),
                          Text(pickupName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFF0F172A)), maxLines: 1, overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 2),
                          Text(pickupFull, style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)), maxLines: 1, overflow: TextOverflow.ellipsis),
                          
                          const SizedBox(height: 16),
                          
                          const Text('DROP-OFF', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF94A3B8), letterSpacing: 0.5)),
                          const SizedBox(height: 2),
                          Text(destName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFF0F172A)), maxLines: 1, overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 2),
                          Text(dest, style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)), maxLines: 1, overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Stats Row
              Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFF0B2144).withValues(alpha: 0.06), // Very light blue
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          const Icon(Icons.currency_rupee_rounded, size: 18, color: Color(0xFF0B2144)),
                          const SizedBox(height: 4),
                          Text(fare != null ? '₹$fare' : '₹--', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                          const SizedBox(height: 2),
                          Text(isCompleted ? 'Paid amount' : 'Fare estimate', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ),
                    Container(width: 1, height: 40, color: const Color(0xFFE2E8F0)),
                    Expanded(
                      child: Column(
                        children: [
                          const Icon(Icons.map_outlined, size: 18, color: Color(0xFF0B2144)),
                          const SizedBox(height: 4),
                          Text(distM != null ? '${(distM / 1000).toStringAsFixed(1)} km' : '--', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                          const SizedBox(height: 2),
                          const Text('Distance', style: TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ),
                    Container(width: 1, height: 40, color: const Color(0xFFE2E8F0)),
                    Expanded(
                      child: Column(
                        children: [
                          const Icon(Icons.access_time_rounded, size: 18, color: Color(0xFF0B2144)),
                          const SizedBox(height: 4),
                          Text(durationText, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                          const SizedBox(height: 2),
                          const Text('Duration', style: TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Details List
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    _buildDetailRow(Icons.directions_car_outlined, 'Vehicle', vehicleLabel),
                    const Divider(height: 1, color: Color(0xFFE2E8F0)),
                    _buildDetailRow(Icons.payment_outlined, 'Payment method', paymentMethod),
                    const Divider(height: 1, color: Color(0xFFE2E8F0)),
                    _buildDetailRow(Icons.tag_rounded, 'Ride ID', rideId, isMonospace: true),
                  ],
                ),
              ),
              
              const SizedBox(height: 24),
              // Close button
              SizedBox(
                width: double.infinity,
                height: 54,
                child: _Bounceable(
                  scaleFactor: 0.96,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E60F6),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Close',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(height: MediaQuery.of(ctx).padding.bottom),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value, {bool isMonospace = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Icon(icon, size: 20, color: const Color(0xFF64748B)),
          const SizedBox(width: 16),
          Text(label, style: const TextStyle(fontSize: 14, color: Color(0xFF475569))),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontSize: 14, 
              fontWeight: FontWeight.w700, 
              color: const Color(0xFF0F172A),
              fontFamily: isMonospace ? 'monospace' : null,
              letterSpacing: isMonospace ? 1.0 : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _Bounceable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double scaleFactor;

  const _Bounceable({
    required this.child,
    this.onTap,
    this.scaleFactor = 0.92,
  });

  @override
  State<_Bounceable> createState() => _BounceableState();
}

class _BounceableState extends State<_Bounceable> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedScale(
        scale: _pressed ? widget.scaleFactor : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        child: widget.child,
      ),
    );
  }
}

class _AnimatedCounterText extends StatelessWidget {
  final num value;
  final String prefix;
  final TextStyle style;

  const _AnimatedCounterText({
    required this.value,
    this.prefix = '',
    required this.style,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: value.toDouble()),
      duration: const Duration(milliseconds: 650),
      curve: Curves.easeOutCubic,
      builder: (context, animatedValue, child) {
        return Text(
          '$prefix${animatedValue.toInt()}',
          style: style,
        );
      },
    );
  }
}

class _FloatingEmptyState extends StatefulWidget {
  final Widget child;
  const _FloatingEmptyState({required this.child});

  @override
  State<_FloatingEmptyState> createState() => _FloatingEmptyStateState();
}

class _FloatingEmptyStateState extends State<_FloatingEmptyState>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final offset = math.sin(_controller.value * math.pi) * 8.0;
        return Transform.translate(
          offset: Offset(0, -offset),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

class _RideHistorySkeletonList extends StatelessWidget {
  const _RideHistorySkeletonList();

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 160),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            return Shimmer.fromColors(
              baseColor: const Color(0xFFE2E8F0),
              highlightColor: const Color(0xFFF8FAFC),
              period: const Duration(milliseconds: 1400),
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(width: 60, height: 12, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4))),
                            const SizedBox(height: 6),
                            Container(width: 90, height: 10, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4))),
                          ],
                        ),
                        const Spacer(),
                        Container(
                          width: 72,
                          height: 22,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(width: 12, height: 48, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4))),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(width: 140, height: 12, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4))),
                              const SizedBox(height: 6),
                              Container(width: 200, height: 10, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4))),
                              const SizedBox(height: 12),
                              Container(width: 120, height: 12, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4))),
                              const SizedBox(height: 6),
                              Container(width: 180, height: 10, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4))),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Container(width: 60, height: 14, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4))),
                        const Spacer(),
                        Container(
                          width: 68,
                          height: 28,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
          childCount: 3,
        ),
      ),
    );
  }
}

