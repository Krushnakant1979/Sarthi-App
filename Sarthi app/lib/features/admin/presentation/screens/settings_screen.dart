import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../admin_design.dart';
import '../admin_providers.dart';
import '../widgets/admin_common_widgets.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  // Local state for batch saving
  String? _localEmail;
  String? _localPhone;
  List<String>? _localZones;

  bool _isSaving = false;

  void _resetLocalState(Map<String, dynamic> data) {
    _localEmail = data['supportEmail'] as String? ?? '';
    _localPhone = data['supportPhone'] as String? ?? '';
    _localZones = List<String>.from(data['activeZones'] ?? []);
  }

  bool _hasChanges(Map<String, dynamic> data) {
    if (_localEmail == null || _localPhone == null || _localZones == null)
      return false;

    final remoteEmail = data['supportEmail'] as String? ?? '';
    final remotePhone = data['supportPhone'] as String? ?? '';
    final remoteZones = List<String>.from(data['activeZones'] ?? []);

    if (_localEmail != remoteEmail) return true;
    if (_localPhone != remotePhone) return true;

    if (_localZones!.length != remoteZones.length) return true;
    for (int i = 0; i < _localZones!.length; i++) {
      if (_localZones![i] != remoteZones[i]) return true;
    }

    return false;
  }

  Future<void> _saveChanges() async {
    if (_localEmail == null || _localPhone == null || _localZones == null)
      return;

    setState(() => _isSaving = true);
    try {
      await ref.read(adminRepositoryProvider).updateGlobalSettings({
        'supportEmail': _localEmail!.trim(),
        'supportPhone': _localPhone!.trim(),
        'activeZones': _localZones!,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AdminColors.success,
            content: Text(
              'Settings saved successfully',
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
              'Failed to save: $e',
              style: GoogleFonts.inter(color: Colors.white),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(globalSettingsProvider);

    return Scaffold(
      backgroundColor: AdminColors.background,
      appBar: AppBar(
        backgroundColor: AdminColors.background,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        automaticallyImplyLeading: false,
        titleSpacing: 16,
        toolbarHeight: 56, // Decreased
        title: Row(
          children: [
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: 32, // Decreased
                height: 32, // Decreased
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: AdminColors.border),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.arrow_back_rounded,
                  color: AdminColors.textPrimary,
                  size: 16,
                ), // Decreased
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Settings & Zones',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AdminColors.textPrimary,
                      letterSpacing: -0.5,
                    ),
                  ), // Decreased
                  const SizedBox(height: 2),
                  Text(
                    'Platform controls and service areas',
                    style: GoogleFonts.inter(
                      fontSize: 9,
                      color: AdminColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ), // Decreased
                ],
              ),
            ),
            Container(
              width: 32, // Decreased
              height: 32, // Decreased
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: AdminColors.border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.admin_panel_settings_outlined,
                color: AdminColors.primary,
                size: 16,
              ), // Decreased
            ),
          ],
        ),
      ),
      body: AsyncPage(
        loading: settingsAsync.isLoading,
        error: settingsAsync.error,
        child: Builder(
          builder: (_) {
            final data = settingsAsync.value;
            if (data == null) return const SizedBox.shrink();

            // Initialize local state if not set
            if (_localEmail == null ||
                _localPhone == null ||
                _localZones == null) {
              _resetLocalState(data);
            }

            final isActive = data['isPlatformActive'] as bool? ?? true;
            final hasChanges = _hasChanges(data);

            return Stack(
              children: [
                Positioned.fill(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(
                      14,
                      10,
                      14,
                      120,
                    ), // Decreased padding
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Section Header
                        Padding(
                          padding: const EdgeInsets.only(
                            left: 4,
                            bottom: 8,
                          ), // Decreased padding
                          child: Text(
                            'PLATFORM CONTROL',
                            style: GoogleFonts.inter(
                              fontSize: 8,
                              fontWeight: FontWeight.w800,
                              color: AdminColors.textSecondary,
                              letterSpacing: 0.5,
                            ),
                          ), // Decreased font
                        ),
                        _MasterKillSwitchCard(isActive: isActive),

                        const SizedBox(height: 16), // Decreased gap

                        Padding(
                          padding: const EdgeInsets.only(
                            left: 4,
                            bottom: 8,
                          ), // Decreased padding
                          child: Text(
                            'SUPPORT',
                            style: GoogleFonts.inter(
                              fontSize: 8,
                              fontWeight: FontWeight.w800,
                              color: AdminColors.textSecondary,
                              letterSpacing: 0.5,
                            ),
                          ), // Decreased font
                        ),
                        _SupportContactsCard(
                          email: _localEmail!,
                          phone: _localPhone!,
                          onContactsSaved: (email, phone) {
                            setState(() {
                              _localEmail = email;
                              _localPhone = phone;
                            });
                          },
                        ),

                        const SizedBox(height: 16), // Decreased gap

                        Padding(
                          padding: const EdgeInsets.only(
                            left: 4,
                            bottom: 8,
                          ), // Decreased padding
                          child: Text(
                            'SERVICE COVERAGE',
                            style: GoogleFonts.inter(
                              fontSize: 8,
                              fontWeight: FontWeight.w800,
                              color: AdminColors.textSecondary,
                              letterSpacing: 0.5,
                            ),
                          ), // Decreased font
                        ),
                        _OperationalZonesCard(
                          zones: _localZones!,
                          onZonesChanged: (newZones) {
                            setState(() {
                              _localZones = newZones;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                ),

                // Docked Save Button
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: EdgeInsets.fromLTRB(
                      16,
                      24,
                      16,
                      MediaQuery.of(context).padding.bottom + 12,
                    ), // Decreased padding
                    decoration: BoxDecoration(
                      color: AdminColors.background,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          AdminColors.background.withValues(alpha: 0.0),
                          AdminColors.background,
                          AdminColors.background,
                        ],
                        stops: const [0.0, 0.4, 1.0],
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _SettingsSaveButton(
                          onPressed: hasChanges && !_isSaving
                              ? _saveChanges
                              : null,
                          isLoading: _isSaving,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Review changes before applying them.',
                          style: GoogleFonts.inter(
                            fontSize: 9,
                            color: AdminColors.textSecondary,
                          ),
                        ), // Decreased font
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Master Kill Switch Components
// ---------------------------------------------------------------------------
class _MasterKillSwitchCard extends ConsumerStatefulWidget {
  final bool isActive;
  const _MasterKillSwitchCard({required this.isActive});

  @override
  ConsumerState<_MasterKillSwitchCard> createState() =>
      _MasterKillSwitchCardState();
}

class _MasterKillSwitchCardState extends ConsumerState<_MasterKillSwitchCard> {
  bool _isToggling = false;

  Future<void> _handleToggle(bool newValue) async {
    if (_isToggling) return;

    if (!newValue) {
      // Trying to turn off
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ), // Decreased radius
          title: Text(
            'Turn Off Platform?',
            style: GoogleFonts.inter(
              color: AdminColors.textPrimary,
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
          ), // Decreased font
          content: Text(
            'Turning this off will pause all new ride bookings immediately. Active rides will not be cancelled.\n\nAre you sure you want to proceed?',
            style: GoogleFonts.inter(
              color: AdminColors.textSecondary,
              fontSize: 11,
              height: 1.5,
            ),
          ), // Decreased font
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(
                'Keep Online',
                style: GoogleFonts.inter(
                  color: AdminColors.textSecondary,
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                ),
              ), // Decreased font
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AdminColors.error,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 0,
              ),
              child: Text(
                'Pause New Bookings',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                ),
              ), // Decreased font
            ),
          ],
        ),
      );

      if (confirm != true) return;
    }

    setState(() => _isToggling = true);

    try {
      await ref.read(adminRepositoryProvider).updateGlobalSettings({
        'isPlatformActive': newValue,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: newValue ? AdminColors.success : AdminColors.error,
            content: Text(
              newValue ? 'Platform is now Online' : 'Platform is Offline',
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
              'Failed to update platform status: $e',
              style: GoogleFonts.inter(color: Colors.white),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isToggling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12), // Decreased radius
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14), // Decreased padding
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 32, // Decreased
                height: 32, // Decreased
                decoration: BoxDecoration(
                  color: widget.isActive
                      ? AdminColors.success.withValues(alpha: 0.1)
                      : AdminColors.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8), // Decreased radius
                  border: Border.all(
                    color: widget.isActive
                        ? AdminColors.success.withValues(alpha: 0.2)
                        : AdminColors.error.withValues(alpha: 0.2),
                  ),
                ),
                child: Icon(
                  Icons.power_settings_new_rounded,
                  color: widget.isActive
                      ? AdminColors.success
                      : AdminColors.error,
                  size: 16,
                ), // Decreased
              ),
              const SizedBox(width: 10), // Decreased
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Master Kill Switch',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: AdminColors.textPrimary,
                          ),
                        ), // Decreased
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 2,
                          ), // Decreased padding
                          decoration: BoxDecoration(
                            color: widget.isActive
                                ? AdminColors.success.withValues(alpha: 0.15)
                                : AdminColors.error.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            widget.isActive ? 'Online' : 'Offline',
                            style: GoogleFonts.inter(
                              fontSize: 7,
                              fontWeight: FontWeight.w700,
                              color: widget.isActive
                                  ? AdminColors.success
                                  : AdminColors.error,
                            ), // Decreased font
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2), // Decreased
                    Text(
                      'Turn off the platform to prevent new rides during maintenance.',
                      style: GoogleFonts.inter(
                        fontSize: 9,
                        color: AdminColors.textSecondary,
                        height: 1.4,
                      ),
                    ), // Decreased font
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12), // Decreased
          // Toggle Panel
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.all(10), // Decreased
            decoration: BoxDecoration(
              color: widget.isActive
                  ? AdminColors.success.withValues(alpha: 0.08)
                  : AdminColors.error.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10), // Decreased
              border: Border.all(
                color: widget.isActive
                    ? AdminColors.success.withValues(alpha: 0.2)
                    : AdminColors.error.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.isActive
                            ? 'Platform is Online'
                            : 'Platform is Offline',
                        style: GoogleFonts.inter(
                          fontSize: 12, // Decreased
                          fontWeight: FontWeight.w800,
                          color: widget.isActive
                              ? AdminColors.success
                              : AdminColors.error,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.isActive
                            ? 'Accepting new ride requests'
                            : 'New ride bookings are temporarily paused',
                        style: GoogleFonts.inter(
                          fontSize: 9,
                          color: AdminColors.textSecondary,
                        ), // Decreased
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(
                            Icons.access_time_rounded,
                            size: 10,
                            color: AdminColors.textSecondary,
                          ), // Decreased
                          const SizedBox(width: 4),
                          Text(
                            'Updated just now',
                            style: GoogleFonts.inter(
                              fontSize: 8,
                              color: AdminColors.textSecondary,
                            ),
                          ), // Decreased
                        ],
                      ),
                    ],
                  ),
                ),
                Transform.scale(
                  scale: 1.0, // Decreased scale
                  child: _isToggling
                      ? const Padding(
                          padding: EdgeInsets.all(8),
                          child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : Switch(
                          value: widget.isActive,
                          onChanged: _handleToggle,
                          activeThumbColor: Colors.white,
                          activeTrackColor: AdminColors.success,
                          inactiveThumbColor: Colors.white,
                          inactiveTrackColor: AdminColors.textSecondary
                              .withValues(alpha: 0.5),
                          trackOutlineColor: WidgetStateProperty.all(
                            Colors.transparent,
                          ),
                        ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10), // Decreased
          // Warning Banner
          Container(
            padding: const EdgeInsets.all(8), // Decreased
            decoration: BoxDecoration(
              color: AdminColors.warning.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  color: AdminColors.warning,
                  size: 14,
                ), // Decreased
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Turning this off will pause all new ride bookings.',
                        style: GoogleFonts.inter(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF92400E),
                        ),
                      ), // Decreased
                      const SizedBox(height: 1),
                      Text(
                        'Confirmation is required to proceed.',
                        style: GoogleFonts.inter(
                          fontSize: 8,
                          color: const Color(0xFFB45309),
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
    );
  }
}

