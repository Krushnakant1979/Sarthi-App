import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../auth/presentation/auth_providers.dart';
import '../../../core/design/tokens.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _isEditing = false;
  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (_nameController.text.trim().isEmpty) return;
    setState(() => _isSaving = true);
    try {
      final user = ref.read(authStateProvider).value;
      if (user != null) {
        await ref.read(userRepositoryProvider).updateUser(user.uid, {
          'name': _nameController.text.trim(),
          'phone': _phoneController.text.trim(),
        });
        ref.invalidate(currentUserProvider);
        if (mounted) {
          setState(() => _isEditing = false);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _updateAddress(String uid, String type) async {
    final result = await context.push('/search');
    if (result != null && result is Map<String, dynamic>) {
      try {
        await ref.read(userRepositoryProvider).updateUser(uid, {
          type: result,
        });
        ref.invalidate(currentUserProvider);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Address updated successfully!'), backgroundColor: Color(0xFF16A34A)),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to update address: $e'), backgroundColor: context.colors.error),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(currentUserProvider);
    final authUser = ref.watch(authStateProvider).value;

    return Scaffold(
      backgroundColor: context.colors.background,
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          // ── Header ────────────────────────────────────────────────
          Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.zero,
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 16, 16),
                child: Column(
                  children: [
                    // Top row
                    Row(
                      children: [
                        IconButton(
                          onPressed: () => context.pop(),
                          icon: Icon(
                            Icons.arrow_back_ios_new_rounded,
                            color: context.colors.primary,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            'My Profile',
                            style: TextStyle(
                              color: context.colors.primary,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        userAsync.when(
                          data: (user) => TextButton(
                            onPressed: user == null
                                ? null
                                : () {
                                    if (_isEditing) {
                                      _saveProfile();
                                    } else {
                                      _nameController.text = user.name;
                                      _phoneController.text = user.phone ?? '';
                                      setState(() => _isEditing = true);
                                    }
                                  },
                            child: Text(
                              _isEditing ? 'Save' : 'Edit',
                              style: TextStyle(
                                color: context.colors.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          loading: () => const SizedBox.shrink(),
                          error: (_, stack) => const SizedBox.shrink(),
                        ),
                      ],
                    ),
                    // Avatar
                    const SizedBox(height: 12),
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: context.colors.primary.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: context.colors.primary.withValues(alpha: 0.2),
                          width: 2,
                        ),
                      ),
                      child: Icon(
                        Icons.person_rounded,
                        color: context.colors.primary,
                        size: 44,
                      ),
                    ),
                    const SizedBox(height: 12),
                    userAsync.when(
                      data: (user) => Text(
                        user?.name ?? 'Sarthi App User',
                        style: TextStyle(
                          color: context.colors.primary,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      loading: () => const SizedBox(
                        width: 120,
                        height: 20,
                        child: LinearProgressIndicator(),
                      ),
                      error: (_, stack) => Text(
                        'User',
                        style: TextStyle(color: context.colors.primary),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      authUser?.email ?? '',
                      style: TextStyle(
                        color: context.colors.primary.withValues(alpha: 0.7),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Body ─────────────────────────────────────────────────
          userAsync.when(
            data: (user) {
              if (user == null) {
                return const Center(child: Text('Could not load profile.'));
              }
              return Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 8),
                    _sectionLabel('Account Information'),
                    const SizedBox(height: 12),

                    // Name field
                    _infoCard(
                      icon: Icons.person_outline_rounded,
                      label: 'Full Name',
                      child: _isEditing
                          ? TextField(
                              controller: _nameController,
                              autofocus: true,
                              textCapitalization: TextCapitalization.words,
                                decoration: InputDecoration(
                                  filled: true,
                                  fillColor: const Color(0xFFF3F4F6),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide.none,
                                  ),
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                ),
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            )
                          : Text(
                              user.name,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),

                    const SizedBox(height: 12),

                    // Email field
                    _infoCard(
                      icon: Icons.email_outlined,
                      label: 'Email Address',
                      child: Text(
                        user.email,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Phone field
                    _infoCard(
                      icon: Icons.phone_outlined,
                      label: 'Phone Number',
                      child: _isEditing
                          ? TextField(
                              controller: _phoneController,
                              keyboardType: TextInputType.phone,
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: const Color(0xFFF3F4F6),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide.none,
                                ),
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              ),
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            )
                          : Text(
                              user.phone?.isNotEmpty == true
                                  ? user.phone!
                                  : 'Not provided',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: user.phone?.isNotEmpty == true
                                    ? null
                                    : const Color(0xFF9CA3AF),
                              ),
                            ),
                    ),

                    const SizedBox(height: 12),

                    // Role chip
                    _infoCard(
                      icon: Icons.badge_outlined,
                      label: 'Account Type',
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          user.role.toUpperCase(),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: context.colors.primary,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),

                    if (_isEditing) ...[
                      const SizedBox(height: 24),
                      _isSaving
                          ? const Center(child: CircularProgressIndicator())
                          : Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: () =>
                                        setState(() => _isEditing = false),
                                    child: const Text('Cancel'),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.black,
                                      foregroundColor: Colors.white,
                                    ),
                                    onPressed: _saveProfile,
                                    child: const Text('Save Changes'),
                                  ),
                                ),
                              ],
                            ),
                    ],

                    const SizedBox(height: 32),
                    _sectionLabel('Saved Places'),
                    const SizedBox(height: 12),
                    _actionTile(
                      icon: Icons.home_rounded,
                      label: user.homeAddress?['description'] ?? 'Add Home',
                      onTap: () => _updateAddress(user.uid, 'homeAddress'),
                    ),
                    const SizedBox(height: 8),
                    _actionTile(
                      icon: Icons.work_rounded,
                      label: user.workAddress?['description'] ?? 'Add Work',
                      onTap: () => _updateAddress(user.uid, 'workAddress'),
                    ),

                    const SizedBox(height: 32),
                    _sectionLabel('App'),
                    const SizedBox(height: 12),

                    _actionTile(
                      icon: Icons.history_rounded,
                      label: 'Ride History',
                      onTap: () => context.push('/history'),
                    ),
                    const SizedBox(height: 8),
                    _actionTile(
                      icon: Icons.shield_outlined,
                      label: 'Legal & Privacy',
                      onTap: () => context.push('/legal'),
                    ),
                    const SizedBox(height: 8),
                    _actionTile(
                      icon: Icons.logout_rounded,
                      label: 'Sign Out',
                      isError: true,
                      onTap: () async {
                        await ref.read(authRepositoryProvider).signOut();
                        if (context.mounted) context.go('/login');
                      },
                    ),
                  ],
                ),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String label) => Text(
    label.toUpperCase(),
    style: const TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w700,
      letterSpacing: 1.2,
      color: Color(0xFF9CA3AF),
    ),
  );

  Widget _infoCard({
    required IconData icon,
    required String label,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: context.colors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: context.colors.primary, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF9CA3AF),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                child,
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionTile({
    required IconData icon,
    required String label,
    bool isError = false,
    required VoidCallback onTap,
  }) {
    final bgColor = isError ? context.colors.error.withValues(alpha: 0.1) : const Color(0xFFF3F4F6);
    final iconColor = isError ? context.colors.error : context.colors.primary;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Color(0x14000000),
              blurRadius: 6,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: Colors.grey[400],
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
