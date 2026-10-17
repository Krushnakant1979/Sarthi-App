import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
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

  @override
  void initState() {
    super.initState();
    int initialIndex = 0;
    if (widget.initialTab == 'pending') initialIndex = 1;
    if (widget.initialTab == 'verified') initialIndex = 2;
    if (widget.initialTab == 'rejected') initialIndex = 3;
    _tabController = TabController(length: 4, vsync: this, initialIndex: initialIndex);
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
            content: Text('${user.name} marked as $newStatus'),
            backgroundColor: newStatus == 'verified' ? AdminColors.success : AdminColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            'Reject Documents',
            style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 16, color: AdminColors.textPrimary),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Select reason for rejecting ${captain.name}\'s KYC:',
                  style: GoogleFonts.inter(fontSize: 13, color: AdminColors.textSecondary),
                ),
                const SizedBox(height: 12),
                ...reasons.map((r) => RadioListTile<String>(
                  title: Text(r, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500)),
                  value: r,
                  groupValue: selectedReason,
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  activeColor: AdminColors.error,
                  onChanged: (val) {
                    if (val != null) setDlgState(() => selectedReason = val);
                  },
                )),
                if (selectedReason.startsWith('Other')) ...[
                  const SizedBox(height: 8),
                  TextField(
                    controller: customCtrl,
                    maxLines: 2,
                    decoration: InputDecoration(
                      hintText: 'Enter specific rejection reason...',
                      hintStyle: GoogleFonts.inter(fontSize: 12, color: AdminColors.textSecondary),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.all(10),
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dlgCtx),
              child: Text('Cancel', style: GoogleFonts.inter(color: AdminColors.textSecondary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AdminColors.error,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () {
                final reason = selectedReason.startsWith('Other') && customCtrl.text.trim().isNotEmpty
                    ? customCtrl.text.trim()
                    : selectedReason;
                Navigator.pop(dlgCtx);
                _updateStatus(captain, 'rejected', rejectionReason: reason);
              },
              child: Text('Confirm Rejection', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }

  void _showCaptainDetailsDialog(AppUser captain) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600, maxHeight: 680),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            captain.name,
                            style: GoogleFonts.inter(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: AdminColors.textPrimary,
                            ),
                          ),
                          Text(
                            'Captain ID: ${captain.publicId}',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: AdminColors.textSecondary,
                            ),
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
                const SizedBox(height: 16),
                // Contact & Vehicle Info
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AdminColors.background,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AdminColors.border),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Phone',
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                color: AdminColors.textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              captain.phone ?? 'Not provided',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AdminColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Vehicle Service',
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                color: AdminColors.textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              (captain.vehicleType ?? 'Bike').toUpperCase(),
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AdminColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Verification Documents',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AdminColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        _buildDocItem('Aadhaar Card', captain.aadhaarCardUrl),
                        const SizedBox(height: 12),
                        _buildDocItem('Driving Licence', captain.drivingLicenceUrl),
                        if (captain.rcBookUrl != null || captain.role == 'captain') ...[
                          const SizedBox(height: 12),
                          _buildDocItem('RC Book (Vehicle Reg)', captain.rcBookUrl),
                        ],
                        if (captain.insuranceUrl != null || captain.role == 'captain') ...[
                          const SizedBox(height: 12),
                          _buildDocItem('Vehicle Insurance', captain.insuranceUrl),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AdminColors.error,
                          side: const BorderSide(color: AdminColors.error),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: () {
                          Navigator.pop(ctx);
                          _promptRejection(captain);
                        },
                        child: Text(
                          'Reject Captain',
                          style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AdminColors.success,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: () {
                          Navigator.pop(ctx);
                          _updateStatus(captain, 'verified');
                        },
                        child: Text(
                          'Approve & Verify',
                          style: GoogleFonts.inter(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
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
            height: 500,
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
                        return const Center(
                          child: CircularProgressIndicator(color: Colors.white),
                        );
                      },
                      errorBuilder: (_, _, _) => Center(
                        child: Text(
                          'Failed to load high-res document',
                          style: GoogleFonts.inter(color: Colors.white70),
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 12,
                  left: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Text(
                      title,
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
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
                  bottom: 12,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.black87,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: Text(
                        'Pinch to zoom • Drag to inspect',
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

  Widget _buildDocItem(String label, String? url) {
    final hasDoc = url != null && url.isNotEmpty;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AdminColors.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AdminColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AdminColors.textPrimary,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: hasDoc
                      ? AdminColors.success.withValues(alpha: 0.1)
                      : AdminColors.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  hasDoc ? 'Uploaded' : 'Missing',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: hasDoc ? AdminColors.success : AdminColors.error,
                  ),
                ),
              ),
            ],
          ),
          if (hasDoc) ...[
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => _showZoomableImage(context, label, url),
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      url,
                      height: 120,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        height: 60,
                        alignment: Alignment.center,
                        color: AdminColors.border.withValues(alpha: 0.3),
                        child: Text(
                          'Preview unavailable',
                          style: GoogleFonts.inter(fontSize: 11, color: AdminColors.textSecondary),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 6,
                    right: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.75),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.zoom_in_rounded,
                            size: 14,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Inspect',
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final allUsersAsync = ref.watch(allUsersProvider);

    return Scaffold(
      backgroundColor: AdminColors.background,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Captains Management',
              style: GoogleFonts.inter(
                color: AdminColors.textPrimary,
                fontWeight: FontWeight.w800,
                fontSize: 15,
              ),
            ),
            Text(
              'Fleet verification and driver partner compliance',
              style: GoogleFonts.inter(
                color: AdminColors.textSecondary,
                fontWeight: FontWeight.w500,
                fontSize: 10,
              ),
            ),
          ],
        ),
        backgroundColor: AdminColors.card,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(color: AdminColors.textPrimary),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, size: 20),
            onPressed: () {
              HapticFeedback.lightImpact();
              ref.invalidate(allUsersProvider);
            },
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            color: AdminColors.card,
            child: TabBar(
              controller: _tabController,
              labelColor: AdminColors.primary,
              unselectedLabelColor: AdminColors.textSecondary,
              indicatorColor: AdminColors.primary,
              indicatorWeight: 3,
              labelStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700),
              tabs: const [
                Tab(text: 'All'),
                Tab(text: 'Pending'),
                Tab(text: 'Verified'),
                Tab(text: 'Rejected'),
              ],
            ),
          ),
        ),
      ),
      body: allUsersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error loading captains: $err')),
        data: (allUsers) {
          // Filter only captains
          final captains = allUsers.where((u) => u.role.toLowerCase() == 'captain').toList();

          final pendingCount = captains.where(_isPending).length;
          final verifiedCount = captains.where(_isVerified).length;
          final rejectedCount = captains.where(_isRejected).length;

          // Search filtering
          final filtered = captains.where((c) {
            if (_searchQuery.isEmpty) return true;
            final q = _searchQuery.toLowerCase();
            return c.name.toLowerCase().contains(q) ||
                (c.phone != null && c.phone!.contains(q)) ||
                c.email.toLowerCase().contains(q) ||
                (c.vehicleType != null && c.vehicleType!.toLowerCase().contains(q));
          }).toList();

          return Column(
            children: [
              // Search & KPI Header
              Container(
                color: AdminColors.card,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Column(
                  children: [
                    // Search bar
                    Container(
                      height: 40,
                      decoration: BoxDecoration(
                        color: AdminColors.background,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AdminColors.border),
                      ),
                      child: TextField(
                        controller: _searchCtrl,
                        onChanged: (val) => setState(() => _searchQuery = val.trim()),
                        style: GoogleFonts.inter(fontSize: 13, color: AdminColors.textPrimary),
                        decoration: InputDecoration(
                          hintText: 'Search by captain name, phone, vehicle...',
                          hintStyle: GoogleFonts.inter(fontSize: 12, color: AdminColors.textSecondary),
                          prefixIcon: const Icon(Icons.search_rounded, size: 18, color: AdminColors.textSecondary),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear_rounded, size: 16),
                                  onPressed: () {
                                    _searchCtrl.clear();
                                    setState(() => _searchQuery = '');
                                  },
                                )
                              : null,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    // Quick Stats Cards
                    Row(
                      children: [
                        _buildQuickKpi('Total', captains.length.toString(), AdminColors.primary),
                        const SizedBox(width: 8),
                        _buildQuickKpi('Pending', pendingCount.toString(), const Color(0xFFF59E0B)),
                        const SizedBox(width: 8),
                        _buildQuickKpi('Verified', verifiedCount.toString(), AdminColors.success),
                        const SizedBox(width: 8),
                        _buildQuickKpi('Rejected', rejectedCount.toString(), AdminColors.error),
                      ],
                    ),
                  ],
                ),
              ),

              // Tab Views
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildCaptainList(filtered),
                    _buildCaptainList(filtered.where(_isPending).toList()),
                    _buildCaptainList(filtered.where(_isVerified).toList()),
                    _buildCaptainList(filtered.where(_isRejected).toList()),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildQuickKpi(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: AdminColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCaptainList(List<AppUser> list) {
    if (list.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.directions_car_filled_outlined, size: 48, color: AdminColors.textSecondary.withValues(alpha: 0.4)),
            const SizedBox(height: 12),
            Text(
              'No captains found',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AdminColors.textPrimary,
              ),
            ),
            Text(
              'No records match current filter criteria',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: AdminColors.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: list.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, idx) {
        final captain = list[idx];
        final isPending = _isPending(captain);
        final isVerified = _isVerified(captain);

        Color badgeColor = AdminColors.error;
        String badgeText = 'Rejected';
        if (isPending) {
          badgeColor = const Color(0xFFF59E0B);
          badgeText = 'Pending Review';
        } else if (isVerified) {
          badgeColor = AdminColors.success;
          badgeText = 'Verified';
        }

        return Container(
          decoration: BoxDecoration(
            color: AdminColors.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: isPending ? const Color(0xFFF59E0B).withValues(alpha: 0.4) : AdminColors.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          padding: const EdgeInsets.all(14),
          child: Column(
            children: [
              Row(
                children: [
                  // Avatar
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AdminColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        captain.name.isNotEmpty ? captain.name[0].toUpperCase() : 'C',
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AdminColors.primary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                captain.name,
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: AdminColors.textPrimary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: badgeColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                badgeText,
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: badgeColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${captain.phone ?? captain.email} • ID: ${captain.publicId}',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: AdminColors.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AdminColors.background,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: AdminColors.border),
                              ),
                              child: Text(
                                (captain.vehicleType ?? 'Bike').toUpperCase(),
                                style: GoogleFonts.inter(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  color: AdminColors.textPrimary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (captain.ratingScore > 0) ...[
                              const Icon(Icons.star_rounded, size: 14, color: Color(0xFFF59E0B)),
                              const SizedBox(width: 2),
                              Text(
                                captain.ratingScore.toStringAsFixed(1),
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: AdminColors.textPrimary,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(height: 1, color: AdminColors.border),
              const SizedBox(height: 10),
              // Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AdminColors.primary,
                      side: const BorderSide(color: AdminColors.border),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      minimumSize: Size.zero,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () => _showCaptainDetailsDialog(captain),
                    child: Text(
                      'Review Documents',
                      style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700),
                    ),
                  ),

                if (isPending) ...[
                  const SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AdminColors.success,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      minimumSize: Size.zero,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () => _updateStatus(captain, 'verified'),
                    child: Text(
                      'Verify',
                      style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AdminColors.error,
                      side: const BorderSide(color: AdminColors.error),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      minimumSize: Size.zero,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () => _updateStatus(captain, 'rejected'),
                    child: Text(
                      'Reject',
                      style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      );
    },
  );
  }
}