// ---------------------------------------------------------------------------
// Support Contacts Components
// ---------------------------------------------------------------------------
class _SupportContactsCard extends StatefulWidget {
  final String email;
  final String phone;
  final void Function(String, String) onContactsSaved;

  const _SupportContactsCard({
    required this.email,
    required this.phone,
    required this.onContactsSaved,
  });

  @override
  State<_SupportContactsCard> createState() => _SupportContactsCardState();
}

class _SupportContactsCardState extends State<_SupportContactsCard> {
  bool _isEditing = false;
  late TextEditingController _emailCtrl;
  late TextEditingController _phoneCtrl;

  @override
  void initState() {
    super.initState();
    _emailCtrl = TextEditingController(text: widget.email);
    _phoneCtrl = TextEditingController(text: widget.phone);
  }

  @override
  void didUpdateWidget(covariant _SupportContactsCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_isEditing) {
      if (_emailCtrl.text != widget.email) _emailCtrl.text = widget.email;
      if (_phoneCtrl.text != widget.phone) _phoneCtrl.text = widget.phone;
    }
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  void _toggleEdit() {
    if (_isEditing) {
      // Save locally
      final e = _emailCtrl.text.trim();
      final p = _phoneCtrl.text.trim();

      // Basic validation
      if (e.isEmpty || p.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AdminColors.error,
            content: Text('Fields cannot be empty'),
          ),
        );
        return;
      }

