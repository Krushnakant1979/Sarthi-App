import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import '../admin_design.dart';
import '../admin_providers.dart';

class MarketingScreen extends ConsumerStatefulWidget {
  const MarketingScreen({super.key});

  @override
  ConsumerState<MarketingScreen> createState() => _MarketingScreenState();
}

class _MarketingScreenState extends ConsumerState<MarketingScreen> {
  int _selectedTab = 0; // 0: Campaigns, 1: Compose New

  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _messageCtrl = TextEditingController();

  String _audience = 'all'; // 'all', 'riders', 'captains'
  String _channel = 'push'; // 'push', 'sms', 'email'
  bool _isSubmitting = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _messageCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendCampaign() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);
    HapticFeedback.mediumImpact();

    try {
      await ref.read(adminRepositoryProvider).createCampaign(
            title: _titleCtrl.text.trim(),
            message: _messageCtrl.text.trim(),
            audience: _audience,
            channel: _channel,
          );

      if (mounted) {
        _titleCtrl.clear();
        _messageCtrl.clear();
        setState(() {
          _selectedTab = 0;
          _isSubmitting = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Campaign launched and broadcasted successfully!'),
            backgroundColor: AdminColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to launch campaign: $e'),
            backgroundColor: AdminColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final campaignsAsync = ref.watch(allCampaignsProvider);

    return Scaffold(
      backgroundColor: AdminColors.background,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Marketing & Broadcast Hub',
              style: GoogleFonts.inter(
                color: AdminColors.textPrimary,
                fontWeight: FontWeight.w800,
                fontSize: 15,
              ),
            ),
            Text(
              'User announcements and push promotions',
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
      ),
      body: Column(
        children: [
          // Smooth Slidable Segmented Tab Switch
          _buildSlidableTabSwitch(),

          Expanded(
            child: _selectedTab == 0
                ? _buildCampaignsList(campaignsAsync)
                : _buildComposeForm(),
          ),
        ],
      ),
    );
  }

  Widget _buildCampaignsList(AsyncValue<List<Map<String, dynamic>>> campaignsAsync) {
    return campaignsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('Error loading campaigns: $err')),
      data: (campaigns) {
        if (campaigns.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.campaign_outlined,
                    size: 38,
                    color: AdminColors.textSecondary.withValues(alpha: 0.3),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'No campaigns created yet',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AdminColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Compose a campaign to engage passengers and captains',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: AdminColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 14),
                  ElevatedButton.icon(
                    onPressed: () => setState(() => _selectedTab = 1),
                    icon: const Icon(Icons.add_rounded, size: 15),
                    label: Text(
                      'Create First Campaign',
                      style: GoogleFonts.inter(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AdminColors.primary,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(0, 36),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 8,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 0,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: campaigns.length,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, idx) {
            final c = campaigns[idx];
            final title = c['title'] ?? 'Announcement';
            final msg = c['message'] ?? '';
            final aud = (c['audience'] ?? 'all').toString().toUpperCase();
            final ch = (c['channel'] ?? 'push').toString().toUpperCase();
            final status = c['status'] ?? 'Active';

            DateTime? created;
            if (c['createdAt'] is Timestamp) {
              created = (c['createdAt'] as Timestamp).toDate();
            }

            return Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AdminColors.card,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AdminColors.border),
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
                      Expanded(
                        child: Text(
                          title,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: AdminColors.textPrimary,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AdminColors.success.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          status,
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AdminColors.success,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    msg,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AdminColors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AdminColors.primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'AUDIENCE: $aud',
                          style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w700, color: AdminColors.primary),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'CHANNEL: $ch',
                          style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w700, color: const Color(0xFFD97706)),
                        ),
                      ),
                      const Spacer(),
                      if (created != null)
                        Text(
                          DateFormat('dd MMM yyyy, hh:mm a').format(created),
                          style: GoogleFonts.inter(fontSize: 10, color: AdminColors.textSecondary),
                        ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildComposeForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AdminColors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AdminColors.border),
        ),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Campaign Details',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AdminColors.textPrimary,
                ),
              ),
              const SizedBox(height: 14),

              // Title Field
              Text('Title / Subject', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: AdminColors.textPrimary)),
              const SizedBox(height: 6),
              TextFormField(
                controller: _titleCtrl,
                style: GoogleFonts.inter(fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'e.g., Weekend Special: 20% Off Cab Rides!',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
                validator: (val) => val == null || val.trim().isEmpty ? 'Please enter a campaign title' : null,
              ),
              const SizedBox(height: 14),

              // Target Audience Selector
              Text('Target Audience', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: AdminColors.textPrimary)),
              const SizedBox(height: 6),
              Row(
                children: [
                  _buildAudienceChip('all', 'All Users', Icons.groups_rounded),
                  const SizedBox(width: 8),
                  _buildAudienceChip('riders', 'Passengers', Icons.person_rounded),
                  const SizedBox(width: 8),
                  _buildAudienceChip('captains', 'Captains', Icons.local_taxi_rounded),
                ],
              ),
              const SizedBox(height: 14),

              // Channel Selector
              Text('Delivery Channel', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: AdminColors.textPrimary)),
              const SizedBox(height: 6),
              Row(
                children: [
                  _buildChannelChip('push', 'Push Notification', Icons.notifications_active_rounded),
                  const SizedBox(width: 8),
                  _buildChannelChip('sms', 'SMS Text', Icons.sms_rounded),
                  const SizedBox(width: 8),
                  _buildChannelChip('email', 'Email', Icons.mail_rounded),
                ],
              ),
              const SizedBox(height: 14),

              // Message Body
              Text('Message Content', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: AdminColors.textPrimary)),
              const SizedBox(height: 6),
              TextFormField(
                controller: _messageCtrl,
                maxLines: 4,
                style: GoogleFonts.inter(fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Write the announcement text that users will receive...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.all(12),
                ),
                validator: (val) => val == null || val.trim().isEmpty ? 'Please write the campaign message' : null,
              ),
              const SizedBox(height: 20),

              // Submit Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isSubmitting ? null : _sendCampaign,
                  icon: _isSubmitting
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.send_rounded, size: 18),
                  label: Text(
                    _isSubmitting ? 'Broadcasting...' : 'Launch & Broadcast Campaign',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 13),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AdminColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAudienceChip(String key, String label, IconData icon) {
    final selected = _audience == key;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _audience = key),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
          decoration: BoxDecoration(
            color: selected ? AdminColors.primary.withValues(alpha: 0.1) : AdminColors.background,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: selected ? AdminColors.primary : AdminColors.border),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14, color: selected ? AdminColors.primary : AdminColors.textSecondary),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected ? AdminColors.primary : AdminColors.textSecondary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChannelChip(String key, String label, IconData icon) {
    final selected = _channel == key;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _channel = key),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFF59E0B).withValues(alpha: 0.1) : AdminColors.background,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: selected ? const Color(0xFFF59E0B) : AdminColors.border),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14, color: selected ? const Color(0xFFD97706) : AdminColors.textSecondary),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected ? const Color(0xFFD97706) : AdminColors.textSecondary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSlidableTabSwitch() {
    final isFirst = _selectedTab == 0;

    void selectTab(int index) {
      if (_selectedTab != index) {
        HapticFeedback.selectionClick();
        setState(() => _selectedTab = index);
      }
    }

    return Container(
      color: AdminColors.card,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final totalWidth = constraints.maxWidth;

          void handlePosition(double localX) {
            if (totalWidth <= 0) return;
            if (localX < totalWidth / 2) {
              selectTab(0);
            } else {
              selectTab(1);
            }
          }

          return Container(
            height: 42,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (details) => handlePosition(details.localPosition.dx),
              onHorizontalDragDown: (details) => handlePosition(details.localPosition.dx),
              onHorizontalDragUpdate: (details) => handlePosition(details.localPosition.dx),
              child: Stack(
                children: [
                  // Smooth sliding indicator pill
                  Positioned.fill(
                    child: AnimatedAlign(
                      alignment: isFirst ? Alignment.centerLeft : Alignment.centerRight,
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOutCubic,
                      child: FractionallySizedBox(
                        widthFactor: 0.5,
                        heightFactor: 1.0,
                        child: Container(
                          decoration: BoxDecoration(
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
                        ),
                      ),
                    ),
                  ),

                  // Tab labels
                  Row(
                    children: [
                      Expanded(
                        child: Center(
                          child: AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 200),
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: isFirst ? FontWeight.w800 : FontWeight.w600,
                              color: isFirst ? Colors.white : const Color(0xFF64748B),
                            ),
                            child: const Text('Active Campaigns'),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Center(
                          child: AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 200),
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: !isFirst ? FontWeight.w800 : FontWeight.w600,
                              color: !isFirst ? Colors.white : const Color(0xFF64748B),
                            ),
                            child: const Text('Compose New'),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
