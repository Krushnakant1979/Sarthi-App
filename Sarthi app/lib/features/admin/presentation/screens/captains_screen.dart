import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../shared/auth/domain/app_user.dart';
import '../admin_design.dart';
import '../admin_providers.dart';

class CaptainsScreen extends ConsumerStatefulWidget {
  final String initialTab;
  const CaptainsScreen({super.key, this.initialTab = 'all'});

  @override
  ConsumerState<CaptainsScreen> createState() => _CaptainsScreenState();
}

class _CaptainsScreenState extends ConsumerState<CaptainsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';
  String _selectedVehicleFilter = 'all';

  @override
  void initState() {
    super.initState();
    int initialIndex = 0;
    if (widget.initialTab == 'pending') initialIndex = 1;
    if (widget.initialTab == 'verified') initialIndex = 2;
    if (widget.initialTab == 'rejected') initialIndex = 3;
    _tabController = TabController(length: 4, vsync: this, initialIndex: initialIndex);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  bool _isPending(AppUser u) {
    final s = u.verificationStatus.toLowerCase();
    return s == 'pending_review' || s == 'pending';
  }

  bool _isVerified(AppUser u) {
    return u.verificationStatus.toLowerCase() == 'verified';
  }

  bool _isRejected(AppUser u) {
    return u.verificationStatus.toLowerCase() == 'rejected';
  }

  int _getUploadedDocCount(AppUser captain) {
    int count = 0;
    if (captain.aadhaarCardUrl != null && captain.aadhaarCardUrl!.isNotEmpty) count++;
    if (captain.drivingLicenceUrl != null && captain.drivingLicenceUrl!.isNotEmpty) count++;
    if (captain.rcBookUrl != null && captain.rcBookUrl!.isNotEmpty) count++;
    if (captain.insuranceUrl != null && captain.insuranceUrl!.isNotEmpty) count++;
    return count;
  }

  String _formatRating(AppUser captain) {
    if (captain.ratingCount > 0) {
      final avg = (captain.ratingScore / captain.ratingCount).clamp(1.0, 5.0);
      return '${avg.toStringAsFixed(1)} (${captain.ratingCount})';
    }
    if (captain.ratingScore > 0 && captain.ratingScore <= 5.0) {
      return captain.ratingScore.toStringAsFixed(1);
    }
    return '5.0 (New)';
  }

  IconData _getVehicleIcon(String? vehicleType) {
    switch (vehicleType?.toLowerCase()) {
      case 'auto':
        return Icons.electric_rickshaw_rounded;
      case 'cab':
        return Icons.local_taxi_rounded;
      case 'parcel':
        return Icons.local_shipping_rounded;
      default:
        return Icons.two_wheeler_rounded;
    }
  }

  Future<void> _makePhoneCall(String? phone) async {
    if (phone == null || phone.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No phone number on record for this captain'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    final cleanPhone = phone.replaceAll(RegExp(r'[^\d+]'), '');
    final uri = Uri.parse('tel:$cleanPhone');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        await Clipboard.setData(ClipboardData(text: cleanPhone));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Phone number $cleanPhone copied to clipboard'),
              backgroundColor: AdminColors.primary,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: cleanPhone));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Phone number $cleanPhone copied to clipboard'),
            backgroundColor: AdminColors.primary,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _updateStatus(AppUser user, String newStatus, {String? rejectionReason}) async {
    HapticFeedback.mediumImpact();
    try {
      await ref.read(adminRepositoryProvider).updateCaptainVerification(
        user.uid,
        newStatus,
        rejectionReason: rejectionReason,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  newStatus == 'verified' ? Icons.check_circle_rounded : Icons.cancel_rounded,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '${user.name} marked as ${newStatus.toUpperCase()}',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            backgroundColor: newStatus == 'verified' ? AdminColors.success : AdminColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update status: $e'),
            backgroundColor: AdminColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  void _promptRejection(AppUser captain) {
    String selectedReason = 'Blurry Document Images';
    final customCtrl = TextEditingController();
    final reasons = [
      'Blurry Document Images',
      'Expired Driving License',
      'Mismatched Vehicle RC/Insurance',
      'Incomplete KYC Documents',
      'Other (Custom Reason)',
    ];

    showDialog(
      context: context,
      builder: (dlgCtx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AdminColors.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.gpp_bad_rounded, color: AdminColors.error, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Reject Verification',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 17, color: AdminColors.textPrimary),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Specify the compliance rejection reason for ${captain.name}. This remark is dispatched to the captain app.',
                  style: GoogleFonts.inter(fontSize: 12, color: AdminColors.textSecondary, height: 1.4),
                ),
                const SizedBox(height: 14),
                ...reasons.map((r) {
                  final isSelected = selectedReason == r;
                  return InkWell(
                    onTap: () => setDlgState(() => selectedReason = r),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected ? AdminColors.error.withValues(alpha: 0.08) : AdminColors.background,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected ? AdminColors.error : AdminColors.border,
                          width: isSelected ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isSelected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                            size: 18,
                            color: isSelected ? AdminColors.error : AdminColors.textSecondary,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              r,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                color: isSelected ? AdminColors.error : AdminColors.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
                if (selectedReason.startsWith('Other')) ...[
                  const SizedBox(height: 10),
                  TextField(
                    controller: customCtrl,
                    maxLines: 2,
                    style: GoogleFonts.inter(fontSize: 12),
                    decoration: InputDecoration(
                      hintText: 'Enter specific reason (e.g. Invalid vehicle plate registration)...',
                      hintStyle: GoogleFonts.inter(fontSize: 11, color: AdminColors.textSecondary),
                      filled: true,
                      fillColor: AdminColors.background,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: AdminColors.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: AdminColors.error),
                      ),
                      contentPadding: const EdgeInsets.all(12),
                    ),
                  ),
                ],
              ],
            ),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dlgCtx),
              child: Text(
                'Cancel',
                style: GoogleFonts.inter(color: AdminColors.textSecondary, fontWeight: FontWeight.w600),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AdminColors.error,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                final reason = selectedReason.startsWith('Other') && customCtrl.text.trim().isNotEmpty
                    ? customCtrl.text.trim()
                    : selectedReason;
                Navigator.pop(dlgCtx);
                _updateStatus(captain, 'rejected', rejectionReason: reason);
              },
              child: Text(
                'Confirm Rejection',
                style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCaptainDetailsDialog(AppUser captain) {
    final isPending = _isPending(captain);

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.white,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 580, maxHeight: 720),
          child: Column(
            children: [
              // Dialog Header
              Container(
                padding: const EdgeInsets.fromLTRB(20, 20, 16, 16),
                decoration: const BoxDecoration(
                  color: Color(0xFF2563EB),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Center(
                        child: Text(
                          captain.name.isNotEmpty ? captain.name[0].toUpperCase() : 'C',
                          style: GoogleFonts.inter(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  captain.name,
                                  style: GoogleFonts.inter(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              _buildStatusBadge(captain, isCompact: true),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Partner ID: ${captain.publicId} • ${captain.phone ?? captain.email}',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: const Color(0xFF94A3B8),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.white70),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),

              // Scrollable Body
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Partner Snapshot Row
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AdminColors.border),
                        ),
                        child: Row(
                          children: [
                            _buildInfoTile('SERVICE', (captain.vehicleType ?? 'Bike').toUpperCase(), _getVehicleIcon(captain.vehicleType)),
                            Container(width: 1, height: 36, color: AdminColors.border),
                            _buildInfoTile('PLATE / REG', captain.vehicleNumber ?? captain.registrationNumber ?? 'Not Assigned', Icons.pin_rounded),
                            Container(width: 1, height: 36, color: AdminColors.border),
                            _buildInfoTile('RATING', _formatRating(captain), Icons.star_rounded, isStar: true),
                          ],
                        ),
                      ),

                      if (captain.rejectionReason != null && captain.rejectionReason!.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AdminColors.error.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AdminColors.error.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.warning_amber_rounded, color: AdminColors.error, size: 18),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'CURRENT REJECTION REMARK',
                                      style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: AdminColors.error),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      captain.rejectionReason!,
                                      style: GoogleFonts.inter(fontSize: 12, color: AdminColors.textPrimary, fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 18),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'COMPLIANCE DOCUMENTS',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: AdminColors.textSecondary,
                              letterSpacing: 0.8,
                            ),
                          ),
                          Text(
                            '${_getUploadedDocCount(captain)} of 4 Verified',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: _getUploadedDocCount(captain) == 4 ? AdminColors.success : AdminColors.warning,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      _buildDocCard('Government Aadhaar Card', captain.aadhaarCardUrl, Icons.badge_rounded),
                      const SizedBox(height: 10),
                      _buildDocCard('Commercial Driving License (DL)', captain.drivingLicenceUrl, Icons.card_membership_rounded),
                      const SizedBox(height: 10),
                      _buildDocCard('Vehicle Registration Certificate (RC)', captain.rcBookUrl, Icons.receipt_long_rounded),
                      const SizedBox(height: 10),
                      _buildDocCard('Vehicle Comprehensive Insurance', captain.insuranceUrl, Icons.security_rounded),
                    ],
                  ),
                ),
              ),

              // Bottom Action Bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: AdminColors.border)),
                  borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
                ),
                child: Row(
                  children: [
                    IconButton.outlined(
                      style: IconButton.styleFrom(
                        side: const BorderSide(color: AdminColors.border),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.all(10),
                        minimumSize: const Size(40, 40),
                      ),
                      icon: const Icon(Icons.phone_rounded, color: AdminColors.primary, size: 18),
                      tooltip: 'Call Captain',
                      onPressed: () => _makePhoneCall(captain.phone),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AdminColors.error,
                          side: const BorderSide(color: AdminColors.error, width: 1.2),
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 11),
                          minimumSize: const Size(0, 42),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () {
                          Navigator.pop(ctx);
                          _promptRejection(captain);
                        },
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.close_rounded, size: 14),
                              const SizedBox(width: 4),
                              Text(
                                'Reject',
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 11,
                                  letterSpacing: -0.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AdminColors.success,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 11),
                          minimumSize: const Size(0, 42),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () {
                          Navigator.pop(ctx);
                          _updateStatus(captain, 'verified');
                        },
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.verified_rounded, size: 14),
                              const SizedBox(width: 4),
                              Text(
                                isPending ? 'Approve & Verify' : 'Mark Verified',
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 11,
                                  letterSpacing: -0.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
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

  Widget _buildInfoTile(String label, String value, IconData icon, {bool isStar = false}) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w700, color: AdminColors.textSecondary, letterSpacing: 0.5),
          ),
          const SizedBox(height: 3),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14, color: isStar ? const Color(0xFFF59E0B) : AdminColors.primary),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  value,
                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w800, color: AdminColors.textPrimary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDocCard(String title, String? url, IconData icon) {
    final hasDoc = url != null && url.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: hasDoc ? Colors.white : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hasDoc ? const Color(0xFFCBD5E1) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: hasDoc ? const Color(0xFFEFF6FF) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              size: 20,
              color: hasDoc ? const Color(0xFF2563EB) : const Color(0xFF94A3B8),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: AdminColors.textPrimary),
                ),
                const SizedBox(height: 2),
                Text(
                  hasDoc ? 'Document available for inspection' : 'Partner has not uploaded this document',
                  style: GoogleFonts.inter(fontSize: 10, color: hasDoc ? AdminColors.success : AdminColors.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (hasDoc)
            FilledButton.tonal(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFEFF6FF),
                foregroundColor: const Color(0xFF2563EB),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                minimumSize: Size.zero,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () => _showZoomableImage(context, title, url),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.zoom_in_rounded, size: 14),
                  const SizedBox(width: 4),
                  Text('Inspect', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700)),
                ],
              ),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'Missing',
                style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: const Color(0xFF94A3B8)),
              ),
            ),
        ],
      ),
    );
  }

  void _showZoomableImage(BuildContext context, String title, String url) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.black.withValues(alpha: 0.95),
        insetPadding: const EdgeInsets.all(12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            width: double.infinity,
            height: 520,
            child: Stack(
              children: [
                Center(
                  child: InteractiveViewer(
                    panEnabled: true,
                    minScale: 0.5,
                    maxScale: 4.0,
                    child: Image.network(
                      url,
                      fit: BoxFit.contain,
                      loadingBuilder: (context, child, progress) {
                        if (progress == null) return child;
                        return const Center(child: CircularProgressIndicator(color: Colors.white));
                      },
                      errorBuilder: (_, _, _) => Center(
                        child: Text(
                          'Failed to load high-res document image',
                          style: GoogleFonts.inter(color: Colors.white70, fontSize: 13),
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 14,
                  left: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Text(
                      title,
                      style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white, size: 24),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ),
                Positioned(
                  bottom: 14,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black87,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: Text(
                        'Pinch to zoom • Drag to examine certificate details',
                        style: GoogleFonts.inter(color: Colors.white70, fontSize: 11),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(AppUser captain, {bool isCompact = false}) {
    final isPending = _isPending(captain);
    final isVerified = _isVerified(captain);

    Color bg;
    Color fg;
    Color border;
    IconData icon;
    String text;

    if (isPending) {
      bg = const Color(0xFFFFFBEB);
      fg = const Color(0xFFD97706);
      border = const Color(0xFFFDE68A);
      icon = Icons.hourglass_top_rounded;
      text = 'Pending Review';
    } else if (isVerified) {
      bg = const Color(0xFFF0FDF4);
      fg = const Color(0xFF16A34A);
      border = const Color(0xFFBBF7D0);
      icon = Icons.verified_rounded;
      text = 'Verified Partner';
    } else {
      bg = const Color(0xFFFEF2F2);
      fg = const Color(0xFFDC2626);
      border = const Color(0xFFFECACA);
      icon = Icons.cancel_rounded;
      text = 'Rejected';
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: isCompact ? 7 : 10, vertical: isCompact ? 3 : 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: border, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: isCompact ? 12 : 14, color: fg),
          const SizedBox(width: 5),
          Text(
            text,
            style: GoogleFonts.inter(
              fontSize: isCompact ? 10 : 11,
              fontWeight: FontWeight.w700,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final allUsersAsync = ref.watch(allUsersProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        titleSpacing: 0,
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF0F172A), size: 22),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Captains Management',
              style: GoogleFonts.inter(
                color: const Color(0xFF0F172A),
                fontWeight: FontWeight.w900,
                fontSize: 16.5,
                letterSpacing: -0.3,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 1),
            Text(
              'Fleet verification & driver compliance',
              style: GoogleFonts.inter(
                color: const Color(0xFF64748B),
                fontWeight: FontWeight.w500,
                fontSize: 10.5,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 12),
            child: IconButton(
              style: IconButton.styleFrom(
                backgroundColor: const Color(0xFFF1F5F9),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.refresh_rounded, size: 18, color: Color(0xFF0F172A)),
              tooltip: 'Refresh fleet records',
              onPressed: () {
                HapticFeedback.lightImpact();
                ref.invalidate(allUsersProvider);
              },
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Container(
              height: 40,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: TabBar(
                controller: _tabController,
                dividerColor: Colors.transparent,
                indicatorSize: TabBarIndicatorSize.tab,
                labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                indicator: BoxDecoration(
                  color: const Color(0xFF2563EB),
                  borderRadius: BorderRadius.circular(9),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF2563EB).withValues(alpha: 0.28),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                labelColor: Colors.white,
                unselectedLabelColor: const Color(0xFF64748B),
                labelStyle: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w800),
                unselectedLabelStyle: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w600),
                tabs: const [
                  Tab(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text('All Fleet'),
                    ),
                  ),
                  Tab(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text('Pending'),
                    ),
                  ),
                  Tab(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text('Verified'),
                    ),
                  ),
                  Tab(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text('Rejected'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: allUsersAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AdminColors.primary),
        ),
        error: (err, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.cloud_off_rounded, size: 48, color: AdminColors.error),
                const SizedBox(height: 12),
                Text('Failed to sync captains', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text('$err', style: GoogleFonts.inter(fontSize: 12, color: AdminColors.textSecondary), textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () => ref.invalidate(allUsersProvider),
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Try Again'),
                ),
              ],
            ),
          ),
        ),
        data: (allUsers) {
          final captains = allUsers.where((u) => u.role.toLowerCase() == 'captain').toList();

          final pendingCount = captains.where(_isPending).length;
          final verifiedCount = captains.where(_isVerified).length;
          final rejectedCount = captains.where(_isRejected).length;

          // Filter by search query and vehicle
          final filtered = captains.where((c) {
            // Vehicle filter
            if (_selectedVehicleFilter != 'all') {
              if (c.vehicleType?.toLowerCase() != _selectedVehicleFilter) {
                return false;
              }
            }
            // Search query
            if (_searchQuery.isEmpty) return true;
            final q = _searchQuery.toLowerCase();
            return c.name.toLowerCase().contains(q) ||
                (c.phone != null && c.phone!.contains(q)) ||
                c.email.toLowerCase().contains(q) ||
                c.publicId.toLowerCase().contains(q) ||
                (c.vehicleNumber != null && c.vehicleNumber!.toLowerCase().contains(q)) ||
                (c.vehicleType != null && c.vehicleType!.toLowerCase().contains(q));
          }).toList();

          return Column(
            children: [
              // Top Filter & Metrics Container
              Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
                ),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                child: Column(
                  children: [
                    // Search Bar
                    Container(
                      height: 42,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: TextField(
                        controller: _searchCtrl,
                        onChanged: (val) => setState(() => _searchQuery = val.trim()),
                        style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF0F172A), fontWeight: FontWeight.w600),
                        decoration: InputDecoration(
                          hintText: 'Search by partner name, phone, plate number or ID...',
                          hintStyle: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8), fontWeight: FontWeight.w500),
                          prefixIcon: const Icon(Icons.search_rounded, size: 20, color: Color(0xFF64748B)),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.close_rounded, size: 18, color: Color(0xFF64748B)),
                                  onPressed: () {
                                    _searchCtrl.clear();
                                    setState(() => _searchQuery = '');
                                  },
                                )
                              : null,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          filled: false,
                          fillColor: Colors.transparent,
                          contentPadding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Interactive KPI Cards (Tap to switch tabs!)
                    Row(
                      children: [
                        _buildInteractiveKpi(
                          label: 'TOTAL',
                          value: captains.length.toString(),
                          icon: Icons.groups_rounded,
                          accentColor: const Color(0xFF2563EB),
                          bgGradient: [const Color(0xFFEFF6FF), const Color(0xFFDBEAFE)],
                          isSelected: _tabController.index == 0,
                          onTap: () => _tabController.animateTo(0),
                        ),
                        const SizedBox(width: 6),
                        _buildInteractiveKpi(
                          label: 'PENDING',
                          value: pendingCount.toString(),
                          icon: Icons.hourglass_top_rounded,
                          accentColor: const Color(0xFF2563EB),
                          bgGradient: [const Color(0xFFEFF6FF), const Color(0xFFDBEAFE)],
                          isSelected: _tabController.index == 1,
                          onTap: () => _tabController.animateTo(1),
                        ),
                        const SizedBox(width: 6),
                        _buildInteractiveKpi(
                          label: 'VERIFIED',
                          value: verifiedCount.toString(),
                          icon: Icons.verified_rounded,
                          accentColor: const Color(0xFF2563EB),
                          bgGradient: [const Color(0xFFEFF6FF), const Color(0xFFDBEAFE)],
                          isSelected: _tabController.index == 2,
                          onTap: () => _tabController.animateTo(2),
                        ),
                        const SizedBox(width: 6),
                        _buildInteractiveKpi(
                          label: 'REJECTED',
                          value: rejectedCount.toString(),
                          icon: Icons.cancel_rounded,
                          accentColor: const Color(0xFF2563EB),
                          bgGradient: [const Color(0xFFEFF6FF), const Color(0xFFDBEAFE)],
                          isSelected: _tabController.index == 3,
                          onTap: () => _tabController.animateTo(3),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // Vehicle Quick Filter Chips Row
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildVehicleFilterChip('all', 'All Services', Icons.apps_rounded),
                          const SizedBox(width: 6),
                          _buildVehicleFilterChip('bike', 'Motorcycle', Icons.two_wheeler_rounded),
                          const SizedBox(width: 6),
                          _buildVehicleFilterChip('auto', 'Auto Rickshaw', Icons.electric_rickshaw_rounded),
                          const SizedBox(width: 6),
                          _buildVehicleFilterChip('cab', 'Cab / Taxi', Icons.local_taxi_rounded),
                          const SizedBox(width: 6),
                          _buildVehicleFilterChip('parcel', 'Parcel Delivery', Icons.local_shipping_rounded),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Tab Views
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildCaptainList(filtered, 'all'),
                    _buildCaptainList(filtered.where(_isPending).toList(), 'pending'),
                    _buildCaptainList(filtered.where(_isVerified).toList(), 'verified'),
                    _buildCaptainList(filtered.where(_isRejected).toList(), 'rejected'),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildInteractiveKpi({
    required String label,
    required String value,
    required IconData icon,
    required Color accentColor,
    required List<Color> bgGradient,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final effectiveBg = isSelected
        ? const [Color(0xFFDBEAFE), Color(0xFFBFDBFE)]
        : bgGradient;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: effectiveBg,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? accentColor : const Color(0xFF93C5FD).withValues(alpha: 0.5),
              width: isSelected ? 2.0 : 1.0,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: accentColor.withValues(alpha: 0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Icon(icon, size: 14, color: accentColor),
                  Text(
                    value,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: accentColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 8.5,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF1E3A8A),
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVehicleFilterChip(String key, String label, IconData icon) {
    final isSelected = _selectedVehicleFilter == key;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _selectedVehicleFilter = key);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF2563EB) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 13,
              color: isSelected ? Colors.white : const Color(0xFF64748B),
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                color: isSelected ? Colors.white : const Color(0xFF334155),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCaptainList(List<AppUser> list, String tabType) {
    if (list.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Icon(
                  Icons.person_search_rounded,
                  size: 36,
                  color: Color(0xFF2563EB),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'No Captains In This Category',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _searchQuery.isNotEmpty
                    ? 'No partners matched "$_searchQuery". Try clearing your search.'
                    : 'Currently there are zero captain partners matching this filter.',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: const Color(0xFF64748B),
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              if (_searchQuery.isNotEmpty || _selectedVehicleFilter != 'all') ...[
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () {
                    _searchCtrl.clear();
                    setState(() {
                      _searchQuery = '';
                      _selectedVehicleFilter = 'all';
                    });
                  },
                  icon: const Icon(Icons.filter_alt_off_rounded, size: 16),
                  label: const Text('Reset All Filters'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AdminColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return ListView.separated(
      padding: EdgeInsets.fromLTRB(16, 14, 16, 120 + bottomInset),
      itemCount: list.length,
      separatorBuilder: (_, _) => const SizedBox(height: 14),
      itemBuilder: (context, idx) {
        return _buildRedesignedCaptainCard(list[idx]);
      },
    );
  }

  Widget _buildRedesignedCaptainCard(AppUser captain) {
    final isPending = _isPending(captain);
    final isRejected = _isRejected(captain);
    final docCount = _getUploadedDocCount(captain);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isPending
              ? const Color(0xFFF59E0B).withValues(alpha: 0.45)
              : const Color(0xFFE2E8F0),
          width: isPending ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header: Avatar, Name, Phone, ID & Status Pill ─────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar with Vehicle Badge Overlay
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(15),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          captain.name.isNotEmpty ? captain.name[0].toUpperCase() : 'C',
                          style: GoogleFonts.inter(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: -3,
                      right: -3,
                      child: Container(
                        padding: const EdgeInsets.all(3.5),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2563EB),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: Icon(
                          _getVehicleIcon(captain.vehicleType),
                          size: 11,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 14),

                // Name, Phone & ID
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Text(
                              captain.name,
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF0F172A),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          _buildStatusBadge(captain),
                        ],
                      ),
                      const SizedBox(height: 4),

                      // Contact row (Responsive Wrap prevents overflow on narrow screens)
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.phone_outlined, size: 13, color: Color(0xFF64748B)),
                              const SizedBox(width: 4),
                              Text(
                                captain.phone ?? captain.email,
                                style: GoogleFonts.inter(
                                  fontSize: 11.5,
                                  color: const Color(0xFF475569),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          GestureDetector(
                            onTap: () {
                              Clipboard.setData(ClipboardData(text: captain.uid));
                              HapticFeedback.lightImpact();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Copied ID: ${captain.publicId}'),
                                  duration: const Duration(milliseconds: 1500),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'ID: ${captain.publicId}',
                                    style: GoogleFonts.robotoMono(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFF334155),
                                    ),
                                  ),
                                  const SizedBox(width: 3),
                                  const Icon(Icons.copy_rounded, size: 10, color: Color(0xFF64748B)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Middle Section: Vehicle, Plate & Rating Spec Strip ─────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  // Vehicle spec
                  Expanded(
                    flex: 11,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'VEHICLE',
                          style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w800, color: const Color(0xFF94A3B8), letterSpacing: 0.5),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          (captain.vehicleType ?? 'Bike').toUpperCase(),
                          style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),

                  Container(width: 1, height: 26, color: const Color(0xFFE2E8F0)),
                  const SizedBox(width: 8),

                  // Registration Number
                  Expanded(
                    flex: 14,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'PLATE NO.',
                          style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w800, color: const Color(0xFF94A3B8), letterSpacing: 0.5),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          captain.vehicleNumber ?? captain.registrationNumber ?? 'Plate Not Added',
                          style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w700, color: const Color(0xFF334155)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),

                  Container(width: 1, height: 26, color: const Color(0xFFE2E8F0)),
                  const SizedBox(width: 8),

                  // Rating Score
                  Expanded(
                    flex: 11,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'RATING',
                          style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w800, color: const Color(0xFF94A3B8), letterSpacing: 0.5),
                        ),
                        const SizedBox(height: 2),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.star_rounded, size: 14, color: Color(0xFFF59E0B)),
                              const SizedBox(width: 3),
                              Text(
                                _formatRating(captain),
                                style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Document Compliance Preview Row (Scrollable to prevent overflow) ─────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
            child: Row(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildMiniDocBadge('Aadhaar', captain.aadhaarCardUrl != null && captain.aadhaarCardUrl!.isNotEmpty),
                        const SizedBox(width: 6),
                        _buildMiniDocBadge('DL', captain.drivingLicenceUrl != null && captain.drivingLicenceUrl!.isNotEmpty),
                        const SizedBox(width: 6),
                        _buildMiniDocBadge('RC', captain.rcBookUrl != null && captain.rcBookUrl!.isNotEmpty),
                        const SizedBox(width: 6),
                        _buildMiniDocBadge('Insurance', captain.insuranceUrl != null && captain.insuranceUrl!.isNotEmpty),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: docCount == 4
                        ? const Color(0xFFF0FDF4)
                        : (docCount > 0 ? const Color(0xFFFFFBEB) : const Color(0xFFFEF2F2)),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '$docCount/4 Docs',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: docCount == 4
                          ? const Color(0xFF16A34A)
                          : (docCount > 0 ? const Color(0xFFD97706) : const Color(0xFFDC2626)),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Rejection reason banner if rejected
          if (isRejected && captain.rejectionReason != null && captain.rejectionReason!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFFECACA)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline_rounded, size: 14, color: Color(0xFFDC2626)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Reason: ${captain.rejectionReason}',
                        style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFFB91C1C)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          const SizedBox(height: 10),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),

          // ── Footer Actions Bar ──────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                // Quick Call shortcut
                IconButton(
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFFF1F5F9),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.all(8),
                    minimumSize: Size.zero,
                  ),
                  icon: const Icon(Icons.phone_rounded, size: 16, color: Color(0xFF0F172A)),
                  tooltip: 'Call Captain',
                  onPressed: () => _makePhoneCall(captain.phone),
                ),
                const SizedBox(width: 8),

                // Review Documents (Dossier Inspection)
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 8),
                      minimumSize: const Size(0, 38),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () => _showCaptainDetailsDialog(captain),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.folder_shared_rounded, size: 15, color: Colors.white),
                          const SizedBox(width: 6),
                          Text(
                            'Review Documents',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Quick Approve / Reject action buttons for Pending reviews
                if (isPending) ...[
                  const SizedBox(width: 6),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AdminColors.success,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                      minimumSize: const Size(0, 38),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () => _updateStatus(captain, 'verified'),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'Approve',
                        style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AdminColors.error,
                      side: const BorderSide(color: AdminColors.error, width: 1.1),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
                      minimumSize: const Size(0, 38),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () => _promptRejection(captain),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'Reject',
                        style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniDocBadge(String label, bool isUploaded) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: isUploaded ? const Color(0xFFF0FDF4) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isUploaded ? const Color(0xFFBBF7D0) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isUploaded ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
            size: 11,
            color: isUploaded ? const Color(0xFF16A34A) : const Color(0xFF94A3B8),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: isUploaded ? FontWeight.w700 : FontWeight.w500,
              color: isUploaded ? const Color(0xFF166534) : const Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }
}
