import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../admin_providers.dart';
import '../admin_design.dart';
import '../../../shared/auth/domain/app_user.dart';
import '../admin_dashboard_screen.dart';
import 'package:google_fonts/google_fonts.dart';

// ─── Status Helpers ─────────────────────────────────────────────────────────────
Color _statusColor(String status) => switch (status) {
  'completed' => AdminColors.success,
  'cancelled' => AdminColors.error,
  'in_progress' => AdminColors.secondary,
  'accepted' || 'arriving' || 'arrived' => AdminColors.secondary,
  _ => AdminColors.warning,
};

String _statusLabel(String status) => switch (status) {
  'completed' => 'Completed',
  'cancelled' => 'Cancelled',
  'in_progress' => 'In Progress',
  'accepted' => 'Accepted',
  'arriving' => 'Arriving',
  'arrived' => 'Arrived',
  _ => pretty(status),
};

IconData _vehicleIcon(String? type) => switch (type) {
  'bike' => Icons.two_wheeler_rounded,
  'auto' => Icons.airport_shuttle_rounded,
  _ => Icons.local_taxi_rounded,
};

// ─── RidesTab ──────────────────────────────────────────────────────────────────
class RidesTab extends ConsumerStatefulWidget {
  const RidesTab({super.key});
  @override
  ConsumerState<RidesTab> createState() => RidesTabState();
}

class RidesTabState extends ConsumerState<RidesTab> {
  RideRange range = RideRange.today;
  String status = 'all';
  String search = '';
  String sort = 'newest';
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(allRidesProvider);

