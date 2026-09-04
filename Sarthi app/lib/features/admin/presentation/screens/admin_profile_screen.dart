import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../auth/presentation/auth_providers.dart';
import '../../../auth/domain/app_user.dart';
import 'package:google_fonts/google_fonts.dart';

// ─── Brand Colors ──────────────────────────────────────────────────────────────
const _navy = Color(0xFF0B2748);
const _yellow = Color(0xFFFFD21E);
const _green = Color(0xFF16A34A);
const _orange = Color(0xFFF59E0B);
const _red = Color(0xFFDC2626);
const _bg = Color(0xFFF4F7FA);
const _card = Colors.white;
const _text = Color(0xFF172B4D);
const _muted = Color(0xFF6B778C);
const _border = Color(0xFFE2E8F0);

class AdminProfileScreen extends ConsumerStatefulWidget {
  const AdminProfileScreen({super.key});
  @override
  ConsumerState<AdminProfileScreen> createState() => _AdminProfileScreenState();
}

class _AdminProfileScreenState extends ConsumerState<AdminProfileScreen> {
  bool _isResettingPassword = false;

  Future<void> _handlePasswordReset(AppUser user) async {
    final emailParts = user.email.split('@');
    final maskedEmail = emailParts.length == 2
        ? '${emailParts[0].isNotEmpty ? emailParts[0][0] : ''}***@${emailParts[1]}'
        : user.email;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Reset Password',
          style: GoogleFonts.inter(color: _text, fontWeight: FontWeight.w800),
        ),
        content: Text.rich(
          TextSpan(
            text: 'Send a password reset link to ',
            style: GoogleFonts.inter(color: _muted),
            children: [
              TextSpan(
                text: maskedEmail,
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w700,
                  color: _navy,
                ),
              ),
              TextSpan(text: '?'),
            ],
          ),
        ),
        actions: [
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text(
                    'Cancel',
                    style: GoogleFonts.inter(
                      color: _muted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _navy,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text(
                    'Send',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isResettingPassword = true);
    try {
      await ref.read(authRepositoryProvider).sendPasswordResetEmail(user.email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white),
                SizedBox(width: 12),
                Expanded(child: Text('Reset link sent to $maskedEmail')),
              ],
            ),
            backgroundColor: _green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send link: $e'),
            backgroundColor: _red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isResettingPassword = false);
    }
  }

  Future<void> _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.logout_rounded, color: _red),
            SizedBox(width: 12),
            Text(
              'Log Out',
              style: GoogleFonts.inter(
                color: _text,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to log out of the admin console?',
          style: GoogleFonts.inter(color: _muted),
        ),
        actions: [
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _border,
                    foregroundColor: _text,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text(
                    'Cancel',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _red,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text(
                    'Logout',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    if (confirm == true) {
      ref.read(authRepositoryProvider).signOut();
      Navigator.pop(context); // Go back after logout triggers auth state change
    }
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(currentUserProvider);

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        title: Text(
          'Admin Profile',
          style: GoogleFonts.inter(
            color: _text,
            fontWeight: FontWeight.w800,
            fontSize: 14,
          ),
        ),
        backgroundColor: _bg,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(color: _text),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: _border, height: 1),
        ),
      ),
      body: userAsync.when(
        loading: () => Center(child: CircularProgressIndicator(color: _navy)),
        error: (err, stack) =>
            Center(child: Text('Error loading profile: $err')),
        data: (user) {
          if (user == null) return Center(child: Text('Not logged in'));

          final joinedDate = DateFormat('MMMM d, yyyy').format(user.createdAt);

          return RefreshIndicator(
            color: _navy,
            onRefresh: () async => ref.refresh(currentUserProvider.future),
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                _buildPremiumHeader(user, joinedDate),
                SizedBox(height: 20),
                _buildPersonalInformation(user, joinedDate),
                SizedBox(height: 20),
                _buildAdminAccess(user),
                SizedBox(height: 20),
                _buildAccountAndSecurity(user),
                SizedBox(height: 32),
                _buildLogoutAction(),
                SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildPremiumHeader(AppUser user, String joinedDate) {
    final initial = user.name.isNotEmpty ? user.name[0].toUpperCase() : 'A';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _navy,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _navy.withValues(alpha: 0.2),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: _yellow,
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.2),
                width: 4,
              ),
            ),
            child: Center(
              child: Text(
                initial,
                style: GoogleFonts.inter(
                  color: _navy,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          SizedBox(height: 12),
          Text(
            user.name.isNotEmpty ? user.name : 'Admin',
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: _green,
                    shape: BoxShape.circle,
                  ),
                ),
                SizedBox(width: 6),
                Text(
                  'Super Admin • Active',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 12),
          Text(
            user.email,
            style: GoogleFonts.inter(color: Colors.white70, fontSize: 12),
          ),
          SizedBox(height: 4),
          Text(
            'Member since $joinedDate',
            style: GoogleFonts.inter(color: Colors.white54, fontSize: 10),
          ),
        ],
      ),
    );
  }

  Widget _buildPersonalInformation(AppUser user, String joinedDate) {
    return _CardWrapper(
      title: 'Personal Information',
      child: Column(
        children: [
          _InfoRow(
            icon: Icons.person_outline_rounded,
            label: 'Full Name',
            value: user.name,
          ),
          const Divider(height: 1, color: _border, indent: 52),
          _InfoRow(
            icon: Icons.email_outlined,
            label: 'Email Address',
            value: user.email,
          ),
          if (user.phone != null && user.phone!.isNotEmpty) ...[
            const Divider(height: 1, color: _border, indent: 52),
            _InfoRow(
              icon: Icons.phone_outlined,
              label: 'Phone Number',
              value: user.phone!,
            ),
          ],
          const Divider(height: 1, color: _border, indent: 52),
          _InfoRow(
            icon: Icons.admin_panel_settings_outlined,
            label: 'Role',
            value: 'Super Admin',
          ),
          const Divider(height: 1, color: _border, indent: 52),
          _InfoRow(
            icon: Icons.calendar_today_outlined,
            label: 'Joined Date',
            value: joinedDate,
          ),
        ],
      ),
    );
  }

  Widget _buildAdminAccess(AppUser user) {
    return _CardWrapper(
      title: 'Admin Access',
      child: Column(
        children: [
          _InfoRow(
            icon: Icons.verified_user_outlined,
            label: 'Permission Level',
            value: 'Full Access',
          ),
          const Divider(height: 1, color: _border, indent: 52),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _bg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.toggle_on_outlined,
                    color: _muted,
                    size: 16,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Account Status',
                        style: GoogleFonts.inter(
                          color: _muted,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Active',
                        style: GoogleFonts.inter(
                          color: _text,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    'Verified',
                    style: GoogleFonts.inter(
                      color: _green,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountAndSecurity(AppUser user) {
    return _CardWrapper(
      title: 'Account & Security',
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _isResettingPassword
                    ? null
                    : () => _handlePasswordReset(user),
                icon: _isResettingPassword
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          color: _yellow,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(
                        Icons.lock_reset_rounded,
                        color: _yellow,
                        size: 18,
                      ),
                label: Text(
                  _isResettingPassword
                      ? 'Sending...'
                      : 'Send Password Reset Link',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _navy,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ),
          const Divider(height: 1, color: _border),
          _InfoRow(
            icon: Icons.mark_email_read_outlined,
            label: 'Email Verification',
            value: 'Verified',
          ),
        ],
      ),
    );
  }

  Widget _buildLogoutAction() {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: OutlinedButton.icon(
        onPressed: _handleLogout,
        icon: const Icon(Icons.logout_rounded, size: 18),
        label: Text(
          'Log Out',
          style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 13),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: _red,
          side: const BorderSide(color: _red, width: 1.5),
          backgroundColor: _card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }
}

class _CardWrapper extends StatelessWidget {
  const _CardWrapper({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: _text,
              letterSpacing: 0.3,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: child,
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _bg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: _muted, size: 16),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.inter(
                    color: _muted,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  value,
                  style: GoogleFonts.inter(
                    color: _text,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