      final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+');
      if (!emailRegex.hasMatch(e)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AdminColors.error,
            content: Text('Invalid email format'),
          ),
        );
        return;
      }

      widget.onContactsSaved(e, p);
    } else {
      // Entering edit mode, ensure controllers match current values
      _emailCtrl.text = widget.email;
      _phoneCtrl.text = widget.phone;
    }

    setState(() {
      _isEditing = !_isEditing;
    });
  }

  void _copyToClipboard(String text, String type) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '$type copied to clipboard',
          style: GoogleFonts.inter(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: AdminColors.primary,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12), // Decreased radius
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14), // Decreased padding
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 24, // Decreased
                height: 24, // Decreased
                decoration: const BoxDecoration(
                  color: AdminColors.primary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.help_outline_rounded,
                  color: Colors.white,
                  size: 12,
                ), // Decreased
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Global Support Contacts',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AdminColors.textPrimary,
                  ),
                ), // Decreased
              ),
              OutlinedButton.icon(
                onPressed: _toggleEdit,
                icon: Icon(
                  _isEditing ? Icons.check_rounded : Icons.edit_rounded,
                  size: 10,
                ), // Decreased
                label: Text(
                  _isEditing ? 'Done' : 'Edit',
                  style: GoogleFonts.inter(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                  ),
                ), // Decreased
                style: OutlinedButton.styleFrom(
                  foregroundColor: AdminColors.textPrimary,
                  side: const BorderSide(color: AdminColors.border),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 0,
                  ), // Decreased
                  minimumSize: const Size(0, 24), // Decreased
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16), // Decreased

          _ContactRow(
            icon: Icons.email_outlined,
            title: 'Support email',
            value: widget.email,
            controller: _emailCtrl,
            isEditing: _isEditing,
            onCopy: () => _copyToClipboard(widget.email, 'Email'),
            keyboardType: TextInputType.emailAddress,
          ),

          const SizedBox(height: 10), // Decreased

          _ContactRow(
            icon: Icons.phone_outlined,
            title: 'Support phone',
            value: widget.phone,
            controller: _phoneCtrl,
            isEditing: _isEditing,
            onCopy: () => _copyToClipboard(widget.phone, 'Phone number'),
            keyboardType: TextInputType.phone,
          ),
        ],
      ),
    );
  }
}

