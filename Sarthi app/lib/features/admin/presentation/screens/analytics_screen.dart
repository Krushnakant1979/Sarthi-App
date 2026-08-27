import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../admin_design.dart';
import '../admin_providers.dart';
import '../widgets/admin_common_widgets.dart';

class AnalyticsScreen extends ConsumerStatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  ConsumerState<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends ConsumerState<AnalyticsScreen> {
  String _selectedTab = 'Analytics';

  @override
  Widget build(BuildContext context) {
    final analyticsAsync = ref.watch(analyticsProvider);

    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        title: Text('Analytics & Heatmaps', style: TextStyle(color: context.colors.text, fontWeight: FontWeight.w800, fontSize: 16)),
        backgroundColor: context.colors.surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        iconTheme: IconThemeData(color: context.colors.text),
      ),
      body: AsyncPage(
        loading: analyticsAsync.isLoading,
        error: analyticsAsync.error,
        child: Builder(builder: (_) {
          final data = analyticsAsync.value;
          if (data == null) return const SizedBox.shrink();

          return RefreshIndicator(
            onRefresh: () async => ref.refresh(analyticsProvider.future),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildToggle(),
                  const SizedBox(height: 24),
                  if (_selectedTab == 'Analytics') ...[
                    _buildKpiGrid(data),
                    const SizedBox(height: 24),
                    _buildRevenueChart(data['weeklyRevenue'] as List<double>),
                  ] else ...[
                    _buildHeatmapList(data['topLocations'] as List<dynamic>),
                  ],
                  const SizedBox(height: 40),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildToggle() {
    return Container(
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.colors.cardBorder),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: () => setState(() => _selectedTab = 'Analytics'),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: _selectedTab == 'Analytics' ? context.colors.adminAccent : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: Text('Analytics', style: TextStyle(
                  color: _selectedTab == 'Analytics' ? Colors.black : context.colors.text,
                  fontWeight: _selectedTab == 'Analytics' ? FontWeight.w800 : FontWeight.w600,
                )),
              ),
            ),
          ),
          Expanded(
            child: InkWell(
              onTap: () => setState(() => _selectedTab = 'Heatmaps'),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: _selectedTab == 'Heatmaps' ? context.colors.error : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: Text('Heatmaps', style: TextStyle(
                  color: _selectedTab == 'Heatmaps' ? Colors.white : context.colors.text,
                  fontWeight: _selectedTab == 'Heatmaps' ? FontWeight.w800 : FontWeight.w600,
                )),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKpiGrid(Map<String, dynamic> data) {
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 1.2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        _KpiCard(
          title: 'Total Revenue',
          value: '₹${NumberFormat.compact().format(data['totalRevenue'])}',
          icon: Icons.currency_rupee_rounded,
          color: context.colors.success,
        ),
        _KpiCard(
          title: 'Total Rides',
          value: data['totalRides'].toString(),
          icon: Icons.local_taxi_rounded,
          color: context.colors.adminAccent,
          textColor: Colors.black,
        ),
        _KpiCard(
          title: 'Avg Fare',
          value: '₹${data['averageFare'].toInt()}',
          icon: Icons.receipt_long_rounded,
          color: context.colors.adminInfo,
        ),
        _KpiCard(
          title: 'Active Captains',
          value: data['activeCaptains'].toString(),
          icon: Icons.people_alt_rounded,
          color: context.colors.warning,
        ),
      ],
    );
  }

  Widget _buildRevenueChart(List<double> weeklyRevenue) {
    double maxVal = 0;
    for (var v in weeklyRevenue) {
      if (v > maxVal) maxVal = v;
    }
    if (maxVal == 0) maxVal = 1;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.colors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Revenue (Last 7 Days)', style: TextStyle(color: context.colors.text, fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 24),
          SizedBox(
            height: 200,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(7, (index) {
                final rev = weeklyRevenue[6 - index];
                final heightFactor = rev / maxVal;
                final date = DateTime.now().subtract(Duration(days: 6 - index));
                
                return Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(rev > 0 ? '₹${NumberFormat.compact().format(rev)}' : '', style: TextStyle(fontSize: 10, color: context.colors.textMuted)),
                    const SizedBox(height: 4),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 500),
                      width: 28,
                      height: 120 * heightFactor,
                      decoration: BoxDecoration(
                        color: index == 6 ? context.colors.adminAccent : context.colors.adminAccent.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(DateFormat('E').format(date), style: TextStyle(fontSize: 12, color: index == 6 ? context.colors.text : context.colors.textMuted, fontWeight: index == 6 ? FontWeight.w700 : FontWeight.normal)),
                  ],
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeatmapList(List<dynamic> topLocations) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.colors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.whatshot_rounded, color: context.colors.error, size: 20),
              const SizedBox(width: 8),
              Text('Top Demand Zones (Cities)', style: TextStyle(color: context.colors.text, fontSize: 16, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 16),
          if (topLocations.isEmpty)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Text('Not enough ride data yet.', style: TextStyle(color: context.colors.textMuted), textAlign: TextAlign.center),
            )
          else
            ...List.generate(topLocations.length, (index) {
              final loc = topLocations[index];
              final isTop = index == 0;
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isTop ? context.colors.error.withValues(alpha: 0.1) : context.colors.background,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isTop ? context.colors.error.withValues(alpha: 0.5) : context.colors.cardBorder),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 28, height: 28,
                      decoration: BoxDecoration(
                        color: isTop ? context.colors.error : context.colors.surfaceAlt,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text('#${index + 1}', style: TextStyle(color: isTop ? Colors.white : context.colors.text, fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(loc['name'].toString(), style: TextStyle(color: context.colors.text, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: context.colors.surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: context.colors.cardBorder),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.local_taxi_rounded, size: 14, color: isTop ? context.colors.error : context.colors.textMuted),
                          const SizedBox(width: 4),
                          Text(loc['count'].toString(), style: TextStyle(color: isTop ? context.colors.error : context.colors.text, fontWeight: FontWeight.w700)),
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

class _KpiCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final Color? textColor;

  const _KpiCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: TextStyle(color: textColor ?? color, fontSize: 24, fontWeight: FontWeight.w900)),
              Text(title, style: TextStyle(color: textColor?.withValues(alpha: 0.8) ?? color.withValues(alpha: 0.8), fontSize: 13, fontWeight: FontWeight.w600)),
            ],
          ),
        ],
      ),
    );
  }
}
