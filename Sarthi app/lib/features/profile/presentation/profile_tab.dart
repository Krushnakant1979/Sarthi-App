import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/design/tokens.dart';
import '../../auth/presentation/auth_providers.dart';

class ProfileTab extends ConsumerWidget {
  final void Function(int) onNavTapped;

  const ProfileTab({
    super.key,
    required this.onNavTapped,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);
    final authUser = ref.watch(authStateProvider).value;

    final name = userAsync.value?.name ?? 'Sarthi App User';
    final emailOrPhone = userAsync.value?.phone?.isNotEmpty == true
        ? userAsync.value!.phone!
        : (authUser?.email ?? '');

    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good morning'
        : hour < 17
        ? 'Good afternoon'
        : 'Good evening';

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 120),
        children: [
          // ── Header ────────────────────────────────────────────
          Text(
            '$greeting 👋',
            style: TextStyle(
              fontSize: 12,
              color: context.colors.textMuted,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'My Profile',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 16),

          // ── User Card ─────────────────────────────────────────
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: context.colors.cardBorder),
            ),
            child: Column(
              children: [
                InkWell(
                  onTap: () => context.push('/profile'),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(20),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        // Avatar — simple, clean, professional
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: context.colors.primary.withValues(alpha: 0.06),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: context.colors.primary.withValues(alpha: 0.15),
                              width: 1.5,
                            ),
                          ),
                          child: Icon(
                            Icons.person_rounded,
                            color: context.colors.primary,
                            size: 30,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.black,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                emailOrPhone,
                                style: TextStyle(
                                  color: context.colors.textMuted,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.chevron_right_rounded,
                          color: context.colors.hint,
                        ),
                      ],
                    ),
                  ),
                ),
                Divider(
                  height: 1,
                  color: context.colors.divider,
                  indent: 16,
                  endIndent: 16,
                ),
                InkWell(
                  onTap: () => context.push('/rating'),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.star_rounded,
                            color: Color(0xFFF59E0B),
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 14),
                        const Expanded(
                          child: Text(
                            'My Rating',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Text(
                          '5.0',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: context.colors.primary,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.chevron_right_rounded,
                          color: context.colors.hint,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ── Menu Items ────────────────────────────────────────
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: context.colors.cardBorder),
            ),
            child: Column(
              children: [
                _buildProfileListItem(context, 
                  Icons.help_outline_rounded,
                  'Help',
                  iconBg: const Color(0xFFEFF6FF),
                  iconColor: const Color(0xFF3B82F6),
                  onTap: () {
                    context.push('/support');
                  },
                ),
                _buildProfileListItem(context, 
                  Icons.history_rounded,
                  'My Rides',
                  iconBg: const Color(0xFFECFDF5),
                  iconColor: context.colors.success,
                  onTap: () {
                    onNavTapped(2);
                  },
                ),
                _buildProfileListItem(context, 
                  Icons.account_balance_wallet_outlined,
                  'Payment',
                  iconBg: const Color(0xFFF0FDF4),
                  iconColor: const Color(0xFF10B981),
                ),
                _buildProfileListItem(context, 
                  Icons.shield_outlined,
                  'Safety',
                  iconBg: const Color(0xFFFFF7ED),
                  iconColor: const Color(0xFFF97316),
                  onTap: () {
                    context.push('/safety');
                  },
                ),
                _buildProfileListItem(context, 
                  Icons.card_giftcard_rounded,
                  'Refer and Earn',
                  iconBg: const Color(0xFFFDF4FF),
                  iconColor: const Color(0xFFA855F7),
                ),
                _buildProfileListItem(context, 
                  Icons.workspace_premium_outlined,
                  'My Rewards',
                  iconBg: const Color(0xFFFEF9C3),
                  iconColor: const Color(0xFFCA8A04),
                ),
                _buildProfileListItem(context, 
                  Icons.monetization_on_outlined,
                  'Sarthi App Coins',
                  iconBg: const Color(0xFFFEF3C7),
                  iconColor: const Color(0xFFF59E0B),
                ),
                _buildProfileListItem(context, 
                  Icons.notifications_none_rounded,
                  'Notifications',
                  showBorder: false,
                  iconBg: const Color(0xFFEFF6FF),
                  iconColor: const Color(0xFF6366F1),
                  onTap: () {
                    context.push('/notifications');
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ── Sign Out ──────────────────────────────────────────
          InkWell(
            onTap: () async {
              await ref.read(authRepositoryProvider).signOut();
              if (context.mounted) context.go('/login');
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: context.colors.cardBorder),
              ),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: context.colors.error.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.logout_rounded,
                      color: context.colors.error,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      'Sign Out',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: context.colors.error,
                      ),
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

  Widget _buildProfileListItem(BuildContext context, 
    IconData icon,
    String title, {
    bool showBorder = true,
    VoidCallback? onTap,
    Color? iconBg,
    Color? iconColor,
  }) {
    final bg = iconBg ?? context.colors.iconBg;
    final ic = iconColor ?? context.colors.textMuted;
    return InkWell(
      onTap: onTap,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: ic, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: context.colors.hint,
                  size: 20,
                ),
              ],
            ),
          ),
          if (showBorder)
            Padding(
              padding: EdgeInsets.only(left: 68),
              child: Divider(height: 1, color: context.colors.divider),
            ),
        ],
      ),
    );
  }
}