    if (async.isLoading) return const _RidesSkeletonLoader();
    if (async.hasError) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                size: 48,
                color: AdminColors.error,
              ),
              SizedBox(height: 12),
              Text(
                'Failed to load rides',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: AdminColors.textPrimary,
                ),
              ),
              SizedBox(height: 6),
              Text(
                async.error.toString(),
                style: GoogleFonts.inter(
                  color: AdminColors.textSecondary,
                  fontSize: 11,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => ref.invalidate(allRidesProvider),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AdminColors.primary,
                ),
                child: Text(
                  'Retry',
                  style: GoogleFonts.inter(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final now = DateTime.now();
    final allRides = async.value ?? [];

    // Filtered by date and search to calculate status counts
    final filteredByDateAndSearch = allRides.where((ride) {
      final date = rideDate(ride);
      final inRange = switch (range) {
        RideRange.today => sameDay(date, now),
        RideRange.last30Days =>
          date != null && date.isAfter(now.subtract(const Duration(days: 30))),
        RideRange.all => true,
      };
      final q = search.toLowerCase();
      final haystack = [
        ride['id'],
        ride['pickup']?['address'],
        ride['destination']?['address'],
        ride['userId'],
        ride['assignedCaptainId'],
        ride['passengerName'],
        ride['captainName'],
      ].map((e) => e?.toString() ?? '').join(' ').toLowerCase();
      return inRange && haystack.contains(q);
    }).toList();

    // Final filtered list based on selected status
    final rides = filteredByDateAndSearch.where((ride) {
      if (status == 'all') return true;
      if (status == 'active')
        return !{'completed', 'cancelled'}.contains(ride['status']);
      return ride['status'] == status;
    }).toList();

    // Sorting
    rides.sort((a, b) {
      final da = rideDate(a), db = rideDate(b);
      final fa = (a['fareEstimate'] as num?)?.toDouble() ?? 0;
      final fb = (b['fareEstimate'] as num?)?.toDouble() ?? 0;
      return switch (sort) {
        'oldest' => (da ?? DateTime(0)).compareTo(db ?? DateTime(0)),
        'highest_fare' => fb.compareTo(fa),
        'lowest_fare' => fa.compareTo(fb),
        _ => (db ?? DateTime(0)).compareTo(da ?? DateTime(0)),
      };
    });

    final String rangeLabel = switch (range) {
      RideRange.today => 'Today',
      RideRange.last30Days => 'Last 30 Days',
      RideRange.all => 'All Time',
    };

    return Column(
      children: [
        // ── Filters Card ──────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 16, 10, 0),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AdminColors.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AdminColors.border.withValues(alpha: 0.5),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Date Segmented Control
                _DateSegmentedControl(
                  range: range,
                  onChanged: (r) => setState(() => range = r),
                ),
                SizedBox(height: 18),

                // Search and Advanced Filters
                Row(
                  children: [
                    Expanded(
                      child: _SearchBar(
                        controller: _searchCtrl,
                        onChanged: (v) => setState(() => search = v.trim()),
                        onClear: () {
                          _searchCtrl.clear();
                          setState(() => search = '');
                        },
                      ),
                    ),
                    SizedBox(width: 12),
                    _SortButton(
                      sort: sort,
                      onChanged: (v) => setState(() => sort = v),
                    ),
                  ],
                ),
                SizedBox(height: 18),

                // Status Filters
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _StatusChip(
                      label: 'All',
                      value: 'all',
                      current: status,
                      onTap: (v) => setState(() => status = v),
                    ),
                    _StatusChip(
                      label: 'Completed',
                      value: 'completed',
                      current: status,
                      onTap: (v) => setState(() => status = v),
                    ),
                    _StatusChip(
                      label: 'Cancelled',
                      value: 'cancelled',
                      current: status,
                      onTap: (v) => setState(() => status = v),
                    ),
                    _StatusChip(
                      label: 'Active',
                      value: 'active',
                      current: status,
                      onTap: (v) => setState(() => status = v),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        // ── Results Summary ───────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
          child: Row(
            children: [
              Text(
                '${rides.length} ride${rides.length == 1 ? '' : 's'} found',
                style: GoogleFonts.inter(
                  color: AdminColors.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                rangeLabel,
                style: GoogleFonts.inter(
                  color: AdminColors.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),

        // ── Ride List ──────────────────────────────────────────────────────
        Expanded(
          child: rides.isEmpty
              ? _EmptyRidesState(
                  onClear: () {
                    _searchCtrl.clear();
                    setState(() {
                      search = '';
                      status = 'all';
                      sort = 'newest';
                      range = RideRange.today;
                    });
                  },
                )
              : RefreshIndicator(
                  color: AdminColors.primary,
                  onRefresh: () async => ref.invalidate(allRidesProvider),
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                    itemCount: rides.length,
                    itemBuilder: (_, i) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: RideCard(ride: rides[i]),
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}

// ─── Date Segmented Control ────────────────────────────────────────────────────
class _DateSegmentedControl extends StatelessWidget {
  const _DateSegmentedControl({required this.range, required this.onChanged});
  final RideRange range;
  final ValueChanged<RideRange> onChanged;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(2),
    decoration: BoxDecoration(
      color: AdminColors.background,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: AdminColors.border.withValues(alpha: 0.5)),
    ),
    child: Row(
      children: [
        _Segment(
          label: 'Today',
          selected: range == RideRange.today,
          onTap: () => onChanged(RideRange.today),
        ),
        _Segment(
          label: 'Last 30 Days',
          selected: range == RideRange.last30Days,
          onTap: () => onChanged(RideRange.last30Days),
        ),
        _Segment(
          label: 'All Time',
          selected: range == RideRange.all,
          onTap: () => onChanged(RideRange.all),
        ),
      ],
    ),
  );
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Expanded(
    child: GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AdminColors.secondary : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: AdminColors.secondary.withValues(alpha: 0.3),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 10,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
            color: selected ? Colors.white : AdminColors.textSecondary,
          ),
        ),
      ),
    ),
  );
}

// ─── Status Chip ────────────────────────────────────────────────────────────────
class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.label,
    required this.value,
    required this.current,
    required this.onTap,
  });
  final String label, value, current;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    final sel = current == value;
    final color = switch (value) {
      'completed' => AdminColors.success,
      'cancelled' => AdminColors.error,
      'active' => AdminColors.secondary,
      _ => AdminColors.primary,
    };

    return GestureDetector(
      onTap: () => onTap(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 10,
        ), // Increased
        decoration: BoxDecoration(
          color: sel ? color : color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: sel ? color : color.withValues(alpha: 0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: sel ? FontWeight.w700 : FontWeight.w600,
                color: sel ? Colors.white : color,
              ),
            ), // Increased font size
          ],
        ),
      ),
    );
  }
}

