import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../shared/auth/presentation/auth_providers.dart';
import '../admin_design.dart';
import '../admin_providers.dart';
import '../screens/support_screen.dart';
import '../screens/analytics_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/pricing_screen.dart';
import '../screens/offers_screen.dart';
import '../screens/admin_profile_screen.dart';
import '../screens/finance_screen.dart';
import '../screens/captains_screen.dart';
import '../screens/marketing_screen.dart';
import '../screens/reviews_screen.dart';
import '../screens/vehicles_screen.dart';

// Brand Colors matching the UI exactly
const _navy = Color(0xFF0B1F3A);
const _bg = Color(0xFFF4F7FB);
const _card = Colors.white;
const _text = Color(0xFF1E293B);
const _muted = Color(0xFF64748B);
const _border = Color(0xFFE2E8F0);
const _primary = Color(0xFF2563EB);

const _cYellow = Color(0xFFF59E0B);
const _cGreen = Color(0xFF10B981);
const _cRed = Color(0xFFEF4444);
const _cBlue = Color(0xFF3B82F6);
const _cPurple = Color(0xFF8B5CF6);

class MenuTab extends ConsumerStatefulWidget {
  const MenuTab({super.key});
  @override
  ConsumerState<MenuTab> createState() => _MenuTabState();
}

