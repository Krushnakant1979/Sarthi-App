import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../admin_design.dart';
import '../../../shared/auth/domain/app_user.dart';
import '../admin_providers.dart';
import '../widgets/admin_common_widgets.dart';
import 'package:google_fonts/google_fonts.dart';

class FinanceScreen extends ConsumerWidget {
  const FinanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ridesAsync = ref.watch(allRidesProvider);
    final usersAsync = ref.watch(allUsersProvider);
    final historyAsync = ref.watch(payoutHistoryProvider);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: context.colors.background,
        appBar: AppBar(
          title: Text(
            'Finance & Payouts',
            style: GoogleFonts.inter(
              color: context.colors.text,
              fontWeight: FontWeight.w800,
              fontSize: 15,
            ),
          ),
          backgroundColor: context.colors.surface,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          iconTheme: IconThemeData(color: context.colors.text),
          bottom: TabBar(
            labelColor: context.colors.adminAccent,
            unselectedLabelColor: context.colors.textMuted,
            indicatorColor: context.colors.adminAccent,
            indicatorWeight: 3,
            tabs: [
              Tab(text: 'Pending Settlements'),
              Tab(text: 'Payout History'),
            ],
          ),
        ),
        body: AsyncPage(
          loading: ridesAsync.isLoading || usersAsync.isLoading,
          error: ridesAsync.error ?? usersAsync.error,
          child: Builder(
            builder: (_) {
              final rides = ridesAsync.value ?? [];
              final users = usersAsync.value ?? [];
              final history = historyAsync.value ?? [];

              // Calculate KPIs
              double totalRevenue = 0;
              double platformEarnings = 0;
              double pendingPayoutsTotal = 0;

              // Group pending rides by captain
              final Map<String, List<Map<String, dynamic>>> pendingByCaptain =
                  {};

              for (final ride in rides) {
                if (ride['status'] == 'completed') {
                  final fare = (ride['fareEstimate'] as num?)?.toDouble() ?? 0;
                  totalRevenue += fare;
                  final comm = fare * 0.15; // 15% commission
                  platformEarnings += comm;

                  // Check if ride is unsettled
                  if (ride['isSettled'] != true) {
                    final capId = ride['assignedCaptainId'];
                    if (capId != null) {
                      pendingByCaptain.putIfAbsent(capId, () => []).add(ride);
                      pendingPayoutsTotal += (fare - comm);
                    }
                  }
                }
              }

              final pendingList = pendingByCaptain.entries.toList();

              return Column(
                children: [
                  // KPI Cards
                  Container(
                    color: context.colors.surface,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: _KPICard(
                            title: 'Total Revenue',
                            amount: totalRevenue,
                            color: context.colors.success,
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: _KPICard(
                            title: 'Platform (15%)',
                            amount: platformEarnings,
                            color: context.colors.adminInfo,
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: _KPICard(
                            title: 'Pending Payout',
                            amount: pendingPayoutsTotal,
                            color: context.colors.warning,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Tabs Content
                  Expanded(
                    child: TabBarView(
                      children: [
                        // Pending Tab
                        pendingList.isEmpty
                            ? const EmptyState(
                                icon: Icons.check_circle_outline_rounded,
                                title: 'All settled up!',
                                subtitle: 'No pending payouts to captains.',
                              )
                            : ListView.separated(
                                padding: const EdgeInsets.all(20),
                                itemCount: pendingList.length,
                                separatorBuilder: (_, _) =>
                                    SizedBox(height: 16),
                                itemBuilder: (context, index) {
                                  final capId = pendingList[index].key;
                                  final capRides = pendingList[index].value;
                                  final captain = users.firstWhere(
                                    (u) => u.uid == capId,
                                    orElse: () => users.first,
                                  ); // fallback

                                  double gross = 0;
                                  for (final r in capRides) {
                                    gross +=
                                        (r['fareEstimate'] as num?)
                                            ?.toDouble() ??
                                        0;
                                  }
                                  final comm = gross * 0.15;
                                  final net = gross - comm;

                                  return _PendingPayoutCard(
                                    captainName: captain.name,
                                    captainId: capId,
                                    rideIds: capRides
                                        .map((r) => r['id'].toString())
                                        .toList(),
                                    tripsCount: capRides.length,
                                    gross: gross,
                                    commission: comm,
                                    netPayout: net,
                                  );
                                },
                              ),

                        // History Tab
                        historyAsync.isLoading
                            ? Center(child: CircularProgressIndicator())
                            : history.isEmpty
                            ? const EmptyState(
                                icon: Icons.history_rounded,
                                title: 'No history yet',
                                subtitle: 'Settled payouts will appear here.',
                              )
                            : ListView.separated(
                                padding: const EdgeInsets.all(20),
                                itemCount: history.length,
                                separatorBuilder: (_, _) =>
                                    SizedBox(height: 12),
                                itemBuilder: (context, index) {
                                  final item = history[index];
                                  final capId = item['captainId'];
                                  final captain = users.firstWhere(
                                    (u) => u.uid == capId,
                                    orElse: () => users.first,
                                  );

                                  DateTime? settledAt;
                                  if (item['settledAt'] is Timestamp) {
                                    settledAt = (item['settledAt'] as Timestamp)
                                        .toDate();
                                  }

                                  return Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: context.colors.surface,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: context.colors.cardBorder,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 40,
                                          height: 40,
                                          decoration: BoxDecoration(
                                            color: context.colors.success
                                                .withValues(alpha: 0.15),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(
                                            Icons.check_rounded,
                                            color: context.colors.success,
                                            size: 20,
                                          ),
                                        ),
                                        SizedBox(width: 16),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Paid to ${captain.name}',
                                                style: GoogleFonts.inter(
                                                  color: context.colors.text,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                              SizedBox(height: 4),
                                              Text(
                                                settledAt != null
                                                    ? DateFormat(
                                                        'MMM d, yyyy - hh:mm a',
                                                      ).format(settledAt)
                                                    : 'Unknown date',
                                                style: GoogleFonts.inter(
                                                  color:
                                                      context.colors.textMuted,
                                                  fontSize: 11,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Text(
                                          '₹${item['amount']}',
                                          style: GoogleFonts.inter(
                                            color: context.colors.success,
                                            fontWeight: FontWeight.w800,
                                            fontSize: 15,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _KPICard extends StatelessWidget {
  const _KPICard({
    required this.title,
    required this.amount,
    required this.color,
  });
  final String title;
  final double amount;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.inter(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 10,
            ),
          ),
          SizedBox(height: 6),
          Text(
            '₹${amount.toStringAsFixed(0)}',
            style: GoogleFonts.inter(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 17,
            ),
          ),
        ],
      ),
    );
  }
}

class _PendingPayoutCard extends ConsumerStatefulWidget {
  const _PendingPayoutCard({
    required this.captainName,
    required this.captainId,
    required this.rideIds,
    required this.tripsCount,
    required this.gross,
    required this.commission,
    required this.netPayout,
  });

  final String captainName;
  final String captainId;
  final List<String> rideIds;
  final int tripsCount;
  final double gross;
  final double commission;
  final double netPayout;

  @override
  ConsumerState<_PendingPayoutCard> createState() => _PendingPayoutCardState();
}

class _PendingPayoutCardState extends ConsumerState<_PendingPayoutCard> {
  bool settling = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.colors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: context.colors.warning.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.account_balance_wallet_rounded,
                  color: context.colors.warning,
                  size: 20,
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.captainName,
                      style: GoogleFonts.inter(
                        color: context.colors.text,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'ID: ${AppUser.shortId(widget.captainId)} • ${widget.tripsCount} trips',
                      style: GoogleFonts.inter(
                        color: context.colors.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '₹${widget.netPayout.toStringAsFixed(0)}',
                style: GoogleFonts.inter(
                  color: context.colors.warning,
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: context.colors.background,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _MiniStat(
                  label: 'Gross Earnings',
                  value: '₹${widget.gross.toStringAsFixed(0)}',
                ),
                Text(
                  '-',
                  style: GoogleFonts.inter(
                    color: context.colors.textMuted,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                _MiniStat(
                  label: 'Comm. (15%)',
                  value: '₹${widget.commission.toStringAsFixed(0)}',
                ),
                Text(
                  '=',
                  style: GoogleFonts.inter(
                    color: context.colors.textMuted,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                _MiniStat(
                  label: 'Net Payout',
                  value: '₹${widget.netPayout.toStringAsFixed(0)}',
                  highlight: true,
                ),
              ],
            ),
          ),
          SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: settling
                  ? null
                  : () async {
                      final messenger = ScaffoldMessenger.of(context);
                      final colors = context.colors;
                      final confirm =
                          await showDialog<bool>(
                            context: context,
                            builder: (c) => AlertDialog(
                              backgroundColor: colors.surfaceAlt,
                              title: Text(
                                'Mark as Settled?',
                                style: GoogleFonts.inter(color: colors.text),
                              ),
                              content: Text(
                                'Have you successfully transferred ₹${widget.netPayout.toStringAsFixed(0)} to ${widget.captainName}?',
                                style: GoogleFonts.inter(
                                  color: colors.textMuted,
                                ),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(c, false),
                                  child: Text('Cancel'),
                                ),
                                FilledButton(
                                  onPressed: () => Navigator.pop(c, true),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: colors.adminAccent,
                                    foregroundColor: Colors.black,
                                  ),
                                  child: Text('Yes, Settled'),
                                ),
                              ],
                            ),
                          ) ??
                          false;

                      if (!confirm || !mounted) return;

                      setState(() => settling = true);
                      try {
                        await ref
                            .read(adminRepositoryProvider)
                            .settleCaptainPayout(
                              widget.captainId,
                              widget.rideIds,
                              widget.netPayout,
                            );
                        if (mounted)
                          messenger.showSnackBar(
                            SnackBar(
                              backgroundColor: colors.success,
                              content: Text(
                                'Payout to ${widget.captainName} settled!',
                              ),
                            ),
                          );
                      } catch (e) {
                        if (mounted)
                          messenger.showSnackBar(
                            SnackBar(
                              backgroundColor: colors.error,
                              content: Text(e.toString()),
                            ),
                          );
                      } finally {
                        if (mounted) setState(() => settling = false);
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: context.colors.adminAccent,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: settling
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.black,
                      ),
                    )
                  : Text(
                      'Mark as Settled',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.label,
    required this.value,
    this.highlight = false,
  });
  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            color: context.colors.textMuted,
            fontSize: 9,
          ),
        ),
        SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.inter(
            color: highlight ? context.colors.warning : context.colors.text,
            fontWeight: highlight ? FontWeight.w800 : FontWeight.w600,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}
