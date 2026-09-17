import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../map/presentation/map_home_screen.dart';
import 'package:go_router/go_router.dart';

enum RideFilter { today, last30Days, allTime }

enum RideStatusFilter { all, completed, cancelled }

enum RideSortOrder { newestFirst, oldestFirst }

final rideFilterProvider = StateProvider<RideFilter>((ref) => RideFilter.today);
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

      Query query = FirebaseFirestore.instance
          .collection('ride_requests')
          .where('userId', isEqualTo: uid);

      if (filter != RideFilter.allTime) {
        query = query.where('createdAt', isGreaterThanOrEqualTo: startDate);
      }

      query = query.orderBy('createdAt', descending: sortOrder == RideSortOrder.newestFirst).limit(50);

      if (_lastDoc != null) {
        query = query.startAfterDocument(_lastDoc!);
      }

      final snapshot = await query.get();

      if (currentFetchId != _fetchId) return;

      if (snapshot.docs.isNotEmpty) {
        _lastDoc = snapshot.docs.last;
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

        state = state.copyWith(
          rides: [...state.rides, ...newRides],
          isLoading: false,
          hasMore: snapshot.docs.length == 50,
        );
      } else {
        state = state.copyWith(isLoading: false, hasMore: false);
      }
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

class _RideHistoryScreenState extends ConsumerState<RideHistoryScreen>
    with TickerProviderStateMixin {
  final _scrollController = ScrollController();
  AnimationController? _headerAnimController;
  Animation<double> _headerFadeAnim = const AlwaysStoppedAnimation(1.0);

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _headerAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _headerFadeAnim = CurvedAnimation(
      parent: _headerAnimController!,
      curve: Curves.easeOut,
    );
    _headerAnimController!.forward();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _headerAnimController?.dispose();
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

    final displayedRides = historyState.rides.where((ride) {
      final status = ride['status'] as String? ?? '';
      if (activeStatusFilter == RideStatusFilter.completed) {
        return status == 'completed';
      }
      if (activeStatusFilter == RideStatusFilter.cancelled) {
        return status == 'cancelled';
      }
      return true;
    }).toList();

    final completedCount = historyState.rides
        .where((r) => r['status'] == 'completed')
        .length;
    final cancelledCount = historyState.rides
        .where((r) => r['status'] == 'cancelled')
        .length;
    final totalFare = historyState.rides
        .where((r) => r['status'] == 'completed')
        .fold<double>(0, (acc, r) {
          final f = r['fareEstimate'];
          if (f is num) return acc + f.toDouble();
          if (f is String) return acc + (double.tryParse(f) ?? 0);
          return acc;
        });

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4FF),
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          SliverAppBar(
            expandedHeight: 230,
            floating: false,
            pinned: true,
            backgroundColor: const Color(0xFF0B2144),
            elevation: 0,
            automaticallyImplyLeading: false,
            flexibleSpace: FlexibleSpaceBar(
              background: _buildHeroHeader(
                context,
                completedCount,
                cancelledCount,
                totalFare,
              ),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0B2144), Color(0xFF1A3A6B)],
                    ),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const SarthiLogo(size: 14),
                ),
                const SizedBox(width: 8),
                ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [Colors.white, Color(0xFFBFDBFE)],
                  ).createShader(bounds),
                  child: const Text(
                    'Sarthi',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                      color: Colors.white,
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
                const Spacer(),
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    GestureDetector(
                      onTap: () => context.push('/notifications'),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.25),
                          ),
                        ),
                        child: const Icon(
                          Icons.notifications_none_rounded,
                          size: 16,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    Positioned(
                      top: 2,
                      right: 2,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: const Color(0xFFEF4444),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFF0B2144),
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 8),
                GestureDetector(
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
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [Color(0xFF0B2144), Color(0xFF3B82F6)],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const CircleAvatar(
                      radius: 15,
                      backgroundColor: Colors.transparent,
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
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 52,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(26),
                    ),
                    child: Stack(
                      children: [
                        AnimatedAlign(
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeInOut,
                          alignment: activeFilter == RideFilter.today
                              ? Alignment.centerLeft
                              : activeFilter == RideFilter.last30Days
                              ? Alignment.center
                              : Alignment.centerRight,
                          child: FractionallySizedBox(
                            widthFactor: 1 / 3,
                            child: Container(
                              margin: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0B2144),
                                borderRadius: BorderRadius.circular(22),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.12),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
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
                              'Last 30 Days',
                              RideFilter.last30Days,
                              activeFilter,
                            ),
                            _buildDateFilterTab(
                              'All Time',
                              RideFilter.allTime,
                              activeFilter,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _buildStatusChip(
                        'All',
                        RideStatusFilter.all,
                        activeStatusFilter,
                      ),
                      const SizedBox(width: 8),
                      _buildStatusChip(
                        'Completed',
                        RideStatusFilter.completed,
                        activeStatusFilter,
                      ),
                      const SizedBox(width: 8),
                      _buildStatusChip(
                        'Cancelled',
                        RideStatusFilter.cancelled,
                        activeStatusFilter,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${displayedRides.length} trips found',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF475569),
                        ),
                      ),
                      PopupMenuButton<RideSortOrder>(
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
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),

          if (historyState.rides.isEmpty)
            if (historyState.isLoading)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: CircularProgressIndicator(color: Color(0xFF0B2144)),
                ),
              )
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
                    return _RideCard(ride: displayedRides[index]);
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

  Widget _buildHeroHeader(
    BuildContext context,
    int completed,
    int cancelled,
    double totalFare,
  ) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF060D1F), Color(0xFF0B2144), Color(0xFF0F3460)],
            ),
          ),
        ),
        Positioned(
          right: -40,
          top: -40,
          child: Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  const Color(0xFF3B82F6).withValues(alpha: 0.25),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
        Positioned(
          left: -30,
          bottom: 40,
          child: Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  const Color(0xFF8B5CF6).withValues(alpha: 0.2),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
        Positioned.fill(child: CustomPaint(painter: _GridPainter())),
        Positioned(
          bottom: 16,
          left: 16,
          right: 16,
          child: FadeTransition(
            opacity: _headerFadeAnim,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFBBF24),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.history_rounded,
                        size: 10,
                        color: Color(0xFF0B2144),
                      ),
                      SizedBox(width: 4),
                      Text(
                        'Trip History',
                        style: TextStyle(
                          color: Color(0xFF0B2144),
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _build3DStatCard(
                      icon: Icons.check_circle_rounded,
                      value: '$completed',
                      label: 'Completed',
                      color1: const Color(0xFF059669),
                      color2: const Color(0xFF10B981),
                    ),
                    const SizedBox(width: 6),
                    _build3DStatCard(
                      icon: Icons.cancel_rounded,
                      value: '$cancelled',
                      label: 'Cancelled',
                      color1: const Color(0xFFDC2626),
                      color2: const Color(0xFFEF4444),
                    ),
                    const SizedBox(width: 6),
                    _build3DStatCard(
                      icon: Icons.currency_rupee_rounded,
                      value: totalFare > 0
                          ? '\u20b9${totalFare.toStringAsFixed(0)}'
                          : '\u20b90',
                      label: 'Total Spent',
                      color1: const Color(0xFF7C3AED),
                      color2: const Color(0xFFA78BFA),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _build3DStatCard({
    required IconData icon,
    required String value,
    required String label,
    required Color color1,
    required Color color2,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withValues(alpha: 0.12),
              Colors.white.withValues(alpha: 0.06),
            ],
          ),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.18),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: color1.withValues(alpha: 0.2),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [color1, color2]),
                borderRadius: BorderRadius.circular(6),
                boxShadow: [
                  BoxShadow(
                    color: color1.withValues(alpha: 0.4),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(icon, color: Colors.white, size: 12),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 8,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
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
        child: Center(
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 250),
            style: TextStyle(
              fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
              fontSize: 12,
              color: isActive ? Colors.white : Colors.grey.shade700,
            ),
            child: Text(text),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(
    String text,
    RideStatusFilter filter,
    RideStatusFilter activeFilter,
  ) {
    final isActive = filter == activeFilter;
    Color activeColor;
    IconData? icon;
    switch (filter) {
      case RideStatusFilter.all:
        activeColor = const Color(0xFF0B2144);
        icon = Icons.grid_view_rounded;
        break;
      case RideStatusFilter.completed:
        activeColor = const Color(0xFF059669);
        icon = Icons.check_circle_rounded;
        break;
      case RideStatusFilter.cancelled:
        activeColor = const Color(0xFFDC2626);
        icon = Icons.cancel_rounded;
        break;
    }
    return GestureDetector(
      onTap: () => ref.read(rideStatusFilterProvider.notifier).state = filter,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          gradient: isActive
              ? LinearGradient(
                  colors: [activeColor, activeColor.withValues(alpha: 0.75)],
                )
              : null,
          color: isActive ? null : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isActive ? activeColor : const Color(0xFFE2E8F0),
          ),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: activeColor.withValues(alpha: 0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 11,
              color: isActive ? Colors.white : activeColor,
            ),
            const SizedBox(width: 5),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
                color: isActive ? Colors.white : const Color(0xFF64748B),
              ),
              child: Text(text),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(top: 80),
      alignment: Alignment.topCenter,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 150,
            width: 150,
            child: Image.asset(
              'assets/images/sarthi-scooter-transparent.png',
              fit: BoxFit.contain,
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

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.03)
      ..strokeWidth = 1;
    const spacing = 32.0;
    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _RideCard extends StatefulWidget {
  final Map<String, dynamic> ride;
  const _RideCard({required this.ride});

  @override
  State<_RideCard> createState() => _RideCardState();
}

class _RideCardState extends State<_RideCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final ride = widget.ride;
    final status = ride['status'] as String? ?? 'unknown';
    final fare = ride['fareEstimate'];
    final dest = ride['destination']?['address'] ?? 'Unknown destination';
    final createdAt = ride['createdAt'];
    final distM = ride['distanceMeters'] as int?;
    final paymentMethod = ride['paymentMethod'] ?? 'Cash';
    final vehicleType = ride['vehicleType']?.toString().toLowerCase() ?? 'auto';

    final pickup = ride['pickup'] as Map<String, dynamic>?;
    final pickupText = pickup != null
        ? (pickup['address'] as String? ?? 'Your Location')
        : 'Unknown pickup';

    String formattedDate = '';
    if (createdAt is Timestamp) {
      formattedDate = DateFormat('MMM d, h:mm a').format(createdAt.toDate());
    }

    final bool isCancelled = status == 'cancelled';
    final bool isCompleted = status == 'completed';

    final statusGradient = isCompleted
        ? [const Color(0xFF059669), const Color(0xFF10B981)]
        : isCancelled
        ? [const Color(0xFFDC2626), const Color(0xFFEF4444)]
        : [const Color(0xFFF59E0B), const Color(0xFFFBBF24)];

    final statusLabel = isCompleted
        ? 'Completed'
        : isCancelled
        ? 'Cancelled'
        : status.toUpperCase();
    final statusIcon = isCompleted
        ? Icons.check_circle_rounded
        : isCancelled
        ? Icons.cancel_rounded
        : Icons.info_rounded;

    String durationText = '--';
    if (distM != null) {
      final mins = (distM / 1000 * 3).round();
      durationText = '$mins min';
    }

    final vehicleLabel = vehicleType == 'bike'
        ? 'Bike'
        : vehicleType == 'cab'
        ? 'Cab'
        : 'Auto';
    final vehicleGradient = vehicleType == 'bike'
        ? [const Color(0xFF1D4ED8), const Color(0xFF3B82F6)]
        : vehicleType == 'cab'
        ? [const Color(0xFF6D28D9), const Color(0xFFA78BFA)]
        : [const Color(0xFF065F46), const Color(0xFF10B981)];
    final vehicleIcon = vehicleType == 'bike'
        ? Icons.two_wheeler_rounded
        : vehicleType == 'cab'
        ? Icons.directions_car_rounded
        : Icons.electric_rickshaw_rounded;

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: () => _showRideDetail(
        context,
        ride,
        formattedDate,
        statusGradient,
        statusLabel,
        statusIcon,
        pickupText,
        dest,
        fare,
        distM,
        durationText,
        paymentMethod,
        vehicleLabel,
        vehicleGradient,
        vehicleIcon,
      ),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0B2144).withValues(alpha: 0.07),
                blurRadius: 20,
                spreadRadius: 1,
                offset: const Offset(0, 6),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      vehicleGradient[0].withValues(alpha: 0.08),
                      vehicleGradient[1].withValues(alpha: 0.04),
                    ],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: vehicleGradient,
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: vehicleGradient[0].withValues(alpha: 0.35),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(vehicleIcon, size: 12, color: Colors.white),
                          const SizedBox(width: 4),
                          Text(
                            vehicleLabel,
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    Text(
                      formattedDate,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: statusGradient),
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: statusGradient[0].withValues(alpha: 0.3),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(statusIcon, size: 9, color: Colors.white),
                          const SizedBox(width: 3),
                          Text(
                            statusLabel,
                            style: const TextStyle(
                              fontSize: 8,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  children: [
                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Column(
                            children: [
                              Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white,
                                  border: Border.all(
                                    color: const Color(0xFF0B2144),
                                    width: 2.5,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Container(
                                  width: 2,
                                  margin: const EdgeInsets.symmetric(
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        const Color(
                                          0xFF0B2144,
                                        ).withValues(alpha: 0.5),
                                        const Color(
                                          0xFFEF4444,
                                        ).withValues(alpha: 0.5),
                                      ],
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                    ),
                                  ),
                                ),
                              ),
                              Container(
                                width: 10,
                                height: 10,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Color(0xFFEF4444),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  pickupText,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF1E293B),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  dest,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF1E293B),
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
                    const SizedBox(height: 12),
                    Container(height: 1, color: const Color(0xFFF1F5F9)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _metricPill(
                          Icons.currency_rupee_rounded,
                          fare != null ? '\u20b9$fare' : '\u20b90',
                          const Color(0xFF059669),
                        ),
                        const SizedBox(width: 8),
                        if (distM != null) ...[
                          _metricPill(
                            Icons.straighten_rounded,
                            '${(distM / 1000).toStringAsFixed(1)} km',
                            const Color(0xFF0B2144),
                          ),
                          const SizedBox(width: 8),
                        ],
                        _metricPill(
                          Icons.access_time_rounded,
                          durationText,
                          const Color(0xFF7C3AED),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF0B2144), Color(0xFF1A3A6B)],
                            ),
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(
                                  0xFF0B2144,
                                ).withValues(alpha: 0.3),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Details',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                              SizedBox(width: 3),
                              Icon(
                                Icons.arrow_forward_rounded,
                                size: 10,
                                color: Colors.white,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _metricPill(IconData icon, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 3),
          Text(
            value,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  void _showRideDetail(
    BuildContext context,
    Map<String, dynamic> ride,
    String formattedDate,
    List<Color> statusGradient,
    String statusLabel,
    IconData statusIcon,
    String pickupText,
    String dest,
    dynamic fare,
    int? distM,
    String durationText,
    String paymentMethod,
    String vehicleLabel,
    List<Color> vehicleGradient,
    IconData vehicleIcon,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 14),
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      vehicleGradient[0].withValues(alpha: 0.1),
                      vehicleGradient[1].withValues(alpha: 0.04),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: vehicleGradient,
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: vehicleGradient[0].withValues(alpha: 0.4),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Icon(vehicleIcon, color: Colors.white, size: 26),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$vehicleLabel Ride',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF0F172A),
                              letterSpacing: -0.4,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            formattedDate,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF64748B),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: statusGradient),
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: statusGradient[0].withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(statusIcon, color: Colors.white, size: 11),
                          const SizedBox(width: 4),
                          Text(
                            statusLabel,
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  24,
                  20,
                  24,
                  24 + MediaQuery.of(ctx).padding.bottom,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Column(
                            children: [
                              Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white,
                                  border: Border.all(
                                    color: const Color(0xFF0B2144),
                                    width: 3,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Container(
                                  width: 2,
                                  color: const Color(0xFFE2E8F0),
                                ),
                              ),
                              Container(
                                width: 12,
                                height: 12,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Color(0xFFEF4444),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  pickupText,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF1E293B),
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 18),
                                Text(
                                  dest,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF0F172A),
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Container(height: 1, color: const Color(0xFFF1F5F9)),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        _detailCard(
                          Icons.currency_rupee_rounded,
                          fare != null ? '\u20b9$fare' : '--',
                          'Fare',
                          const Color(0xFF059669),
                        ),
                        const SizedBox(width: 10),
                        _detailCard(
                          Icons.straighten_rounded,
                          distM != null
                              ? '${(distM / 1000).toStringAsFixed(1)} km'
                              : '--',
                          'Distance',
                          const Color(0xFF0B2144),
                        ),
                        const SizedBox(width: 10),
                        _detailCard(
                          Icons.access_time_rounded,
                          durationText,
                          'Duration',
                          const Color(0xFF7C3AED),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _detailCard(
                          vehicleIcon,
                          vehicleLabel,
                          'Vehicle',
                          vehicleGradient[0],
                        ),
                        const SizedBox(width: 10),
                        _detailCard(
                          Icons.payment_rounded,
                          paymentMethod,
                          'Payment',
                          const Color(0xFFF59E0B),
                        ),
                        const SizedBox(width: 10),
                        _detailCard(
                          Icons.tag_rounded,
                          (ride['id'] as String?)
                                  ?.substring(0, 8)
                                  .toUpperCase() ??
                              '--',
                          'Ride ID',
                          const Color(0xFF64748B),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0B2144),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          'Close',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _detailCard(IconData icon, String value, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.12)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: color,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                fontSize: 8.5,
                color: Color(0xFF94A3B8),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
