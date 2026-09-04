import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui' as ui;

import '../admin_design.dart';
import '../admin_providers.dart';

class AnalyticsScreen extends ConsumerStatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  ConsumerState<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends ConsumerState<AnalyticsScreen> {
  String _selectedTab = 'Analytics';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Analytics & Heatmaps',
              style: GoogleFonts.inter(
                color: context.colors.text,
                fontWeight: FontWeight.w800,
                fontSize: 14,
              ),
            ),
            Text(
              'Revenue, rides and demand insights',
              style: GoogleFonts.inter(
                color: context.colors.textMuted,
                fontWeight: FontWeight.w500,
                fontSize: 10,
              ),
            ),
          ],
        ),
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Container(
            decoration: BoxDecoration(
              color: context.colors.surfaceAlt,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: Icon(
                Icons.arrow_back,
                color: context.colors.primary,
                size: 18,
              ),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.refresh_rounded,
              color: context.colors.text,
              size: 20,
            ),
            onPressed: () {
              HapticFeedback.lightImpact();
              ref.invalidate(filteredRidesProvider);
              ref.invalidate(previousFilteredRidesProvider);
            },
          ),
        ],
        backgroundColor: context.colors.surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildToggle(),
                  const SizedBox(height: 12),
                  if (_selectedTab == 'Analytics') ...[
                    const _RevenuePeriodSelector(),
                    const SizedBox(height: 12),
                    const _RevenueSummaryCard(),
                    const SizedBox(height: 12),
                    const _KpiCards(),
                    const SizedBox(height: 12),
                    const _RevenueTrendChart(),
                    const SizedBox(height: 12),
                    const _RevenueByServiceCard(),
                  ] else ...[
                    const _HeatmapView(),
                  ],
                  const SizedBox(height: 120),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggle() {
    return Container(
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: context.colors.cardBorder.withValues(alpha: 0.5),
        ),
      ),
      padding: const EdgeInsets.all(2),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: () => setState(() => _selectedTab = 'Analytics'),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: _selectedTab == 'Analytics'
                      ? AdminColors.primary.withValues(alpha: 0.85)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.bar_chart_rounded,
                      size: 14,
                      color: _selectedTab == 'Analytics'
                          ? Colors.white
                          : context.colors.text,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Analytics',
                      style: GoogleFonts.inter(
                        color: _selectedTab == 'Analytics'
                            ? Colors.white
                            : context.colors.text,
                        fontWeight: _selectedTab == 'Analytics'
                            ? FontWeight.w700
                            : FontWeight.w600,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: InkWell(
              onTap: () => setState(() => _selectedTab = 'Heatmaps'),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: _selectedTab == 'Heatmaps'
                      ? AdminColors.primary.withValues(alpha: 0.85)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.map_outlined,
                      size: 14,
                      color: _selectedTab == 'Heatmaps'
                          ? Colors.white
                          : context.colors.textMuted,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Heatmaps',
                      style: GoogleFonts.inter(
                        color: _selectedTab == 'Heatmaps'
                            ? Colors.white
                            : context.colors.textMuted,
                        fontWeight: _selectedTab == 'Heatmaps'
                            ? FontWeight.w700
                            : FontWeight.w600,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Period Selector ───────────────────────────────────────────────────────────
class _RevenuePeriodSelector extends ConsumerWidget {
  const _RevenuePeriodSelector();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filterState = ref.watch(analyticsFilterProvider);
    final notifier = ref.read(analyticsFilterProvider.notifier);

    String dateText;
    switch (filterState.period) {
      case RevenuePeriod.day:
        dateText = DateFormat('dd MMM yyyy').format(filterState.selectedDate);
        break;
      case RevenuePeriod.month:
        dateText = DateFormat('MMMM yyyy').format(filterState.selectedDate);
        break;
      case RevenuePeriod.year:
        dateText = DateFormat('yyyy').format(filterState.selectedDate);
        break;
    }

    return Container(
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: context.colors.cardBorder.withValues(alpha: 0.5),
        ),
      ),
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Revenue Period',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: context.colors.text,
                ),
              ),
              Row(
                children: [
                  Container(
                    width: 5,
                    height: 5,
                    decoration: BoxDecoration(
                      color: context.colors.success,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Live • Updated just now',
                    style: GoogleFonts.inter(
                      fontSize: 9,
                      color: context.colors.success,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Day / Month / Year Tabs
          Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: context.colors.background.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: RevenuePeriod.values.map((p) {
                final isSelected = filterState.period == p;
                return Expanded(
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      notifier.setPeriod(p);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AdminColors.primary.withValues(alpha: 0.85)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        p.name.substring(0, 1).toUpperCase() +
                            p.name.substring(1),
                        style: GoogleFonts.inter(
                          color: isSelected
                              ? Colors.white
                              : context.colors.textMuted,
                          fontWeight: isSelected
                              ? FontWeight.w700
                              : FontWeight.w600,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 8),
          // Calendar Selector
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  _shiftDate(notifier, filterState, -1);
                },
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: context.colors.cardBorder),
                  ),
                  child: Icon(
                    Icons.chevron_left_rounded,
                    size: 16,
                    color: context.colors.text,
                  ),
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => _pickDate(context, filterState, notifier),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: context.colors.cardBorder),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.calendar_today_outlined,
                        size: 12,
                        color: context.colors.text,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        dateText,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: context.colors.text,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: _canShiftForward(filterState)
                    ? () {
                        HapticFeedback.lightImpact();
                        _shiftDate(notifier, filterState, 1);
                      }
                    : null,
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: context.colors.cardBorder),
                  ),
                  child: Icon(
                    Icons.chevron_right_rounded,
                    size: 16,
                    color: _canShiftForward(filterState)
                        ? context.colors.text
                        : context.colors.textMuted.withValues(alpha: 0.3),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  notifier.setDate(DateTime.now());
                },
                child: Text(
                  'Today',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF2563EB),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  bool _canShiftForward(AnalyticsFilterState state) {
    final now = DateTime.now();
    switch (state.period) {
      case RevenuePeriod.day:
        return state.selectedDate.isBefore(
          DateTime(now.year, now.month, now.day),
        );
      case RevenuePeriod.month:
        return state.selectedDate.year < now.year ||
            (state.selectedDate.year == now.year &&
                state.selectedDate.month < now.month);
      case RevenuePeriod.year:
        return state.selectedDate.year < now.year;
    }
  }

  void _shiftDate(
    AnalyticsFilterNotifier notifier,
    AnalyticsFilterState state,
    int direction,
  ) {
    final d = state.selectedDate;
    if (state.period == RevenuePeriod.day) {
      notifier.setDate(d.add(Duration(days: direction)));
    } else if (state.period == RevenuePeriod.month) {
      notifier.setDate(DateTime(d.year, d.month + direction));
    } else {
      notifier.setDate(DateTime(d.year + direction));
    }
  }

  Future<void> _pickDate(
    BuildContext context,
    AnalyticsFilterState state,
    AnalyticsFilterNotifier notifier,
  ) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: state.selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(
              primary: AdminColors.primary,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: AdminColors.primary,
            ),
            textTheme: GoogleFonts.interTextTheme(Theme.of(context).textTheme),
            datePickerTheme: DatePickerThemeData(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              headerBackgroundColor: AdminColors.primary,
              headerForegroundColor: Colors.white,
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.transparent,
              dayStyle: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              weekdayStyle: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
              yearStyle: GoogleFonts.inter(fontSize: 14),
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: AdminColors.primary,
                textStyle: GoogleFonts.inter(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
          ),
          child: Transform.scale(scale: 0.85, child: child!),
        );
      },
    );
    if (picked != null) {
      notifier.setDate(picked);
    }
  }
}

