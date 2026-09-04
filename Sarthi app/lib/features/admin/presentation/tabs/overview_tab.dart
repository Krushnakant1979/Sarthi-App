import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../admin_providers.dart';
import '../admin_design.dart';
import '../admin_dashboard_screen.dart';
import '../widgets/admin_common_widgets.dart';
import 'package:google_fonts/google_fonts.dart';

class OverviewTab extends ConsumerStatefulWidget {
  const OverviewTab({super.key});

  @override
  ConsumerState<OverviewTab> createState() => _OverviewTabState();
}

class _OverviewTabState extends ConsumerState<OverviewTab>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  String _chartToggle = 'Rides';
  String _chartFilter = '7 Days';

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _onRefresh() async {
    ref.invalidate(allRidesProvider);
    ref.invalidate(allUsersProvider);
    // Add artificial delay for UX feel
    await Future.delayed(const Duration(milliseconds: 800));
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    String greeting;
    if (hour < 12) {
      greeting = 'Good morning';
    } else if (hour < 17) {
      greeting = 'Good afternoon';
    } else {
      greeting = 'Good evening';
    }

    return '$greeting, Admin';
  }

  @override
  Widget build(BuildContext context) {
    final ridesAsync = ref.watch(allRidesProvider);
    final usersAsync = ref.watch(allUsersProvider);

    if (ridesAsync.isLoading || usersAsync.isLoading) {
      return const _SkeletonDashboard();
    }

    if (ridesAsync.hasError || usersAsync.hasError) {
      return Center(
        child: Text(
          'Error loading data',
          style: GoogleFonts.inter(color: AdminColors.textPrimary),
        ),
      );
    }

    final rideList = ridesAsync.value ?? [];
    final userList = usersAsync.value ?? [];
    final today = DateTime.now();

    final todayRides = rideList
        .where((r) => sameDay(rideDate(r), today))
        .length;
    final active = rideList
        .where((r) => !{'completed', 'cancelled'}.contains(r['status']))
        .length;
    final revenue = rideList
        .where((r) => r['status'] == 'completed')
        .fold<double>(
          0,
          (acc, r) => acc + ((r['fareEstimate'] as num?)?.toDouble() ?? 0),
        );
    final pending = userList
        .where(
          (u) =>
              u.role == 'captain' && u.verificationStatus == 'pending_review',
        )
        .length;

    final List<double> weeklyRevenue = List.filled(7, 0.0);
    for (int i = 0; i < 7; i++) {
      final day = today.subtract(Duration(days: 6 - i));
      final dayRides = rideList.where((r) => sameDay(rideDate(r), day));
      weeklyRevenue[i] = dayRides
          .where((r) => r['status'] == 'completed')
          .fold<double>(
            0,
            (acc, r) => acc + ((r['fareEstimate'] as num?)?.toDouble() ?? 0),
          );
    }

    return RefreshIndicator(
      onRefresh: _onRefresh,
      color: AdminColors.primary,
      backgroundColor: AdminColors.card,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(
          left: 14,
          right: 14,
          top: 10,
          bottom: 120,
        ),
        children: [
          // Header / Snapshot
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _getGreeting(),
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AdminColors.textPrimary,
                        letterSpacing: -0.5,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      DateFormat('EEEE, d MMMM y').format(today),
                      style: GoogleFonts.inter(
                        color: AdminColors.textSecondary,
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AdminColors.success.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AdminColors.success.withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FadeTransition(
                      opacity: _pulseAnimation,
                      child: Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: AdminColors.success,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    SizedBox(width: 4),
                    Text(
                      'Live',
                      style: GoogleFonts.inter(
                        color: AdminColors.success,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 12),

          // Revenue Summary Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AdminColors.primary, Color(0xFF14478B)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: AdminColors.primary.withValues(alpha: 0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Total Revenue',
                      style: GoogleFonts.inter(
                        color: Colors.white70,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.account_balance_wallet_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '₹${revenue.toStringAsFixed(0)}',
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -1,
                          ),
                        ),
                        SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(
                              Icons.trending_up_rounded,
                              color: AdminColors.success,
                              size: 14,
                            ),
                            SizedBox(width: 4),
                            Text(
                              '+5% this week',
                              style: GoogleFonts.inter(
                                color: AdminColors.success,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Expanded(
                      child: Container(
                        height: 50,
                        padding: const EdgeInsets.only(left: 20),
                        child: CustomPaint(
                          painter: _SparklinePainter(
                            data: weeklyRevenue,
                            color: const Color(0xFF60A5FA),
                          ), // Lighter blue for dark bg
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(height: 12),

          // Statistics Grid (2x2)
          LayoutBuilder(
            builder: (context, constraints) {
              final w = constraints.maxWidth;
              final itemWidth = (w - 8) / 2;
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  SizedBox(
                    width: itemWidth,
                    child: MetricCard(
                      label: "Today's Rides",
                      value: '$todayRides',
                      icon: Icons.calendar_today_rounded,
                      color: const Color(0xFF3B82F6),
                      trend: null,
                      onTap: () =>
                          DefaultTabController.of(context).animateTo(1),
                    ),
                  ),
                  SizedBox(
                    width: itemWidth,
                    child: MetricCard(
                      label: 'Active Rides',
                      value: '$active',
                      icon: Icons.moving_rounded,
                      color: AdminColors.accent,
                      trend: null,
                      onTap: () =>
                          DefaultTabController.of(context).animateTo(1),
                    ),
                  ),
                  SizedBox(
                    width: itemWidth,
                    child: MetricCard(
                      label: 'Total Users',
                      value:
                          '${userList.where((u) => u.role == 'user').length}',
                      icon: Icons.people_rounded,
                      color: const Color(0xFF8B5CF6),
                      trend: null,
                      onTap: () {
                        ref.read(usersFilterProvider.notifier).state = 'user';
                        DefaultTabController.of(context).animateTo(2);
                      },
                    ),
                  ),
                  SizedBox(
                    width: itemWidth,
                    child: MetricCard(
                      label: 'Captains',
                      value:
                          '${userList.where((u) => u.role == 'captain').length}',
                      icon: Icons.local_taxi_rounded,
                      color: const Color(0xFF10B981),
                      trend: null,
                      onTap: () {
                        ref.read(usersFilterProvider.notifier).state =
                            'captain';
                        DefaultTabController.of(context).animateTo(2);
                      },
                    ),
                  ),
                ],
              );
            },
          ),
          SizedBox(height: 12),
          GestureDetector(
            onTap: () {
              ref.read(usersFilterProvider.notifier).state = 'pending';
              DefaultTabController.of(context).animateTo(2);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7ED), // very light amber/orange
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.orange,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.shield_rounded,
                      color: Colors.white,
                      size: 12,
                    ),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '$pending captains awaiting verification',
                      style: GoogleFonts.inter(
                        color: Color(0xFF9A3412),
                        fontWeight: FontWeight.w600,
                        fontSize: 9,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: Colors.orange,
                    size: 16,
                  ),
                ],
              ),
            ),
          ),

          SizedBox(height: 12),

          // Weekly Performance Chart Section
          Text(
            'Weekly Performance',
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: AdminColors.textPrimary,
              letterSpacing: -0.3,
            ),
          ),
          SizedBox(height: 8),
          _buildChartSection(rideList),

          SizedBox(height: 12),

          // Quick Actions
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Quick Actions',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AdminColors.textPrimary,
                  letterSpacing: -0.3,
                ),
              ),
              GestureDetector(
                onTap: () => DefaultTabController.of(context).animateTo(3),
                child: Text(
                  'View all',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AdminColors.secondary,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _buildQuickActionCard(
                    icon: Icons.verified_user_rounded,
                    label: 'Verify Captains',
                    color: AdminColors.primary,
                    onTap: () {
                      ref.read(usersFilterProvider.notifier).state = 'pending';
                      DefaultTabController.of(context).animateTo(2);
                    },
                  ),
                ),
                SizedBox(width: 14),
                Expanded(
                  child: _buildQuickActionCard(
                    icon: Icons.near_me_rounded,
                    label: 'Active Rides',
                    color: Colors.orange,
                    onTap: () => DefaultTabController.of(context).animateTo(1),
                  ),
                ),
                SizedBox(width: 14),
                Expanded(
                  child: _buildQuickActionCard(
                    icon: Icons.local_activity_rounded,
                    label: 'Create Offer',
                    color: AdminColors.success,
                    onTap: () {}, // Need route for Create Offer
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: 20),

          // Recent Activity
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent Activity',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AdminColors.textPrimary,
                  letterSpacing: -0.3,
                ),
              ),
              GestureDetector(
                onTap: () => DefaultTabController.of(
                  context,
                ).animateTo(1), // Assuming Rides is default activity view
                child: Text(
                  'View all',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AdminColors.secondary,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          _buildRecentActivityList(rideList, userList),
          SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildChartSection(List<Map<String, dynamic>> rides) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AdminColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AdminColors.border.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                decoration: BoxDecoration(
                  color: AdminColors.background,
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.all(4),
                child: Row(
                  children: [
                    _buildChartToggle('Rides'),
                    _buildChartToggle('Revenue'),
                  ],
                ),
              ),
              DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _chartFilter,
                  icon: const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 14,
                    color: AdminColors.textSecondary,
                  ),
                  style: GoogleFonts.inter(
                    color: AdminColors.textSecondary,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                  onChanged: (v) => setState(() => _chartFilter = v!),
                  items: ['7 Days', '30 Days', '90 Days']
                      .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                      .toList(),
                ),
              ),
            ],
          ),
          SizedBox(height: 30),
          _buildAnimatedLineChart(rides),
        ],
      ),
    );
  }

  Widget _buildChartToggle(String title) {
    final isActive = _chartToggle == title;
    return GestureDetector(
      onTap: () => setState(() => _chartToggle = title),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? AdminColors.secondary : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: isActive
              ? [
                  const BoxShadow(
                    color: AdminColors.secondary,
                    blurRadius: 4,
                    spreadRadius: -2,
                  ),
                ]
              : null,
        ),
        child: Text(
          title,
          style: GoogleFonts.inter(
            color: isActive ? Colors.white : AdminColors.textSecondary,
            fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
            fontSize: 10,
          ),
        ),
      ),
    );
  }

  Widget _buildAnimatedLineChart(List<Map<String, dynamic>> rides) {
    int daysPerPoint = 1;
    int pointsCount = 7;
    if (_chartFilter == '30 Days') {
      daysPerPoint = 5;
      pointsCount = 6;
    } else if (_chartFilter == '90 Days') {
      daysPerPoint = 15;
      pointsCount = 6;
    }

    final today = DateTime.now();
    final List<double> chartData = List.filled(pointsCount, 0.0);
    final List<String> labels = List.filled(pointsCount, '');

    double maxValue = 0;

    for (int i = 0; i < pointsCount; i++) {
      final periodEnd = today.subtract(
        Duration(days: (pointsCount - 1 - i) * daysPerPoint),
      );
      final periodStart = periodEnd.subtract(Duration(days: daysPerPoint - 1));

      if (daysPerPoint == 1) {
        labels[i] = DateFormat('EEE').format(periodEnd);
      } else {
        // Use newline to reduce label width and prevent overlap
        labels[i] =
            '${DateFormat('d').format(periodStart)}-${DateFormat('d').format(periodEnd)}\n${DateFormat('MMM').format(periodEnd)}';
      }

      double periodValue = 0;

      for (int d = 0; d < daysPerPoint; d++) {
        final day = periodStart.add(Duration(days: d));
        final dayRides = rides.where((r) => sameDay(rideDate(r), day));

        if (_chartToggle == 'Rides') {
          periodValue += dayRides.length.toDouble();
        } else {
          periodValue += dayRides
              .where((r) => r['status'] == 'completed')
              .fold<double>(
                0,
                (acc, r) =>
                    acc + ((r['fareEstimate'] as num?)?.toDouble() ?? 0),
              );
        }
      }

      chartData[i] = periodValue;
      if (periodValue > maxValue) maxValue = periodValue;
    }

    return AnimatedLineChart(
      data: chartData,
      labels: labels,
      maxValue: maxValue,
    );
  }

  Widget _buildQuickActionCard({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
        decoration: BoxDecoration(
          color: AdminColors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AdminColors.border.withValues(alpha: 0.5)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                color: AdminColors.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _timeAgo(DateTime? date) {
    if (date == null) return 'Unknown';
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 60) return '${diff.inMinutes} mins ago';
    if (diff.inHours < 24) return '${diff.inHours} hours ago';
    return '${diff.inDays} days ago';
  }

  Widget _buildRecentActivityList(
    List<Map<String, dynamic>> rides,
    List<dynamic> users,
  ) {
    final List<Map<String, dynamic>> activities = [];

    for (final ride in rides) {
      final date = rideDate(ride);
      if (date == null) continue;

      if (ride['status'] == 'completed') {
        activities.add({
          'title': 'Ride Completed',
          'desc': 'A ride was successfully completed.',
          'time': date,
          'icon': Icons.check_circle_rounded,
          'color': AdminColors.success,
        });
      } else if (ride['status'] == 'cancelled') {
        activities.add({
          'title': 'Ride Cancelled',
          'desc': 'A ride was cancelled.',
          'time': date,
          'icon': Icons.cancel_rounded,
          'color': Colors.redAccent,
        });
      } else if (ride['status'] == 'in_progress' ||
          ride['status'] == 'accepted') {
        activities.add({
          'title': 'Active Ride',
          'desc': 'A new ride is currently in progress.',
          'time': date,
          'icon': Icons.moving_rounded,
          'color': AdminColors.accent,
        });
      }
    }

    for (final user in users) {
      final date = user.createdAt;
      if (date == null) continue;

      if (user.role == 'captain') {
        if (user.verificationStatus == 'pending_review') {
          activities.add({
            'title': 'New Captain Registration',
            'desc': '${user.name} submitted documents for verification.',
            'time': date,
            'icon': Icons.assignment_ind_rounded,
            'color': Colors.orange,
          });
        } else {
          activities.add({
            'title': 'New Captain Joined',
            'desc': '${user.name} joined as a captain.',
            'time': date,
            'icon': Icons.local_taxi_rounded,
            'color': AdminColors.primary,
          });
        }
      } else if (user.role == 'user') {
        activities.add({
          'title': 'New User Joined',
          'desc': '${user.name} joined Sarthi.',
          'time': date,
          'icon': Icons.person_add_rounded,
          'color': const Color(0xFF8B5CF6),
        });
      }
    }

    activities.sort(
      (a, b) => (b['time'] as DateTime).compareTo(a['time'] as DateTime),
    );
    final top4 = activities.take(4).toList();

    if (top4.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Text(
            "No recent activity.",
            style: GoogleFonts.inter(color: AdminColors.textSecondary),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: AdminColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AdminColors.border.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: List.generate(top4.length, (index) {
          final act = top4[index];
          final isLast = index == top4.length - 1;
          return _buildTimelineItem(act, isLast, context);
        }),
      ),
    );
  }

  Widget _buildTimelineItem(
    Map<String, dynamic> act,
    bool isLast,
    BuildContext context,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {}, // Add specific route based on activity type if needed
        borderRadius: BorderRadius.circular(16),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(width: 16),
              Column(
                children: [
                  SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: (act['color'] as Color).withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      act['icon'] as IconData,
                      color: act['color'] as Color,
                      size: 16,
                    ),
                  ),
                  if (!isLast)
                    Expanded(
                      child: Container(
                        width: 1.5,
                        color: AdminColors.border.withValues(alpha: 0.5),
                        margin: const EdgeInsets.symmetric(vertical: 4),
                      ),
                    ),
                  if (isLast) SizedBox(height: 20),
                ],
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: 20),
                    Text(
                      act['title'] as String,
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                        color: AdminColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      act['desc'] as String,
                      style: GoogleFonts.inter(
                        color: AdminColors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                    SizedBox(height: 20),
                    const Spacer(),
                    if (!isLast)
                      const Divider(height: 1, color: AdminColors.border),
                  ],
                ),
              ),
              Column(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  SizedBox(height: 22),
                  Row(
                    children: [
                      Text(
                        _timeAgo(act['time'] as DateTime),
                        style: GoogleFonts.inter(
                          color: AdminColors.textSecondary,
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(width: 6),
                      const Icon(
                        Icons.chevron_right_rounded,
                        size: 14,
                        color: AdminColors.textSecondary,
                      ),
                    ],
                  ),
                ],
              ),
              SizedBox(width: 12),
            ],
          ),
        ),
      ),
    );
  }
}