class _MenuTabState extends ConsumerState<MenuTab> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isSearching = _searchQuery.trim().isNotEmpty;

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: RefreshIndicator(
          color: _primary,
          onRefresh: () async {
            ref.invalidate(currentUserProvider);
          },
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: ResponsiveCenter(
                  maxWidth: 900,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const _UserProfileBanner(),
                        const SizedBox(height: 16),
                        _SearchBar(
                          controller: _searchCtrl,
                          onChanged: (val) => setState(() => _searchQuery = val),
                          onClear: () {
                            _searchCtrl.clear();
                            setState(() => _searchQuery = '');
                          },
                        ),
                        const SizedBox(height: 20),
                        if (!isSearching) ...[
                          const _QuickActionsSection(),
                          const SizedBox(height: 20),
                        ],
                        _AdminToolsSection(searchQuery: _searchQuery),
                        if (!isSearching) ...[
                          const SizedBox(height: 20),
                          const _AccountSecuritySection(),
                          const SizedBox(height: 20),
                          const _AppInfoSection(),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UserProfileBanner extends ConsumerWidget {
  const _UserProfileBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);
    final user = userAsync.value;
    final name = user?.name.isNotEmpty == true ? user!.name : 'Admin';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'A';
    final isNarrow = AdminResponsive.isNarrow(context);

    return Container(
      padding: EdgeInsets.all(isNarrow ? 12 : 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F2027), Color(0xFF142F4B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: _navy.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: isNarrow ? 40 : 48,
            height: isNarrow ? 40 : 48,
            decoration: BoxDecoration(
              color: const Color(0xFFFBBF24),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.2),
                width: 2.5,
              ),
            ),
            child: Center(
              child: Text(
                initial,
                style: GoogleFonts.inter(
                  color: _navy,
                  fontSize: isNarrow ? 16 : 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          SizedBox(width: isNarrow ? 10 : 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: isNarrow ? 14 : 16,
                    fontWeight: FontWeight.w800,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(
                      Icons.shield_outlined,
                      color: Colors.white70,
                      size: 10,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Super Admin',
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 5,
                      height: 5,
                      decoration: const BoxDecoration(
                        color: _cGreen,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Online',
                      style: GoogleFonts.inter(
                        color: Colors.white70,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Full platform access',
                  style: GoogleFonts.inter(color: Colors.white54, fontSize: 10),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AdminProfileScreen()),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Colors.white54),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: EdgeInsets.symmetric(
                horizontal: isNarrow ? 8 : 12,
                vertical: isNarrow ? 6 : 8,
              ),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              'View Profile',
              style: GoogleFonts.inter(
                fontSize: isNarrow ? 9 : 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  const _SearchBar({
    required this.controller,
    required this.onChanged,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          const Icon(Icons.search_rounded, color: _muted, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              style: GoogleFonts.inter(color: _text, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Search admin tools (pricing, support, finance...)...',
                hintStyle: GoogleFonts.inter(color: _muted, fontSize: 12),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          if (controller.text.isNotEmpty)
            GestureDetector(
              onTap: onClear,
              child: const Icon(Icons.clear_rounded, color: _muted, size: 16),
            ),
        ],
      ),
    );
  }
}

class _QuickActionsSection extends ConsumerWidget {
  const _QuickActionsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ticketsAsync = ref.watch(supportTicketsProvider);
    final openTickets = (ticketsAsync.value ?? [])
        .where((t) => (t['status'] as String? ?? 'open').toLowerCase() == 'open')
        .length;

    final cardOffers = _QuickActionCard(
      title: 'Create Offer',
      subtitle: 'Add new offer',
      icon: Icons.local_offer_rounded,
      color: const Color(0xFFF59E0B),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const OffersScreen()),
      ),
    );

    final cardPricing = _QuickActionCard(
      title: 'Update Pricing',
      subtitle: 'Change base fares',
      icon: Icons.currency_rupee_rounded,
      color: const Color(0xFF10B981),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const PricingScreen()),
      ),
    );

    final cardComplaints = _QuickActionCard(
      title: 'Complaints',
      subtitle: 'Review & resolve',
      icon: Icons.headset_mic_rounded,
      color: const Color(0xFFEF4444),
      badgeText: openTickets > 0 ? '$openTickets' : null,
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const SupportScreen()),
      ),
    );

    final cardUsers = _QuickActionCard(
      title: 'Captains & Fleet',
      subtitle: 'Verify & manage',
      icon: Icons.local_taxi_rounded,
      color: const Color(0xFF3B82F6),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const CaptainsScreen()),
      ),
    );

    final isWide = AdminResponsive.isWide(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Quick Actions',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: _navy,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (isWide) ...[
          Row(
            children: [
              Expanded(child: cardOffers),
              const SizedBox(width: 10),
              Expanded(child: cardPricing),
              const SizedBox(width: 10),
              Expanded(child: cardComplaints),
              const SizedBox(width: 10),
              Expanded(child: cardUsers),
            ],
          ),
        ] else ...[
          Row(
            children: [
              Expanded(child: cardOffers),
              const SizedBox(width: 10),
              Expanded(child: cardPricing),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: cardComplaints),
              const SizedBox(width: 10),
              Expanded(child: cardUsers),
            ],
          ),
        ],
      ],
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  const _QuickActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    this.badgeText,
    required this.onTap,
  });
  final String title, subtitle;
  final IconData icon;
  final Color color;
  final String? badgeText;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isNarrow = AdminResponsive.isNarrow(context);

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        padding: EdgeInsets.all(isNarrow ? 8 : 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(isNarrow ? 6 : 8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: isNarrow ? 14 : 16),
            ),
            SizedBox(width: isNarrow ? 6 : 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: GoogleFonts.inter(
                            fontSize: isNarrow ? 10 : 11,
                            fontWeight: FontWeight.w700,
                            color: _navy,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (badgeText != null) ...[
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 2,
                          ),
                          decoration: const BoxDecoration(
                            color: _cRed,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            badgeText!,
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      fontSize: isNarrow ? 8 : 9,
                      fontWeight: FontWeight.w500,
                      color: _muted,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right_rounded, color: _muted, size: 14),
          ],
        ),
      ),
    );
  }
}

class _ToolData {
  final String title;
  final String subtitle;
  final String keywords;
  final IconData icon;
  final Color color;
  final Widget? badgeWidget;
  final void Function(BuildContext) onTap;

  const _ToolData({
    required this.title,
    required this.subtitle,
    required this.keywords,
    required this.icon,
    required this.color,
    this.badgeWidget,
    required this.onTap,
  });
}

class _AdminToolsSection extends ConsumerWidget {
  final String searchQuery;
  const _AdminToolsSection({this.searchQuery = ''});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ticketsAsync = ref.watch(supportTicketsProvider);
    final openTickets = (ticketsAsync.value ?? [])
        .where((t) => (t['status'] as String? ?? 'open').toLowerCase() == 'open')
        .length;

    final q = searchQuery.trim().toLowerCase();