// ─── Revenue Summary Card ──────────────────────────────────────────────────────
class _RevenueSummaryCard extends ConsumerWidget {
  const _RevenueSummaryCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ridesAsync = ref.watch(filteredRidesProvider);
    final prevRidesAsync = ref.watch(previousFilteredRidesProvider);

    if (!ridesAsync.hasValue || !prevRidesAsync.hasValue) {
      return const _SkeletonCard(height: 140);
    }

    final data = ref.watch(processedAnalyticsProvider);
    final filterState = ref.watch(analyticsFilterProvider);
    final periodName = filterState.period.name;

    double trend = 0;
    if (data.previousTotalRevenue > 0) {
      trend =
          ((data.totalRevenue - data.previousTotalRevenue) /
              data.previousTotalRevenue) *
          100;
    }

    final isTrendPositive = trend >= 0;
    final trendColor = isTrendPositive
        ? const Color(0xFF4ADE80)
        : const Color(0xFFF87171); // Lighter green/red for dark bg
    final trendIcon = isTrendPositive
        ? Icons.arrow_upward_rounded
        : Icons.arrow_downward_rounded;
    final trendText = data.previousTotalRevenue == 0
        ? 'No previous data'
        : '${isTrendPositive ? '+' : ''}${trend.toStringAsFixed(1)}% vs prev';

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AdminColors.primary, Color(0xFF14478B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AdminColors.primary.withValues(alpha: 0.25),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Background sparkline decoration
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(16),
              ),
              child: CustomPaint(
                size: const Size(double.infinity, 60),
                painter: _SparklinePainter(
                  data: data.chartData,
                  color: Colors.white.withValues(alpha: 0.15),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Revenue for selected $periodName',
                      style: GoogleFonts.inter(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 4,
                            height: 4,
                            decoration: const BoxDecoration(
                              color: Color(0xFF4ADE80),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Real-time',
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 8,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '₹${NumberFormat.compact().format(data.totalRevenue)}',
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -1,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.account_balance_wallet_rounded,
                        color: AdminColors.primary,
                        size: 22,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    if (data.previousTotalRevenue > 0)
                      Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: trendColor.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(trendIcon, color: trendColor, size: 10),
                      ),
                    if (data.previousTotalRevenue > 0) const SizedBox(width: 4),
                    Text(
                      trendText,
                      style: GoogleFonts.inter(
                        color: data.previousTotalRevenue > 0
                            ? trendColor
                            : Colors.white70,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(
                      Icons.calendar_today_outlined,
                      color: Colors.white70,
                      size: 10,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      DateFormat(
                        'dd MMM yyyy',
                      ).format(filterState.selectedDate),
                      style: GoogleFonts.inter(
                        color: Colors.white70,
                        fontSize: 9,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── KPI Cards ─────────────────────────────────────────────────────────────────
class _KpiCards extends ConsumerWidget {
  const _KpiCards();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ridesAsync = ref.watch(filteredRidesProvider);
    final captainsAsync = ref.watch(activeCaptainsCountProvider);

    if (!ridesAsync.hasValue) {
      return Row(
        children: [
          Expanded(child: const _SkeletonCard(height: 80)),
          const SizedBox(width: 10),
          Expanded(child: const _SkeletonCard(height: 80)),
          const SizedBox(width: 10),
          Expanded(child: const _SkeletonCard(height: 80)),
        ],
      );
    }

    final data = ref.watch(processedAnalyticsProvider);

    return Row(
      children: [
        Expanded(
          child: _MiniKpiCard(
            title: 'Total Rides',
            value: data.totalRides.toString(),
            icon: Icons.directions_car_rounded,
            color: AdminColors.primary,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _MiniKpiCard(
            title: 'Avg Fare',
            value: '₹${data.averageFare.toInt()}',
            icon: Icons.receipt_long_rounded,
            color: const Color(0xFF7C3AED),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _MiniKpiCard(
            title: 'Captains',
            value: captainsAsync.value?.toString() ?? '-',
            icon: Icons.people_alt_rounded,
            color: context.colors.warning,
          ),
        ),
      ],
    );
  }
}

class _MiniKpiCard extends StatelessWidget {
  const _MiniKpiCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });
  final String title, value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: context.colors.cardBorder.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, color: color, size: 14),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.inter(
              color: context.colors.text,
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: GoogleFonts.inter(
              color: context.colors.textMuted,
              fontSize: 8,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Trend Chart ───────────────────────────────────────────────────────────────
class _RevenueTrendChart extends ConsumerWidget {
  const _RevenueTrendChart();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ridesAsync = ref.watch(filteredRidesProvider);
    if (!ridesAsync.hasValue) return const _SkeletonCard(height: 200);

    final data = ref.watch(processedAnalyticsProvider);
    final filterState = ref.watch(analyticsFilterProvider);
    final periodName = filterState.period.name;
    final dateStr = DateFormat('dd MMM yyyy').format(filterState.selectedDate);

    // Calc max Y
    double maxY = 0;
    for (var val in data.chartData) {
      if (val > maxY) maxY = val;
    }
    if (maxY == 0) maxY = 100; // default empty scale

    // nice rounding for Y axis
    final magnitude = pow(10, (log(maxY) / ln10).floor());
    maxY = (maxY / magnitude).ceil() * magnitude.toDouble();

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: context.colors.cardBorder.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Revenue Trend',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: context.colors.text,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: context.colors.cardBorder.withValues(alpha: 0.5),
                  ),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    Text(
                      periodName == 'day'
                          ? 'Hourly'
                          : periodName == 'month'
                          ? 'Daily'
                          : 'Monthly',
                      style: GoogleFonts.inter(
                        fontSize: 9,
                        color: context.colors.textMuted,
                      ),
                    ),
                    const SizedBox(width: 2),
                    Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 12,
                      color: context.colors.textMuted,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            '$dateStr • ${periodName == 'day'
                ? 'Hourly'
                : periodName == 'month'
                ? 'Daily'
                : 'Monthly'}',
            style: GoogleFonts.inter(
              fontSize: 9,
              color: context.colors.textMuted,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 20),
          if (data.totalRevenue == 0)
            SizedBox(
              height: 140,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.query_stats,
                      color: context.colors.textMuted.withValues(alpha: 0.3),
                      size: 32,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'No revenue found',
                      style: GoogleFonts.inter(
                        color: context.colors.textMuted,
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'There are no completed and settled\nrides for this period.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        color: context.colors.textMuted,
                        fontSize: 9,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            SizedBox(
              height: 140,
              child: CustomPaint(
                size: const Size(double.infinity, 140),
                painter: _TrendAreaPainter(
                  data: data.chartData,
                  labels: data.chartLabels,
                  maxY: maxY,
                  color: AdminColors.primary,
                  textColor: context.colors.textMuted,
                  gridColor: context.colors.cardBorder.withValues(alpha: 0.5),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Revenue by Service ────────────────────────────────────────────────────────
class _RevenueByServiceCard extends ConsumerWidget {
  const _RevenueByServiceCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ridesAsync = ref.watch(filteredRidesProvider);
    if (!ridesAsync.hasValue) return const _SkeletonCard(height: 110);

    final data = ref.watch(processedAnalyticsProvider);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: context.colors.cardBorder.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Revenue by Service',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: context.colors.text,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _ServiceItem(
                  name: 'Bike',
                  icon: Icons.electric_moped_rounded,
                  revenue: data.serviceRevenue['bike'] ?? 0,
                  total: data.totalRevenue,
                  color: AdminColors.primary,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _ServiceItem(
                  name: 'Auto',
                  icon: Icons.electric_rickshaw_rounded,
                  revenue: data.serviceRevenue['auto'] ?? 0,
                  total: data.totalRevenue,
                  color: context.colors.warning,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _ServiceItem(
                  name: 'Cab',
                  icon: Icons.local_taxi_rounded,
                  revenue: data.serviceRevenue['cab'] ?? 0,
                  total: data.totalRevenue,
                  color: context.colors.success,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ServiceItem extends StatelessWidget {
  const _ServiceItem({
    required this.name,
    required this.icon,
    required this.revenue,
    required this.total,
    required this.color,
  });
  final String name;
  final IconData icon;
  final double revenue;
  final double total;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final pct = total > 0 ? revenue / total : 0.0;
    return Column(
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: context.colors.textMuted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '₹${NumberFormat.compact().format(revenue)}',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: color,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: pct,
            backgroundColor: color.withValues(alpha: 0.1),
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 4,
          ),
        ),
      ],
    );
  }
}

// ─── Heatmaps ──────────────────────────────────────────────────────────────────
class _HeatmapView extends ConsumerWidget {
  const _HeatmapView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ridesAsync = ref.watch(filteredRidesProvider);
    if (!ridesAsync.hasValue) return const _SkeletonCard(height: 300);

    final data = ref.watch(processedAnalyticsProvider);
    final topLocations = data.topLocations;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: context.colors.cardBorder.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                Icons.whatshot_rounded,
                color: context.colors.error,
                size: 16,
              ),
              const SizedBox(width: 6),
              Text(
                'Top Demand Zones (Cities)',
                style: GoogleFonts.inter(
                  color: context.colors.text,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (topLocations.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 30),
              child: Text(
                'No location data for this period.',
                style: GoogleFonts.inter(
                  color: context.colors.textMuted,
                  fontSize: 11,
                ),
                textAlign: TextAlign.center,
              ),
            )
          else
            ...List.generate(topLocations.length, (index) {
              final loc = topLocations[index];
              final isTop = index == 0;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isTop
                      ? context.colors.error.withValues(alpha: 0.06)
                      : context.colors.background,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isTop
                        ? context.colors.error.withValues(alpha: 0.25)
                        : context.colors.cardBorder.withValues(alpha: 0.5),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: isTop
                            ? context.colors.error
                            : context.colors.surfaceAlt,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '#${index + 1}',
                        style: GoogleFonts.inter(
                          color: isTop ? Colors.white : context.colors.text,
                          fontWeight: FontWeight.bold,
                          fontSize: 9,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        loc['name'].toString(),
                        style: GoogleFonts.inter(
                          color: context.colors.text,
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: context.colors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: context.colors.cardBorder.withValues(
                            alpha: 0.5,
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.local_taxi_rounded,
                            size: 10,
                            color: isTop
                                ? context.colors.error
                                : context.colors.textMuted,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            loc['count'].toString(),
                            style: GoogleFonts.inter(
                              color: isTop
                                  ? context.colors.error
                                  : context.colors.text,
                              fontWeight: FontWeight.w800,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}

// ─── Custom Painters ───────────────────────────────────────────────────────────
class _SparklinePainter extends CustomPainter {
  final List<double> data;
  final Color color;

  _SparklinePainter({required this.data, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    double maxVal = 0;
    for (var d in data) {
      if (d > maxVal) maxVal = d;
    }
    if (maxVal == 0) return;

    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    final stepX = size.width / (data.length > 1 ? data.length - 1 : 1);

    for (int i = 0; i < data.length; i++) {
      final x = i * stepX;
      final y =
          size.height - (data[i] / maxVal) * (size.height - 10); // padding top
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    // Add fill
    final fillPath = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        colors: [color.withValues(alpha: 0.3), color.withValues(alpha: 0.0)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, paint);

    // Draw dot on last point
    if (data.isNotEmpty) {
      final lastY = size.height - (data.last / maxVal) * (size.height - 10);
      canvas.drawCircle(
        Offset(size.width, lastY),
        3,
        Paint()..color = Colors.white.withValues(alpha: 0.5),
      );
      canvas.drawCircle(
        Offset(size.width, lastY),
        1.5,
        Paint()..color = Colors.white,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _TrendAreaPainter extends CustomPainter {
  final List<double> data;
  final List<String> labels;
  final double maxY;
  final Color color;
  final Color textColor;
  final Color gridColor;

  _TrendAreaPainter({
    required this.data,
    required this.labels,
    required this.maxY,
    required this.color,
    required this.textColor,
    required this.gridColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    const leftPadding = 26.0;
    const bottomPadding = 18.0;
    final chartWidth = size.width - leftPadding;
    final chartHeight = size.height - bottomPadding;

    // Draw Y axis & grid
    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    final textStyle = GoogleFonts.inter(color: textColor, fontSize: 8);

    final ySteps = 3; // reduced from 4
    for (int i = 0; i <= ySteps; i++) {
      final yVal = (maxY / ySteps) * i;
      final yPos = chartHeight - (chartHeight / ySteps) * i;

      canvas.drawLine(
        Offset(leftPadding, yPos),
        Offset(size.width, yPos),
        gridPaint,
      );

      final textSpan = TextSpan(
        text: '₹${NumberFormat.compact().format(yVal)}',
        style: textStyle,
      );
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: ui.TextDirection.ltr,
      )..layout();
      textPainter.paint(canvas, Offset(0, yPos - 5));
    }

    // Draw Line and Area
    final linePaint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    final stepX = chartWidth / (data.length > 1 ? data.length - 1 : 1);

    // Create bezier curve path
    List<Offset> points = [];
    for (int i = 0; i < data.length; i++) {
      final x = leftPadding + (i * stepX);
      final y = chartHeight - (data[i] / maxY) * chartHeight;
      points.add(Offset(x, y));
    }

    final smoothPath = Path();
    smoothPath.moveTo(points[0].dx, points[0].dy);
    for (int i = 0; i < points.length - 1; i++) {
      final p0 = points[i];
      final p1 = points[i + 1];
      final controlX = p0.dx + (p1.dx - p0.dx) / 2;
      smoothPath.cubicTo(controlX, p0.dy, controlX, p1.dy, p1.dx, p1.dy);
    }

    final fillPath = Path.from(smoothPath)
      ..lineTo(points.last.dx, chartHeight)
      ..lineTo(points.first.dx, chartHeight)
      ..close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        colors: [color.withValues(alpha: 0.2), color.withValues(alpha: 0.0)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(leftPadding, 0, chartWidth, chartHeight));

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(smoothPath, linePaint);

    // Draw dots and labels on X axis
    for (int i = 0; i < data.length; i++) {
      final p = points[i];
      if (data[i] > 0) {
        canvas.drawCircle(p, 3, Paint()..color = Colors.white);
        canvas.drawCircle(p, 1.5, Paint()..color = color);

        // Value label above dot for non-zero points
        final valText = TextSpan(
          text: '₹${NumberFormat.compact().format(data[i])}',
          style: GoogleFonts.inter(
            color: color,
            fontSize: 8,
            fontWeight: FontWeight.w700,
          ),
        );
        final tp = TextPainter(
          text: valText,
          textDirection: ui.TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(p.dx - tp.width / 2, p.dy - 12));
      }

      if (i < labels.length && labels[i].isNotEmpty) {
        final textSpan = TextSpan(text: labels[i], style: textStyle);
        final textPainter = TextPainter(
          text: textSpan,
          textDirection: ui.TextDirection.ltr,
        )..layout();
        textPainter.paint(
          canvas,
          Offset(p.dx - textPainter.width / 2, chartHeight + 4),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _SkeletonCard extends StatelessWidget {
  final double height;
  const _SkeletonCard({required this.height});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: context.colors.surfaceAlt,
        borderRadius: BorderRadius.circular(14),
      ),
    );
  }
}