class _SkeletonDashboard extends StatelessWidget {
  const _SkeletonDashboard();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(left: 20, right: 20, top: 24, bottom: 120),
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _shimmerBox(width: 180, height: 28),
                  SizedBox(height: 8),
                  _shimmerBox(width: 120, height: 16),
                ],
              ),
            ),
            _shimmerBox(width: 60, height: 30, radius: 20),
          ],
        ),
        SizedBox(height: 30),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: MediaQuery.of(context).size.width > 900 ? 3 : 2,
          mainAxisSpacing: 14,
          crossAxisSpacing: 14,
          childAspectRatio: 1.5,
          children: List.generate(
            6,
            (i) => _shimmerBox(height: 100, radius: 18),
          ),
        ),
      ],
    );
  }

  Widget _shimmerBox({double? width, double? height, double radius = 8}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AdminColors.border.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

class AnimatedLineChart extends ImplicitlyAnimatedWidget {
  final List<double> data;
  final List<String> labels;
  final double maxValue;

  const AnimatedLineChart({
    super.key,
    required this.data,
    required this.labels,
    required this.maxValue,
    super.duration = const Duration(milliseconds: 500),
  });

  @override
  AnimatedWidgetBaseState<AnimatedLineChart> createState() =>
      _AnimatedLineChartState();
}

class _AnimatedLineChartState
    extends AnimatedWidgetBaseState<AnimatedLineChart> {
  _ListTween? _dataTween;
  Tween<double>? _maxValueTween;

  @override
  void forEachTween(TweenVisitor<dynamic> visitor) {
    _dataTween =
        visitor(
              _dataTween,
              widget.data,
              (dynamic value) => _ListTween(begin: value as List<double>),
            )
            as _ListTween?;
    _maxValueTween =
        visitor(
              _maxValueTween,
              widget.maxValue,
              (dynamic value) => Tween<double>(begin: value as double),
            )
            as Tween<double>?;
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 180,
      width: double.infinity,
      child: CustomPaint(
        painter: _LineChartPainter(
          data: _dataTween?.evaluate(animation) ?? widget.data,
          labels: widget.labels,
          maxValue: _maxValueTween?.evaluate(animation) ?? widget.maxValue,
          lineColor: AdminColors.secondary,
          textColor: AdminColors.textPrimary,
        ),
      ),
    );
  }
}

