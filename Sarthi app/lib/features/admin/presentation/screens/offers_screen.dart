import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../admin_design.dart';
import '../admin_providers.dart';
import 'package:google_fonts/google_fonts.dart';

class OffersScreen extends ConsumerWidget {
  const OffersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offersAsync = ref.watch(offersProvider);
    final processedOffers = ref.watch(processedOffersProvider);

    int activeCount = 0;
    int scheduledCount = 0;
    int expiredCount = 0;

    if (offersAsync.hasValue && offersAsync.value != null) {
      final now = DateTime.now();
      for (var o in offersAsync.value!) {
        final status =
            o['status'] as String? ??
            (o['isActive'] == true ? 'published' : 'draft');
        if (status == 'published') {
          DateTime? start;
          if (o['startDate'] != null)
            start = (o['startDate'] as dynamic).toDate();
          DateTime? expiry;
          if (o['expiryDate'] != null)
            expiry = (o['expiryDate'] as dynamic).toDate();

          if (expiry != null && expiry.isBefore(now)) {
            expiredCount++;
          } else if (start != null && start.isAfter(now)) {
            scheduledCount++;
          } else {
            activeCount++;
          }
        }
      }
    }

    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Offers & Promos',
              style: GoogleFonts.inter(
                color: context.colors.text,
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
            Text(
              'Create and manage rider discounts',
              style: GoogleFonts.inter(
                color: context.colors.textMuted,
                fontSize: 11,
              ),
            ),
          ],
        ),
        backgroundColor: context.colors.surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        iconTheme: IconThemeData(color: context.colors.text),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CreateOfferScreen()),
                );
              },
              borderRadius: BorderRadius.circular(24),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: context.colors.cardBorder),
                ),
                child: Icon(
                  Icons.add_rounded,
                  color: context.colors.primary,
                  size: 20,
                ),
              ),
            ),
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Column(
              children: [
                Container(
                  color: context.colors.surface,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: _OfferSummaryCard(
                          title: 'Active',
                          count: activeCount,
                          icon: Icons.local_activity_rounded,
                          color: context.colors.success,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _OfferSummaryCard(
                          title: 'Scheduled',
                          count: scheduledCount,
                          icon: Icons.calendar_month_rounded,
                          color: context.colors.primary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _OfferSummaryCard(
                          title: 'Expired',
                          count: expiredCount,
                          icon: Icons.history_rounded,
                          color: context.colors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _OffersFilterTabs(),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: context.colors.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: context.colors.cardBorder,
                            ),
                          ),
                          child: TextField(
                            onChanged: (val) =>
                                ref.read(offersSearchProvider.notifier).state =
                                    val,
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: context.colors.text,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Search coupon code or offer...',
                              hintStyle: GoogleFonts.inter(
                                color: context.colors.textMuted,
                                fontSize: 11,
                              ),
                              prefixIcon: Icon(
                                Icons.search_rounded,
                                color: context.colors.textMuted,
                                size: 16,
                              ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 8,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: context.colors.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: context.colors.cardBorder),
                        ),
                        child: Icon(
                          Icons.tune_rounded,
                          color: context.colors.text,
                          size: 16,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${processedOffers.length} ${ref.watch(offersTabProvider).toLowerCase()} offers',
                        style: GoogleFonts.inter(
                          color: context.colors.textMuted,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      DropdownButton<String>(
                        value: ref.watch(offersSortProvider),
                        icon: Icon(
                          Icons.keyboard_arrow_down_rounded,
                          size: 14,
                          color: context.colors.textMuted,
                        ),
                        underline: const SizedBox(),
                        style: GoogleFonts.inter(
                          color: context.colors.text,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'newest',
                            child: Text('Newest first'),
                          ),
                          DropdownMenuItem(
                            value: 'oldest',
                            child: Text('Oldest first'),
                          ),
                          DropdownMenuItem(
                            value: 'expiring',
                            child: Text('Expiring soon'),
                          ),
                          DropdownMenuItem(
                            value: 'discount',
                            child: Text('Highest discount'),
                          ),
                        ],
                        onChanged: (val) {
                          if (val != null)
                            ref.read(offersSortProvider.notifier).state = val;
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
          if (offersAsync.isLoading)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            )
          else if (processedOffers.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    _OffersEmptyState(
                      tab: ref.watch(offersTabProvider),
                      onCreate: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const CreateOfferScreen(),
                          ),
                        );
                      },
                      onViewExpired: () =>
                          ref.read(offersTabProvider.notifier).state =
                              'Expired',
                    ),
                    const SizedBox(height: 16),
                    const _OfferInfoCard(),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.only(left: 20, right: 20, bottom: 100),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final offer = processedOffers[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: _OfferCard(offer: offer),
                  );
                }, childCount: processedOffers.length),
              ),
            ),
        ],
      ),
    );
  }

  // Removed _showCreateOfferSheet
}

