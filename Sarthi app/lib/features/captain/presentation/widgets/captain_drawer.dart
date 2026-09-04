import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/design/tokens.dart';
import '../captain_providers.dart';

class CaptainDrawer extends ConsumerWidget {
  final void Function(String) onCallNumber;

  const CaptainDrawer({super.key, required this.onCallNumber});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeRide = ref.watch(currentCaptainRideProvider).value;
    return Drawer(
      width: 215,
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          color: Colors.white.withValues(alpha: 0.85),
          child: SafeArea(
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  alignment: Alignment.centerLeft,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.local_taxi_rounded,
                        size: 48,
                        color: context.colors.primary,
                      ),
                      SizedBox(height: 12),
                      Text(
                        'Captain Panel',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: context.colors.primary,
                        ),
                      ),
                      Text(
                        'Manage your rides',
                        style: TextStyle(color: Color(0xFF6B7280)),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: Color(0xFFF3F4F6)),
                if (activeRide != null)
                  ListTile(
                    leading: const Icon(
                      Icons.navigation_rounded,
                      color: Color(0xFF2563EB),
                    ),
                    title: const Text(
                      'Active Ride',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      activeRide['status']?.toString().replaceAll('_', ' ') ??
                          'In progress',
                    ),
                    onTap: () => Scaffold.of(context).closeDrawer(),
                  ),
                ListTile(
                  leading: Icon(
                    Icons.history_rounded,
                    color: context.colors.primary,
                  ),
                  title: const Text(
                    'My Trips',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  onTap: () {
                    Scaffold.of(context).closeDrawer();
                    context.push('/captain/trips');
                  },
                ),
                ListTile(
                  leading: Icon(
                    Icons.person_rounded,
                    color: context.colors.primary,
                  ),
                  title: const Text(
                    'My Profile',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  onTap: () {
                    Scaffold.of(context).closeDrawer();
                    context.push('/captain/profile');
                  },
                ),
                ListTile(
                  leading: Icon(
                    Icons.support_agent_rounded,
                    color: context.colors.primary,
                  ),
                  title: const Text(
                    'Support',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  onTap: () {
                    Scaffold.of(context).closeDrawer();
                    context.push('/support');
                  },
                ),
                const Spacer(),
                const Divider(height: 1, color: Color(0xFFF3F4F6)),
                ListTile(
                  leading: Icon(
                    Icons.logout_rounded,
                    color: context.colors.error,
                  ),
                  title: Text(
                    'Log Out',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: context.colors.error,
                    ),
                  ),
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
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
