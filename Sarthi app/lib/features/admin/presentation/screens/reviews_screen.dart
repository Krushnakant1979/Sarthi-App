import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import '../admin_design.dart';
import '../admin_providers.dart';

class ReviewsScreen extends ConsumerStatefulWidget {
  const ReviewsScreen({super.key});

  @override
  ConsumerState<ReviewsScreen> createState() => _ReviewsScreenState();
}

class _ReviewsScreenState extends ConsumerState<ReviewsScreen> {
  String _selectedFilter = 'all'; // 'all', 'low_rated', 'flagged', 'resolved'

  Future<void> _updateStatus(String reviewId, String status) async {
    HapticFeedback.lightImpact();
    try {
      await ref.read(adminRepositoryProvider).updateReviewStatus(reviewId, status);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Review marked as $status'),
            backgroundColor: status == 'Resolved' ? AdminColors.success : AdminColors.warning,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update review: $e'),
            backgroundColor: AdminColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final reviewsAsync = ref.watch(allReviewsProvider);

    return Scaffold(
      backgroundColor: AdminColors.background,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Trip Reviews & Moderation',
              style: GoogleFonts.inter(
                color: AdminColors.textPrimary,
                fontWeight: FontWeight.w800,
                fontSize: 15,
              ),
            ),
            Text(
              'Inspect low-rated trips and resolve rider feedback',
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
              ref.invalidate(allReviewsProvider);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Chips
          Container(
            color: AdminColors.card,
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('all', 'All Reviews'),
                  const SizedBox(width: 8),
                  _buildFilterChip('low_rated', '⚠️ Low Rated (≤ 2★)'),
                  const SizedBox(width: 8),
                  _buildFilterChip('flagged', '🚩 Flagged'),
                  const SizedBox(width: 8),
                  _buildFilterChip('resolved', '✅ Resolved'),
                ],
              ),
            ),
          ),

          // Content List
          Expanded(
            child: reviewsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(child: Text('Error loading reviews: $err')),
              data: (reviews) {
                // Filter items
                final filtered = reviews.where((r) {
                  final rating = (r['rating'] as num?)?.toDouble() ?? 5.0;
                  final status = (r['status'] ?? 'Active').toString().toLowerCase();

                  if (_selectedFilter == 'low_rated') return rating <= 2.0 && status != 'resolved';
                  if (_selectedFilter == 'flagged') return status == 'flagged';
                  if (_selectedFilter == 'resolved') return status == 'resolved';
                  return true;
                }).toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.rate_review_outlined, size: 48, color: AdminColors.textSecondary.withValues(alpha: 0.3)),
                        const SizedBox(height: 12),
                        Text(
                          'No reviews found',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AdminColors.textPrimary,
                          ),
                        ),
                        Text(
                          'No feedback records match the current filter',
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
                  itemCount: filtered.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 12),
                  itemBuilder: (context, idx) {
                    final r = filtered[idx];
                    final reviewId = r['id'] ?? '';
                    final rating = (r['rating'] as num?)?.toDouble() ?? 5.0;
                    final comment = r['comment'] ?? r['feedback'] ?? 'No written comment provided.';
                    final riderName = r['riderName'] ?? r['userName'] ?? 'Rider';
                    final captainName = r['captainName'] ?? 'Captain';
                    final status = r['status'] ?? 'Active';
                    final tripId = r['rideId'] ?? r['tripId'] ?? '';

                    DateTime? date;
                    if (r['createdAt'] is Timestamp) {
                      date = (r['createdAt'] as Timestamp).toDate();
                    }

                    final isLowRated = rating <= 2.0;

                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AdminColors.card,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isLowRated
                              ? AdminColors.error.withValues(alpha: 0.3)
                              : AdminColors.border,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.02),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: List.generate(5, (sIdx) {
                                  return Icon(
                                    sIdx < rating ? Icons.star_rounded : Icons.star_outline_rounded,
                                    size: 16,
                                    color: sIdx < rating ? const Color(0xFFF59E0B) : AdminColors.border,
                                  );
                                }),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: status == 'Resolved'
                                      ? AdminColors.success.withValues(alpha: 0.1)
                                      : (status == 'Flagged'
                                          ? AdminColors.error.withValues(alpha: 0.1)
                                          : AdminColors.background),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  status,
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: status == 'Resolved'
                                        ? AdminColors.success
                                        : (status == 'Flagged' ? AdminColors.error : AdminColors.textSecondary),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '"$comment"',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AdminColors.textPrimary,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Text(
                                'By $riderName for $captainName',
                                style: GoogleFonts.inter(fontSize: 11, color: AdminColors.textSecondary),
                              ),
                              if (tripId.isNotEmpty) ...[
                                Text(' • ', style: GoogleFonts.inter(color: AdminColors.textSecondary)),
                                Text(
                                  'Trip #$tripId',
                                  style: GoogleFonts.inter(fontSize: 10, color: AdminColors.primary, fontWeight: FontWeight.w600),
                                ),
                              ],
                              const Spacer(),
                              if (date != null)
                                Text(
                                  DateFormat('dd MMM, hh:mm a').format(date),
                                  style: GoogleFonts.inter(fontSize: 10, color: AdminColors.textSecondary),
                                ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          const Divider(height: 1, color: AdminColors.border),
                          const SizedBox(height: 8),
                          // Actions
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              if (status != 'Flagged' && status != 'Resolved')
                                TextButton.icon(
                                  onPressed: () => _updateStatus(reviewId, 'Flagged'),
                                  icon: const Icon(Icons.flag_rounded, size: 14, color: AdminColors.error),
                                  label: Text(
                                    'Flag Trip',
                                    style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: AdminColors.error),
                                  ),
                                ),
                              const SizedBox(width: 8),
                              if (status != 'Resolved')
                                ElevatedButton.icon(
                                  onPressed: () => _updateStatus(reviewId, 'Resolved'),
                                  icon: const Icon(Icons.check_circle_rounded, size: 14),
                                  label: Text(
                                    'Resolve',
                                    style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AdminColors.success,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    minimumSize: Size.zero,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String key, String label) {
    final selected = _selectedFilter == key;
    return GestureDetector(
      onTap: () => setState(() => _selectedFilter = key),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AdminColors.primary : AdminColors.background,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? AdminColors.primary : AdminColors.border),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? Colors.white : AdminColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
