import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/design/tokens.dart';
import '../../../shared/auth/presentation/auth_providers.dart';

class ProfileTab extends ConsumerWidget {
  final void Function(int) onNavTapped;

  const ProfileTab({super.key, required this.onNavTapped});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);
    final authUser = ref.watch(authStateProvider).value;

    final name = userAsync.value?.name ?? 'Sarthi App User';
    final emailOrPhone = userAsync.value?.phone?.isNotEmpty == true
        ? userAsync.value!.phone!
        : (authUser?.email ?? '');

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
        children: [
          // ── Top Header Row ────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Sarthi Logo
              Row(
                children: [
                  Image.asset(
                    'assets/app-logo/Sarthi app user logo.png',
                    height: 20,
                    errorBuilder: (context, error, stackTrace) =>
                        const Icon(Icons.bolt, color: Colors.amber, size: 24),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Sarthi',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              // Action Icons
              Row(
                children: [
                  Stack(
                    children: [
                      IconButton(
                        padding: const EdgeInsets.all(8),
                        constraints: const BoxConstraints(),
                        onPressed: () {},
                        icon: const Icon(
                          Icons.notifications_none_rounded,
                          size: 20,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      Positioned(
                        right: 8,
                        top: 8,
                        child: Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    padding: const EdgeInsets.all(8),
                    constraints: const BoxConstraints(),
                    onPressed: () {},
                    icon: const Icon(
                      Icons.help_outline_rounded,
                      size: 20,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          // ── Title & Subtitle ──────────────────────────────────
          const Text(
            'My Profile',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            'Manage your account and preferences',
            style: TextStyle(
              fontSize: 11,
              color: Color(0xFF6B7280),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),

          // ── Premium User Card ─────────────────────────────────
          Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0B2144), Color(0xFF001224)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      // Avatar with badge
                      Stack(
                        children: [
                          Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.2),
                                width: 1.5,
                              ),
                            ),
                            child: const Icon(
                              Icons.person_rounded,
                              color: Colors.white,
                              size: 32,
                            ),
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(3),
                              decoration: const BoxDecoration(
                                color: Color(0xFFFBBF24),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.camera_alt_rounded,
                                color: Color(0xFF001224),
                                size: 10,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 12),
                      // Name and Phone
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  name.split(' ')[0], // First name
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(
                                  Icons.verified,
                                  color: Color(0xFF3B82F6),
                                  size: 14,
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              emailOrPhone,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.7),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Edit Button
                      InkWell(
                        onTap: () => context.push('/profile'),
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.3),
                            ),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            'Edit profile',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Divider(height: 1, color: Colors.white.withValues(alpha: 0.1)),
                InkWell(
                  onTap: () => context.push('/rating'),
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFFF59E0B,
                            ).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Icon(
                            Icons.star_rounded,
                            color: Color(0xFFF59E0B),
                            size: 14,
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'My Rating',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const Text(
                          '5.0',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(
                          Icons.chevron_right_rounded,
                          color: Colors.white.withValues(alpha: 0.5),
                          size: 14,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── Activity & payments ───────────────────────────────
          _buildSectionHeader('Activity & payments'),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: context.colors.cardBorder),
            ),
            child: Column(
              children: [
                _buildProfileListItem(
                  context,
                  Icons.history_rounded,
                  'My Rides',
                  subtitle: 'View your ride history',
                  iconBg: const Color(0xFFECFDF5),
                  iconColor: context.colors.success,
                  onTap: () => onNavTapped(2),
                ),
                _buildProfileListItem(
                  context,
                  Icons.account_balance_wallet_outlined,
                  'Payment',
                  subtitle: 'Manage payment methods',
                  iconBg: const Color(0xFFECFDF5),
                  iconColor: context.colors.success,
                  showBorder: false,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── Rewards ───────────────────────────────────────────
          _buildSectionHeader('Rewards'),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: context.colors.cardBorder),
            ),
            child: Column(
              children: [
                _buildProfileListItem(
                  context,
                  Icons.card_giftcard_rounded,
                  'Refer and Earn',
                  iconBg: const Color(0xFFFDF4FF),
                  iconColor: const Color(0xFFA855F7),
                ),
                _buildProfileListItem(
                  context,
                  Icons.workspace_premium_outlined,
                  'My Rewards',
                  iconBg: const Color(0xFFFEF9C3),
                  iconColor: const Color(0xFFCA8A04),
                ),
                _buildProfileListItem(
                  context,
                  Icons.monetization_on_outlined,
                  'Sarthi App Coins',
                  iconBg: const Color(0xFFFEF3C7),
                  iconColor: const Color(0xFFF59E0B),
                  showBorder: false,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── Support & safety ──────────────────────────────────
          _buildSectionHeader('Support & safety'),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: context.colors.cardBorder),
            ),
            child: Column(
              children: [
                _buildProfileListItem(
                  context,
                  Icons.help_outline_rounded,
                  'Help',
                  subtitle: 'FAQs and customer support',
                  iconBg: const Color(0xFFEFF6FF),
                  iconColor: const Color(0xFF3B82F6),
                  onTap: () => context.push('/support'),
                ),
                _buildProfileListItem(
                  context,
                  Icons.shield_outlined,
                  'Safety',
                  subtitle: 'Emergency and ride safety',
                  iconBg: const Color(0xFFFFF7ED),
                  iconColor: const Color(0xFFF97316),
                  onTap: () => context.push('/safety'),
                ),
                _buildProfileListItem(
                  context,
                  Icons.notifications_none_rounded,
                  'Notifications',
                  iconBg: const Color(0xFFEFF6FF),
                  iconColor: const Color(0xFF6366F1),
                  showBorder: false,
                  trailingWidget: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 2,
                    ),
                    decoration: const BoxDecoration(
                      color: Color(0xFF0F172A),
                      shape: BoxShape.circle,
                    ),
                    child: const Text(
                      '2',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  onTap: () => context.push('/notifications'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── Sign Out ──────────────────────────────────────────
          InkWell(
            onTap: () async {
              await ref.read(authRepositoryProvider).signOut();
              if (context.mounted) context.go('/login');
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.5),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.logout_rounded,
                    color: Color(0xFFEF4444),
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Sign Out',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFEF4444),
                    ),
                  ),
                  const Spacer(),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: Color(0xFFEF4444),
                    size: 18,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 6),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Color(0xFF4B5563),
        ),
      ),
    );
  }

  Widget _buildProfileListItem(
    BuildContext context,
    IconData icon,
    String title, {
    String? subtitle,
    bool showBorder = true,
    VoidCallback? onTap,
    Color? iconBg,
    Color? iconColor,
    Widget? trailingWidget,
  }) {
    final bg = iconBg ?? context.colors.iconBg;
    final ic = iconColor ?? context.colors.textMuted;
    return InkWell(
      onTap: onTap,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: ic, size: 16),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF111827),
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (trailingWidget != null) ...[
                  trailingWidget,
                  const SizedBox(width: 8),
                ],
                Icon(
                  Icons.chevron_right_rounded,
                  color: context.colors.hint,
                  size: 16,
                ),
              ],
            ),
          ),
          if (showBorder)
            Padding(
              padding: const EdgeInsets.only(left: 56),
              child: Divider(height: 1, color: context.colors.cardBorder),
            ),
        ],
      ),
    );
  }
}