class _ContactRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final TextEditingController controller;
  final bool isEditing;
  final VoidCallback onCopy;
  final TextInputType keyboardType;

  const _ContactRow({
    required this.icon,
    required this.title,
    required this.value,
    required this.controller,
    required this.isEditing,
    required this.onCopy,
    required this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8), // Decreased
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8), // Decreased
        border: Border.all(color: AdminColors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(4), // Decreased
            decoration: BoxDecoration(
              color: AdminColors.background,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              icon,
              color: AdminColors.primary,
              size: 14,
            ), // Decreased
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 8,
                    color: AdminColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ), // Decreased
                const SizedBox(height: 2), // Decreased
                if (isEditing)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: TextField(
                      controller: controller,
                      keyboardType: keyboardType,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AdminColors.textPrimary,
                      ), // Decreased
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 6,
                        ), // Decreased
                        isDense: true,
                        filled: true,
                        fillColor: AdminColors.background,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: BorderSide.none,
                        ), // Decreased radius
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: BorderSide.none,
                        ),
                        hintText: 'Enter $title',
                        hintStyle: GoogleFonts.inter(
                          fontSize: 11,
                          color: AdminColors.textSecondary,
                        ), // Decreased
                      ),
                    ),
                  )
                else
                  Text(
                    value.isEmpty ? 'Not Set' : value,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AdminColors.textPrimary,
                    ),
                  ), // Decreased
              ],
            ),
          ),
          if (!isEditing)
            IconButton(
              icon: const Icon(
                Icons.content_copy_rounded,
                color: AdminColors.textSecondary,
                size: 14,
              ), // Decreased
              onPressed: onCopy,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              splashRadius: 18,
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Operational Zones Components
// ---------------------------------------------------------------------------
class _OperationalZonesCard extends StatefulWidget {
  final List<String> zones;
  final void Function(List<String>) onZonesChanged;

  const _OperationalZonesCard({
    required this.zones,
    required this.onZonesChanged,
  });

  @override
  State<_OperationalZonesCard> createState() => _OperationalZonesCardState();
}

class _OperationalZonesCardState extends State<_OperationalZonesCard> {
  final _zoneController = TextEditingController();

  @override
  void dispose() {
    _zoneController.dispose();
    super.dispose();
  }

  void _addZone() {
    final city = _zoneController.text.trim();
    if (city.isEmpty) return;

    // Normalize capitalization (e.g. "mumbai" -> "Mumbai")
    final normalized = city
        .split(' ')
        .map((word) {
          if (word.isEmpty) return '';
          return word[0].toUpperCase() + word.substring(1).toLowerCase();
        })
        .join(' ');

    final currentZones = List<String>.from(widget.zones);

    if (currentZones
        .map((z) => z.toLowerCase())
        .contains(normalized.toLowerCase())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AdminColors.warning,
          content: Text('Zone already exists'),
        ),
      );
      return;
    }

    currentZones.add(normalized);
    widget.onZonesChanged(currentZones);

    _zoneController.clear();
    FocusScope.of(context).unfocus();
  }

  Future<void> _removeZone(String zone) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ), // Decreased
        title: Text(
          'Remove Zone?',
          style: GoogleFonts.inter(
            color: AdminColors.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 14,
          ),
        ), // Decreased
        content: Text(
          'Are you sure you want to remove $zone from operational zones? Users in this area will no longer be able to book rides.',
          style: GoogleFonts.inter(
            color: AdminColors.textSecondary,
            fontSize: 11,
            height: 1.5,
          ),
        ), // Decreased
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(
                color: AdminColors.textSecondary,
                fontWeight: FontWeight.w600,
                fontSize: 11,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AdminColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              elevation: 0,
            ),
            child: Text(
              'Remove',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w700,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final currentZones = List<String>.from(widget.zones);
    currentZones.remove(zone);
    widget.onZonesChanged(currentZones);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12), // Decreased
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14), // Decreased
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 24, // Decreased
                height: 24, // Decreased
                decoration: BoxDecoration(
                  color: AdminColors.warning.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.location_on_rounded,
                  color: AdminColors.warning,
                  size: 12,
                ), // Decreased
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Operational Zones',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AdminColors.textPrimary,
                      ),
                    ), // Decreased
                    const SizedBox(height: 2),
                    Text(
                      'Manage cities and regions where users can book rides.',
                      style: GoogleFonts.inter(
                        fontSize: 8,
                        color: AdminColors.textSecondary,
                      ),
                    ), // Decreased
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 4,
                  vertical: 2,
                ), // Decreased
                decoration: BoxDecoration(
                  color: AdminColors.success.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4), // Decreased
                ),
                child: Text(
                  '${widget.zones.length} active',
                  style: GoogleFonts.inter(
                    color: AdminColors.success,
                    fontWeight: FontWeight.w700,
                    fontSize: 8,
                  ),
                ), // Decreased
              ),
            ],
          ),

          const SizedBox(height: 16), // Decreased

          if (widget.zones.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Center(
                child: Text(
                  'No active zones set.',
                  style: GoogleFonts.inter(
                    color: AdminColors.textSecondary,
                    fontSize: 10,
                    fontStyle: FontStyle.italic,
                  ),
                ), // Decreased
              ),
            )
          else
            ...widget.zones.map(
              (zone) => Padding(
                padding: const EdgeInsets.only(bottom: 8), // Decreased
                child: _OperationalZoneItem(
                  zone: zone,
                  onRemove: () => _removeZone(zone),
                ),
              ),
            ),

          const SizedBox(height: 6),

          Text(
            'Add a service area',
            style: GoogleFonts.inter(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: AdminColors.textPrimary,
            ),
          ), // Decreased
          const SizedBox(height: 6),

          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _zoneController,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: AdminColors.textPrimary,
                  ), // Decreased
                  decoration: InputDecoration(
                    hintText: 'Enter city or region',
                    hintStyle: GoogleFonts.inter(
                      color: AdminColors.textSecondary,
                      fontSize: 11,
                    ), // Decreased
                    filled: true,
                    fillColor: Colors.white,
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      color: AdminColors.textSecondary,
                      size: 14,
                    ), // Decreased
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8), // Decreased
                      borderSide: const BorderSide(color: AdminColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: AdminColors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: AdminColors.primary),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ), // Decreased
                  ),
                  onSubmitted: (_) => _addZone(),
                ),
              ),
              const SizedBox(width: 10), // Decreased
              ElevatedButton.icon(
                onPressed: _addZone,
                icon: const Icon(Icons.add_rounded, size: 14), // Decreased
                label: Text(
                  'Add',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ), // Decreased
                style: ElevatedButton.styleFrom(
                  backgroundColor: AdminColors.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(0, 36), // Decreased
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                  ), // Decreased
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ), // Decreased
                  elevation: 0,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12), // Decreased

          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 6,
            ), // Decreased
            decoration: BoxDecoration(
              color: AdminColors.primary.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(6), // Decreased
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.sync_rounded,
                  color: AdminColors.primary,
                  size: 12,
                ), // Decreased
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Zone changes are synchronized across all Sarthi apps.',
                    style: GoogleFonts.inter(
                      fontSize: 8,
                      color: AdminColors.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ), // Decreased
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OperationalZoneItem extends StatelessWidget {
  final String zone;
  final VoidCallback onRemove;

  const _OperationalZoneItem({required this.zone, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 8,
      ), // Decreased
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8), // Decreased
        border: Border.all(color: AdminColors.border),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.location_on_rounded,
            color: AdminColors.warning,
            size: 14,
          ), // Decreased
          const SizedBox(width: 10),
          Text(
            zone,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AdminColors.textPrimary,
            ),
          ), // Decreased
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 4,
                  height: 4,
                  decoration: const BoxDecoration(
                    color: AdminColors.success,
                    shape: BoxShape.circle,
                  ),
                ), // Decreased
                const SizedBox(width: 4),
                Text(
                  'Active',
                  style: GoogleFonts.inter(
                    color: AdminColors.success,
                    fontSize: 8,
                    fontWeight: FontWeight.w600,
                  ),
                ), // Decreased
              ],
            ),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(
              Icons.close_rounded,
              color: AdminColors.textSecondary,
              size: 14,
            ), // Decreased
            onPressed: onRemove,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(
              minWidth: 24,
              minHeight: 24,
            ), // Decreased
            style: IconButton.styleFrom(
              backgroundColor: AdminColors.background,
              shape: const CircleBorder(),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Save Button Component
// ---------------------------------------------------------------------------
class _SettingsSaveButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final bool isLoading;

  const _SettingsSaveButton({required this.onPressed, this.isLoading = false});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 44, // Decreased
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: isLoading
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.check_circle_rounded, size: 16), // Decreased
        label: Text(
          isLoading ? 'Saving...' : 'Save Changes',
          style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 12),
        ), // Decreased
        style: ElevatedButton.styleFrom(
          backgroundColor: AdminColors.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AdminColors.border,
          disabledForegroundColor: AdminColors.textSecondary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ), // Decreased
          elevation: 0,
        ),
      ),
    );
  }
}