class _OfferSummaryCard extends StatelessWidget {
  final String title;
  final int count;
  final IconData icon;
  final Color color;

  const _OfferSummaryCard({
    required this.title,
    required this.count,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
      decoration: BoxDecoration(
        color: context.colors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.colors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 12),
              ),
              const SizedBox(width: 8),
              Text(
                count.toString(),
                style: GoogleFonts.inter(
                  color: context.colors.text,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            title,
            style: GoogleFonts.inter(
              color: context.colors.textMuted,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _OffersFilterTabs extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedTab = ref.watch(offersTabProvider);
    final tabs = ['All', 'Active', 'Scheduled', 'Expired'];

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.colors.cardBorder),
      ),
      child: Row(
        children: tabs.map((tab) {
          final isSelected = selectedTab == tab;
          return Expanded(
            child: GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                ref.read(offersTabProvider.notifier).state = tab;
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFF0B1F3A)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: Text(
                  tab,
                  style: GoogleFonts.inter(
                    color: isSelected ? Colors.white : context.colors.textMuted,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                    fontSize: 11,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _OffersEmptyState extends StatelessWidget {
  final String tab;
  final VoidCallback onCreate;
  final VoidCallback onViewExpired;

  const _OffersEmptyState({
    required this.tab,
    required this.onCreate,
    required this.onViewExpired,
  });

  @override
  Widget build(BuildContext context) {
    String title = 'No active offers';
    if (tab == 'Scheduled') title = 'No scheduled offers';
    if (tab == 'Expired') title = 'No expired offers';
    if (tab == 'All') title = 'No offers found';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.colors.cardBorder),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.asset(
              'assets/images/offers_empty.jpg',
              height: 120,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: GoogleFonts.inter(
              color: context.colors.text,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Create a discount code to boost bookings and reward riders.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: context.colors.textMuted,
              fontSize: 10,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 40,
            child: ElevatedButton.icon(
              onPressed: onCreate,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0B1F3A),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 0,
              ),
              icon: const Icon(Icons.add_rounded, size: 14),
              label: Text(
                'Create Offer',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                ),
              ),
            ),
          ),
          if (tab != 'Expired') ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: onViewExpired,
              child: Text(
                'View expired offers',
                style: GoogleFonts.inter(
                  color: context.colors.primary,
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _OfferInfoCard extends StatelessWidget {
  const _OfferInfoCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.colors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Create an offer in 3 steps',
            style: GoogleFonts.inter(
              color: context.colors.text,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildStep(
                context,
                1,
                'Set discount',
                Icons.percent_rounded,
                const Color(0xFFE0E7FF),
                const Color(0xFF4F46E5),
              ),
              _buildDashedLine(context),
              _buildStep(
                context,
                2,
                'Choose eligibility',
                Icons.people_rounded,
                const Color(0xFFF3E8FF),
                const Color(0xFF9333EA),
              ),
              _buildDashedLine(context),
              _buildStep(
                context,
                3,
                'Publish',
                Icons.send_rounded,
                const Color(0xFFFFF7ED),
                const Color(0xFFEA580C),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.cloud_sync_outlined,
                size: 12,
                color: context.colors.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'Offers are synchronized across all Sarthi apps.',
                style: GoogleFonts.inter(
                  color: context.colors.textMuted,
                  fontSize: 9,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStep(
    BuildContext context,
    int step,
    String title,
    IconData icon,
    Color bgColor,
    Color fgColor,
  ) {
    return Column(
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle),
              child: Icon(icon, color: fgColor, size: 16),
            ),
            Positioned(
              bottom: -4,
              right: -4,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: fgColor,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  step.toString(),
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 8,
                    fontWeight: FontWeight.w800,
                    height: 1,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          title,
          style: GoogleFonts.inter(
            color: context.colors.text,
            fontSize: 9,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildDashedLine(BuildContext context) {
    return Expanded(
      child: Container(
        height: 1,
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 20),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Flex(
              direction: Axis.horizontal,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(
                (constraints.constrainWidth() / 4).floor(),
                (index) {
                  return SizedBox(
                    width: 2,
                    height: 1,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: context.colors.cardBorder,
                      ),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }
}

class _OfferCard extends StatelessWidget {
  final Map<String, dynamic> offer;

  const _OfferCard({required this.offer});

  @override
  Widget build(BuildContext context) {
    final liveStatus = offer['liveStatus'] as String? ?? 'draft';
    final isFlat = offer['type'] == 'flat';
    final valStr = isFlat ? '₹${offer['value']}' : '${offer['value']}% OFF';

    DateTime? expiry;
    if (offer['expiryDate'] != null)
      expiry = (offer['expiryDate'] as dynamic).toDate();

    Color statusColor;
    switch (liveStatus) {
      case 'active':
        statusColor = context.colors.success;
        break;
      case 'scheduled':
        statusColor = context.colors.primary;
        break;
      case 'expired':
        statusColor = context.colors.textMuted;
        break;
      default:
        statusColor = context.colors.warning;
        break;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.colors.cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: context.colors.background,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      offer['code']?.toString() ?? '---',
                      style: GoogleFonts.inter(
                        color: context.colors.text,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      liveStatus.toUpperCase(),
                      style: GoogleFonts.inter(
                        color: statusColor,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              Text(
                valStr,
                style: GoogleFonts.inter(
                  color: statusColor,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            offer['description']?.toString() ?? '',
            style: GoogleFonts.inter(
              color: context.colors.text,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                Icons.local_taxi_rounded,
                size: 14,
                color: context.colors.textMuted,
              ),
              const SizedBox(width: 4),
              Text(
                'Min Ride: ₹${offer['minAmount'] ?? 0}',
                style: GoogleFonts.inter(
                  color: context.colors.textMuted,
                  fontSize: 11,
                ),
              ),
              const SizedBox(width: 16),
              if (expiry != null) ...[
                Icon(
                  Icons.event_rounded,
                  size: 14,
                  color: context.colors.textMuted,
                ),
                const SizedBox(width: 4),
                Text(
                  'Expires: ${DateFormat('d MMM, yyyy').format(expiry)}',
                  style: GoogleFonts.inter(
                    color: context.colors.textMuted,
                    fontSize: 11,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// CREATE OFFER SCREEN
// -----------------------------------------------------------------------------

class CreateOfferScreen extends ConsumerStatefulWidget {
  const CreateOfferScreen({super.key});

  @override
  ConsumerState<CreateOfferScreen> createState() => _CreateOfferScreenState();
}

class _CreateOfferScreenState extends ConsumerState<CreateOfferScreen> {
  final _formKey = GlobalKey<FormState>();
  final _code = TextEditingController();
  final _desc = TextEditingController();
  final _value = TextEditingController();
  final _min = TextEditingController();

  final _totalUses = TextEditingController();
  final _perRider = TextEditingController();

  String _type = 'flat';
  DateTime _start = DateTime.now();
  DateTime _expiry = DateTime.now().add(const Duration(days: 30));

  String _audience = 'All riders';
  List<String> _selectedServices = ['Bike', 'Auto', 'Cab'];

  bool _saving = false;
  bool _drafting = false;

  void _generateCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rnd = Random();
    final code = String.fromCharCodes(
      Iterable.generate(8, (_) => chars.codeUnitAt(rnd.nextInt(chars.length))),
    );
    setState(() => _code.text = code);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Create New Offer',
              style: GoogleFonts.inter(
                color: context.colors.text,
                fontWeight: FontWeight.w800,
                fontSize: 14,
              ),
            ),
            Text(
              'Configure discount, eligibility and validity',
              style: GoogleFonts.inter(
                color: context.colors.textMuted,
                fontSize: 10,
              ),
            ),
          ],
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        iconTheme: IconThemeData(color: context.colors.text),
        actions: [
          IconButton(
            icon: Icon(
              Icons.help_outline,
              color: context.colors.textMuted,
              size: 20,
            ),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Draft saved banner
                    Container(
                      margin: const EdgeInsets.only(bottom: 20),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: context.colors.primary.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.cloud_done_outlined,
                            size: 16,
                            color: context.colors.primary,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Draft is saved automatically',
                            style: GoogleFonts.inter(
                              color: context.colors.primary,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),

                    _buildCard(
                      title: 'Offer details',
                      icon: Icons.local_activity_outlined,
                      children: [
                        _buildFieldLabel('Coupon code'),
                        TextFormField(
                          controller: _code,
                          textCapitalization: TextCapitalization.characters,
                          style: GoogleFonts.inter(
                            color: context.colors.text,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                          decoration: InputDecoration(
                            prefixIcon: Icon(
                              Icons.local_activity_outlined,
                              color: context.colors.textMuted,
                              size: 16,
                            ),
                            hintText: 'e.g. FLAT50',
                            hintStyle: GoogleFonts.inter(
                              color: context.colors.textMuted,
                              fontSize: 12,
                            ),
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(
                                color: context.colors.cardBorder,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(
                                color: context.colors.primary,
                              ),
                            ),
                            suffixIcon: Padding(
                              padding: const EdgeInsets.all(4),
                              child: OutlinedButton(
                                onPressed: _generateCode,
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: context.colors.primary,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  side: BorderSide(
                                    color: context.colors.primary.withValues(
                                      alpha: 0.5,
                                    ),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                  ),
                                  minimumSize: const Size(0, 32),
                                ),
                                child: Text(
                                  'Generate',
                                  style: GoogleFonts.inter(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'[a-zA-Z0-9]'),
                            ),
                          ],
                          validator: (v) =>
                              v == null || v.isEmpty ? 'Required' : null,
                          onChanged: (_) => setState(() {}),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(
                            top: 6,
                            left: 4,
                            bottom: 16,
                          ),
                          child: Text(
                            'Customers will enter this code at checkout.',
                            style: GoogleFonts.inter(
                              color: context.colors.textMuted,
                              fontSize: 10,
                            ),
                          ),
                        ),
                        _buildFieldLabel('Description'),
                        TextFormField(
                          controller: _desc,
                          style: GoogleFonts.inter(
                            color: context.colors.text,
                            fontSize: 13,
                          ),
                          decoration: _inputDecoration(
                            'Save ₹50 on your next ride',
                          ),
                          maxLength: 60,
                          validator: (v) =>
                              v == null || v.isEmpty ? 'Required' : null,
                          onChanged: (_) => setState(() {}),
                        ),
                      ],
                    ),

                    _buildCard(
                      title: 'Discount configuration',
                      icon: Icons.percent,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: context.colors.background,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: GestureDetector(
                                  onTap: () => setState(() => _type = 'flat'),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 10,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _type == 'flat'
                                          ? const Color(0xFF0B1F3A)
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    alignment: Alignment.center,
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.local_activity_outlined,
                                          size: 14,
                                          color: _type == 'flat'
                                              ? Colors.white
                                              : context.colors.textMuted,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          'Flat Amount',
                                          style: GoogleFonts.inter(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 11,
                                            color: _type == 'flat'
                                                ? Colors.white
                                                : context.colors.textMuted,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: GestureDetector(
                                  onTap: () =>
                                      setState(() => _type = 'percent'),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 10,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _type == 'percent'
                                          ? const Color(0xFF0B1F3A)
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    alignment: Alignment.center,
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.percent,
                                          size: 14,
                                          color: _type == 'percent'
                                              ? Colors.white
                                              : context.colors.textMuted,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          'Percentage',
                                          style: GoogleFonts.inter(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 11,
                                            color: _type == 'percent'
                                                ? Colors.white
                                                : context.colors.textMuted,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildFieldLabel('Discount value'),
                                  TextFormField(
                                    controller: _value,
                                    keyboardType: TextInputType.number,
                                    style: GoogleFonts.inter(
                                      color: context.colors.text,
                                      fontSize: 13,
                                    ),
                                    decoration: _inputDecoration(
                                      '50',
                                      prefix: _type == 'flat' ? '₹' : null,
                                      suffix: _type == 'percent' ? '%' : null,
                                    ),
                                    validator: (v) {
                                      if (v == null || v.isEmpty)
                                        return 'Required';
                                      final val = double.tryParse(v);
                                      if (val == null || val <= 0)
                                        return 'Invalid';
                                      if (_type == 'percent' && val > 100)
                                        return 'Max 100%';
                                      return null;
                                    },
                                    onChanged: (_) => setState(() {}),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildFieldLabel('Minimum ride'),
                                  TextFormField(
                                    controller: _min,
                                    keyboardType: TextInputType.number,
                                    style: GoogleFonts.inter(
                                      color: context.colors.text,
                                      fontSize: 13,
                                    ),
                                    decoration: _inputDecoration(
                                      '199',
                                      prefix: '₹',
                                    ),
                                    validator: (v) => v == null || v.isEmpty
                                        ? 'Required'
                                        : null,
                                    onChanged: (_) => setState(() {}),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: context.colors.primary.withValues(
                              alpha: 0.05,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.sell_outlined,
                                size: 14,
                                color: context.colors.primary,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _getSummaryText(),
                                  style: GoogleFonts.inter(
                                    color: context.colors.primary,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    _buildCard(
                      title: 'Eligibility',
                      icon: Icons.people_outline,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildFieldLabel('Eligible services'),
                            InkWell(
                              onTap: () => setState(
                                () => _selectedServices = [
                                  'Bike',
                                  'Auto',
                                  'Cab',
                                  'Parcel',
                                ],
                              ),
                              child: Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: Text(
                                  'Select all',
                                  style: GoogleFonts.inter(
                                    color: context.colors.primary,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            _buildServicePill('Bike', Icons.two_wheeler),
                            const SizedBox(width: 8),
                            _buildServicePill('Auto', Icons.electric_rickshaw),
                            const SizedBox(width: 8),
                            _buildServicePill('Cab', Icons.local_taxi),
                            const SizedBox(width: 8),
                            _buildServicePill(
                              'Parcel',
                              Icons.inventory_2_outlined,
                            ),
                          ],
                        ),
                        if (_selectedServices.isEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 8, left: 4),
                            child: Text(
                              'Select at least one service',
                              style: GoogleFonts.inter(
                                color: context.colors.error,
                                fontSize: 10,
                              ),
                            ),
                          ),

                        const SizedBox(height: 16),
                        _buildFieldLabel('Audience'),
                        DropdownButtonFormField<String>(
                          initialValue: _audience,
                          icon: const Icon(
                            Icons.keyboard_arrow_down_rounded,
                            size: 20,
                          ),
                          decoration: _inputDecoration('Select audience')
                              .copyWith(
                                prefixIcon: Icon(
                                  Icons.people_outline,
                                  color: context.colors.textMuted,
                                  size: 16,
                                ),
                              ),
                          dropdownColor: Colors.white,
                          items: ['All riders', 'New riders', 'Existing riders']
                              .map(
                                (e) => DropdownMenuItem(
                                  value: e,
                                  child: Text(
                                    e,
                                    style: GoogleFonts.inter(fontSize: 12),
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (v) => setState(() => _audience = v!),
                        ),
                      ],
                    ),

                    _buildCard(
                      title: 'Validity and usage limits',
                      icon: Icons.calendar_today_outlined,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildFieldLabel('Starts'),
                                  InkWell(
                                    onTap: () async {
                                      final d = await showDatePicker(
                                        context: context,
                                        initialDate: _start,
                                        firstDate: DateTime.now(),
                                        lastDate: DateTime.now().add(
                                          const Duration(days: 365),
                                        ),
                                      );
                                      if (d != null) setState(() => _start = d);
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: context.colors.cardBorder,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            DateFormat(
                                              'dd MMM yyyy',
                                            ).format(_start),
                                            style: GoogleFonts.inter(
                                              color: context.colors.text,
                                              fontSize: 12,
                                            ),
                                          ),
                                          Icon(
                                            Icons.calendar_today_outlined,
                                            size: 14,
                                            color: context.colors.textMuted,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildFieldLabel('Expires'),
                                  InkWell(
                                    onTap: () async {
                                      final d = await showDatePicker(
                                        context: context,
                                        initialDate: _expiry,
                                        firstDate: _start,
                                        lastDate: DateTime.now().add(
                                          const Duration(days: 365),
                                        ),
                                      );
                                      if (d != null)
                                        setState(() => _expiry = d);
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: context.colors.cardBorder,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            DateFormat(
                                              'dd MMM yyyy',
                                            ).format(_expiry),
                                            style: GoogleFonts.inter(
                                              color: context.colors.text,
                                              fontSize: 12,
                                            ),
                                          ),
                                          Icon(
                                            Icons.calendar_today_outlined,
                                            size: 14,
                                            color: context.colors.textMuted,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildFieldLabel('Total uses'),
                                  TextFormField(
                                    controller: _totalUses,
                                    keyboardType: TextInputType.number,
                                    style: GoogleFonts.inter(
                                      color: context.colors.text,
                                      fontSize: 13,
                                    ),
                                    decoration: _inputDecoration('500'),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildFieldLabel('Per rider'),
                                  TextFormField(
                                    controller: _perRider,
                                    keyboardType: TextInputType.number,
                                    style: GoogleFonts.inter(
                                      color: context.colors.text,
                                      fontSize: 13,
                                    ),
                                    decoration: _inputDecoration('1'),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        Padding(
                          padding: const EdgeInsets.only(top: 12, left: 4),
                          child: Row(
                            children: [
                              Icon(
                                Icons.access_time_outlined,
                                size: 14,
                                color: context.colors.textMuted,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Offer will run for ${_expiry.difference(_start).inDays} days.',
                                style: GoogleFonts.inter(
                                  color: context.colors.textMuted,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    _buildCard(
                      title: 'Live Preview',
                      icon: Icons.visibility_outlined,
                      children: [
                        _OfferPreviewCard(
                          code: _code.text.isEmpty ? 'CODE' : _code.text,
                          valStr: _value.text.isEmpty
                              ? '0'
                              : (_type == 'flat'
                                    ? '₹${_value.text} OFF'
                                    : '${_value.text}% OFF'),
                          minStr: _min.text.isEmpty ? '₹0' : '₹${_min.text}',
                          services: _selectedServices,
                          expiry: _expiry,
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: context.colors.success.withValues(
                              alpha: 0.05,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.check_circle_rounded,
                                size: 14,
                                color: context.colors.success,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Offer details look good',
                                style: GoogleFonts.inter(
                                  color: context.colors.success,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Footer
          Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: context.colors.cardBorder)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 8,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: (_saving || _drafting)
                              ? null
                              : () => _save(draft: true),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            side: BorderSide(color: context.colors.primary),
                          ),
                          child: _drafting
                              ? const SizedBox(
                                  height: 14,
                                  width: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.save_outlined,
                                      size: 16,
                                      color: context.colors.primary,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Save as Draft',
                                      style: GoogleFonts.inter(
                                        color: context.colors.primary,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed:
                              (_saving ||
                                  _drafting ||
                                  _selectedServices.isEmpty)
                              ? null
                              : () => _save(draft: false),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: context.colors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            elevation: 0,
                          ),
                          child: _saving
                              ? const SizedBox(
                                  height: 14,
                                  width: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.send_rounded,
                                      size: 16,
                                      color: Colors.white,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Publish Offer',
                                      style: GoogleFonts.inter(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Offer will become active immediately after publishing.',
                    style: GoogleFonts.inter(
                      color: context.colors.textMuted,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.colors.cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: context.colors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 14, color: context.colors.primary),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: GoogleFonts.inter(
                  color: context.colors.text,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ...children,
        ],
      ),
    );
  }

  Widget _buildFieldLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        label,
        style: GoogleFonts.inter(
          color: context.colors.textMuted,
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildServicePill(String service, IconData icon) {
    final isSel = _selectedServices.contains(service);
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            if (isSel) {
              _selectedServices.remove(service);
            } else {
              _selectedServices.add(service);
            }
          });
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSel
                ? context.colors.primary.withValues(alpha: 0.05)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSel ? context.colors.primary : context.colors.cardBorder,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 12,
                color: isSel
                    ? context.colors.primary
                    : context.colors.textMuted,
              ),
              const SizedBox(width: 4),
              Text(
                service,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: isSel ? FontWeight.w600 : FontWeight.w500,
                  color: isSel ? context.colors.primary : context.colors.text,
                ),
              ),
              if (isSel) ...[
                const SizedBox(width: 4),
                Icon(
                  Icons.check_circle,
                  size: 12,
                  color: context.colors.primary,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _getSummaryText() {
    final v = _value.text.isEmpty ? '0' : _value.text;
    final m = _min.text.isEmpty ? '0' : _min.text;
    if (_type == 'flat') {
      return 'Riders save ₹$v on fares of ₹$m or more.';
    }
    return 'Riders save $v% on fares of ₹$m or more.';
  }

  InputDecoration _inputDecoration(
    String hint, {
    String? prefix,
    String? suffix,
    IconData? icon,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.inter(
        color: context.colors.textMuted,
        fontSize: 12,
      ),
      prefixText: prefix != null ? '$prefix ' : null,
      prefixStyle: GoogleFonts.inter(
        color: context.colors.text,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
      suffixText: suffix,
      suffixStyle: GoogleFonts.inter(
        color: context.colors.text,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
      prefixIcon: icon != null
          ? Icon(icon, color: context.colors.textMuted, size: 16)
          : null,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: context.colors.cardBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: context.colors.primary),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: context.colors.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: context.colors.error),
      ),
    );
  }

  Future<void> _save({required bool draft}) async {
    if (!draft && !(_formKey.currentState?.validate() ?? false)) return;
    if (!draft && _selectedServices.isEmpty) return;

    if (draft) {
      setState(() => _drafting = true);
    } else {
      setState(() => _saving = true);
    }

    try {
      await ref.read(adminRepositoryProvider).createOffer({
        'code': _code.text.trim().toUpperCase(),
        'description': _desc.text.trim(),
        'type': _type,
        'value': int.tryParse(_value.text.trim()) ?? 0,
        'minAmount': int.tryParse(_min.text.trim()) ?? 0,
        'startDate': Timestamp.fromDate(_start),
        'expiryDate': Timestamp.fromDate(_expiry),
        'eligibleServices': _selectedServices,
        'audience': _audience,
        'totalUses': int.tryParse(_totalUses.text.trim()),
        'perRiderUses': int.tryParse(_perRider.text.trim()),
        'status': draft ? 'draft' : 'published',
        'isActive': !draft, // Critical for user app visibility
      });
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: context.colors.success,
            content: Text(draft ? 'Draft saved!' : 'Offer published!'),
          ),
        );
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: context.colors.error,
            content: Text('Error: $e'),
          ),
        );
    } finally {
      if (mounted) {
        if (draft) {
          setState(() => _drafting = false);
        } else {
          setState(() => _saving = false);
        }
      }
    }
  }
}

class _OfferPreviewCard extends StatelessWidget {
  final String code;
  final String valStr;
  final String minStr;
  final List<String> services;
  final DateTime expiry;

  const _OfferPreviewCard({
    required this.code,
    required this.valStr,
    required this.minStr,
    required this.services,
    required this.expiry,
  });

  @override
  Widget build(BuildContext context) {
    return ClipPath(
      clipper: _TicketClipper(),
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF0B1F3A), Color(0xFF0044C7)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            stops: [0.65, 0.65],
          ),
        ),
        child: IntrinsicHeight(
          child: Row(
            children: [
              // Left part
              Expanded(
                flex: 65,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: Colors.white24,
                                style: BorderStyle.solid,
                              ),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Icon(
                              Icons.local_activity_outlined,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            code.toUpperCase(),
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          const Icon(
                            Icons.people_outline,
                            color: Colors.white54,
                            size: 14,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              services.isEmpty
                                  ? 'No services'
                                  : (services.length == 4
                                        ? 'All services'
                                        : services.join(' • ')),
                              style: GoogleFonts.inter(
                                color: Colors.white70,
                                fontSize: 11,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(
                            Icons.calendar_today_outlined,
                            color: Colors.white54,
                            size: 14,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Valid until ${DateFormat('d MMM yyyy').format(expiry)}',
                            style: GoogleFonts.inter(
                              color: Colors.white70,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              // Dashed divider
              CustomPaint(
                size: const Size(1, double.infinity),
                painter: _DashedLinePainter(),
              ),
              // Right part
              Expanded(
                flex: 35,
                child: Stack(
                  children: [
                    Positioned(
                      top: 12,
                      right: 12,
                      child: const Icon(
                        Icons.star,
                        color: Colors.amber,
                        size: 16,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 20, 24, 20),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            valStr,
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              height: 1.1,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'On rides of $minStr or more',
                            style: GoogleFonts.inter(
                              color: Colors.white70,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
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

class _DashedLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white24
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    double dashHeight = 4, dashSpace = 4, startY = 16;
    while (startY < size.height - 16) {
      canvas.drawLine(Offset(0, startY), Offset(0, startY + dashHeight), paint);
      startY += dashHeight + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _TicketClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    const radius = 12.0;

    path.moveTo(radius, 0);
    path.lineTo(size.width - radius, 0);
    path.arcToPoint(
      Offset(size.width, radius),
      radius: const Radius.circular(radius),
    );

    path.lineTo(size.width, size.height / 2 - 8);
    path.arcToPoint(
      Offset(size.width, size.height / 2 + 8),
      radius: const Radius.circular(8),
      clockwise: false,
    );

    path.lineTo(size.width, size.height - radius);
    path.arcToPoint(
      Offset(size.width - radius, size.height),
      radius: const Radius.circular(radius),
    );

    path.lineTo(radius, size.height);
    path.arcToPoint(
      Offset(0, size.height - radius),
      radius: const Radius.circular(radius),
    );

    path.lineTo(0, size.height / 2 + 8);
    path.arcToPoint(
      Offset(0, size.height / 2 - 8),
      radius: const Radius.circular(8),
      clockwise: false,
    );

    path.lineTo(0, radius);
    path.arcToPoint(Offset(radius, 0), radius: const Radius.circular(radius));

    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
