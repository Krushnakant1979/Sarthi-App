import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../../core/design/tokens.dart';

enum RideFilter { today, last30Days }
enum RideStatusFilter { all, completed, cancelled }

final rideFilterProvider = StateProvider<RideFilter>((ref) => RideFilter.today);
final rideStatusFilterProvider = StateProvider<RideStatusFilter>((ref) => RideStatusFilter.all);

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

class PaginatedRideHistoryNotifier extends StateNotifier<PaginatedRideHistoryState> {
  final Ref ref;
  DocumentSnapshot? _lastDoc;
  int _fetchId = 0;

  PaginatedRideHistoryNotifier(this.ref) : super(PaginatedRideHistoryState(rides: [])) {
    ref.listen(rideFilterProvider, (previous, next) {
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
      DateTime startDate;
      final now = DateTime.now();
      if (filter == RideFilter.today) {
        startDate = DateTime(now.year, now.month, now.day);
      } else {
        startDate = now.subtract(const Duration(days: 30));
      }

      Query query = FirebaseFirestore.instance
          .collection('ride_requests')
          .where('userId', isEqualTo: uid)
          .where('createdAt', isGreaterThanOrEqualTo: startDate)
          .orderBy('createdAt', descending: true)
          .limit(50); // fetch more to account for filtered-out statuses

      if (_lastDoc != null) {
        query = query.startAfterDocument(_lastDoc!);
      }

      final snapshot = await query.get();
      
      if (currentFetchId != _fetchId) return;

      if (snapshot.docs.isNotEmpty) {
        _lastDoc = snapshot.docs.last;

        // Filter client-side: always store all completed+cancelled rides
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

final paginatedRideHistoryProvider = StateNotifierProvider<
    PaginatedRideHistoryNotifier, PaginatedRideHistoryState>((ref) {
  return PaginatedRideHistoryNotifier(ref);
});

class RideHistoryScreen extends ConsumerStatefulWidget {
  final VoidCallback? onBack;
  const RideHistoryScreen({super.key, this.onBack});

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

    // Apply status filter purely in the UI — no re-fetch needed
    final displayedRides = historyState.rides.where((ride) {
      final status = ride['status'] as String? ?? '';
      if (activeStatusFilter == RideStatusFilter.completed) return status == 'completed';
      if (activeStatusFilter == RideStatusFilter.cancelled) return status == 'cancelled';
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: context.colors.background,
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          SliverAppBar(
            centerTitle: true,
            backgroundColor: context.colors.background,
            foregroundColor: const Color(0xFF111827),
            leading: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: Color(0xFF111827)),
                  onPressed: () {
                    if (Navigator.canPop(context)) {
                      Navigator.pop(context);
                    } else if (widget.onBack != null) {
                      widget.onBack!();
                    }
                  },
                ),
              ),
            ),
            title: const Text(
              'My Trips',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18, color: Color(0xFF111827)),
            ),
            elevation: 0,
            floating: false,
            pinned: false,
          ),
          SliverToBoxAdapter(
            child: Column(
              children: [
                // Date Filter Row
                Container(
                  color: context.colors.background,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => ref.read(rideFilterProvider.notifier).state = RideFilter.today,
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: activeFilter == RideFilter.today ? const Color(0xFF0F172A) : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                'Today',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: activeFilter == RideFilter.today ? FontWeight.w600 : FontWeight.w500,
                                  color: activeFilter == RideFilter.today ? Colors.white : const Color(0xFF6B7280),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => ref.read(rideFilterProvider.notifier).state = RideFilter.last30Days,
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: activeFilter == RideFilter.last30Days ? const Color(0xFF0F172A) : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                'Last 30 Days',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: activeFilter == RideFilter.last30Days ? FontWeight.w600 : FontWeight.w500,
                                  color: activeFilter == RideFilter.last30Days ? Colors.white : const Color(0xFF6B7280),
                                ),
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
          // List View
          if (historyState.rides.isEmpty)
            if (historyState.isLoading)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator()),
              )
            else if (historyState.error != null)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.error_outline, color: context.colors.error, size: 48),
                      const SizedBox(height: 12),
                      Text(
                        'Could not load rides:\n${historyState.error}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Color(0xFF6B7280)),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => ref.read(paginatedRideHistoryProvider.notifier).refresh(),
                        child: const Text('Retry'),
                      )
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
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    if (index == displayedRides.length) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    return _RideCard(ride: displayedRides[index]);
                  },
                  childCount: displayedRides.length + (historyState.isLoading && historyState.hasMore ? 1 : 0),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: context.colors.background,
              shape: BoxShape.circle,
              border: Border.all(color: context.colors.cardBorder, width: 1.5),
            ),
            child: Icon(
              Icons.route_rounded,
              color: context.colors.hint,
              size: 36,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'No rides yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your completed rides will appear here.',
            style: TextStyle(color: context.colors.textMuted, fontSize: 14),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}


class _StatusChipFilter extends StatelessWidget {
  final String label;
  final bool isSelected;
  final Color color;
  final VoidCallback onTap;

