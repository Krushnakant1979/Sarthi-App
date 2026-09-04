import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../auth/domain/app_user.dart';
import '../admin_providers.dart';
import '../admin_design.dart';
import '../admin_dashboard_screen.dart';
import '../widgets/captain_documents_dialog.dart';
import 'package:google_fonts/google_fonts.dart';

// ─── Brand Colors ──────────────────────────────────────────────────────────────
const _navy = Color(0xFF0B2748);
const _yellow = Color(0xFFFFD21E);
const _green = Color(0xFF16A34A);
const _orange = Color(0xFFF59E0B);
const _red = Color(0xFFDC2626);
const _purple = Color(0xFF7C3AED);
const _blue = Color(0xFF3B82F6);
const _bg = Color(0xFFF4F7FA);
const _card = Colors.white;
const _text = Color(0xFF172B4D);
const _muted = Color(0xFF6B778C);
const _border = Color(0xFFE2E8F0);

// ─── Helpers ───────────────────────────────────────────────────────────────────
Color _roleColor(String role) => switch (role) {
  'admin' => _orange,
  'captain' => _purple,
  _ => _blue,
};

String _roleLabel(String role) => switch (role) {
  'admin' => 'Admin',
  'captain' => 'Captain',
  _ => 'Passenger',
};

Color _verificationColor(String? v) => switch (v) {
  'verified' => _green,
  'rejected' => _red,
  'pending_review' => _orange,
  _ => _muted,
};

String _verificationLabel(String? v) => switch (v) {
  'verified' => 'Verified',
  'rejected' => 'Rejected',
  'pending_review' => 'Pending',
  _ => 'Not Set',
};

String _initials(String name) {
  final parts = name.trim().split(' ');
  if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  return name.isEmpty ? 'U' : name[0].toUpperCase();
}

// ─── UsersTab ──────────────────────────────────────────────────────────────────
class UsersTab extends ConsumerStatefulWidget {
  const UsersTab({super.key});
  @override
  ConsumerState<UsersTab> createState() => UsersTabState();
}

class UsersTabState extends ConsumerState<UsersTab> {
  String search = '';
  String sort = 'newest';
  Map<String, dynamic> advancedFilters = {};
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _clearFilters() {
    _searchCtrl.clear();
    setState(() {
      search = '';
      sort = 'newest';
      advancedFilters.clear();
    });
    ref.read(usersFilterProvider.notifier).state = 'all';
  }

