import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../shared/auth/presentation/auth_providers.dart';
import 'admin_providers.dart';
import 'admin_design.dart';
import 'tabs/overview_tab.dart';
import 'tabs/rides_tab.dart';
import 'tabs/users_tab.dart';
import 'tabs/menu_tab.dart';
import 'package:google_fonts/google_fonts.dart';

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
          backgroundColor: AdminColors.background,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          titleSpacing: 16,
          toolbarHeight: 56,
          title: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AdminColors.primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.bolt_rounded,
                  color: AdminColors.accent,
                  size: 20,
                ),
              ),
              SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Sarthi Admin',
                    style: GoogleFonts.inter(
                      color: AdminColors.textPrimary,
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      letterSpacing: -0.3,
                    ),
                  ),
                  Text(
                    'Operations Console',
                    style: GoogleFonts.inter(
                      color: AdminColors.textSecondary,
                      fontSize: 10,
                      letterSpacing: 0,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: AdminColors.card,
                    shape: BoxShape.circle,
                    border: Border.all(color: AdminColors.border),
                  ),
                  child: IconButton(
                    tooltip: 'Notifications / Refresh',
                    icon: const Icon(
                      Icons.notifications_none_rounded,
                      color: AdminColors.textPrimary,
                      size: 20,
                    ),
                    onPressed: () {
                      ref.invalidate(allRidesProvider);
                      ref.invalidate(allUsersProvider);
                    },
                  ),
                ),
                Positioned(
                  top: 10,
                  right: 14,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: AdminColors.accent,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(width: 4),
            PopupMenuButton<String>(
              tooltip: 'Admin account',
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              color: AdminColors.card,
              offset: const Offset(0, 50),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: const BoxDecoration(
                        color: AdminColors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.person_rounded,
                        color: AdminColors.card,
                        size: 18,
                      ),
                    ),
                    SizedBox(width: 4),
                    const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: AdminColors.textSecondary,
                      size: 16,
                    ),
                  ],
                ),
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        FirebaseAuth.instance.currentUser?.email ??
                            'Administrator',
                        style: GoogleFonts.inter(
                          color: AdminColors.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        'System Administrator',
                        style: GoogleFonts.inter(
                          color: AdminColors.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                const PopupMenuDivider(),
                PopupMenuItem(
                  value: 'logout',
                  child: Row(
                    children: [
                      const Icon(
                        Icons.logout_rounded,
                        color: Colors.redAccent,
                        size: 20,
                      ),
                      SizedBox(width: 12),
                      Text(
                        'Sign out',
                        style: GoogleFonts.inter(
                          color: Colors.redAccent,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(width: 16),
          ],
        ),
        extendBody: true,
        body: const TabBarView(
          children: [OverviewTab(), RidesTab(), UsersTab(), MenuTab()],
        ),
        bottomNavigationBar: Container(
          decoration: const BoxDecoration(
            color: AdminColors.card,
            border: Border(top: BorderSide(color: AdminColors.border)),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: TabBar(
                dividerColor: Colors.transparent,
                indicator: const _AdminTabIndicator(),
                indicatorSize: TabBarIndicatorSize.tab,
                labelColor: AdminColors.secondary,
                unselectedLabelColor: AdminColors.textSecondary,
                splashFactory: NoSplash.splashFactory,
                overlayColor: WidgetStateProperty.all(Colors.transparent),
                labelStyle: GoogleFonts.inter(
                  fontWeight: FontWeight.w800,
                  fontSize: 9,
                ),
                unselectedLabelStyle: GoogleFonts.inter(
                  fontWeight: FontWeight.w600,
                  fontSize: 9,
                ),
                tabs: const [
                  Tab(
                    icon: Icon(Icons.dashboard_rounded, size: 20),
                    text: 'Overview',
                    iconMargin: EdgeInsets.only(bottom: 2),
                    height: 50,
                  ),
                  Tab(
                    icon: Icon(Icons.local_taxi_rounded, size: 20),
                    text: 'Rides',
                    iconMargin: EdgeInsets.only(bottom: 2),
                    height: 50,
                  ),
                  Tab(
                    icon: Icon(Icons.people_alt_rounded, size: 20),
                    text: 'Users',
                    iconMargin: EdgeInsets.only(bottom: 2),
                    height: 50,
                  ),
                  Tab(
                    icon: Icon(Icons.menu_rounded, size: 20),
                    text: 'Menu',
                    iconMargin: EdgeInsets.only(bottom: 2),
                    height: 50,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

enum RideRange { today, last30Days, all }

// ─── Utilities ────────────────────────────────────────────────────────────────
DateTime? rideDate(Map<String, dynamic> ride) {
  final value = ride['createdAt'];
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  return null;
}

bool sameDay(DateTime? a, DateTime b) =>
    a != null && a.year == b.year && a.month == b.month && a.day == b.day;
String pretty(String value) => value
    .replaceAll('_', ' ')
    .split(' ')
    .map(
      (word) =>
          word.isEmpty ? word : '${word[0].toUpperCase()}${word.substring(1)}',
    )
    .join(' ');
Color statusColor(BuildContext context, String status) => switch (status) {
  'completed' => context.colors.success,
  'cancelled' => context.colors.error,
  'in_progress' => context.colors.adminInfo,
  'accepted' || 'arriving' || 'arrived' => context.colors.adminInfo,
  _ => context.colors.warning,
};
String friendlyError(Object error) {
  final text = error
      .toString()
      .replaceFirst('Exception: ', '')
      .replaceFirst('Bad state: ', '');
  if (text.contains('permission-denied'))
    return 'Permission denied. Confirm that the latest Firestore rules are deployed.';
  return text;
}

class _AdminTabIndicator extends Decoration {
  const _AdminTabIndicator();
  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) =>
      _AdminTabPainter(this, onChanged);
}

class _AdminTabPainter extends BoxPainter {
  final _AdminTabIndicator decoration;
  _AdminTabPainter(this.decoration, VoidCallback? onChanged) : super(onChanged);

  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration configuration) {
    final Rect rect = offset & configuration.size!;
    final Paint linePaint = Paint()
      ..color = AdminColors.secondary
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 3;

    final double lineW = 24;
    final double lineX = rect.center.dx - (lineW / 2);
    final double lineY = rect.bottom - 6;
    canvas.drawLine(
      Offset(lineX, lineY),
      Offset(lineX + lineW, lineY),
      linePaint,
    );
  }
}
