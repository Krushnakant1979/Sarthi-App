import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import '../admin_design.dart';
import '../admin_providers.dart';
import '../../../shared/auth/domain/app_user.dart';

class ReviewsScreen extends ConsumerStatefulWidget {
  const ReviewsScreen({super.key});

  @override
  ConsumerState<ReviewsScreen> createState() => _ReviewsScreenState();
}

class _ReviewsScreenState extends ConsumerState<ReviewsScreen> {
  String _selectedFilter = 'all'; // 'all', 'low_rated', 'flagged', 'resolved'
  String _searchQuery = '';
  bool _isSearchExpanded = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _updateStatus(String reviewId, String status) async {
    HapticFeedback.lightImpact();
    try {
      await ref.read(adminRepositoryProvider).updateReviewStatus(reviewId, status);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  status.toLowerCase() == 'resolved'
                      ? Icons.check_circle_rounded
                      : (status.toLowerCase() == 'flagged' ? Icons.flag_rounded : Icons.info_outline_rounded),
                  color: Colors.white,
                  size: 18,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Review marked as $status',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                ),
              ],
            ),
            backgroundColor: status.toLowerCase() == 'resolved'
                ? AdminColors.success
                : (status.toLowerCase() == 'flagged' ? AdminColors.error : AdminColors.primary),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline_rounded, color: Colors.white, size: 18),
                const SizedBox(width: 10),
                Expanded(child: Text('Failed to update review: $e')),
              ],
            ),
            backgroundColor: AdminColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          ),
        );
      }
    }
  }

  void _copyToClipboard(String text, String label) {
    HapticFeedback.lightImpact();
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label copied to clipboard', style: GoogleFonts.inter(fontSize: 12)),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final reviewsAsync = ref.watch(allReviewsProvider);
    final allUsers = ref.watch(allUsersProvider).value ?? [];

    return Scaffold(
      backgroundColor: AdminColors.background,
      appBar: AppBar(
        backgroundColor: AdminColors.card,
        elevation: 0,
        titleSpacing: 0,
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Container(
            decoration: BoxDecoration(
              color: AdminColors.background,
              shape: BoxShape.circle,
              border: Border.all(color: AdminColors.border.withValues(alpha: 0.7)),
            ),
            child: IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: AdminColors.textPrimary, size: 18),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Trip Reviews & Moderation',
              style: GoogleFonts.inter(
                color: AdminColors.textPrimary,
                fontWeight: FontWeight.w800,
                fontSize: 14.5,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              'Inspect low-rated trips & resolve rider feedback',
              style: GoogleFonts.inter(
                color: AdminColors.textSecondary,
                fontWeight: FontWeight.w500,
                fontSize: 10,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        actions: [
          // Search Toggle Button
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: Container(
              decoration: BoxDecoration(
                color: _isSearchExpanded
                    ? AdminColors.primary.withValues(alpha: 0.1)
                    : AdminColors.background,
                shape: BoxShape.circle,
                border: Border.all(color: AdminColors.border.withValues(alpha: 0.7)),
              ),
              child: IconButton(
                icon: Icon(
                  _isSearchExpanded ? Icons.close_rounded : Icons.search_rounded,
                  color: _isSearchExpanded ? AdminColors.primary : AdminColors.textPrimary,
                  size: 18,
                ),
                tooltip: _isSearchExpanded ? 'Close Search' : 'Search Reviews',
                onPressed: () {
                  HapticFeedback.lightImpact();
                  setState(() {
                    _isSearchExpanded = !_isSearchExpanded;
                    if (!_isSearchExpanded) {
                      _searchController.clear();
                      _searchQuery = '';
                    }
                  });
                },
              ),
            ),
          ),
          // Refresh Button
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Container(
              decoration: BoxDecoration(
                color: AdminColors.background,
                shape: BoxShape.circle,
                border: Border.all(color: AdminColors.border.withValues(alpha: 0.7)),
              ),
              child: IconButton(
                icon: const Icon(Icons.refresh_rounded, color: AdminColors.textPrimary, size: 18),
                tooltip: 'Refresh Reviews',
                onPressed: () {
                  HapticFeedback.lightImpact();
                  ref.invalidate(allReviewsProvider);
                },
              ),
            ),
          ),
        ],
      ),
      body: reviewsAsync.when(
        loading: () => _buildLoadingSkeleton(),
        error: (err, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AdminColors.error.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.cloud_off_rounded, size: 40, color: AdminColors.error),
                ),
                const SizedBox(height: 16),
                Text(
                  'Error loading reviews',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16, color: AdminColors.textPrimary),
                ),
                const SizedBox(height: 6),
                Text(
                  err.toString(),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(fontSize: 12, color: AdminColors.textSecondary),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () => ref.invalidate(allReviewsProvider),
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: const Text('Try Again'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AdminColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
          ),
        ),
        data: (allReviews) {
          // Compute summary metrics for KPI ribbon
          final totalReviews = allReviews.length;
          double ratingSum = 0;
          int lowRatedCount = 0;
          int flaggedCount = 0;
          int resolvedCount = 0;

          for (final r in allReviews) {
            final rating = (r['rating'] as num?)?.toDouble() ?? 5.0;
            final status = (r['status'] ?? 'Active').toString().toLowerCase();
            ratingSum += rating;

            if (rating <= 2.0 && status != 'resolved') {
              lowRatedCount++;
            }
            if (status == 'flagged') {
              flaggedCount++;
            }
            if (status == 'resolved') {
              resolvedCount++;
            }
          }

          final avgRating = totalReviews > 0 ? (ratingSum / totalReviews) : 5.0;

          // Apply current filter tab
          var filtered = allReviews.where((r) {
            final rating = (r['rating'] as num?)?.toDouble() ?? 5.0;
            final status = (r['status'] ?? 'Active').toString().toLowerCase();

            if (_selectedFilter == 'low_rated') return rating <= 2.0 && status != 'resolved';
            if (_selectedFilter == 'flagged') return status == 'flagged';
            if (_selectedFilter == 'resolved') return status == 'resolved';
            return true;
          }).toList();

          // Apply search query filter
          if (_searchQuery.isNotEmpty) {
            filtered = filtered.where((r) {
              final rawTripId = (r['rideId'] as String? ?? r['tripId'] as String? ?? '').toLowerCase();
              final comment = (r['comment'] as String? ?? r['feedback'] as String? ?? '').toLowerCase();

              // User lookup for names
              AppUser? rider;
              AppUser? captain;
              try {
                rider = allUsers.firstWhere((u) => u.uid == r['userId']);
              } catch (_) {}
              try {
                captain = allUsers.firstWhere((u) => u.uid == r['captainId']);
              } catch (_) {}

              final riderName = (r['riderName'] as String?)?.toLowerCase() ??
                  rider?.name.toLowerCase() ??
                  (r['userName'] as String?)?.toLowerCase() ??
                  '';
              final captainName = (r['captainName'] as String?)?.toLowerCase() ??
                  captain?.name.toLowerCase() ??
                  '';

              return rawTripId.contains(_searchQuery) ||
                  comment.contains(_searchQuery) ||
                  riderName.contains(_searchQuery) ||
                  captainName.contains(_searchQuery);
            }).toList();
          }

          return Column(
            children: [
              // Expandable Search Bar
              if (_isSearchExpanded)
                Container(
                  color: AdminColors.card,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Container(
                    decoration: BoxDecoration(
                      color: AdminColors.background,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AdminColors.border),
                    ),
                    child: TextField(
                      controller: _searchController,
                      autofocus: true,
                      onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
                      style: GoogleFonts.inter(fontSize: 13, color: AdminColors.textPrimary),
                      decoration: InputDecoration(
                        hintText: 'Search rider, captain, trip ID or review...',
                        hintStyle: GoogleFonts.inter(fontSize: 12, color: AdminColors.textSecondary),
                        prefixIcon: const Icon(Icons.search_rounded, size: 18, color: AdminColors.textSecondary),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear_rounded, size: 16),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _searchQuery = '');
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                    ),
                  ),
                ),

              // KPI Ribbon
              _buildExecutiveKpiRibbon(
                avgRating: avgRating,
                totalReviews: totalReviews,
                lowRatedCount: lowRatedCount,
                flaggedCount: flaggedCount,
                resolvedCount: resolvedCount,
              ),

              // Filter Tabs Strip with live badge counts
              _buildFilterTabs(
                totalCount: totalReviews,
                lowRatedCount: lowRatedCount,
                flaggedCount: flaggedCount,
                resolvedCount: resolvedCount,
              ),

              // Review List
              Expanded(
                child: filtered.isEmpty
                    ? _buildEmptyState()
                    : ResponsiveCenter(
                        maxWidth: 850,
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 14, 16, 96),
                          itemCount: filtered.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 14),
                          itemBuilder: (context, idx) {
                            return _buildReviewCard(
                              review: filtered[idx],
                              allUsers: allUsers,
                            );
                          },
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ─── Executive KPI Overview Ribbon ──────────────────────────────────────────
  Widget _buildExecutiveKpiRibbon({
    required double avgRating,
    required int totalReviews,
    required int lowRatedCount,
    required int flaggedCount,
    required int resolvedCount,
  }) {
    return Container(
      color: AdminColors.card,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildKpiCard(
              title: 'Avg Rating',
              value: '${avgRating.toStringAsFixed(1)} ★',
              subtitle: '$totalReviews reviews',
              icon: Icons.star_rounded,
              color: const Color(0xFFF59E0B),
              isSelected: _selectedFilter == 'all',
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _selectedFilter = 'all');
              },
            ),
            const SizedBox(width: 10),
            _buildKpiCard(
              title: 'Needs Attention',
              value: '$lowRatedCount',
              subtitle: '≤ 2★ reviews',
              icon: Icons.warning_amber_rounded,
              color: const Color(0xFFEF4444),
              isSelected: _selectedFilter == 'low_rated',
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _selectedFilter = 'low_rated');
              },
            ),
            const SizedBox(width: 10),
            _buildKpiCard(
              title: 'Flagged',
              value: '$flaggedCount',
              subtitle: 'Investigating',
              icon: Icons.flag_rounded,
              color: const Color(0xFFF97316),
              isSelected: _selectedFilter == 'flagged',
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _selectedFilter = 'flagged');
              },
            ),
            const SizedBox(width: 10),
            _buildKpiCard(
              title: 'Resolved',
              value: '$resolvedCount',
              subtitle: 'Closed feedback',
              icon: Icons.check_circle_rounded,
              color: AdminColors.success,
              isSelected: _selectedFilter == 'resolved',
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _selectedFilter = 'resolved');
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.08) : AdminColors.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color.withValues(alpha: 0.6) : AdminColors.border.withValues(alpha: 0.7),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 16, color: color),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      value,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AdminColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: AdminColors.textSecondary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ─── Filter Tabs with Interactive Badges ─────────────────────────────────────
  Widget _buildFilterTabs({
    required int totalCount,
    required int lowRatedCount,
    required int flaggedCount,
    required int resolvedCount,
  }) {
    return Container(
      color: AdminColors.card,
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildTabPill('all', 'All Reviews', totalCount, Icons.grid_view_rounded),
            const SizedBox(width: 8),
            _buildTabPill('low_rated', 'Low Rated', lowRatedCount, Icons.warning_amber_rounded,
                accentColor: const Color(0xFFEF4444)),
            const SizedBox(width: 8),
            _buildTabPill('flagged', 'Flagged', flaggedCount, Icons.flag_rounded,
                accentColor: const Color(0xFFF97316)),
            const SizedBox(width: 8),
            _buildTabPill('resolved', 'Resolved', resolvedCount, Icons.check_circle_rounded,
                accentColor: AdminColors.success),
          ],
        ),
      ),
    );
  }

  Widget _buildTabPill(
    String key,
    String label,
    int count,
    IconData icon, {
    Color? accentColor,
  }) {
    final selected = _selectedFilter == key;
    final pillColor = accentColor ?? AdminColors.primary;

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _selectedFilter = key);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? pillColor : AdminColors.background,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: selected ? pillColor : AdminColors.border,
            width: selected ? 1.5 : 1.0,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: pillColor.withValues(alpha: 0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 13,
              color: selected ? Colors.white : AdminColors.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 11.5,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                color: selected ? Colors.white : AdminColors.textSecondary,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
              decoration: BoxDecoration(
                color: selected
                    ? Colors.white.withValues(alpha: 0.25)
                    : AdminColors.border.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$count',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: selected ? Colors.white : AdminColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Modern Review Card ──────────────────────────────────────────────────────
  Widget _buildReviewCard({
    required Map<String, dynamic> review,
    required List<AppUser> allUsers,
  }) {
    final reviewId = review['id'] ?? '';
    final rating = (review['rating'] as num?)?.toDouble() ?? 5.0;
    final rawComment = (review['comment'] as String? ?? review['feedback'] as String? ?? '').trim();
    final hasComment = rawComment.isNotEmpty;

    // Resolve Users
    AppUser? rider;
    AppUser? captain;
    try {
      rider = allUsers.firstWhere((u) => u.uid == review['userId']);
    } catch (_) {}
    try {
      captain = allUsers.firstWhere((u) => u.uid == review['captainId']);
    } catch (_) {}

    final riderName = (review['riderName'] as String?)?.trim().isNotEmpty == true
        ? review['riderName']
        : (rider?.name.trim().isNotEmpty == true
            ? rider!.name.trim()
            : (review['userName'] ?? 'Rider'));

    final captainName = (review['captainName'] as String?)?.trim().isNotEmpty == true
        ? review['captainName']
        : (captain?.name.trim().isNotEmpty == true ? captain!.name.trim() : 'Captain');

    final status = (review['status'] ?? 'Active').toString();
    final statusLower = status.toLowerCase();
    final isResolved = statusLower == 'resolved';
    final isFlagged = statusLower == 'flagged';
    final isLowRated = rating <= 2.0;

    final rawTripId = (review['rideId'] as String? ?? review['tripId'] as String? ?? '').trim();
    final tripId = rawTripId.length > 8 ? rawTripId.substring(0, 8).toUpperCase() : rawTripId.toUpperCase();

    DateTime? date;
    if (review['createdAt'] is Timestamp) {
      date = (review['createdAt'] as Timestamp).toDate();
    }

    // Determine badge and accent colors based on rating
    Color ratingAccent;
    Color ratingBg;
    if (rating >= 4.0) {
      ratingAccent = const Color(0xFF059669);
      ratingBg = const Color(0xFFECFDF5);
    } else if (rating >= 3.0) {
      ratingAccent = const Color(0xFFD97706);
      ratingBg = const Color(0xFFFFFBEB);
    } else {
      ratingAccent = const Color(0xFFDC2626);
      ratingBg = const Color(0xFFFEF2F2);
    }

    return Container(
      decoration: BoxDecoration(
        color: AdminColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isFlagged
              ? const Color(0xFFFCA5A5)
              : (isLowRated && !isResolved
                  ? const Color(0xFFFED7AA)
                  : (isResolved ? const Color(0xFFA7F3D0) : AdminColors.border.withValues(alpha: 0.8))),
          width: (isFlagged || (isLowRated && !isResolved)) ? 1.4 : 1.0,
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
          // ── Header: Rating Pill + Stars + Status Badge ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Star Rating Tag + Mini Stars
                Flexible(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: ratingBg,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: ratingAccent.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.star_rounded, size: 15, color: ratingAccent),
                            const SizedBox(width: 4),
                            Text(
                              rating.toStringAsFixed(1),
                              style: GoogleFonts.inter(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w800,
                                color: ratingAccent,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: List.generate(5, (sIdx) {
                            return Icon(
                              sIdx < rating ? Icons.star_rounded : Icons.star_outline_rounded,
                              size: 14,
                              color: sIdx < rating ? const Color(0xFFF59E0B) : AdminColors.border,
                            );
                          }),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // Status Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isResolved
                        ? AdminColors.success.withValues(alpha: 0.12)
                        : (isFlagged
                            ? AdminColors.error.withValues(alpha: 0.12)
                            : AdminColors.primary.withValues(alpha: 0.08)),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isResolved
                          ? AdminColors.success.withValues(alpha: 0.3)
                          : (isFlagged
                              ? AdminColors.error.withValues(alpha: 0.3)
                              : AdminColors.primary.withValues(alpha: 0.2)),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isResolved
                            ? Icons.check_circle_rounded
                            : (isFlagged ? Icons.flag_rounded : Icons.fiber_manual_record_rounded),
                        size: isResolved || isFlagged ? 12 : 8,
                        color: isResolved
                            ? AdminColors.success
                            : (isFlagged ? AdminColors.error : AdminColors.secondary),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        isResolved ? 'Resolved' : (isFlagged ? 'Flagged' : 'Active'),
                        style: GoogleFonts.inter(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: isResolved
                              ? AdminColors.success
                              : (isFlagged ? AdminColors.error : AdminColors.primary),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Trip ID & Timestamp Strip ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                if (tripId.isNotEmpty) ...[
                  InkWell(
                    onTap: () => _copyToClipboard(rawTripId, 'Trip ID'),
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: AdminColors.background,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AdminColors.border),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.directions_car_rounded, size: 11, color: AdminColors.secondary),
                          const SizedBox(width: 4),
                          Text(
                            'Trip #$tripId',
                            style: GoogleFonts.inter(
                              fontSize: 10.5,
                              color: AdminColors.secondary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.copy_rounded,
                            size: 10,
                            color: AdminColors.textSecondary.withValues(alpha: 0.6),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text('•', style: GoogleFonts.inter(color: AdminColors.border)),
                  const SizedBox(width: 8),
                ],
                if (date != null) ...[
                  Icon(Icons.schedule_rounded, size: 12, color: AdminColors.textSecondary.withValues(alpha: 0.7)),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      DateFormat('dd MMM yyyy, hh:mm a').format(date),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 10.5,
                        color: AdminColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 12),

          // ── Participant Relationship Bar (Rider ➔ Captain) ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AdminColors.border.withValues(alpha: 0.6)),
              ),
              child: Row(
                children: [
                  // Rider Section
                  Expanded(
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 13,
                          backgroundColor: AdminColors.secondary.withValues(alpha: 0.15),
                          child: Text(
                            riderName.isNotEmpty ? riderName[0].toUpperCase() : 'R',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: AdminColors.secondary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                riderName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: AdminColors.textPrimary,
                                ),
                              ),
                              Text(
                                'Rider',
                                style: GoogleFonts.inter(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w500,
                                  color: AdminColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Connecting Arrow
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Icon(
                      Icons.arrow_forward_rounded,
                      size: 14,
                      color: AdminColors.textSecondary.withValues(alpha: 0.4),
                    ),
                  ),

                  // Captain Section
                  Expanded(
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 13,
                          backgroundColor: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                          child: Text(
                            captainName.isNotEmpty ? captainName[0].toUpperCase() : 'C',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFFD97706),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                captainName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: AdminColors.textPrimary,
                                ),
                              ),
                              Text(
                                'Captain',
                                style: GoogleFonts.inter(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w500,
                                  color: AdminColors.textSecondary,
                                ),
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

          const SizedBox(height: 12),

          // ── Comment / Feedback Quote Box ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: hasComment
                ? Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AdminColors.background,
                      borderRadius: BorderRadius.circular(10),
                      border: Border(
                        left: BorderSide(color: ratingAccent, width: 3.5),
                        top: BorderSide(color: AdminColors.border.withValues(alpha: 0.5)),
                        right: BorderSide(color: AdminColors.border.withValues(alpha: 0.5)),
                        bottom: BorderSide(color: AdminColors.border.withValues(alpha: 0.5)),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.format_quote_rounded,
                          size: 18,
                          color: ratingAccent.withValues(alpha: 0.6),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            rawComment,
                            style: GoogleFonts.inter(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: AdminColors.textPrimary,
                              height: 1.4,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                : Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AdminColors.background,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AdminColors.border.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.chat_bubble_outline_rounded,
                          size: 13,
                          color: AdminColors.textSecondary.withValues(alpha: 0.6),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Rated $rating★ without written feedback',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w500,
                              color: AdminColors.textSecondary.withValues(alpha: 0.8),
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),

          const SizedBox(height: 12),
          const Divider(height: 1, color: AdminColors.border),

          // ── Actions Footer ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Alert badge if low rated & active
                if (isLowRated && !isResolved)
                  Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, size: 14, color: Color(0xFFEF4444)),
                      const SizedBox(width: 4),
                      Text(
                        'Needs Review',
                        style: GoogleFonts.inter(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFFEF4444),
                        ),
                      ),
                    ],
                  )
                else
                  const SizedBox.shrink(),

                // Buttons
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Flag Trip Button
                    if (!isFlagged && !isResolved) ...[
                      OutlinedButton.icon(
                        onPressed: () => _updateStatus(reviewId, 'Flagged'),
                        icon: const Icon(Icons.flag_outlined, size: 13, color: AdminColors.error),
                        label: Text(
                          'Flag Trip',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AdminColors.error,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: AdminColors.error.withValues(alpha: 0.4)),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          minimumSize: const Size(0, 32),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],

                    // Resolve Button
                    if (!isResolved) ...[
                      ElevatedButton.icon(
                        onPressed: () => _updateStatus(reviewId, 'Resolved'),
                        icon: const Icon(Icons.check_circle_rounded, size: 14, color: Colors.white),
                        label: Text(
                          'Resolve',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AdminColors.success,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          minimumSize: const Size(0, 32),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ],

                    // Reopen Case Button
                    if (isResolved) ...[
                      OutlinedButton.icon(
                        onPressed: () => _updateStatus(reviewId, 'Active'),
                        icon: const Icon(Icons.refresh_rounded, size: 13, color: AdminColors.textSecondary),
                        label: Text(
                          'Reopen Case',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AdminColors.textSecondary,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: AdminColors.border),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          minimumSize: const Size(0, 32),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
    );
  }

  // ─── Empty State ─────────────────────────────────────────────────────────────
  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AdminColors.card,
                shape: BoxShape.circle,
                border: Border.all(color: AdminColors.border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(
                Icons.rate_review_outlined,
                size: 44,
                color: AdminColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No reviews found',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AdminColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _searchQuery.isNotEmpty
                  ? 'No reviews match "$_searchQuery".'
                  : 'There are no reviews matching this category filter.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: AdminColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            if (_selectedFilter != 'all' || _searchQuery.isNotEmpty)
              TextButton.icon(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  setState(() {
                    _selectedFilter = 'all';
                    _searchQuery = '';
                    _searchController.clear();
                    _isSearchExpanded = false;
                  });
                },
                icon: const Icon(Icons.refresh_rounded, size: 14),
                label: const Text('Reset All Filters'),
                style: TextButton.styleFrom(
                  foregroundColor: AdminColors.secondary,
                  textStyle: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 12),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ─── Loading Skeleton ────────────────────────────────────────────────────────
  Widget _buildLoadingSkeleton() {
    return Column(
      children: [
        // Skeleton KPI header
        Container(
          color: AdminColors.card,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(
            children: List.generate(3, (index) {
              return Expanded(
                child: Container(
                  height: 52,
                  margin: EdgeInsets.only(right: index < 2 ? 8 : 0),
                  decoration: BoxDecoration(
                    color: AdminColors.background,
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              );
            }),
          ),
        ),
        // Skeleton List items
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: 4,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) => Container(
              height: 180,
              decoration: BoxDecoration(
                color: AdminColors.card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AdminColors.border.withValues(alpha: 0.6)),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
