import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../auth/presentation/auth_providers.dart';
import 'admin_providers.dart';
import 'admin_design.dart';
import 'tabs/overview_tab.dart';
import 'tabs/rides_tab.dart';
import 'tabs/users_tab.dart';
import 'tabs/menu_tab.dart';
import 'widgets/admin_common_widgets.dart';


// ─── Design Tokens ────────────────────────────────────────────────────────────
class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        backgroundColor: context.colors.background,
        appBar: AppBar(
          backgroundColor: context.colors.surface,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          titleSpacing: 20,
          toolbarHeight: 70,
          title: Row(children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [context.colors.adminAccent, context.colors.adminAccentDark], begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.bolt_rounded, color: context.colors.background, size: 20),
            ),
            const SizedBox(width: 12),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('RapidGo Admin', style: TextStyle(color: context.colors.text, fontWeight: FontWeight.w800, fontSize: 16, letterSpacing: 0.3)),
              Text('Operations Console', style: TextStyle(color: context.colors.textMuted, fontSize: 11, letterSpacing: 0.5)),
            ]),
          ]),
          actions: [
            IconAction(
              tooltip: 'Refresh data', icon: Icons.refresh_rounded,
              onPressed: () { ref.invalidate(allRidesProvider); ref.invalidate(allUsersProvider); },
            ),
            const SizedBox(width: 6),
            PopupMenuButton<String>(
              tooltip: 'Admin account',
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              color: context.colors.surfaceAlt, offset: const Offset(0, 50),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                child: Row(children: [
                  Container(
                    width: 34, height: 34,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [context.colors.adminAccent, context.colors.adminAccentDark], begin: Alignment.topLeft, end: Alignment.bottomRight),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.admin_panel_settings_rounded, color: context.colors.background, size: 18),
                  ),
                  const SizedBox(width: 6),
                  Icon(Icons.keyboard_arrow_down_rounded, color: context.colors.textMuted, size: 18),
                ]),
              ),
              onSelected: (value) async {
                if (value == 'logout') {
                  await ref.read(authRepositoryProvider).signOut();
                  if (context.mounted) context.go('/login');
                }
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                  enabled: false,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(FirebaseAuth.instance.currentUser?.email ?? 'Administrator', style: TextStyle(color: context.colors.text, fontWeight: FontWeight.w600, fontSize: 13)),
                    Text('System Administrator', style: TextStyle(color: context.colors.textMuted, fontSize: 11)),
                  ]),
                ),
                const PopupMenuDivider(),
                PopupMenuItem(value: 'logout', child: Row(children: [
                  Icon(Icons.logout_rounded, color: context.colors.error, size: 18),
                  SizedBox(width: 10),
                  Text('Sign out', style: TextStyle(color: context.colors.error, fontWeight: FontWeight.w600)),
                ])),
              ],
            ),
            const SizedBox(width: 16),
          ],
        ),
        extendBody: true,
        body: const TabBarView(children: [OverviewTab(), RidesTab(), UsersTab(), MenuTab()]),
        bottomNavigationBar: SafeArea(
          child: Container(
            margin: const EdgeInsets.only(bottom: 20, left: 24, right: 24),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(40),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 20, offset: const Offset(0, 10))
              ],
            ),
            child: TabBar(
              dividerColor: Colors.transparent,
              overlayColor: WidgetStateProperty.all(Colors.transparent),
              indicator: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(30),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              labelColor: Colors.black,
              unselectedLabelColor: Colors.black54,
              labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 10, letterSpacing: 0.2),
              unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 10),
              tabs: const [
                Tab(icon: Icon(Icons.dashboard_rounded, size: 22), text: 'Overview', iconMargin: EdgeInsets.only(bottom: 2), height: 50),
                Tab(icon: Icon(Icons.local_taxi_rounded, size: 22), text: 'Rides', iconMargin: EdgeInsets.only(bottom: 2), height: 50),
                Tab(icon: Icon(Icons.people_alt_rounded, size: 22), text: 'Users', iconMargin: EdgeInsets.only(bottom: 2), height: 50),
                Tab(icon: Icon(Icons.menu_rounded, size: 22), text: 'Menu', iconMargin: EdgeInsets.only(bottom: 2), height: 50),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

enum RideRange { today, last30Days, all }


// ─── Utilities ────────────────────────────────────────────────────────────────
DateTime? rideDate(Map<String, dynamic> ride) { final value = ride['createdAt']; if (value is Timestamp) return value.toDate(); if (value is DateTime) return value; if (value is String) return DateTime.tryParse(value); return null; }
bool sameDay(DateTime? a, DateTime b) => a != null && a.year == b.year && a.month == b.month && a.day == b.day;
String pretty(String value) => value.replaceAll('_', ' ').split(' ').map((word) => word.isEmpty ? word : '${word[0].toUpperCase()}${word.substring(1)}').join(' ');
Color statusColor(BuildContext context, String status) => switch (status) { 'completed' => context.colors.success, 'cancelled' => context.colors.error, 'in_progress' => context.colors.adminInfo, 'accepted' || 'arriving' || 'arrived' => context.colors.adminInfo, _ => context.colors.warning };
String friendlyError(Object error) { final text = error.toString().replaceFirst('Exception: ', '').replaceFirst('Bad state: ', ''); if (text.contains('permission-denied')) return 'Permission denied. Confirm that the latest Firestore rules are deployed.'; return text; }
