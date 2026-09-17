import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import '../captain_providers.dart';

class CaptainDrawer extends ConsumerWidget {
  final void Function(String) onCallNumber;

  const CaptainDrawer({super.key, required this.onCallNumber});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeRide = ref.watch(currentCaptainRideProvider).value;
    return Drawer(
      width: 240,
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          color: Colors.white.withValues(alpha: 0.92),
          child: SafeArea(
            child: Column(
              children: [
                // ── Premium header ─────────────────────────────────
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF0B2144), Color(0xFF1A3A6B)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Avatar circle
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.3),
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.2),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.electric_rickshaw_rounded,
                          size: 28,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'Captain Panel',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: -0.4,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Manage your rides',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.65),
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 8),

                // ── Active ride tile ────────────────────────────────
                if (activeRide != null)
                  _buildDrawerTile(
                    context,
                    icon: Icons.navigation_rounded,
                    iconColor: const Color(0xFF2563EB),
                    label: 'Active Ride',
                    subtitle: activeRide['status']
                            ?.toString()
                            .replaceAll('_', ' ')
                            .capitalizeFirst() ??
                        'In progress',
                    onTap: () => Scaffold.of(context).closeDrawer(),
                  ),

                // ── Nav tiles ───────────────────────────────────────
                _buildDrawerTile(
                  context,
                  icon: Icons.history_rounded,
                  iconColor: const Color(0xFF2563EB),
                  label: 'My Trips',
                  onTap: () {
                    Scaffold.of(context).closeDrawer();
                    context.push('/captain/trips');
                  },
                ),
                _buildDrawerTile(
                  context,
                  icon: Icons.person_rounded,
                  iconColor: const Color(0xFF2563EB),
                  label: 'My Profile',
                  onTap: () {
                    Scaffold.of(context).closeDrawer();
                    context.push('/captain/profile');
                  },
                ),
                _buildDrawerTile(
                  context,
                  icon: Icons.support_agent_rounded,
                  iconColor: const Color(0xFF2563EB),
                  label: 'Support',
                  onTap: () {
                    Scaffold.of(context).closeDrawer();
                    context.push('/support');
                  },
                ),

                const Spacer(),

                // ── Logout ──────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                  child: GestureDetector(
                    onTap: () async {
                      Scaffold.of(context).closeDrawer();
                      final uid = FirebaseAuth.instance.currentUser?.uid;
                      if (uid != null) {
                        await ref
                            .read(captainRepositoryProvider)
                            .setAvailability(uid, false);
                      }
                      await FirebaseAuth.instance.signOut();
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: const Color(0xFFEF4444).withValues(alpha: 0.3),
                          width: 1.5,
                        ),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.logout_rounded,
                            color: Color(0xFFEF4444),
                            size: 18,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Log Out',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: Color(0xFFEF4444),
                              fontSize: 14,
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
        ),
      ),
    );
  }

  Widget _buildDrawerTile(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String label,
    String? subtitle,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: iconColor, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 1),
                        Text(
                          subtitle,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF6B7280),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: Color(0xFFCBD5E1),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

extension _StringExt on String {
  String capitalizeFirst() =>
      isEmpty ? this : '${this[0].toUpperCase()}${substring(1)}';
}