    final allTools = <_ToolData>[
      _ToolData(
        title: 'Captains Management',
        subtitle: 'Verify drivers, documents and onboarding',
        keywords: 'captains drivers verify onboarding licence kyc verification',
        icon: Icons.badge_rounded,
        color: _cPurple,
        onTap: (ctx) => Navigator.push(ctx, MaterialPageRoute(builder: (_) => const CaptainsScreen())),
      ),
      _ToolData(
        title: 'Finance & Payouts',
        subtitle: 'Platform commission and driver settlements',
        keywords: 'finance payouts money commission driver settlements wallet banking earnings',
        icon: Icons.account_balance_wallet_rounded,
        color: _cGreen,
        onTap: (ctx) => Navigator.push(ctx, MaterialPageRoute(builder: (_) => const FinanceScreen())),
      ),
      _ToolData(
        title: 'Analytics & Heatmaps',
        subtitle: 'Revenue, rides and live demand',
        keywords: 'analytics heatmaps revenue rides live demand metrics statistics kpi charts',
        icon: Icons.bar_chart_rounded,
        color: _cBlue,
        badgeWidget: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: BoxDecoration(
            color: _cGreen.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            'Live',
            style: GoogleFonts.inter(
              color: _cGreen,
              fontSize: 9,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        onTap: (ctx) => Navigator.push(ctx, MaterialPageRoute(builder: (_) => const AnalyticsScreen())),
      ),
      _ToolData(
        title: 'Pricing & Surge',
        subtitle: 'Base fares, fees and surge rules',
        keywords: 'pricing surge rates base fares fees tariffs distance per km peak pricing',
        icon: Icons.currency_rupee_rounded,
        color: _cGreen,
        onTap: (ctx) => Navigator.push(ctx, MaterialPageRoute(builder: (_) => const PricingScreen())),
      ),
      _ToolData(
        title: 'Fleet & Vehicles',
        subtitle: 'Cabs, autos, bikes and parcel fleet',
        keywords: 'fleet vehicles cabs autos bikes parcel delivery categories motors transport',
        icon: Icons.directions_car_rounded,
        color: _cBlue,
        onTap: (ctx) => Navigator.push(ctx, MaterialPageRoute(builder: (_) => const VehiclesScreen())),
      ),
      _ToolData(
        title: 'Marketing & Broadcast Hub',
        subtitle: 'Send announcements, push and SMS campaigns',
        keywords: 'marketing broadcast announcements push notifications sms campaigns messages alerts promo banner',
        icon: Icons.campaign_rounded,
        color: _cYellow,
        onTap: (ctx) => Navigator.push(ctx, MaterialPageRoute(builder: (_) => const MarketingScreen())),
      ),
      _ToolData(
        title: 'Trip Reviews & Moderation',
        subtitle: 'Inspect low ratings and moderate rider feedback',
        keywords: 'trip reviews moderation ratings feedback stars comments low rated complaints rider captain',
        icon: Icons.rate_review_rounded,
        color: const Color(0xFFF97316),
        onTap: (ctx) => Navigator.push(ctx, MaterialPageRoute(builder: (_) => const ReviewsScreen())),
      ),
      _ToolData(
        title: 'Settings & Zones',
        subtitle: 'Service areas and platform controls',
        keywords: 'settings zones service areas geo fencing platform configuration controls boundaries',
        icon: Icons.location_on_rounded,
        color: _muted,
        onTap: (ctx) => Navigator.push(ctx, MaterialPageRoute(builder: (_) => const SettingsScreen())),
      ),
      _ToolData(
        title: 'Offers & Promotions',
        subtitle: 'Discounts, campaigns and coupons',
        keywords: 'offers promotions coupons discounts promo codes deals vouchers referral',
        icon: Icons.local_offer_rounded,
        color: _cYellow,
        onTap: (ctx) => Navigator.push(ctx, MaterialPageRoute(builder: (_) => const OffersScreen())),
      ),
      _ToolData(
        title: 'Support & Complaints',
        subtitle: 'Review and resolve reported issues',
        keywords: 'support complaints tickets help desk issues customer driver resolution helpline dispute',
        icon: Icons.headset_mic_rounded,
        color: _cRed,
        badgeWidget: openTickets > 0
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: _cYellow.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '$openTickets Open',
                  style: GoogleFonts.inter(
                    color: const Color(0xFFD97706),
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              )
            : null,
        onTap: (ctx) => Navigator.push(ctx, MaterialPageRoute(builder: (_) => const SupportScreen())),
      ),
    ];

    final filtered = q.isEmpty
        ? allTools
        : allTools.where((t) =>
            t.title.toLowerCase().contains(q) ||
            t.subtitle.toLowerCase().contains(q) ||
            t.keywords.toLowerCase().contains(q)).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              q.isEmpty ? 'Admin Tools' : 'Matching Tools (${filtered.length})',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: _navy,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: filtered.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: Text(
                      'No admin tools match "$searchQuery"',
                      style: GoogleFonts.inter(color: _muted, fontSize: 13),
                    ),
                  ),
                )
              : Column(
                  children: [
                    for (int i = 0; i < filtered.length; i++) ...[
                      if (i > 0) const Divider(height: 1, color: _border, indent: 48),
                      _ToolTile(
                        title: filtered[i].title,
                        subtitle: filtered[i].subtitle,
                        icon: filtered[i].icon,
                        color: filtered[i].color,
                        badgeWidget: filtered[i].badgeWidget,
                        onTap: () => filtered[i].onTap(context),
                      ),
                    ],
                  ],
                ),
        ),
      ],
    );
  }
}