// ─── Search Bar ────────────────────────────────────────────────────────────────
class _SearchBar extends StatelessWidget {
  const _SearchBar({
    required this.controller,
    required this.onChanged,
    required this.onClear,
  });
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) => Container(
    height: 42,
    decoration: BoxDecoration(
      color: AdminColors.background,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: AdminColors.border),
    ),
    child: TextField(
      controller: controller,
      onChanged: onChanged,
      style: GoogleFonts.inter(color: AdminColors.textPrimary, fontSize: 11),
      decoration: InputDecoration(
        hintText: 'Search by ID, location, passenger...',
        hintStyle: GoogleFonts.inter(
          color: AdminColors.textSecondary,
          fontSize: 10,
        ),
        prefixIcon: const Icon(
          Icons.search_rounded,
          color: AdminColors.textSecondary,
          size: 18,
        ),
        suffixIcon: controller.text.isNotEmpty
            ? IconButton(
                icon: const Icon(
                  Icons.close_rounded,
                  color: AdminColors.textSecondary,
                  size: 16,
                ),
                onPressed: onClear,
              )
            : null,
        border: InputBorder.none,
        contentPadding: const EdgeInsets.symmetric(vertical: 10),
      ),
    ),
  );
}

// ─── Sort Button ───────────────────────────────────────────────────────────────
class _SortButton extends StatelessWidget {
  const _SortButton({required this.sort, required this.onChanged});
  final String sort;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => PopupMenuButton<String>(
    onSelected: onChanged,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    color: AdminColors.card,
    offset: const Offset(0, 40),
    child: Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AdminColors.border),
      ),
      child: const Icon(
        Icons.tune_rounded,
        size: 18,
        color: AdminColors.textSecondary,
      ),
    ),
    itemBuilder: (_) => [
      _sortItem('newest', 'Newest First', sort),
      _sortItem('oldest', 'Oldest First', sort),
      _sortItem('highest_fare', 'Highest Fare', sort),
      _sortItem('lowest_fare', 'Lowest Fare', sort),
    ],
  );

  PopupMenuItem<String> _sortItem(String v, String label, String current) =>
      PopupMenuItem(
        value: v,
        child: Row(
          children: [
            Icon(
              v == current ? Icons.check_rounded : Icons.circle_outlined,
              size: 16,
              color: v == current ? AdminColors.primary : Colors.transparent,
            ),
            SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.inter(
                fontWeight: v == current ? FontWeight.w700 : FontWeight.w500,
                color: AdminColors.textPrimary,
                fontSize: 12,
              ),
            ),
          ],
        ),
      );
}

// ─── Ride Card ─────────────────────────────────────────────────────────────────
class RideCard extends StatelessWidget {
  const RideCard({super.key, required this.ride});
  final Map<String, dynamic> ride;