  void _openFilters() async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AdvancedFiltersSheet(initialFilters: advancedFilters),
    );
    if (result != null) {
      setState(() => advancedFilters = result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final role = ref.watch(usersFilterProvider);
    final async = ref.watch(allUsersProvider);

    if (async.isLoading) return const _UsersSkeletonLoader();

    if (async.hasError) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                size: 48,
                color: AdminColors.error,
              ),
              SizedBox(height: 12),
              Text(
                'Failed to load users',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: AdminColors.textPrimary,
                ),
              ),
              SizedBox(height: 6),
              Text(
                async.error.toString(),
                style: GoogleFonts.inter(
                  color: AdminColors.textSecondary,
                  fontSize: 11,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => ref.invalidate(allUsersProvider),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AdminColors.primary,
                ),
                child: Text(
                  'Retry',
                  style: GoogleFonts.inter(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final all = async.value ?? [];

    // Filtered list
    final users = all.where((u) {
      final matchesRole = role == 'all' || u.role == role;

      bool matchesAdv = true;
      if (advancedFilters.isNotEmpty) {
        if (advancedFilters['verificationStatus'] != null &&
            advancedFilters['verificationStatus'] != 'all') {
          matchesAdv =
              matchesAdv &&
              u.verificationStatus == advancedFilters['verificationStatus'];
        }
        if (advancedFilters['vehicleType'] != null &&
            advancedFilters['vehicleType'] != 'all') {
          matchesAdv =
              matchesAdv && u.vehicleType == advancedFilters['vehicleType'];
        }
      }

      final q = search.toLowerCase();
      final hay = '${u.name} ${u.email} ${u.phone ?? ''} ${u.publicId}'
          .toLowerCase();
      return matchesRole && matchesAdv && hay.contains(q);
    }).toList();

    // Sort
    users.sort(
      (a, b) => switch (sort) {
        'oldest' => a.createdAt.compareTo(b.createdAt),
        'name_asc' => a.name.compareTo(b.name),
        'name_desc' => b.name.compareTo(a.name),
        'verified' => (a.verificationStatus == 'verified' ? 0 : 1).compareTo(
          b.verificationStatus == 'verified' ? 0 : 1,
        ),
        'pending' =>
          (a.verificationStatus == 'pending_review' ? 0 : 1).compareTo(
            b.verificationStatus == 'pending_review' ? 0 : 1,
          ),
        _ => b.createdAt.compareTo(a.createdAt),
      },
    );

    final m1Count = role == 'user'
        ? users.length
        : (role == 'admin'
              ? users.where((u) => u.role == 'admin').length
              : users.where((u) => u.role == 'captain').length);
    final m1Label = role == 'user'
        ? 'Passengers'
        : (role == 'admin' ? 'Admins' : 'Captains');
    final m1Icon = role == 'user'
        ? Icons.person_rounded
        : Icons.people_alt_rounded;

    final m2Count = role == 'user'
        ? users.length
        : users.where((u) => u.verificationStatus == 'verified').length;
    final m2Label = role == 'user' ? 'Active' : 'Verified';

    final m3Count = role == 'user'
        ? 0
        : users
              .where(
                (u) =>
                    u.verificationStatus == 'pending_review' ||
                    u.verificationStatus == 'pending',
              )
              .length;
    final m3Label = role == 'user' ? 'New' : 'Pending';

    return Column(
      children: [
        // ── Header & Filters ─────────────────────────────────────────────
        Container(
          color: AdminColors.card,
          padding: const EdgeInsets.fromLTRB(14, 16, 14, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title + sort
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'User Management',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: AdminColors.textPrimary,
                            letterSpacing: -0.5,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Manage passengers, captains and admins.',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            color: AdminColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _SortButton(
                    sort: sort,
                    onChanged: (v) => setState(() => sort = v),
                  ),
                ],
              ),
              SizedBox(height: 24),

              // Role segmented control
              _RoleSegmentedControl(role: role),
              SizedBox(height: 20),

              // Search bar and advanced filters
              Row(
                children: [
                  Expanded(
                    child: _SearchBar(
                      controller: _searchCtrl,
                      onChanged: (v) => setState(() => search = v.trim()),
                      onClear: () {
                        _searchCtrl.clear();
                        setState(() => search = '');
                      },
                    ),
                  ),
                  SizedBox(width: 10),
                  GestureDetector(
                    onTap: _openFilters,
                    child: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: AdminColors.card,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AdminColors.border),
                      ),
                      child: Icon(
                        Icons.tune_rounded,
                        color: advancedFilters.isNotEmpty
                            ? AdminColors.primary
                            : AdminColors.textSecondary,
                        size: 18,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 20),

              // Summary Cards
              Row(
                children: [
                  Expanded(
                    child: _SummaryCard(
                      title: m1Label,
                      count: m1Count,
                      icon: m1Icon,
                      color: AdminColors.primary,
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: _SummaryCard(
                      title: m2Label,
                      count: m2Count,
                      icon: Icons.verified_user_rounded,
                      color: AdminColors.success,
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: _SummaryCard(
                      title: m3Label,
                      count: m3Count,
                      icon: Icons.schedule_rounded,
                      color: AdminColors.warning,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 24),
            ],
          ),
        ),
        const Divider(height: 1, color: AdminColors.border),

        // ── Count bar ────────────────────────────────────────────────────
        Container(
          color: AdminColors.background,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              Text(
                '${users.length} account${users.length == 1 ? '' : 's'} found',
                style: GoogleFonts.inter(
                  color: AdminColors.textSecondary,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: _clearFilters,
                child: Text(
                  'Clear filters',
                  style: GoogleFonts.inter(
                    color: AdminColors.primary,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),

        // ── User list ────────────────────────────────────────────────────
        Expanded(
          child: users.isEmpty
              ? _EmptyUsersState(onClear: _clearFilters)
              : RefreshIndicator(
                  color: AdminColors.primary,
                  onRefresh: () async => ref.invalidate(allUsersProvider),
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(14, 8, 14, 100),
                    itemCount: users.length,
                    itemBuilder: (_, i) =>
                        UserCard(user: users[i], onAction: _performAction),
                  ),
                ),
        ),
      ],
    );
  }

  Future<void> _performAction(AppUser user, String action) async {
    final label = switch (action) {
      'approve' => 'approve this captain',
      'reject' => 'reject these documents',
      _ => 'change this account role to ${pretty(action)}',
    };

    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: AdminColors.card,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Text(
              'Confirm Action',
              style: GoogleFonts.inter(
                color: AdminColors.textPrimary,
                fontWeight: FontWeight.w800,
                fontSize: 17,
              ),
            ),
            content: Text(
              'Do you want to $label for ${user.name}?',
              style: GoogleFonts.inter(
                color: AdminColors.textSecondary,
                fontSize: 13,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(
                  'Cancel',
                  style: GoogleFonts.inter(color: AdminColors.textSecondary),
                ),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AdminColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text(
                  'Confirm',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmed || !mounted) return;
    try {
      final repo = ref.read(adminRepositoryProvider);
      if (action == 'approve' || action == 'reject') {
        await repo.updateCaptainVerification(
          user.uid,
          action == 'approve' ? 'verified' : 'rejected',
        );
      } else {
        await repo.updateUserRole(user.uid, action);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AdminColors.success,
            content: Text(
              'Action completed successfully.',
              style: GoogleFonts.inter(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AdminColors.error,
            content: Text(
              friendlyError(e),
              style: GoogleFonts.inter(color: Colors.white),
            ),
          ),
        );
      }
    }
  }
}

// ─── Role Segmented Control ────────────────────────────────────────────────────
class _RoleSegmentedControl extends ConsumerWidget {
  const _RoleSegmentedControl({required this.role});
  final String role;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final options = const {
      'all': 'All Users',
      'user': 'Passengers',
      'captain': 'Captains',
      'admin': 'Admins',
    };
    return Container(
      decoration: BoxDecoration(
        color: AdminColors.background,
        borderRadius: BorderRadius.circular(14),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: options.entries.map((e) {
          final sel = role == e.key;
          return Expanded(
            child: GestureDetector(
              onTap: () => ref.read(usersFilterProvider.notifier).state = e.key,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: sel ? AdminColors.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: sel
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : [],
                ),
                alignment: Alignment.center,
                child: Text(
                  e.value,
                  style: GoogleFonts.inter(
                    fontSize: 9,
                    fontWeight: sel ? FontWeight.w800 : FontWeight.w600,
                    color: sel ? Colors.white : AdminColors.textSecondary,
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

// ─── Search Bar ────────────────────────────────────────────────────────────────
class _SearchBar extends StatelessWidget {
  const _SearchBar({
    required this.controller,
    required this.onChanged,
    required this.onClear,
  });
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) => Container(
    height: 42,
    decoration: BoxDecoration(
      color: AdminColors.background,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AdminColors.border),
    ),
    child: TextField(
      controller: controller,
      onChanged: onChanged,
      style: GoogleFonts.inter(color: AdminColors.textPrimary, fontSize: 11),
      decoration: InputDecoration(
        hintText: 'Search name, email, phone or ID…',
        hintStyle: GoogleFonts.inter(
          color: AdminColors.textSecondary,
          fontSize: 10,
        ),
        prefixIcon: const Icon(
          Icons.search_rounded,
          color: AdminColors.textSecondary,
          size: 18,
        ),
        suffixIcon: controller.text.isNotEmpty
            ? IconButton(
                icon: const Icon(
                  Icons.close_rounded,
                  color: AdminColors.textSecondary,
                  size: 16,
                ),
                onPressed: onClear,
              )
            : null,
        border: InputBorder.none,
        contentPadding: const EdgeInsets.symmetric(vertical: 10),
      ),
    ),
  );
}

// ─── Sort Button ───────────────────────────────────────────────────────────────
class _SortButton extends StatelessWidget {
  const _SortButton({required this.sort, required this.onChanged});
  final String sort;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => PopupMenuButton<String>(
    onSelected: onChanged,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    color: AdminColors.card,
    offset: const Offset(0, 40),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AdminColors.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AdminColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.sort_rounded, size: 14, color: AdminColors.textSecondary),
          SizedBox(width: 4),
          Text(
            'Sort',
            style: GoogleFonts.inter(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: AdminColors.textPrimary,
            ),
          ),
        ],
      ),
    ),
    itemBuilder: (_) => [
      _sortItem('newest', 'Newest First', sort),
      _sortItem('oldest', 'Oldest First', sort),
      _sortItem('name_asc', 'Name (A-Z)', sort),
      _sortItem('name_desc', 'Name (Z-A)', sort),
      _sortItem('verified', 'Verified First', sort),
      _sortItem('pending', 'Pending First', sort),
    ],
  );

  PopupMenuItem<String> _sortItem(String v, String label, String current) =>
      PopupMenuItem(
        value: v,
        child: Row(
          children: [
            Icon(
              v == current ? Icons.check_rounded : Icons.circle_outlined,
              size: 14,
              color: v == current ? AdminColors.primary : Colors.transparent,
            ),
            SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.inter(
                fontWeight: v == current ? FontWeight.w700 : FontWeight.w500,
                color: AdminColors.textPrimary,
                fontSize: 11,
              ),
            ),
          ],
        ),
      );
}

// ─── Summary Card ──────────────────────────────────────────────────────────────
class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.title,
    required this.count,
    required this.icon,
    required this.color,
  });
  final String title;
  final int count;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: AdminColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AdminColors.border),
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
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$count',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: AdminColors.textPrimary,
                        letterSpacing: -0.5,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      title,
                      style: GoogleFonts.inter(
                        fontSize: 8,
                        color: AdminColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── User Card ─────────────────────────────────────────────────────────────────
class UserCard extends StatelessWidget {
  const UserCard({super.key, required this.user, required this.onAction});
  final AppUser user;
  final Future<void> Function(AppUser, String) onAction;

  @override
  Widget build(BuildContext context) {
    final roleColor = _roleColor(user.role);
    final initials = _initials(user.name);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: AdminColors.card,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            HapticFeedback.lightImpact();
            if (user.role == 'captain') {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) =>
                    _CaptainDetailsSheet(user: user, onAction: onAction),
              );
            } else {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) =>
                    _UserDetailsSheet(user: user, onAction: onAction),
              );
            }
          },
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AdminColors.border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Avatar
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: roleColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      initials,
                      style: GoogleFonts.inter(
                        color: roleColor,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 12),

                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.name.isEmpty ? 'Unnamed User' : user.name,
                        style: GoogleFonts.inter(
                          color: AdminColors.textPrimary,
                          fontWeight: FontWeight.w800,
                          fontSize: 11,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 2),
                      Text(
                        user.email,
                        style: GoogleFonts.inter(
                          color: AdminColors.textSecondary,
                          fontSize: 9,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (user.phone != null && user.phone!.isNotEmpty) ...[
                        SizedBox(height: 1),
                        Text(
                          user.phone!,
                          style: GoogleFonts.inter(
                            color: AdminColors.textSecondary,
                            fontSize: 9,
                          ),
                        ),
                      ],
                      SizedBox(height: 8),
                      Row(
                        children: [
                          _RoleBadge(role: user.role),
                          if (user.role == 'captain') ...[
                            SizedBox(width: 6),
                            _VerifBadge(status: user.verificationStatus),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),

                // Actions
                PopupMenuButton<String>(
                  color: AdminColors.card,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  icon: const Icon(
                    Icons.more_vert_rounded,
                    color: AdminColors.textSecondary,
                    size: 20,
                  ),
                  onSelected: (v) => onAction(user, v),
                  itemBuilder: (_) => [
                    if (user.role == 'captain') ...[
                      _popItem(
                        'approve',
                        Icons.check_circle_outline,
                        AdminColors.success,
                        'Approve Documents',
                      ),
                      _popItem(
                        'reject',
                        Icons.cancel_outlined,
                        AdminColors.error,
                        'Reject Documents',
                      ),
                      const PopupMenuDivider(),
                    ],
                    _popItem(
                      'user',
                      Icons.person_rounded,
                      _blue,
                      'Set as Passenger',
                    ),
                    _popItem(
                      'captain',
                      Icons.local_taxi_rounded,
                      _purple,
                      'Set as Captain',
                    ),
                    _popItem(
                      'admin',
                      Icons.admin_panel_settings_rounded,
                      _orange,
                      'Set as Admin',
                    ),
                  ],
                ),
                SizedBox(width: 2),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AdminColors.textSecondary,
                  size: 18,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  PopupMenuItem<String> _popItem(
    String value,
    IconData icon,
    Color color,
    String label,
  ) => PopupMenuItem(
    value: value,
    child: Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 16),
        ),
        SizedBox(width: 10),
        Text(
          label,
          style: GoogleFonts.inter(
            color: AdminColors.textPrimary,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );
}

// ─── Role Badge ────────────────────────────────────────────────────────────────
class _RoleBadge extends StatelessWidget {
  const _RoleBadge({required this.role});
  final String role;
  @override
  Widget build(BuildContext context) {
    final color = _roleColor(role);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        _roleLabel(role),
        style: GoogleFonts.inter(
          fontSize: 8,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

// ─── Verification Badge ────────────────────────────────────────────────────────
class _VerifBadge extends StatelessWidget {
  const _VerifBadge({required this.status});
  final String? status;
  @override
  Widget build(BuildContext context) {
    final color = _verificationColor(status);
    final isVerified = status == 'verified';
    final isPending = status == 'pending_review' || status == 'pending';
    final icon = isVerified
        ? Icons.shield_rounded
        : (isPending ? Icons.schedule_rounded : Icons.info_outline_rounded);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          SizedBox(width: 4),
          Text(
            _verificationLabel(status),
            style: GoogleFonts.inter(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Advanced Filters Sheet ──────────────────────────────────────────────────
class _AdvancedFiltersSheet extends StatefulWidget {
  final Map<String, dynamic> initialFilters;
  const _AdvancedFiltersSheet({required this.initialFilters});

  @override
  State<_AdvancedFiltersSheet> createState() => _AdvancedFiltersSheetState();
}

class _AdvancedFiltersSheetState extends State<_AdvancedFiltersSheet> {
  late String _verificationStatus;
  late String _vehicleType;

  @override
  void initState() {
    super.initState();
    _verificationStatus = widget.initialFilters['verificationStatus'] ?? 'all';
    _vehicleType = widget.initialFilters['vehicleType'] ?? 'all';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
      decoration: const BoxDecoration(
        color: AdminColors.card,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Advanced Filters',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AdminColors.textPrimary,
                ),
              ),
              IconButton(
                icon: const Icon(
                  Icons.close_rounded,
                  color: AdminColors.textSecondary,
                ),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          SizedBox(height: 24),
          Text(
            'Verification Status',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AdminColors.textPrimary,
            ),
          ),
          SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _filterChip(
                'All',
                'all',
                _verificationStatus,
                (v) => setState(() => _verificationStatus = v),
              ),
              _filterChip(
                'Verified',
                'verified',
                _verificationStatus,
                (v) => setState(() => _verificationStatus = v),
              ),
              _filterChip(
                'Pending',
                'pending_review',
                _verificationStatus,
                (v) => setState(() => _verificationStatus = v),
              ),
              _filterChip(
                'Rejected',
                'rejected',
                _verificationStatus,
                (v) => setState(() => _verificationStatus = v),
              ),
            ],
          ),
          SizedBox(height: 24),
          Text(
            'Vehicle Type',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AdminColors.textPrimary,
            ),
          ),
          SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _filterChip(
                'All',
                'all',
                _vehicleType,
                (v) => setState(() => _vehicleType = v),
              ),
              _filterChip(
                'Two Wheeler',
                'two_wheeler',
                _vehicleType,
                (v) => setState(() => _vehicleType = v),
              ),
              _filterChip(
                'Auto',
                'auto',
                _vehicleType,
                (v) => setState(() => _vehicleType = v),
              ),
              _filterChip(
                'Cab',
                'cab',
                _vehicleType,
                (v) => setState(() => _vehicleType = v),
              ),
            ],
          ),
          SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AdminColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: () {
                Navigator.pop(context, {
                  'verificationStatus': _verificationStatus,
                  'vehicleType': _vehicleType,
                });
              },
              child: Text(
                'Apply Filters',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(
    String label,
    String value,
    String groupValue,
    ValueChanged<String> onSelected,
  ) {
    final sel = value == groupValue;
    return GestureDetector(
      onTap: () => onSelected(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: sel ? AdminColors.primary : AdminColors.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: sel ? AdminColors.primary : AdminColors.border,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: sel ? FontWeight.w700 : FontWeight.w600,
            color: sel ? Colors.white : AdminColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

// ─── User Details Bottom Sheet ─────────────────────────────────────────────────
class _UserDetailsSheet extends StatelessWidget {
  const _UserDetailsSheet({required this.user, required this.onAction});
  final AppUser user;
  final Future<void> Function(AppUser, String) onAction;

  @override
  Widget build(BuildContext context) {
    final roleColor = _roleColor(user.role);
    return Container(
      decoration: const BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.92,
        minChildSize: 0.5,
        maxChildSize: 0.92, // Leave space for status bar
        builder: (_, controller) => SafeArea(
          bottom: false,
          child: Column(
            children: [
              SizedBox(height: 12),
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: _border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                ), // Decreased
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: roleColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: roleColor.withValues(alpha: 0.25),
                        ),
                      ),
                      child: Center(
                        child: Text(
                          _initials(user.name),
                          style: GoogleFonts.inter(
                            color: roleColor,
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ), // Decreased
                    SizedBox(width: 12), // Decreased
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user.name.isEmpty ? 'Unnamed User' : user.name,
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              color: _text,
                            ),
                          ), // Decreased
                          SizedBox(height: 4),
                          Row(children: [_RoleBadge(role: user.role)]),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(
                        Icons.close_rounded,
                        color: _muted,
                        size: 18,
                      ),
                      style: IconButton.styleFrom(
                        backgroundColor: _bg,
                        shape: const CircleBorder(),
                      ),
                    ), // Decreased
                  ],
                ),
              ),
              SizedBox(height: 16),
              const Divider(height: 1, color: _border),
              Expanded(
                child: ListView(
                  controller: controller,
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
                  children: [
                    // Increased bottom padding
                    _DetailCard(
                      title: 'Contact Info',
                      children: [
                        _InfoRow(
                          icon: Icons.email_rounded,
                          label: 'Email',
                          value: user.email,
                        ),
                        if (user.phone != null && user.phone!.isNotEmpty)
                          _InfoRow(
                            icon: Icons.phone_rounded,
                            label: 'Phone',
                            value: user.phone!,
                          ),
                      ],
                    ),
                    SizedBox(height: 14),
                    _DetailCard(
                      title: 'Account',
                      children: [
                        _InfoRow(
                          icon: Icons.badge_rounded,
                          label: 'Account ID',
                          value: user.publicId,
                        ),
                        _InfoRow(
                          icon: Icons.calendar_today_rounded,
                          label: 'Registered',
                          value: DateFormat('d MMM y').format(user.createdAt),
                        ),
                      ],
                    ),
                    SizedBox(height: 14),
                    _buildRoleActions(context),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoleActions(BuildContext context) => Column(
    children: [
      _ActionButton(
        icon: Icons.local_taxi_rounded,
        label: 'Set as Captain',
        color: _purple,
        onTap: () {
          Navigator.pop(context);
          onAction(user, 'captain');
        },
      ),
      SizedBox(height: 10),
      _ActionButton(
        icon: Icons.admin_panel_settings_rounded,
        label: 'Set as Admin',
        color: _orange,
        onTap: () {
          Navigator.pop(context);
          onAction(user, 'admin');
        },
      ),
    ],
  );
}

// ─── Captain Details Bottom Sheet ──────────────────────────────────────────────
class _CaptainDetailsSheet extends StatelessWidget {
  const _CaptainDetailsSheet({required this.user, required this.onAction});
  final AppUser user;
  final Future<void> Function(AppUser, String) onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.92,
        minChildSize: 0.5,
        maxChildSize: 0.92, // Leave space for status bar
        builder: (_, controller) => SafeArea(
          bottom: false,
          child: Column(
            children: [
              SizedBox(height: 12),
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: _border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                ), // Decreased
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: _purple.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _purple.withValues(alpha: 0.25),
                        ),
                      ),
                      child: Center(
                        child: Text(
                          _initials(user.name),
                          style: GoogleFonts.inter(
                            color: _purple,
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ), // Decreased
                    SizedBox(width: 12), // Decreased
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user.name.isEmpty ? 'Unnamed Captain' : user.name,
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              color: _text,
                            ),
                          ), // Decreased
                          SizedBox(height: 4),
                          Row(
                            children: [
                              const _RoleBadge(role: 'captain'),
                              SizedBox(width: 6),
                              _VerifBadge(status: user.verificationStatus),
                            ],
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(
                        Icons.close_rounded,
                        color: _muted,
                        size: 18,
                      ),
                      style: IconButton.styleFrom(
                        backgroundColor: _bg,
                        shape: const CircleBorder(),
                      ),
                    ), // Decreased
                  ],
                ),
              ),
              SizedBox(height: 16),
              const Divider(height: 1, color: _border),
              Expanded(
                child: ListView(
                  controller: controller,
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
                  children: [
                    // Increased bottom padding
                    _DetailCard(
                      title: 'Contact Info',
                      children: [
                        _InfoRow(
                          icon: Icons.email_rounded,
                          label: 'Email',
                          value: user.email,
                        ),
                        if (user.phone != null && user.phone!.isNotEmpty)
                          _InfoRow(
                            icon: Icons.phone_rounded,
                            label: 'Phone',
                            value: user.phone!,
                          ),
                      ],
                    ),
                    SizedBox(height: 14),
                    _DetailCard(
                      title: 'Account',
                      children: [
                        _InfoRow(
                          icon: Icons.badge_rounded,
                          label: 'Captain ID',
                          value: user.publicId,
                        ),
                        _InfoRow(
                          icon: Icons.calendar_today_rounded,
                          label: 'Registered',
                          value: DateFormat('d MMM y').format(user.createdAt),
                        ),
                        if (user.vehicleType != null)
                          _InfoRow(
                            icon: Icons.two_wheeler_rounded,
                            label: 'Vehicle Type',
                            value: pretty(user.vehicleType!),
                          ),
                        _InfoRow(
                          icon: Icons.star_rounded,
                          label: 'Rating',
                          value:
                              '${user.ratingScore.toStringAsFixed(1)} (${user.ratingCount} reviews)',
                        ),
                      ],
                    ),
                    SizedBox(height: 14),

                    // Verification progress
                    _DetailCard(
                      title: 'Document Verification',
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(14), // Decreased
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _VerifItem(
                                label: 'Aadhaar Card',
                                uploaded: user.aadhaarCardUrl != null,
                              ),
                              SizedBox(height: 10),
                              _VerifItem(
                                label: 'Driving Licence',
                                uploaded: user.drivingLicenceUrl != null,
                              ),
                              SizedBox(height: 16),
                              GestureDetector(
                                onTap: () => showDialog(
                                  context: context,
                                  builder: (_) =>
                                      CaptainDocumentsDialog(user: user),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.visibility_rounded,
                                      color: _navy,
                                      size: 14,
                                    ), // Decreased
                                    SizedBox(width: 6),
                                    Text(
                                      'View Documents',
                                      style: GoogleFonts.inter(
                                        color: _navy,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 10,
                                      ),
                                    ), // Decreased
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 20),

                    // Verification actions
                    if (user.verificationStatus != 'verified') ...[
                      _ActionButton(
                        icon: Icons.check_circle_rounded,
                        label: 'Approve Captain',
                        color: _green,
                        onTap: () {
                          Navigator.pop(context);
                          onAction(user, 'approve');
                        },
                      ),
                      SizedBox(height: 10),
                    ],
                    if (user.verificationStatus != 'rejected') ...[
                      _ActionButton(
                        icon: Icons.cancel_rounded,
                        label: 'Reject Documents',
                        color: _red,
                        onTap: () {
                          Navigator.pop(context);
                          onAction(user, 'reject');
                        },
                      ),
                      SizedBox(height: 10),
                    ],
                    _ActionButton(
                      icon: Icons.person_rounded,
                      label: 'Set as Passenger',
                      color: _blue,
                      onTap: () {
                        Navigator.pop(context);
                        onAction(user, 'user');
                      },
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

// ─── Verification Item ─────────────────────────────────────────────────────────
class _VerifItem extends StatelessWidget {
  const _VerifItem({required this.label, required this.uploaded});
  final String label;
  final bool uploaded;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(
        uploaded
            ? Icons.check_circle_rounded
            : Icons.radio_button_unchecked_rounded,
        color: uploaded ? _green : _muted,
        size: 14,
      ), // Decreased
      SizedBox(width: 8), // Decreased
      Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: uploaded ? _text : _muted,
        ),
      ), // Decreased
    ],
  );
}

// ─── Action Button ─────────────────────────────────────────────────────────────
class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    height: 46, // Decreased
    child: ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(
        icon,
        size: 16,
        color: color == _yellow ? _navy : Colors.white,
      ), // Decreased
      label: Text(
        label,
        style: GoogleFonts.inter(
          fontWeight: FontWeight.w700,
          fontSize: 11,
          color: color == _yellow ? _navy : Colors.white,
        ),
      ), // Decreased
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 0,
      ), // Decreased
    ),
  );
}

// ─── Detail Card ───────────────────────────────────────────────────────────────
class _DetailCard extends StatelessWidget {
  const _DetailCard({required this.title, required this.children});
  final String title;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: _bg,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: _border),
    ), // Decreased
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
          child: Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              color: _muted,
              letterSpacing: 0.5,
            ),
          ),
        ), // Decreased
        ...children.map(
          (c) => Column(
            children: [
              const Divider(
                height: 1,
                color: _border,
                indent: 14,
                endIndent: 14,
              ),
              c,
            ],
          ),
        ), // Decreased
      ],
    ),
  );
}

// ─── Info Row ──────────────────────────────────────────────────────────────────
class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label, value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(
      vertical: 10,
      horizontal: 14,
    ), // Decreased
    child: Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: _navy.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 12, color: _navy),
        ), // Decreased
        SizedBox(width: 10), // Decreased
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 8,
                  color: _muted,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 2),
              Text(
                value,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: _text,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

// ─── Empty State ───────────────────────────────────────────────────────────────
class _EmptyUsersState extends StatelessWidget {
  const _EmptyUsersState({required this.onClear});
  final VoidCallback onClear;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AdminColors.primary.withValues(alpha: 0.06),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.people_outline_rounded,
              size: 40,
              color: AdminColors.primary,
            ),
          ),
          SizedBox(height: 20),
          Text(
            'No accounts found',
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AdminColors.textPrimary,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'There are no accounts matching the selected filters.',
            style: GoogleFonts.inter(
              color: AdminColors.textSecondary,
              fontSize: 11,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 24),
          OutlinedButton(
            onPressed: onClear,
            style: OutlinedButton.styleFrom(
              foregroundColor: AdminColors.primary,
              side: const BorderSide(color: AdminColors.primary),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: Text(
              'Clear Filters',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w700,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

// ─── Skeleton Loader ───────────────────────────────────────────────────────────
class _UsersSkeletonLoader extends StatelessWidget {
  const _UsersSkeletonLoader();
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(16),
    children: List.generate(5, (_) => _SkeletonCard()),
  );
}

class _SkeletonCard extends StatelessWidget {
  static Widget _bone(double w, double h, {double r = 8}) => Container(
    width: w,
    height: h,
    decoration: BoxDecoration(
      color: const Color(0xFFE8EDF3),
      borderRadius: BorderRadius.circular(r),
    ),
  );

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: _card,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: _border),
    ),
    child: Row(
      children: [
        _bone(48, 48, r: 14),
        SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _bone(120, 14),
              SizedBox(height: 6),
              _bone(180, 11),
              SizedBox(height: 8),
              _bone(60, 20, r: 20),
            ],
          ),
        ),
        _bone(20, 20, r: 10),
      ],
    ),
  );
}
