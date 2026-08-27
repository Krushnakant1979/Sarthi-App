import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/domain/app_user.dart';
import '../admin_providers.dart';
import '../admin_design.dart';
import '../admin_dashboard_screen.dart';
import '../widgets/admin_badges.dart';
import '../widgets/admin_common_widgets.dart';
import '../widgets/captain_documents_dialog.dart';


class UsersTab extends ConsumerStatefulWidget {
  const UsersTab({super.key});
  @override
  ConsumerState<UsersTab> createState() => UsersTabState();
}


class UsersTabState extends ConsumerState<UsersTab> {
  String search = '';
  @override
  Widget build(BuildContext context) {
    final role = ref.watch(usersFilterProvider);
    final async = ref.watch(allUsersProvider);
    return AsyncPage(
      loading: async.isLoading, error: async.error,
      child: Builder(builder: (_) {
        final users = (async.value ?? []).where((u) {
          final matchesRole = role == 'all' || u.role == role || (role == 'pending' && u.role == 'captain' && u.verificationStatus == 'pending_review');
          return matchesRole && '${u.uid} ${u.name} ${u.email} ${u.phone ?? ''}'.toLowerCase().contains(search.toLowerCase());
        }).toList();
        return Column(children: [
          FilterPanel(children: [
            DarkDropdown<String>(
              value: role, label: 'Account type', icon: Icons.manage_accounts_rounded,
              items: const {'all': 'All users', 'user': 'Users', 'captain': 'Captains', 'admin': 'Admins', 'pending': 'Pending approval'}.entries
                  .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value, style: TextStyle(color: context.colors.text, fontSize: 13)))).toList(),
              onChanged: (v) => ref.read(usersFilterProvider.notifier).state = v ?? 'all',
            ),
            SearchField(hint: 'Search name, email, phone or ID...', onChanged: (v) => setState(() => search = v.trim())),
          ]),
          Expanded(child: users.isEmpty
              ? const EmptyState(icon: Icons.people_outline, title: 'No matching users', subtitle: 'Try another account filter.')
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  itemCount: users.length,
                  itemBuilder: (_, i) => UserCard(user: users[i], onAction: _performAction),
                )),
        ]);
      }),
    );
  }

  Future<void> _performAction(AppUser user, String action) async {
    final label = switch (action) {
      'approve' => 'approve this captain', 'reject' => 'reject these documents', _ => 'change this account role to ${pretty(action)}',
    };
    final confirmed = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
      backgroundColor: context.colors.surfaceAlt, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text('Confirm admin action', style: TextStyle(color: context.colors.text, fontWeight: FontWeight.w800)),
      content: Text('Do you want to $label for ${user.name}?', style: TextStyle(color: context.colors.textMuted)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Cancel', style: TextStyle(color: context.colors.textMuted))),
        FilledButton(onPressed: () => Navigator.pop(context, true), style: FilledButton.styleFrom(backgroundColor: context.colors.adminAccent, foregroundColor: Colors.black), child: const Text('Confirm', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w700))),
      ],
    )) ?? false;
    if (!confirmed || !mounted) return;
    try {
      final repo = ref.read(adminRepositoryProvider);
      if (action == 'approve' || action == 'reject') {
        await repo.updateCaptainVerification(user.uid, action == 'approve' ? 'verified' : 'rejected');
      } else {
        await repo.updateUserRole(user.uid, action);
      }
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(backgroundColor: context.colors.success, content: Text('Admin action completed successfully.', style: TextStyle(color: Colors.white))));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(backgroundColor: context.colors.error, content: Text(friendlyError(e), style: const TextStyle(color: Colors.white))));
    }
  }
}


class UserCard extends StatelessWidget {
  const UserCard({super.key, required this.user, required this.onAction});
  final AppUser user;
  final Future<void> Function(AppUser, String) onAction;
  @override
  Widget build(BuildContext context) {
    final pending = user.role == 'captain' && user.verificationStatus == 'pending_review';
    final initial = user.name.isEmpty ? 'U' : user.name[0].toUpperCase();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: context.colors.surface, borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: user.role == 'captain' ? () => showDialog(context: context, builder: (_) => CaptainDocumentsDialog(user: user)) : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [context.colors.adminAccent, context.colors.adminAccentDark], begin: Alignment.topLeft, end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(child: Text(initial, style: TextStyle(color: context.colors.background, fontWeight: FontWeight.w800, fontSize: 16))),
              ),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Flexible(child: Text(user.name.isEmpty ? 'Unnamed user' : user.name, style: TextStyle(color: context.colors.text, fontWeight: FontWeight.w700, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis)),
                  if (pending) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: context.colors.warning.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10), border: Border.all(color: context.colors.warning.withValues(alpha: 0.4))),
                      child: Text('Review', style: TextStyle(color: context.colors.warning, fontSize: 10, fontWeight: FontWeight.w700)),
                    ),
                  ],
                ]),
                const SizedBox(height: 4),
                Text(user.email, style: TextStyle(color: context.colors.textMuted, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
              ])),
              const SizedBox(width: 8),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                RoleBadge(role: user.role),
                if (user.role == 'captain') ...[
                  const SizedBox(height: 4),
                  VerificationBadge(status: user.verificationStatus),
                ],
              ]),
              PopupMenuButton<String>(
                color: context.colors.surfaceAlt, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                icon: Icon(Icons.more_vert_rounded, color: context.colors.textMuted),
                onSelected: (v) => onAction(user, v),
                itemBuilder: (_) => [
                  if (user.role == 'captain') ...[
                    _popItem(context, 'approve', Icons.check_circle_outline, context.colors.success, 'Approve documents'),
                    _popItem(context, 'reject', Icons.cancel_outlined, context.colors.error, 'Reject documents'),
                    const PopupMenuDivider(),
                  ],
                  _popItem(context, 'user', Icons.person_rounded, context.colors.adminInfo, 'Set as User'),
                  _popItem(context, 'captain', Icons.local_taxi_rounded, context.colors.warning, 'Set as Captain'),
                  _popItem(context, 'admin', Icons.admin_panel_settings_rounded, context.colors.adminAccent, 'Set as Admin'),
                ],
              ),
            ]),
          ),
        ),
      ),
    );
  }
  PopupMenuItem<String> _popItem(BuildContext context, String value, IconData icon, Color color, String label) =>
      PopupMenuItem(value: value, child: Row(children: [Icon(icon, color: color, size: 18), const SizedBox(width: 10), Text(label, style: TextStyle(color: context.colors.text, fontSize: 13))]));
}
