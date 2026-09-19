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
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9), // Light grey
                      borderRadius: BorderRadius.circular(26),
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
                                  color: const Color(0xFF0F62FE),
                                  borderRadius: BorderRadius.circular(22),
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
    return Container(
      color: const Color(0xFF0B2144),
      padding: const EdgeInsets.only(left: 20, right: 20, bottom: 20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _build3DStatCard(context, completed, cancelled, totalFare),
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
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF16325B), // Slightly lighter than background
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildStatItem(
            icon: Icons.check_rounded,
            iconColor: Colors.white,
            iconBg: const Color(0xFF22C55E),
            value: '$completed',
            label: 'Completed',
          ),
          Container(width: 1, height: 40, color: Colors.white.withOpacity(0.15)),
          _buildStatItem(
            icon: Icons.close_rounded,
            iconColor: Colors.white,
            iconBg: const Color(0xFFEF4444),
            value: '$cancelled',
            label: 'Cancelled',
          ),
          Container(width: 1, height: 40, color: Colors.white.withOpacity(0.15)),
          _buildStatItem(
            icon: Icons.account_balance_wallet_rounded,
            iconColor: Colors.white,
            iconBg: null,
            value: '₹${totalFare.toInt()}',
            label: 'Total spent',
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required Color iconColor,
    required Color? iconBg,
    required String value,
    required String label,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (iconBg != null)
          Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: iconBg,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 14),
          )
        else
          Icon(icon, color: iconColor, size: 20),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w800,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.6),
            fontSize: 12,
            fontWeight: FontWeight.w500,
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
                fontSize: 13,
                color: isActive ? Colors.white : const Color(0xFF64748B),
                fontFamily: 'Inter',
              ),
              child: Text(text),
            ),
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
    Widget iconWidget;

    switch (filter) {
      case RideStatusFilter.all:
        activeColor = const Color(0xFF0F62FE); // Blue
        iconWidget = Icon(Icons.filter_list_rounded, color: isActive ? activeColor : const Color(0xFF64748B), size: 12);
        break;
      case RideStatusFilter.completed:
        activeColor = const Color(0xFF22C55E); // Green
        iconWidget = Container(
          decoration: BoxDecoration(color: activeColor, shape: BoxShape.circle),
          padding: const EdgeInsets.all(2),
          child: const Icon(Icons.check_rounded, color: Colors.white, size: 8),
        );
        break;
      case RideStatusFilter.cancelled:
        activeColor = const Color(0xFFEF4444); // Red
        iconWidget = Container(
          decoration: BoxDecoration(color: activeColor, shape: BoxShape.circle),
          padding: const EdgeInsets.all(2),
          child: const Icon(Icons.close_rounded, color: Colors.white, size: 8),
        );
        break;
    }

    final borderColor = isActive ? activeColor : const Color(0xFFCBD5E1);
    final textColor = isActive ? activeColor : const Color(0xFF64748B);

    return GestureDetector(
      onTap: () => ref.read(rideStatusFilterProvider.notifier).state = filter,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: borderColor, width: 1.0),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            iconWidget,
            const SizedBox(width: 4),
            Text(
              text,
              style: TextStyle(
                color: textColor,
                fontSize: 11,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
              ),
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

    final statusColor = isCompleted ? const Color(0xFF22C55E) : (isCancelled ? const Color(0xFFEF4444) : const Color(0xFFF59E0B));
    final statusBg = isCompleted ? const Color(0xFFDCFCE7) : (isCancelled ? const Color(0xFFFEE2E2) : const Color(0xFFFEF3C7));
    
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

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: () => _showRideDetail(context, ride), 
      child: AnimatedScale(
        scale: _pressed ? 0.98 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFF1F5F9)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 10,
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
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(vehicleIcon, color: const Color(0xFF2563EB), size: 18),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(vehicleLabel, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFF0F172A))),
                        Text(formattedDate, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: statusBg,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(statusIcon, size: 12, color: statusColor),
                        const SizedBox(width: 4),
                        Text(
                          statusLabel,
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: statusColor),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
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
                          border: Border.all(color: const Color(0xFF2563EB), width: 2.5),
                        ),
                      ),
                      Container(
                        width: 2,
                        height: 24,
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        color: const Color(0xFFCBD5E1), // Simulated dashed line
                      ),
                      const Icon(Icons.location_on_rounded, size: 14, color: Color(0xFF0F172A)),
                    ],
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(pickupName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF0F172A)), maxLines: 1, overflow: TextOverflow.ellipsis),
                        Text(pickupFull, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)), maxLines: 1, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 12),
                        Text(destName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF0F172A)), maxLines: 1, overflow: TextOverflow.ellipsis),
                        Text(dest, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)), maxLines: 1, overflow: TextOverflow.ellipsis),
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
                  Text(isCompleted ? 'Paid ' : 'Est. ', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                  Text(fare != null ? '₹$fare' : '₹--', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
                  Container(width: 1, height: 10, color: const Color(0xFFCBD5E1), margin: const EdgeInsets.symmetric(horizontal: 8)),
                  const Icon(Icons.route_outlined, size: 12, color: Color(0xFF64748B)),
                  const SizedBox(width: 4),
                  Text(distText, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                  Container(width: 1, height: 10, color: const Color(0xFFCBD5E1), margin: const EdgeInsets.symmetric(horizontal: 8)),
                  const Icon(Icons.schedule_rounded, size: 12, color: Color(0xFF64748B)),
                  const SizedBox(width: 4),
                  Text(durationText, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                  const Spacer(),
                  const Text('Details >', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF2563EB))),
                ],
              ),
            ],
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
                      color: const Color(0xFFEFF6FF), // Light blue
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(vehicleIcon, color: const Color(0xFF2563EB), size: 28),
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
                            border: Border.all(color: const Color(0xFF2563EB), width: 3.5),
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
                  color: const Color(0xFFEFF6FF), // Very light blue
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          const Icon(Icons.currency_rupee_rounded, size: 18, color: Color(0xFF2563EB)),
                          const SizedBox(height: 4),
                          Text(fare != null ? '₹$fare' : '₹--', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                          const SizedBox(height: 2),
                          Text(isCompleted ? 'Paid amount' : 'Fare estimate', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ),
                    Container(width: 1, height: 40, color: const Color(0xFFBFDBFE)),
                    Expanded(
                      child: Column(
                        children: [
                          const Icon(Icons.map_outlined, size: 18, color: Color(0xFF2563EB)),
                          const SizedBox(height: 4),
                          Text(distM != null ? '${(distM / 1000).toStringAsFixed(1)} km' : '--', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                          const SizedBox(height: 2),
                          const Text('Distance', style: TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ),
                    Container(width: 1, height: 40, color: const Color(0xFFBFDBFE)),
                    Expanded(
                      child: Column(
                        children: [
                          const Icon(Icons.access_time_rounded, size: 18, color: Color(0xFF2563EB)),
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
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F62FE), // Bright blue
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Close',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
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
