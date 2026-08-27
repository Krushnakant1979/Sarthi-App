import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import '../../../core/design/tokens.dart';
import '../../auth/presentation/auth_providers.dart';

class CaptainProfileScreen extends ConsumerStatefulWidget {
  const CaptainProfileScreen({super.key});

  @override
  ConsumerState<CaptainProfileScreen> createState() =>
      _CaptainProfileScreenState();
}

class _CaptainProfileScreenState extends ConsumerState<CaptainProfileScreen> {
  bool _isLoading = false;

  Future<void> _pickAndUploadImage(WidgetRef ref, String uid) async {
    setState(() {
      _isLoading = true;      });

    try {
      final picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);
      if (image == null) {
        setState(() => _isLoading = false);
        return;
      }

      // Compress image
      final compressedBytes = await FlutterImageCompress.compressWithFile(
        image.path,
        minWidth: 500,
        minHeight: 500,
        quality: 70,
      );

      if (compressedBytes == null) {
        throw Exception("Failed to compress image");
      }

      // Write compressed bytes to a temporary file
      final tempDir = Directory.systemTemp;
      final tempFile = File('${tempDir.path}/temp_profile.jpg');
      await tempFile.writeAsBytes(compressedBytes);

      // Upload to Storage
      final userRepo = ref.read(userRepositoryProvider);
      final downloadUrl = await userRepo.uploadProfilePicture(uid, tempFile);

      // Update Firestore profile
      await userRepo.updateUser(uid, {
        'profilePictureUrl': downloadUrl,
      });

      // Invalidate provider to fetch updated user
      ref.invalidate(currentUserProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile picture updated successfully!'),
            backgroundColor: Color(0xFF16A34A),
          ),
        );
      }
    } catch (e) {

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update picture: $e'),
            backgroundColor: context.colors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showEditDialog(
    String title,
    String initialValue,
    Function(String) onSave,
  ) {
    final controller = TextEditingController(text: initialValue);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Edit $title',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: 'Enter new $title',
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: context.colors.primary, width: 2),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Color(0xFF6B7280)),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              onSave(controller.text.trim());
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: context.colors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showReauthDialog(
    String title,
    String currentEmail,
    Function(String, String) onReauthSuccess,
  ) {
    final passwordController = TextEditingController();
    final newValueController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Update $title',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'For your security, please verify your current password.',
              style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'Current Password',
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: context.colors.primary, width: 2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: newValueController,
              obscureText: title == 'Password',
              decoration: InputDecoration(
                labelText: 'New $title',
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: context.colors.primary, width: 2),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Color(0xFF6B7280)),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              onReauthSuccess(
                passwordController.text,
                newValueController.text.trim(),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: context.colors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Verify & Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleSensitiveUpdate(
    String title,
    String currentEmail,
    String uid,
    bool isEmail,
  ) async {
    _showReauthDialog(title, currentEmail, (password, newValue) async {
      if (newValue.isEmpty || password.isEmpty) return;

      setState(() => _isLoading = true);
      try {
        final authRepo = ref.read(authRepositoryProvider);
        await authRepo.reauthenticate(password);

        if (isEmail) {
          await authRepo.updateEmail(newValue);
          await ref.read(userRepositoryProvider).updateUser(uid, {
            'email': newValue,
          });
        } else {
          await authRepo.updatePassword(newValue);
        }

        ref.invalidate(currentUserProvider);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '$title updated successfully! ${isEmail ? 'Please check your inbox to verify.' : ''}',
              ),
              backgroundColor: const Color(0xFF16A34A),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to update $title: $e'),
              backgroundColor: context.colors.error,
            ),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    });
  }

  IconData _getVehicleIcon(String? type) {
    final t = type?.toLowerCase() ?? '';
    if (t.contains('bike') || t.contains('motorcycle')) {
      return Icons.two_wheeler_outlined;
    }
    if (t.contains('auto')) {
      return Icons.electric_rickshaw_outlined;
    }
    return Icons.directions_car_outlined;
  }

  String _formatVehicleType(String? type) {
    if (type == null || type.isEmpty) return 'Not Assigned';
    if (type.toLowerCase() == 'cab') return 'Cab (Car)';
    if (type.toLowerCase() == 'auto') return 'Auto Rickshaw';
    if (type.toLowerCase() == 'bike') return 'Bike (Two Wheeler)';
    return type[0].toUpperCase() + type.substring(1).toLowerCase();
  }

  @override
  Widget build(BuildContext context) {
    final appUserAsync = ref.watch(currentUserProvider);

    return Scaffold(
      backgroundColor: context.colors.background,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ──────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 8,
                          offset: Offset(0, 3),
                        ),
                      ],
                    ),
                    child: IconButton(
                      onPressed: () => context.pop(),
                      icon: Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: context.colors.primary,
                        size: 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    'My Profile',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: context.colors.primary,
                    ),
                  ),
                ],
              ),
            ),

            if (_isLoading)
              LinearProgressIndicator(color: context.colors.liveTeal),

            // ── Content ─────────────────────────────────────────
            Expanded(
              child: appUserAsync.when(
                data: (user) {
                  if (user == null) {
                    return const Center(
                      child: Text(
                        'Profile not found',
                        style: TextStyle(color: Color(0xFF6B7280)),
                      ),
                    );
                  }

                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        // Profile Picture Section
                        Center(
                          child: Stack(
                            children: [
                              Container(
                                width: 120,
                                height: 120,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE5E7EB),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 4,
                                  ),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Colors.black12,
                                      blurRadius: 10,
                                      offset: Offset(0, 4),
                                    ),
                                  ],
                                  image: user.profilePictureUrl != null
                                      ? DecorationImage(
                                          image: NetworkImage(
                                            user.profilePictureUrl!,
                                          ),
                                          fit: BoxFit.cover,
                                        )
                                      : null,
                                ),
                                child: user.profilePictureUrl == null
                                    ? const Icon(
                                        Icons.person_rounded,
                                        size: 60,
                                        color: Color(0xFF9CA3AF),
                                      )
                                    : null,
                              ),
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: GestureDetector(
                                  onTap: () =>
                                      _pickAndUploadImage(ref, user.uid),
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: context.colors.primary,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.camera_alt_rounded,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Verification Status Badge & Rating
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: user.verificationStatus == 'verified'
                                    ? const Color(0xFF16A34A).withValues(alpha: 0.1)
                                    : const Color(
                                        0xFFF59E0B,
                                      ).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: user.verificationStatus == 'verified'
                                      ? const Color(
                                          0xFF16A34A,
                                        ).withValues(alpha: 0.3)
                                      : const Color(
                                          0xFFF59E0B,
                                        ).withValues(alpha: 0.3),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    user.verificationStatus == 'verified'
                                        ? Icons.verified_rounded
                                        : Icons.pending_actions_rounded,
                                    color: user.verificationStatus == 'verified'
                                        ? const Color(0xFF16A34A)
                                        : const Color(0xFFF59E0B),
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    user.verificationStatus.toUpperCase(),
                                    style: TextStyle(
                                      color: user.verificationStatus == 'verified'
                                          ? const Color(0xFF16A34A)
                                          : const Color(0xFFF59E0B),
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: context.colors.rapidoYellow.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: context.colors.rapidoYellow.withValues(alpha: 0.5),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.star_rounded,
                                    color: context.colors.primary,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    user.ratingCount > 0 
                                      ? (user.ratingScore / user.ratingCount).toStringAsFixed(1)
                                      : 'New',
                                    style: TextStyle(
                                      color: context.colors.primary,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 32),

                        // Basic Info Section
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Basic Information',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                              color: context.colors.primary,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFE5E7EB)),
                          ),
                          child: Column(
                            children: [
                              _buildProfileItem(
                                Icons.person_outline_rounded,
                                'Full Name',
                                user.name,
                                () {
                                  _showEditDialog('Full Name', user.name, (
                                    val,
                                  ) async {
                                    if (val.isEmpty) return;
                                    setState(() => _isLoading = true);
                                    await ref
                                        .read(userRepositoryProvider)
                                        .updateUser(user.uid, {'name': val});
                                    ref.invalidate(currentUserProvider);
                                    setState(() => _isLoading = false);
                                  });
                                },
                              ),
                              const Divider(height: 1, indent: 56),
                              _buildProfileItem(
                                Icons.phone_outlined,
                                'Phone Number',
                                user.phone ?? 'Add Phone Number',
                                () {
                                  _showEditDialog(
                                    'Phone Number',
                                    user.phone ?? '',
                                    (val) async {
                                      setState(() => _isLoading = true);
                                      await ref
                                          .read(userRepositoryProvider)
                                          .updateUser(user.uid, {'phone': val});
                                      ref.invalidate(currentUserProvider);
                                      setState(() => _isLoading = false);
                                    },
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Vehicle Information Section
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Vehicle Information',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                              color: context.colors.primary,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFE5E7EB)),
                          ),
                          child: _buildProfileItem(
                            _getVehicleIcon(user.vehicleType),
                            'Vehicle Type',
                            _formatVehicleType(user.vehicleType),
                            null,
                            isReadOnly: true,
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Security Section
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Security',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                              color: context.colors.primary,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFE5E7EB)),
                          ),
                          child: Column(
                            children: [
                              _buildProfileItem(
                                Icons.email_outlined,
                                'Email Address',
                                user.email,
                                () {
                                  _handleSensitiveUpdate(
                                    'Email Address',
                                    user.email,
                                    user.uid,
                                    true,
                                  );
                                },
                              ),
                              const Divider(height: 1, indent: 56),
                              _buildProfileItem(
                                Icons.lock_outline_rounded,
                                'Password',
                                '••••••••',
                                () {
                                  _handleSensitiveUpdate(
                                    'Password',
                                    user.email,
                                    user.uid,
                                    false,
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // System Section
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'System Information',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                              color: context.colors.primary,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFE5E7EB)),
                          ),
                          child: _buildProfileItem(
                            Icons.badge_outlined,
                            'Captain ID',
                            user.uid,
                            null,
                            isReadOnly: true,
                          ),
                        ),
                        const SizedBox(height: 40),
                      ],
                    ),
                  );
                },
                loading: () => Center(
                  child: CircularProgressIndicator(color: context.colors.liveTeal),
                ),
                error: (e, s) => Center(
                  child: Text(
                    'Error: $e',
                    style: TextStyle(color: context.colors.error),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileItem(
    IconData icon,
    String title,
    String value,
    VoidCallback? onTap, {
    bool isReadOnly = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: context.colors.primary, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF6B7280),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: context.colors.primary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (!isReadOnly)
              const Icon(Icons.chevron_right_rounded, color: Color(0xFF9CA3AF)),
          ],
        ),
      ),
    );
  }
}