  const _StatusChipFilter({
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.color = const Color(0xFF6B7280),
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.12) : Colors.transparent,
          border: Border.all(
            color: isSelected ? color : context.colors.cardBorder,
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(50),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? color : context.colors.textMuted,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

class _RideCard extends StatelessWidget {
  final Map<String, dynamic> ride;
  const _RideCard({required this.ride});

  @override
  Widget build(BuildContext context) {
    final status = ride['status'] as String? ?? 'unknown';
    final fare = ride['fareEstimate'];
    final dest = ride['destination']?['address'] ?? 'Unknown destination';
    final distM = ride['distanceMeters'] as int?;
    final createdAt = ride['createdAt'];
    final captainId = ride['assignedCaptainId'] as String?;
    final paymentMethod = ride['paymentMethod'] ?? 'Cash';

    final pickup = ride['pickup'] as Map<String, dynamic>?;
    final pickupText = pickup != null ? (pickup['address'] as String? ?? 'Your Location') : 'Unknown pickup';

    String formattedDate = '';
    if (createdAt is Timestamp) {
      formattedDate = DateFormat('MMM d, h:mm a').format(createdAt.toDate());
    }

    final (statusColor, statusLabel, statusIcon) = _statusMeta(context, status);
    final bool isCancelled = status == 'cancelled';

    // Calculate approximate duration (assume 20 km/h or 3 mins per km)
    String durationText = '—';
    if (distM != null) {
      final mins = (distM / 1000 * 3).round();
      durationText = '$mins mins';
    }

    return InkWell(
      onTap: () => _showRideDetail(
        context,
        ride,
        formattedDate,
        statusColor,
        statusLabel,
        statusIcon,
        pickupText,
        dest,
        fare,
        distM,
        durationText,
        paymentMethod,
      ),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: isCancelled ? const Color(0xFFF9FAFB) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Color(0x14000000),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
          border: isCancelled ? Border.all(color: Colors.grey.shade200) : null,
        ),
        child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date & Status Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  formattedDate,
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF4B5563),
                    fontSize: 13,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    statusLabel.toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: statusColor,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Route (Pickup -> Destination)
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Column(
                    children: [
                      const SizedBox(height: 4),
                      const Icon(Icons.circle, color: Colors.amber, size: 10),
                      Expanded(
                        child: Container(
                          width: 1,
                          color: Colors.grey.shade300,
                        ),
                      ),
                      const Icon(Icons.location_on, color: Colors.red, size: 12),
                      const SizedBox(height: 4),
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
                            fontSize: 13,
                            color: Color(0xFF4B5563),
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          dest,
                          style: const TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: 13,
                            color: Color(0xFF4B5563),
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

            const SizedBox(height: 16),
            const Divider(height: 1, color: Color(0xFFF3F4F6)),
            const SizedBox(height: 12),

            // Footer (Fare and View Details)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Net Income', style: TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
                    const SizedBox(height: 2),
                    Text(
                      fare != null ? '₹$fare' : '₹0',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF111827),
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Text(
                    'View Details',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF111827),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      ),
    );
  }

  Widget _metricChip(IconData icon, String value, String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
            Text(
              label,
              style: const TextStyle(fontSize: 10, color: Color(0xFF9CA3AF)),
            ),
          ],
        ),
      ],
    );
  }

  (Color, String, IconData) _statusMeta(BuildContext context, String status) {
    return switch (status) {
      'completed' => (
        const Color(0xFF16A34A),
        'Completed',
        Icons.check_circle_rounded,
      ),
      'cancelled' => (context.colors.error, 'Cancelled', Icons.cancel_rounded),
      'searching' => (context.colors.rapidoYellow, 'Searching', Icons.search_rounded),
      'in_progress' => (
        context.colors.rapidoYellow,
        'In Progress',
        Icons.electric_moped_rounded,
      ),
      'accepted' || 'arriving' || 'arrived' => (
        context.colors.warning,
        'En Route',
        Icons.local_taxi_rounded,
      ),
      _ => (
        const Color(0xFF9CA3AF),
        status.toUpperCase(),
        Icons.help_outline_rounded,
      ),
    };
  }

  void _showRideDetail(
    BuildContext context,
    Map<String, dynamic> ride,
    String formattedDate,
    Color statusColor,
    String statusLabel,
    IconData statusIcon,
    String pickupText,
    String dest,
    dynamic fare,
    int? distM,
    String durationText,
    String paymentMethod,
  ) {
    final vehicleType = ride['vehicleType']?.toString().toUpperCase() ?? 'AUTO';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Handle
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
              
              // Title and Status
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Ride Details',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(statusIcon, color: statusColor, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          statusLabel,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: statusColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                formattedDate,
                style: const TextStyle(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 24),

              // Route details
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    children: [
                      Icon(Icons.circle, color: context.colors.primary, size: 12),
                      Container(width: 2, height: 32, color: Colors.grey.shade300),
                      Icon(Icons.location_on, color: context.colors.error, size: 14),
                    ],
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          pickupText,
                          style: const TextStyle(fontSize: 14, color: Colors.black87, fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          dest,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const Divider(color: Color(0xFFF3F4F6)),
              const SizedBox(height: 16),

              // Trip Info Grid
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _detailItem('Fare', fare != null ? '₹$fare' : '—'),
                  _detailItem('Distance', distM != null ? '${(distM / 1000).toStringAsFixed(1)} km' : '—'),
                  _detailItem('Duration', durationText),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _detailItem('Vehicle', vehicleType),
                  _detailItem('Payment', paymentMethod),
                  _detailItem('Ride ID', (ride['id'] as String?)?.substring(0, 8).toUpperCase() ?? '—'),
                ],
              ),
              
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: context.colors.rapidoYellow,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Close', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _detailItem(String title, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87),
        ),
      ],
    );
  }
}
