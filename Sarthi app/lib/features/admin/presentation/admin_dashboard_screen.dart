import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../shared/auth/presentation/auth_providers.dart';
import 'admin_providers.dart';
import 'admin_design.dart';
import 'tabs/overview_tab.dart';
import 'tabs/rides_tab.dart';
import 'tabs/users_tab.dart';
import 'tabs/menu_tab.dart';
import 'screens/captains_screen.dart';
import '../../shared/auth/domain/app_user.dart';
import 'package:google_fonts/google_fonts.dart';

// ─── Design Tokens ────────────────────────────────────────────────────────────
class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 4,
      child: Builder(
        builder: (context) {
          final isWide = AdminResponsive.isWide(context);
          final tabController = DefaultTabController.of(context);

          return Scaffold(
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
                  const SizedBox(width: 10),
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
                        isWide ? 'Operations Console • Tablet / Desktop' : 'Operations Console',
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
                const _CaptainNotificationBell(),
                const SizedBox(width: 4),
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
                        const SizedBox(width: 4),
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
                          const SizedBox(width: 12),
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
                const SizedBox(width: 16),
              ],
            ),
            extendBody: false,
            body: Column(
              children: [
                if (ref.watch(activeEmergencyEventsProvider).value?.isNotEmpty == true) ...[
                  Builder(builder: (context) {
                    final emergencies = ref.watch(activeEmergencyEventsProvider).value!;
                    return Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      color: const Color(0xFFDC2626),
                      child: Row(
                        children: [
                          const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'CRITICAL: ${emergencies.length} Active Emergency SOS Alert${emergencies.length == 1 ? '' : 's'}! Immediate attention required.',
                              style: GoogleFonts.inter(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          ElevatedButton(
                            onPressed: () {
                              HapticFeedback.heavyImpact();
                              _AdminDashboardHelpers._showEmergencyModal(context, ref, emergencies);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: const Color(0xFFDC2626),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                            ),
                            child: Text(
                              'Respond',
                              style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 11),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
                Expanded(
                  child: isWide
                      ? ListenableBuilder(
                          listenable: tabController,
                          builder: (context, _) => Row(
                            children: [
                              _AdminNavRail(
                                selectedIndex: tabController.index,
                                onDestinationSelected: (idx) {
                                  HapticFeedback.selectionClick();
                                  tabController.animateTo(idx);
                                },
                              ),
                              const VerticalDivider(
                                width: 1,
                                thickness: 1,
                                color: AdminColors.border,
                              ),
                              const Expanded(
                                child: TabBarView(
                                  children: [
                                    OverviewTab(),
                                    RidesTab(),
                                    UsersTab(),
                                    MenuTab(),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        )
                      : const TabBarView(
                          children: [
                            OverviewTab(),
                            RidesTab(),
                            UsersTab(),
                            MenuTab(),
                          ],
                        ),
                ),
              ],
            ),
            bottomNavigationBar: isWide
                ? null
                : Container(
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
          );
        },
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
  if (text.contains('permission-denied')) {
    return 'Permission denied. Confirm that the latest Firestore rules are deployed.';
  }
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

class _AdminNavRail extends StatelessWidget {
  const _AdminNavRail({
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 76,
      decoration: const BoxDecoration(
        color: AdminColors.card,
        border: Border(right: BorderSide(color: AdminColors.border)),
      ),
      child: SafeArea(
        right: false,
        child: Column(
          children: [
            const SizedBox(height: 16),
            _railItem(0, Icons.dashboard_rounded, 'Overview'),
            const SizedBox(height: 12),
            _railItem(1, Icons.local_taxi_rounded, 'Rides'),
            const SizedBox(height: 12),
            _railItem(2, Icons.people_alt_rounded, 'Users'),
            const SizedBox(height: 12),
            _railItem(3, Icons.menu_rounded, 'Menu'),
          ],
        ),
      ),
    );
  }

  Widget _railItem(int index, IconData icon, String label) {
    final isSelected = selectedIndex == index;
    return Tooltip(
      message: label,
      child: InkWell(
        onTap: () => onDestinationSelected(index),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 60,
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? AdminColors.primary.withValues(alpha: 0.08)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: isSelected ? AdminColors.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  size: 20,
                  color: isSelected ? Colors.white : AdminColors.textSecondary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  color: isSelected
                      ? AdminColors.primary
                      : AdminColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CaptainNotificationBell extends ConsumerWidget {
  const _CaptainNotificationBell();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersAsync = ref.watch(allUsersProvider);
    final emergencyAsync = ref.watch(activeEmergencyEventsProvider);
    final emergencies = emergencyAsync.value ?? [];
    final users = usersAsync.value ?? [];
    final pendingCaptains = users.where((u) {
      if (u.role.toLowerCase() != 'captain') return false;
      final st = u.verificationStatus.toLowerCase();
      return st == 'pending_review' || st == 'pending';
    }).toList();

    final hasEmergency = emergencies.isNotEmpty;
    final totalCount = emergencies.length + pendingCaptains.length;

    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          margin: const EdgeInsets.only(right: 8),
          decoration: BoxDecoration(
            color: hasEmergency ? const Color(0xFFFEF2F2) : AdminColors.card,
            shape: BoxShape.circle,
            border: Border.all(
              color: hasEmergency ? const Color(0xFFEF4444) : AdminColors.border,
              width: hasEmergency ? 2 : 1,
            ),
          ),
          child: IconButton(
            tooltip: hasEmergency
                ? '🚨 ${emergencies.length} EMERGENCY SOS ACTIVE!'
                : (pendingCaptains.isNotEmpty
                    ? '${pendingCaptains.length} Captains Pending Review'
                    : 'Notifications'),
            icon: Icon(
              hasEmergency
                  ? Icons.warning_rounded
                  : (pendingCaptains.isNotEmpty
                      ? Icons.notifications_active_rounded
                      : Icons.notifications_none_rounded),
              color: hasEmergency
                  ? const Color(0xFFDC2626)
                  : (pendingCaptains.isNotEmpty
                      ? const Color(0xFFF59E0B)
                      : AdminColors.textPrimary),
              size: 20,
            ),
            onPressed: () {
              HapticFeedback.lightImpact();
              if (hasEmergency) {
                _AdminDashboardHelpers._showEmergencyModal(context, ref, emergencies);
              } else {
                _AdminDashboardHelpers._showNotificationsDrawer(context, ref, pendingCaptains);
              }
            },
          ),
        ),
        if (totalCount > 0)
          Positioned(
            top: 4,
            right: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: hasEmergency ? const Color(0xFFDC2626) : const Color(0xFFEF4444),
                borderRadius: BorderRadius.circular(10),
              ),
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              alignment: Alignment.center,
              child: Text(
                hasEmergency ? 'SOS' : (totalCount > 9 ? '9+' : '$totalCount'),
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 8.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _AdminDashboardHelpers {
  static void _showEmergencyModal(
    BuildContext context,
    WidgetRef ref,
    List<Map<String, dynamic>> emergencies,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AdminColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDC2626).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626), size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Active Emergency Incidents',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFFDC2626),
                          ),
                        ),
                        Text(
                          'Immediate dispatcher intervention and safety check',
                          style: GoogleFonts.inter(fontSize: 11, color: AdminColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AdminColors.border),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: emergencies.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (_, idx) {
                  final ev = emergencies[idx];
                  final rideId = ev['rideId']?.toString() ?? 'Unknown';
                  final userId = ev['userId']?.toString() ?? 'Unknown';
                  final pickup = ev['pickupAddress']?.toString() ?? 'Live Location';
                  final drop = ev['destinationAddress']?.toString() ?? 'Live Destination';

                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFCA5A5)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFDC2626),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'SOS ACTIVE',
                                style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 10),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Ride ID: ${AppUser.shortId(rideId)}',
                                style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13, color: const Color(0xFF991B1B)),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Rider ID: ${AppUser.shortId(userId)}',
                          style: GoogleFonts.inter(fontSize: 11, color: AdminColors.textSecondary),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Pickup: $pickup',
                          style: GoogleFonts.inter(fontSize: 11, color: AdminColors.textPrimary, fontWeight: FontWeight.w500),
                        ),
                        Text(
                          'Destination: $drop',
                          style: GoogleFonts.inter(fontSize: 11, color: AdminColors.textPrimary, fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFDC2626),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                ),
                                onPressed: () {
                                  _showResolveEmergencyDialog(context, ref, ev['id']);
                                },
                                child: Text(
                                  'Resolve Incident',
                                  style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 12),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  static void _showResolveEmergencyDialog(BuildContext context, WidgetRef ref, String eventId) {
    final notesCtrl = TextEditingController(text: 'Contacted rider and captain, verified safety.');
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Resolve Emergency SOS',
          style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 16),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Enter verification notes to close this active emergency event:',
              style: GoogleFonts.inter(fontSize: 12, color: AdminColors.textSecondary),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: notesCtrl,
              maxLines: 2,
              style: GoogleFonts.inter(fontSize: 13),
              decoration: InputDecoration(
                filled: true,
                fillColor: AdminColors.background,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AdminColors.border)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: Text('Cancel', style: GoogleFonts.inter(color: AdminColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AdminColors.success,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              Navigator.pop(dialogCtx);
              try {
                await ref.read(adminRepositoryProvider).resolveEmergencyEvent(eventId, notesCtrl.text.trim());
                if (context.mounted) {
                  Navigator.of(context).pop(); // close modal
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Emergency incident marked as resolved.'), backgroundColor: AdminColors.success),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to resolve: $e'), backgroundColor: AdminColors.error),
                  );
                }
              }
            },
            child: Text('Confirm Resolve', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  static void _showNotificationsDrawer(
    BuildContext context,
    WidgetRef ref,
    List<AppUser> pendingCaptains,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.75,
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AdminColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.notifications_active_rounded, color: Color(0xFFF59E0B), size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Pending Applications',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AdminColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  if (pendingCaptains.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${pendingCaptains.length} Pending',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFFD97706),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const Divider(height: 1, color: AdminColors.border),
            Expanded(
              child: pendingCaptains.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_circle_outline_rounded, size: 48, color: AdminColors.success.withValues(alpha: 0.5)),
                          const SizedBox(height: 12),
                          Text(
                            'All caught up!',
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AdminColors.textPrimary,
                            ),
                          ),
                          Text(
                            'No pending captain verification requests.',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: AdminColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: pendingCaptains.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 10),
                      itemBuilder: (_, idx) {
                        final captain = pendingCaptains[idx];
                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AdminColors.background,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AdminColors.border),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: AdminColors.primary.withValues(alpha: 0.1),
                                radius: 20,
                                child: Text(
                                  captain.name.isNotEmpty ? captain.name[0].toUpperCase() : 'C',
                                  style: GoogleFonts.inter(
                                    fontWeight: FontWeight.w800,
                                    color: AdminColors.primary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      captain.name,
                                      style: GoogleFonts.inter(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: AdminColors.textPrimary,
                                      ),
                                    ),
                                    Text(
                                      '${captain.phone ?? captain.email} • ${(captain.vehicleType ?? 'Bike').toUpperCase()}',
                                      style: GoogleFonts.inter(
                                        fontSize: 11,
                                        color: AdminColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AdminColors.primary,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  minimumSize: Size.zero,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                onPressed: () {
                                  Navigator.pop(ctx);
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => const CaptainsScreen(initialTab: 'pending'),
                                    ),
                                  );
                                },
                                child: Text(
                                  'Review',
                                  style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const CaptainsScreen(),
                        ),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AdminColors.primary,
                      side: const BorderSide(color: AdminColors.primary),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: Text(
                      'Open Captains Management Hub',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