  @override
  Widget build(BuildContext context) {
    final status = ride['status'] as String? ?? 'unknown';
    final color = _statusColor(status);
    final date = rideDate(ride);
    final fare = ride['fareEstimate'] ?? 0;
    final pickup = ride['pickup']?['address']?.toString() ?? 'Pickup unknown';
    final drop =
        ride['destination']?['address']?.toString() ?? 'Destination unknown';
    final vehicleType = ride['vehicleType'] as String?;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: AdminColors.card,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () {
            HapticFeedback.lightImpact();
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (_) => RideDetails(ride: ride),
            );
          },
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AdminColors.border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top row: vehicle type + status badge + fare
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: color.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Icon(
                          _vehicleIcon(vehicleType),
                          color: color,
                          size: 14,
                        ),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              vehicleType != null
                                  ? pretty(vehicleType)
                                  : 'Ride',
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: AdminColors.textPrimary,
                              ),
                            ),
                            if (date != null)
                              Text(
                                DateFormat('d MMM, hh:mm a').format(date),
                                style: GoogleFonts.inter(
                                  fontSize: 8,
                                  color: AdminColors.textSecondary,
                                ),
                              ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '₹$fare',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              color: AdminColors.textPrimary,
                              letterSpacing: -0.5,
                            ),
                          ),
                          SizedBox(height: 2),
                          _StatusBadge(status: status),
                        ],
                      ),
                    ],
                  ),
                  SizedBox(height: 10),
                  const Divider(height: 1, color: AdminColors.border),
                  SizedBox(height: 10),

                  // Route section
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Route line
                      Column(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: AdminColors.primary,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AdminColors.card,
                                width: 1.5,
                              ),
                            ),
                          ),
                          Container(
                            width: 2,
                            height: 18,
                            color: AdminColors.border,
                          ),
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: AdminColors.error,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AdminColors.card,
                                width: 1.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              pickup,
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: AdminColors.textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            SizedBox(height: 12),
                            Text(
                              drop,
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: AdminColors.textSecondary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: AdminColors.textSecondary,
                        size: 16,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Status Badge ──────────────────────────────────────────────────────────────
class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        _statusLabel(status),
        style: GoogleFonts.inter(
          fontSize: 9,
          fontWeight: FontWeight.w800,
          color: color,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

// ─── Ride Details Bottom Sheet ─────────────────────────────────────────────────
class RideDetails extends StatelessWidget {
  const RideDetails({super.key, required this.ride});
  final Map<String, dynamic> ride;

  @override
  Widget build(BuildContext context) {
    final date = rideDate(ride);
    final status = ride['status'] as String? ?? 'unknown';
    final color = _statusColor(status);
    final fare = ride['fareEstimate'] ?? 0;
    final pickup = ride['pickup']?['address']?.toString() ?? 'Unknown pickup';
    final drop =
        ride['destination']?['address']?.toString() ?? 'Unknown destination';
    final rideId = ride['id']?.toString() ?? '---';

    return Container(
      decoration: const BoxDecoration(
        color: AdminColors.card,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.92,
        minChildSize: 0.5,
        maxChildSize: 0.92, // Leave space for status bar
        builder: (_, controller) => SafeArea(
          bottom: false,
          child: Column(
            children: [
              // Handle bar
              SizedBox(height: 12),
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AdminColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              SizedBox(height: 16),

              // Header
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                ), // Decreased
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8), // Decreased
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ), // Decreased radius
                      child: Icon(
                        _vehicleIcon(ride['vehicleType'] as String?),
                        color: color,
                        size: 18,
                      ), // Decreased
                    ),
                    SizedBox(width: 10), // Decreased
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Ride Details',
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              color: AdminColors.textPrimary,
                            ),
                          ), // Decreased
                          Text(
                            'ID: ${AppUser.shortId(rideId)}',
                            style: GoogleFonts.inter(
                              fontSize: 9,
                              color: AdminColors.textSecondary,
                            ),
                          ), // Decreased
                        ],
                      ),
                    ),
                    _StatusBadge(status: status),
                    SizedBox(width: 8),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(
                        Icons.close_rounded,
                        color: AdminColors.textSecondary,
                        size: 18,
                      ),
                      style: IconButton.styleFrom(
                        backgroundColor: AdminColors.background,
                        shape: const CircleBorder(),
                      ),
                    ), // Decreased
                  ],
                ),
              ),
              SizedBox(height: 16),
              const Divider(height: 1, color: AdminColors.border),

              Expanded(
                child: ListView(
                  controller: controller,
                  padding: const EdgeInsets.all(20), // Decreased
                  children: [
                    // Fare highlight
                    Container(
                      padding: const EdgeInsets.all(16), // Decreased
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AdminColors.primary,
                            AdminColors.primary.withValues(alpha: 0.85),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16), // Decreased
                      ),
                      child: Row(
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Total Fare',
                                style: GoogleFonts.inter(
                                  color: Colors.white70,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '₹$fare',
                                style: GoogleFonts.inter(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -1,
                                ),
                              ),
                            ],
                          ),
                          const Spacer(),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  ride['paymentMethod']?.toString() ?? 'Cash',
                                  style: GoogleFonts.inter(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ), // Decreased
                              SizedBox(height: 6),
                              if (date != null)
                                Text(
                                  DateFormat('d MMM y').format(date),
                                  style: GoogleFonts.inter(
                                    color: Colors.white60,
                                    fontSize: 9,
                                  ),
                                ), // Decreased
                            ],
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 20),

                    // Route card
                    _DetailCard(
                      title: 'Route',
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Column(
                              children: [
                                Container(
                                  width: 12,
                                  height: 12,
                                  decoration: const BoxDecoration(
                                    color: AdminColors.primary,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                Container(
                                  width: 2,
                                  height: 40,
                                  color: AdminColors.border,
                                ),
                                Container(
                                  width: 12,
                                  height: 12,
                                  decoration: const BoxDecoration(
                                    color: AdminColors.error,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    pickup,
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: AdminColors.textPrimary,
                                    ),
                                  ), // Decreased
                                  SizedBox(height: 20), // Decreased
                                  Text(
                                    drop,
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: AdminColors.textSecondary,
                                    ),
                                  ), // Decreased
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    SizedBox(height: 14),

                    // Ride info
                    _DetailCard(
                      title: 'Ride Info',
                      children: [
                        _InfoRow(
                          icon: Icons.schedule_rounded,
                          label: 'Created',
                          value: date == null
                              ? 'Unknown'
                              : DateFormat('d MMM y, hh:mm a').format(date),
                        ),
                        _InfoRow(
                          icon: Icons.two_wheeler_rounded,
                          label: 'Vehicle',
                          value: pretty(
                            ride['vehicleType']?.toString() ?? 'Unknown',
                          ),
                        ),
                        if (ride['cancelReason'] != null &&
                            ride['cancelReason'].toString().isNotEmpty)
                          _InfoRow(
                            icon: Icons.cancel_outlined,
                            label: 'Cancel Reason',
                            value: ride['cancelReason'].toString(),
                          ),
                      ],
                    ),
                    SizedBox(height: 14),

                    // Participant info (using public IDs, no raw UID)
                    _DetailCard(
                      title: 'Participants',
                      children: [
                        _InfoRow(
                          icon: Icons.person_rounded,
                          label: 'Passenger',
                          value:
                              ride['passengerName']?.toString() ??
                              (ride['userId'] != null
                                  ? AppUser.shortId(ride['userId'].toString())
                                  : '---'),
                        ),
                        _InfoRow(
                          icon: Icons.local_taxi_rounded,
                          label: 'Captain',
                          value:
                              ride['captainName']?.toString() ??
                              (ride['assignedCaptainId'] != null
                                  ? 'ID: ${AppUser.shortId(ride['assignedCaptainId'].toString())}'
                                  : 'Not assigned'),
                        ),
                      ],
                    ),
                    SizedBox(height: 20),

                    // CTA
                    SizedBox(
                      width: double.infinity,
                      height: 46, // Decreased
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Map tracking and route replay is coming soon.',
                              ),
                            ),
                          );
                        },
                        icon: const Icon(
                          Icons.map_rounded,
                          color: AdminColors.primary,
                          size: 18,
                        ), // Decreased
                        label: Text(
                          'Track on Map',
                          style: GoogleFonts.inter(
                            color: AdminColors.primary,
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        ), // Decreased
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AdminColors.accent,
                          foregroundColor: AdminColors.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ), // Decreased radius
                      ),
                    ),
                    SizedBox(height: 12),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Detail Card ───────────────────────────────────────────────────────────────
