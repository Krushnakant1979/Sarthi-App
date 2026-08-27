import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../../core/design/tokens.dart';
import 'captain_providers.dart';

class CaptainTripsScreen extends ConsumerStatefulWidget {
  const CaptainTripsScreen({super.key});

  @override
  ConsumerState<CaptainTripsScreen> createState() => _CaptainTripsScreenState();
}

class _CaptainTripsScreenState extends ConsumerState<CaptainTripsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  DateTime _getStartOfToday() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  DateTime _getStartOf30Days() {
    return DateTime.now().subtract(const Duration(days: 30));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 8,
                          offset: Offset(0, 3),
                        ),
                      ],
                    ),
                    child: IconButton(
                      onPressed: () => context.pop(),
                      icon: Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: context.colors.primary,
                        size: 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    'My Trips',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: context.colors.primary,
                    ),
                  ),
                ],
              ),
            ),

            // Tabs
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  color: context.colors.primary,
                  borderRadius: BorderRadius.circular(16),
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                labelColor: Colors.white,
                unselectedLabelColor: const Color(0xFF6B7280),
                labelStyle: const TextStyle(fontWeight: FontWeight.w700),
                dividerColor: Colors.transparent,
                padding: const EdgeInsets.all(4),
                tabs: const [
                  Tab(text: 'Today'),
                  Tab(text: 'Last 30 Days'),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Tab Views
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _TripsTabView(
                    startDate: _getStartOfToday(),
                    endDate: DateTime.now(),
                    isToday: true,
                  ),
                  _TripsTabView(
                    startDate: _getStartOf30Days(),
                    endDate: DateTime.now(),
                    isToday: false,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TripsTabView extends ConsumerStatefulWidget {
  final DateTime startDate;
  final DateTime endDate;
  final bool isToday;

  const _TripsTabView({
    required this.startDate,
    required this.endDate,
    required this.isToday,
  });

  @override
  ConsumerState<_TripsTabView> createState() => _TripsTabViewState();
}

class _TripsTabViewState extends ConsumerState<_TripsTabView> {
  final List<Map<String, dynamic>> _trips = [];
  DocumentSnapshot? _lastDocument;
  bool _hasMore = true;
  bool _isLoading = false;
  String? _error;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _fetchTrips();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
              _scrollController.position.maxScrollExtent - 200 &&
          !_isLoading &&
          _hasMore) {
        _fetchTrips();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchTrips() async {
    if (_isLoading || !_hasMore) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final repo = ref.read(captainRepositoryProvider);
      final result = await repo.getPaginatedTrips(
        user.uid,
        widget.startDate,
        widget.endDate,
        startAfter: _lastDocument,
        limit: 10,
      );

      setState(() {
        _trips.addAll(result['trips']);
        _lastDocument = result['lastDocument'];
        _hasMore = result['hasMore'];
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final statsAsync = ref.watch(
      captainTripStatsProvider((
        start: widget.startDate,
        end: widget.endDate,
      )),
    );

    return RefreshIndicator(
      onRefresh: () async {
        setState(() {
          _trips.clear();
          _lastDocument = null;
          _hasMore = true;
          _error = null;
        });
        ref.invalidate(
          captainTripStatsProvider((
            start: widget.startDate,
            end: widget.endDate,
          )),
        );
        await _fetchTrips();
      },
      child: CustomScrollView(
        controller: _scrollController,
        slivers: [
          // 1. Stats Grid (Only show if we have data or if trips already exist)
          SliverToBoxAdapter(
            child: statsAsync.when(
              data: (stats) {
                // Hide stats initially if there's an error and no trips
                if (_trips.isEmpty && (_error != null || statsAsync.hasError)) {
                  return const SizedBox.shrink();
                }
                // Hide stats initially while loading
                if (_trips.isEmpty && _isLoading) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      _buildStatsGrid(stats),
                      const SizedBox(height: 24),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Trip History',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: context.colors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
              loading: () => _trips.isNotEmpty
                  ? SizedBox(
                      height: 150,
                      child: Center(
                        child: CircularProgressIndicator(color: context.colors.liveTeal),
                      ),
                    )
                  : const SizedBox.shrink(),
              error: (e, s) => _trips.isNotEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'Failed to load stats',
                        style: TextStyle(color: context.colors.error),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ),

          // 2. Global Loading State
          if (_trips.isEmpty && (_isLoading || statsAsync.isLoading))
            SliverFillRemaining(
              child: Center(
                child: CircularProgressIndicator(color: context.colors.primary),
              ),
            )

          // 3. Global Error State
          else if (_trips.isEmpty && (_error != null || statsAsync.hasError))
            SliverFillRemaining(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.error_outline, color: context.colors.error, size: 48),
                      const SizedBox(height: 16),
                      SelectableText(
                        _error ?? (statsAsync.hasError ? statsAsync.error.toString() : null) ?? 'Failed to load trip history',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: context.colors.error, fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ),
            )

          // 4. Empty State
          else if (_trips.isEmpty)
            const SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.history_rounded,
                      size: 64,
                      color: Color(0xFFD1D5DB),
                    ),
                    SizedBox(height: 16),
                    Text(
                      'No trips found',
                      style: TextStyle(
                        color: Color(0xFF9CA3AF),
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            )

          // 5. Trip List
          else
            SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                if (index == _trips.length) {
                  return _isLoading
                      ? Padding(
                          padding: EdgeInsets.all(32),
                          child: Center(
                            child: CircularProgressIndicator(
                              color: context.colors.primary,
                            ),
                          ),
                        )
                      : const SizedBox(height: 32);
                }
                return _buildTripCard(_trips[index]);
              }, childCount: _trips.length + 1),
            ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid(Map<String, dynamic> stats) {
    final count = stats['count'] as int;
    final income = stats['totalIncome'] as double;
    final distance = stats['totalDistance'] as double;

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.5,
      children: [
        _buildStatCard(
          'Completed Trips',
          count.toString(),
          Icons.check_circle_outline,
          context.colors.liveTeal,
        ),
        _buildStatCard(
          'Total Income',
          '₹${income.toStringAsFixed(0)}',
          Icons.account_balance_wallet_outlined,
          const Color(0xFF16A34A),
        ),
        _buildStatCard(
          'Distance',
          '${(distance / 1000).toStringAsFixed(1)} km',
          Icons.map_outlined,
          const Color(0xFFF59E0B),
        ),
        if (!widget.isToday)
          _buildStatCard(
            'Avg Income/Trip',
            '₹${count > 0 ? (income / count).toStringAsFixed(0) : '0'}',
            Icons.insights_rounded,
            const Color(0xFF8B5CF6),
          ),
      ],
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF6B7280),
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTripCard(Map<String, dynamic> trip) {
    final pickupName = trip['pickup']?['address'] ?? 'Unknown Pickup';
    final dropoffName = trip['destination']?['address'] ?? trip['dropoff']?['address'] ?? 'Unknown Dropoff';
    final fare = (trip['fareEstimate'] as num?)?.toDouble() ?? 0.0;

    DateTime? tripTime;
    if (trip['updatedAt'] is Timestamp) {
      tripTime = (trip['updatedAt'] as Timestamp).toDate();
    } else if (trip['updatedAt'] is String) {
      tripTime = DateTime.tryParse(trip['updatedAt']);
    }

    final timeString = tripTime != null
        ? DateFormat('MMM d, h:mm a').format(tripTime)
        : 'Unknown Time';

    // Using 80% of fare estimate for Captain's net income calculation
    final netIncome = fare * 0.8;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 3)),
        ],
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFFF9FAFB),
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  timeString,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF4B5563),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF16A34A).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Text(
                    'COMPLETED',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF16A34A),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Route
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.circle,
                      size: 12,
                      color: context.colors.rapidoYellow,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        pickupName,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                Container(
                  margin: const EdgeInsets.only(left: 5, top: 4, bottom: 4),
                  height: 20,
                  width: 2,
                  color: const Color(0xFFE5E7EB),
                ),
                Row(
                  children: [
                    Icon(
                      Icons.location_on,
                      size: 14,
                      color: context.colors.error,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        dropoffName,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: Color(0xFFF3F4F6)),

          // Footer
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Net Income',
                      style: TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
                    ),
                    Text(
                      '₹${netIncome.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: context.colors.primary,
                      ),
                    ),
                  ],
                ),
                TextButton(
                  onPressed: () => _showTripDetails(trip),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    backgroundColor: const Color(0xFFF3F4F6),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    'View Details',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: context.colors.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showTripDetails(Map<String, dynamic> trip) {
    final fare = (trip['fareEstimate'] as num?)?.toDouble() ?? 0.0;
    final netIncome = fare * 0.8;
    final commission = fare * 0.2;
    final pickupName = trip['pickup']?['address'] ?? 'Unknown Pickup';
    final dropoffName = trip['destination']?['address'] ?? trip['dropoff']?['address'] ?? 'Unknown Dropoff';
    final distM = trip['distanceMeters'] as int?;
    final distanceStr = distM != null ? '${(distM / 1000).toStringAsFixed(1)} km' : 'Unknown Distance';
    final status = trip['status'] as String? ?? 'unknown';

    DateTime? tripTime;
    if (trip['updatedAt'] is Timestamp) {
      tripTime = (trip['updatedAt'] as Timestamp).toDate();
    } else if (trip['updatedAt'] is String) {
      tripTime = DateTime.tryParse(trip['updatedAt']);
    }
    final timeString = tripTime != null ? DateFormat('MMM d, yyyy • h:mm a').format(tripTime) : 'Unknown Time';
    final riderName = trip['riderName'] ?? 'Rider';

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(24, 16, 24, MediaQuery.of(context).padding.bottom + 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Trip Details',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: context.colors.primary,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: status == 'completed' ? const Color(0xFF10B981).withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        status.toUpperCase(),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: status == 'completed' ? const Color(0xFF10B981) : Colors.grey.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  timeString,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF6B7280),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Divider(height: 32, color: Color(0xFFF3F4F6)),
                
                // Route
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                      children: [
                        const SizedBox(height: 4),
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: context.colors.rapidoYellow,
                            shape: BoxShape.circle,
                          ),
                        ),
                        Container(
                          width: 2,
                          height: 30,
                          color: const Color(0xFFE5E7EB),
                        ),
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: context.colors.error,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            pickupName,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: context.colors.primary,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            dropoffName,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: context.colors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Divider(height: 32, color: Color(0xFFF3F4F6)),
                
                // Earnings Breakdown
                Text(
                  'Earnings Breakdown',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: context.colors.primary,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Customer Fare', style: TextStyle(color: Color(0xFF6B7280), fontWeight: FontWeight.w500)),
                    Text('₹${fare.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Platform Fee (20%)', style: TextStyle(color: context.colors.error, fontWeight: FontWeight.w500)),
                    Text('-₹${commission.toStringAsFixed(0)}', style: TextStyle(color: context.colors.error, fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Net Income', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: context.colors.primary)),
                    Text('₹${netIncome.toStringAsFixed(0)}', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: context.colors.primary)),
                  ],
                ),
                const Divider(height: 32, color: Color(0xFFF3F4F6)),
                
                // Additional Info
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Distance', style: TextStyle(color: Color(0xFF6B7280), fontWeight: FontWeight.w500)),
                    Text(distanceStr, style: TextStyle(fontWeight: FontWeight.w700, color: context.colors.primary)),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Rider', style: TextStyle(color: Color(0xFF6B7280), fontWeight: FontWeight.w500)),
                    Text(riderName, style: TextStyle(fontWeight: FontWeight.w700, color: context.colors.primary)),
                  ],
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => context.pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: context.colors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text('Close', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