class _ToolTile extends StatelessWidget {
  const _ToolTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    this.titleColor,
    this.badgeWidget,
    required this.onTap,
  });
  final String title, subtitle;
  final IconData icon;
  final Color color;
  final Color? titleColor;
  final Widget? badgeWidget;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 16),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: titleColor ?? _navy,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: _muted,
                      ),
                    ),
                  ],
                ),
              ),
              if (badgeWidget != null) ...[
                badgeWidget!,
                const SizedBox(width: 8),
              ],
              const Icon(Icons.chevron_right_rounded, color: _muted, size: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _AccountSecuritySection extends ConsumerWidget {
  const _AccountSecuritySection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Account & Security',
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: _navy,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              _ToolTile(
                title: 'Admin Profile',
                subtitle: 'Personal details and access level',
                icon: Icons.shield_rounded,
                color: _cPurple,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AdminProfileScreen()),
                ),
              ),
              const Divider(height: 1, color: _border, indent: 48),
              _ToolTile(
                title: 'Notifications',
                subtitle: 'Alerts, updates and preferences',
                icon: Icons.notifications_rounded,
                color: _cBlue,
                badgeWidget: Container(
                  padding: const EdgeInsets.all(5),
                  decoration: const BoxDecoration(
                    color: _cYellow,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '2',
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                onTap: () {},
              ),
              const Divider(height: 1, color: _border, indent: 48),
              _ToolTile(
                title: 'Security Settings',
                subtitle: 'Password, sessions and authentication',
                icon: Icons.lock_rounded,
                color: _navy,
                onTap: () {},
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFFEF2F2),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFFECACA)),
          ),
          child: _ToolTile(
            title: 'Sign Out',
            subtitle: 'Sign out from this device',
            icon: Icons.logout_rounded,
            color: _cRed,
            titleColor: _cRed,
            onTap: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  backgroundColor: _card,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  title: Text(
                    'Sign Out',
                    style: GoogleFonts.inter(
                      color: _navy,
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                  content: Text(
                    'Are you sure you want to sign out?',
                    style: GoogleFonts.inter(color: _muted, fontSize: 12),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: Text(
                        'Cancel',
                        style: GoogleFonts.inter(
                          color: _muted,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _cRed,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        'Sign Out',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              );
              if (confirm == true) {
                ref.read(authRepositoryProvider).signOut();
              }
            },
          ),
        ),
      ],
    );
  }
}

class _AppInfoSection extends StatelessWidget {
  const _AppInfoSection();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'App Information',
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: _navy,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.info_outline_rounded, color: _muted, size: 16),
              const SizedBox(width: 10),
              Text(
                'Sarthi Admin',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: _text,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.local_offer_outlined, color: _muted, size: 16),
              const SizedBox(width: 10),
              Text(
                'Version 1.0.0',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: _text,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Privacy & Terms',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: _primary,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: _primary,
                  size: 14,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
