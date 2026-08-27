import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../admin_providers.dart';
import '../admin_design.dart';
import '../admin_dashboard_screen.dart';
import '../widgets/admin_badges.dart';
import '../widgets/admin_common_widgets.dart';


class RidesTab extends ConsumerStatefulWidget {
  const RidesTab({super.key});
  @override
  ConsumerState<RidesTab> createState() => RidesTabState();
}


class RidesTabState extends ConsumerState<RidesTab> {
  RideRange range = RideRange.today;
  String status = 'completed';
  String search = '';

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(allRidesProvider);
    const allowedStatuses = {'completed', 'cancelled'};
    final selectedStatus = allowedStatuses.contains(status)
        ? status
        : 'completed';
    return AsyncPage(
      loading: async.isLoading, error: async.error,
      child: Builder(builder: (_) {
        final now = DateTime.now();
        final rides = (async.value ?? []).where((ride) {
          final date = rideDate(ride);
          final inRange = switch (range) {
            RideRange.today      => sameDay(date, now),
            RideRange.last30Days => date != null && date.isAfter(now.subtract(const Duration(days: 30))),
            RideRange.all        => true,
          };
          final matchesStatus = ride['status'] == selectedStatus;
          final haystack = '${ride['id']} ${ride['pickup']?['address']} ${ride['destination']?['address']}'.toLowerCase();
          return inRange && matchesStatus && haystack.contains(search.toLowerCase());
        }).toList();
        return Column(children: [
          FilterPanel(children: [
            Wrap(spacing: 8, runSpacing: 8, children: [
              AdminFilterChip(label: 'Today', selected: range == RideRange.today, onTap: () => setState(() => range = RideRange.today)),
              AdminFilterChip(label: 'Last 30 days', selected: range == RideRange.last30Days, onTap: () => setState(() => range = RideRange.last30Days)),
              AdminFilterChip(label: 'All time', selected: range == RideRange.all, onTap: () => setState(() => range = RideRange.all)),
            ]),
            DarkDropdown<String>(
              value: selectedStatus, label: 'Status', icon: Icons.filter_alt_rounded,
              items: const ['completed', 'cancelled']
                  .map((s) => DropdownMenuItem(value: s, child: Text(pretty(s), style: TextStyle(color: context.colors.text, fontSize: 13)))).toList(),
              onChanged: (v) => setState(() => status = v ?? 'completed'),
            ),
            SearchField(hint: 'Search ride or location...', onChanged: (v) => setState(() => search = v.trim())),
          ]),
          Expanded(child: rides.isEmpty
              ? const EmptyState(icon: Icons.route_outlined, title: 'No matching rides', subtitle: 'Try another date or status filter.')
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  itemCount: rides.length,
                  itemBuilder: (_, i) => RideCard(ride: rides[i]),
                )),
        ]);
      }),
    );
  }
}


class RideCard extends StatelessWidget {
  const RideCard({super.key, required this.ride});
  final Map<String, dynamic> ride;
  @override
  Widget build(BuildContext context) {
    final status = ride['status'] as String? ?? 'unknown';
    final color = statusColor(context, status);
    final date = rideDate(ride);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: context.colors.surface, borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => showModalBottomSheet(
            context: context, isScrollControlled: true,
            backgroundColor: context.colors.surfaceAlt,
            shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
            builder: (_) => RideDetails(ride: ride),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withValues(alpha: 0.25))),
                child: Icon(Icons.local_taxi_rounded, color: color, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(ride['destination']?['address']?.toString() ?? 'Unknown destination', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: context.colors.text, fontWeight: FontWeight.w700, fontSize: 14)),
                const SizedBox(height: 4),
                Row(children: [
                  Text(date == null ? 'Unknown date' : DateFormat('d MMM, hh:mm a').format(date), style: TextStyle(color: context.colors.textMuted, fontSize: 12)),
                  const SizedBox(width: 8),
                  Container(width: 3, height: 3, decoration: BoxDecoration(color: context.colors.cardBorder, shape: BoxShape.circle)),
                  const SizedBox(width: 8),
                  StatusBadge(status: status),
                ]),
              ])),
              const SizedBox(width: 12),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text('₹${ride['fareEstimate'] ?? 0}', style: TextStyle(color: context.colors.text, fontWeight: FontWeight.w800, fontSize: 17)),
                const SizedBox(height: 2),
                Icon(Icons.chevron_right_rounded, color: context.colors.textMuted, size: 18),
              ]),
            ]),
          ),
        ),
      ),
    );
  }
}


class RideDetails extends StatelessWidget {
  const RideDetails({super.key, required this.ride});
  final Map<String, dynamic> ride;
  @override
  Widget build(BuildContext context) {
    final date = rideDate(ride);
    return SafeArea(child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: context.colors.cardBorder, borderRadius: BorderRadius.circular(2)))),
        const SizedBox(height: 20),
        Row(children: [
          Expanded(child: Text('Ride Details', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: context.colors.text))),
          IconButton(onPressed: () => Navigator.pop(context), icon: Icon(Icons.close_rounded, color: context.colors.textMuted), style: IconButton.styleFrom(backgroundColor: context.colors.surface)),
        ]),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(color: context.colors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: context.colors.cardBorder)),
          child: Column(children: [
            DetailRow(icon: Icons.fingerprint, label: 'Ride ID', value: ride['id']?.toString() ?? '---'),
            DividerRow(),
            DetailRow(icon: Icons.my_location_rounded, label: 'Pickup', value: ride['pickup']?['address']?.toString() ?? 'Unknown pickup'),
            DividerRow(),
            DetailRow(icon: Icons.location_on_rounded, label: 'Destination', value: ride['destination']?['address']?.toString() ?? 'Unknown destination'),
            DividerRow(),
            DetailRow(icon: Icons.info_outline_rounded, label: 'Status', value: pretty(ride['status']?.toString() ?? 'unknown')),
            DividerRow(),
            DetailRow(icon: Icons.currency_rupee_rounded, label: 'Fare', value: '₹${ride['fareEstimate'] ?? 0}'),
            DividerRow(),
            DetailRow(icon: Icons.person_rounded, label: 'User ID', value: ride['userId']?.toString() ?? '---'),
            DividerRow(),
            DetailRow(icon: Icons.local_taxi_rounded, label: 'Captain ID', value: ride['assignedCaptainId']?.toString() ?? 'Not assigned'),
            DividerRow(),
            DetailRow(icon: Icons.schedule_rounded, label: 'Created', value: date == null ? 'Unknown' : DateFormat('d MMM y, hh:mm a').format(date)),
          ]),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton.icon(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Map tracking and route replay is coming soon.')),
              );
            },
            icon: const Icon(Icons.map_rounded, color: Colors.black),
            label: const Text('Track on Map / Replay', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w700, fontSize: 15)),
            style: ElevatedButton.styleFrom(backgroundColor: context.colors.adminAccent, foregroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), elevation: 0),
          ),
        ),
      ]),
    ));
  }
}
