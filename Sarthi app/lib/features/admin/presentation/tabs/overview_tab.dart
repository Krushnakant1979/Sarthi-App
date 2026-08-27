import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../admin_providers.dart';
import '../admin_design.dart';
import '../admin_dashboard_screen.dart';
import '../widgets/admin_common_widgets.dart';


class OverviewTab extends ConsumerWidget {
  const OverviewTab({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rides = ref.watch(allRidesProvider);
    final users = ref.watch(allUsersProvider);
    return AsyncPage(
      loading: rides.isLoading || users.isLoading,
      error: rides.error ?? users.error,
      child: Builder(builder: (_) {
        final rideList = rides.value ?? [];
        final userList = users.value ?? [];
        final today = DateTime.now();
        final todayRides = rideList.where((r) => sameDay(rideDate(r), today)).length;
        final active = rideList.where((r) => !{'completed', 'cancelled'}.contains(r['status'])).length;
        final revenue = rideList.where((r) => r['status'] == 'completed').fold<double>(0, (acc, r) => acc + ((r['fareEstimate'] as num?)?.toDouble() ?? 0));
        final todayRevenue = rideList.where((r) => r['status'] == 'completed' && sameDay(rideDate(r), today)).fold<double>(0, (acc, r) => acc + ((r['fareEstimate'] as num?)?.toDouble() ?? 0));
        final pending = userList.where((u) => u.role == 'captain' && u.verificationStatus == 'pending_review').length;
        return ListView(padding: const EdgeInsets.all(20), children: [
          Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Business Snapshot', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: context.colors.text, letterSpacing: 0.2)),
              const SizedBox(height: 4),
              Text(DateFormat('EEEE, d MMMM y').format(today), style: TextStyle(color: context.colors.textMuted, fontSize: 13)),
            ])),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(color: context.colors.success.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20), border: Border.all(color: context.colors.success.withValues(alpha: 0.3))),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Container(width: 6, height: 6, decoration: BoxDecoration(color: context.colors.success, shape: BoxShape.circle)),
                const SizedBox(width: 6),
                Text('Live', style: TextStyle(color: context.colors.success, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
              ]),
            ),
          ]),
          const SizedBox(height: 14),
          LayoutBuilder(builder: (context, constraints) {
            final w = constraints.maxWidth;
            final cross = w > 900 ? 3 : 2;
            return GridView.count(
              shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: cross, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 1.7,
              children: [
                MetricCard(label: "Today's Rides", value: '$todayRides', icon: Icons.today_rounded, color: context.colors.adminInfo, trend: null, onTap: () => DefaultTabController.of(context).animateTo(1)),
                MetricCard(label: "Today's Revenue", value: '₹${todayRevenue.toStringAsFixed(0)}', icon: Icons.currency_rupee_rounded, color: context.colors.success, trend: null, onTap: () => DefaultTabController.of(context).animateTo(1)),
                MetricCard(label: 'Active Rides', value: '$active', icon: Icons.route_rounded, color: context.colors.warning, trend: null, onTap: () => DefaultTabController.of(context).animateTo(1)),
                MetricCard(label: 'Total Revenue', value: '₹${revenue.toStringAsFixed(0)}', icon: Icons.payments_rounded, color: context.colors.success, trend: null, onTap: () => DefaultTabController.of(context).animateTo(1)),
                MetricCard(label: 'Pending Captains', value: '$pending', icon: Icons.verified_user_rounded, color: context.colors.error, trend: null, onTap: () {
                  ref.read(usersFilterProvider.notifier).state = 'pending';
                  DefaultTabController.of(context).animateTo(2);
                }),
                MetricCard(label: 'Total Users', value: '${userList.where((u) => u.role == 'user').length}', icon: Icons.person_rounded, color: context.colors.adminInfo, trend: null, onTap: () {
                  ref.read(usersFilterProvider.notifier).state = 'user';
                  DefaultTabController.of(context).animateTo(2);
                }),
                MetricCard(label: 'Captains', value: '${userList.where((u) => u.role == 'captain').length}', icon: Icons.local_taxi_rounded, color: context.colors.success, trend: null, onTap: () {
                  ref.read(usersFilterProvider.notifier).state = 'captain';
                  DefaultTabController.of(context).animateTo(2);
                }),
              ],
            );
          }),
          if (pending > 0) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: context.colors.warning.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: context.colors.warning.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.pending_actions_rounded, color: context.colors.warning, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '$pending captain${pending == 1 ? '' : 's'} awaiting document verification.',
                      style: TextStyle(color: context.colors.warning, fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ]);
      }),
    );
  }
}