class _DetailCard extends StatelessWidget {
  const _DetailCard({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: AdminColors.background,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AdminColors.border),
    ), // Decreased
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 6), // Decreased
          child: Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              color: AdminColors.textSecondary,
              letterSpacing: 0.5,
            ),
          ), // Decreased
        ),
        ...children.map(
          (c) => Column(
            children: [
              const Divider(
                height: 1,
                color: AdminColors.border,
                indent: 14,
                endIndent: 14,
              ),
              c,
            ],
          ),
        ), // Decreased
      ],
    ),
  );
}

// ─── Info Row ──────────────────────────────────────────────────────────────────
class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label, value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(
      vertical: 10,
      horizontal: 14,
    ), // Decreased
    child: Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: AdminColors.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 12, color: AdminColors.primary),
        ), // Decreased
        SizedBox(width: 10), // Decreased
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 8,
                  color: AdminColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ), // Decreased
              SizedBox(height: 2),
              Text(
                value,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AdminColors.textPrimary,
                ),
              ), // Decreased
            ],
          ),
        ),
      ],
    ),
  );
}

// ─── Empty State ───────────────────────────────────────────────────────────────
class _EmptyRidesState extends StatelessWidget {
  const _EmptyRidesState({required this.onClear});
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.fromLTRB(40, 16, 40, 24),
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      decoration: BoxDecoration(
        color: AdminColors.card,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AdminColors.primary.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(color: AdminColors.border.withValues(alpha: 0.6)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Impressive visual element
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AdminColors.primary.withValues(alpha: 0.04),
                ),
              ),
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AdminColors.primary.withValues(alpha: 0.08),
                ),
              ),
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [AdminColors.primary, const Color(0xFF8B5CF6)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AdminColors.primary.withValues(alpha: 0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.search_off_rounded,
                  color: Colors.white,
                  size: 26,
                ),
              ),
              // Floating decorative icons
              Positioned(
                top: 5,
                left: 15,
                child: Icon(
                  Icons.local_taxi_rounded,
                  color: AdminColors.primary.withValues(alpha: 0.4),
                  size: 18,
                ),
              ),
              Positioned(
                bottom: 10,
                right: 10,
                child: Icon(
                  Icons.location_on_rounded,
                  color: const Color(0xFF8B5CF6).withValues(alpha: 0.4),
                  size: 22,
                ),
              ),
              Positioned(
                top: 20,
                right: 15,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AdminColors.warning,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          Text(
            'No Rides Found',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: AdminColors.textPrimary,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'We couldn\'t find any rides matching your filters.\nTry adjusting your search or date range.',
            style: GoogleFonts.inter(
              color: AdminColors.textSecondary,
              fontSize: 12,
              height: 1.5,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 28),
          InkWell(
            onTap: onClear,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AdminColors.primary.withValues(alpha: 0.2),
                ),
                color: AdminColors.primary.withValues(alpha: 0.08),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.refresh_rounded,
                    size: 16,
                    color: AdminColors.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Clear All Filters',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AdminColors.primary,
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
}

// ─── Skeleton Loader ───────────────────────────────────────────────────────────
class _RidesSkeletonLoader extends StatelessWidget {
  const _RidesSkeletonLoader();

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(16),
    children: List.generate(5, (_) => _SkeletonCard()),
  );
}

class _SkeletonCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AdminColors.card,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: AdminColors.border),
    ),
    child: Column(
      children: [
        Row(
          children: [
            _bone(44, 44, radius: 12),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [_bone(100, 14), SizedBox(height: 6), _bone(70, 11)],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _bone(50, 20),
                SizedBox(height: 4),
                _bone(60, 18, radius: 20),
              ],
            ),
          ],
        ),
        SizedBox(height: 12),
        _bone(double.infinity, 1),
        SizedBox(height: 12),
        Row(
          children: [
            SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _bone(180, 13),
                  SizedBox(height: 28),
                  _bone(140, 13),
                ],
              ),
            ),
          ],
        ),
      ],
    ),
  );

  static Widget _bone(double w, double h, {double radius = 8}) => Container(
    width: w,
    height: h,
    decoration: BoxDecoration(
      color: const Color(0xFFE8EDF3),
      borderRadius: BorderRadius.circular(radius),
    ),
  );
}