class _ListTween extends Tween<List<double>> {
  _ListTween({super.begin});

  @override
  List<double> lerp(double t) {
    if (begin == null || end == null || begin!.length != end!.length)
      return end ?? [];
    return List.generate(
      begin!.length,
      (i) => begin![i] + (end![i] - begin![i]) * t,
    );
  }
}

class _LineChartPainter extends CustomPainter {
  final List<double> data;
  final List<String> labels;
  final double maxValue;
  final Color lineColor;
  final Color textColor;

  _LineChartPainter({
    required this.data,
    required this.labels,
    required this.maxValue,
    required this.lineColor,
    required this.textColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final paintLine = Paint()
      ..color = lineColor
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final paintArea = Paint()
      ..shader = LinearGradient(
        colors: [
          lineColor.withValues(alpha: 0.3),
          lineColor.withValues(alpha: 0.0),
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;

    final double stepX = size.width / (data.length - 1);
    final double maxH = size.height - 40;

    final path = Path();
    final areaPath = Path();

    final List<Offset> points = [];

    for (int i = 0; i < data.length; i++) {
      final double x = i * stepX;
      final double normalized = maxValue > 0 ? (data[i] / maxValue) : 0;
      final double y = maxH - (normalized * (maxH - 30));

      points.add(Offset(x, y));

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    if (points.isNotEmpty) {
      areaPath.addPath(path, Offset.zero);
      areaPath.lineTo(size.width, size.height - 30);
      areaPath.lineTo(0, size.height - 30);
      areaPath.close();

      canvas.drawPath(areaPath, paintArea);
      canvas.drawPath(path, paintLine);

      final gridPaint = Paint()
        ..color = AdminColors.border.withValues(alpha: 0.5)
        ..strokeWidth = 1;
      for (int i = 0; i <= 4; i++) {
        double y = 30 + (maxH - 30) * (i / 4);
        canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
      }

      for (int i = 0; i < points.length; i++) {
        final p = points[i];
        canvas.drawCircle(p, 4, Paint()..color = Colors.white);
        canvas.drawCircle(
          p,
          4,
          Paint()
            ..color = lineColor
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );

        final valueStr = data[i] >= 1000
            ? '${(data[i] / 1000).toStringAsFixed(1)}k'
            : data[i].toInt().toString();
        final textSpan = TextSpan(
          text: valueStr,
          style: GoogleFonts.inter(
            color: textColor,
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        );
        final tp = TextPainter(
          text: textSpan,
          textDirection: ui.TextDirection.ltr,
        );
        tp.layout();
        double valueX = (p.dx - tp.width / 2).clamp(0.0, size.width - tp.width);
        tp.paint(canvas, Offset(valueX, p.dy - 20));

        final labelSpan = TextSpan(
          text: labels[i],
          style: GoogleFonts.inter(
            color: AdminColors.textSecondary,
            fontSize: 9,
            fontWeight: FontWeight.w600,
            height: 1.1,
          ),
        );
        final labelTp = TextPainter(
          text: labelSpan,
          textDirection: ui.TextDirection.ltr,
          textAlign: TextAlign.center,
        );
        labelTp.layout();
        double labelX = (p.dx - labelTp.width / 2).clamp(
          0.0,
          size.width - labelTp.width,
        );

        // Adjust Y offset slightly higher if it's a multiline string so it doesn't get cut off
        double yOffset = labels[i].contains('\n') ? 26 : 20;
        labelTp.paint(canvas, Offset(labelX, size.height - yOffset));
      }
    }
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter oldDelegate) {
    return oldDelegate.data != data ||
        oldDelegate.lineColor != lineColor ||
        oldDelegate.maxValue != maxValue;
  }
}

class _SparklinePainter extends CustomPainter {
  final List<double> data;
  final Color color;

  _SparklinePainter({required this.data, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final paintLine = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final paintArea = Paint()
      ..shader = LinearGradient(
        colors: [color.withValues(alpha: 0.3), color.withValues(alpha: 0.0)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;

    double maxVal = 0;
    for (var v in data) {
      if (v > maxVal) maxVal = v;
    }
    if (maxVal == 0) maxVal = 1;

    final stepX = size.width / (data.length > 1 ? data.length - 1 : 1);
    final maxH = size.height;

    final path = Path();
    final areaPath = Path();
    final points = <Offset>[];

    for (int i = 0; i < data.length; i++) {
      final x = i * stepX;
      final y = maxH - ((data[i] / maxVal) * (maxH - 4));
      points.add(Offset(x, y));
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    if (points.length > 1) {
      areaPath.addPath(path, Offset.zero);
      areaPath.lineTo(size.width, size.height);
      areaPath.lineTo(0, size.height);
      areaPath.close();

      canvas.drawPath(areaPath, paintArea);
      canvas.drawPath(path, paintLine);

      final last = points.last;
      canvas.drawCircle(last, 3, Paint()..color = Colors.white);
      canvas.drawCircle(
        last,
        3,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter oldDelegate) =>
      oldDelegate.data != data;
}
