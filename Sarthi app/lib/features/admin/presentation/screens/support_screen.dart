import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../../auth/domain/app_user.dart';
import '../admin_design.dart';
import '../admin_providers.dart';
import 'package:google_fonts/google_fonts.dart';

class SupportScreen extends ConsumerWidget {
  const SupportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ticketsAsync = ref.watch(supportTicketsProvider);
    final tab = ref.watch(supportTabProvider);
    final roleFilter = ref.watch(supportRoleProvider);
    final search = ref.watch(supportSearchProvider).toLowerCase();
    final sort = ref.watch(supportSortProvider);

    final tickets = ticketsAsync.value ?? [];

    // Filter Open / Resolved
    final openTickets = tickets
        .where((t) => t['status'] != 'resolved')
        .toList();
    final resolvedTickets = tickets
        .where((t) => t['status'] == 'resolved')
        .toList();

    final currentTabList = tab == 'Open Complaints'
        ? openTickets
        : resolvedTickets;

    // Role Counts for current tab
    final usersCount = currentTabList
        .where((t) => (t['reporterRole'] ?? 'user') == 'user')
        .length;
    final captainsCount = currentTabList
        .where((t) => t['reporterRole'] == 'captain')
        .length;
    final allCount = currentTabList.length;

    // Apply Role Filter
    var filteredList = currentTabList.where((t) {
      if (roleFilter == 'All') return true;
      final role = t['reporterRole'] as String? ?? 'user';
      return role.toLowerCase() == roleFilter.toLowerCase();
    }).toList();

    // Apply Search Filter
    if (search.isNotEmpty) {
      filteredList = filteredList.where((t) {
        final id = (t['id'] as String? ?? '').toLowerCase();
        final subject = (t['subject'] as String? ?? '').toLowerCase();
        final msg = (t['message'] as String? ?? '').toLowerCase();
        final userId = (t['userId'] as String? ?? '').toLowerCase();
        return id.contains(search) ||
            subject.contains(search) ||
            msg.contains(search) ||
            userId.contains(search);
      }).toList();
    }

    // Apply Sort
    filteredList.sort((a, b) {
      final aDate = a['createdAt'] as Timestamp?;
      final bDate = b['createdAt'] as Timestamp?;
      if (aDate == null || bDate == null) return 0;
      if (sort == 'newest') return bDate.compareTo(aDate);
      return aDate.compareTo(bDate);
    });

    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Support & Complaints',
              style: GoogleFonts.inter(
                color: context.colors.text,
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
            Text(
              'Review tickets and resolve reported issues',
              style: GoogleFonts.inter(
                color: context.colors.textMuted,
                fontWeight: FontWeight.w500,
                fontSize: 11,
              ),
            ),
          ],
        ),
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Container(
            decoration: BoxDecoration(
              color: context.colors.surfaceAlt,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: Icon(
                Icons.arrow_back,
                color: context.colors.primary,
                size: 18,
              ),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.tune_rounded, color: context.colors.primary),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Advanced filters coming soon')),
              );
            },
          ),
        ],
        backgroundColor: context.colors.surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          HapticFeedback.lightImpact();
          ref.invalidate(supportTicketsProvider);
        },
        color: AdminColors.primary,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _ComplaintStatusTabs(
                      openCount: openTickets.length,
                      resolvedCount: resolvedTickets.length,
                    ),
                    const SizedBox(height: 16),
                    const _ComplaintSearchField(),
                    const SizedBox(height: 16),
                    _ComplaintRoleFilters(
                      allCount: allCount,
                      usersCount: usersCount,
                      captainsCount: captainsCount,
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
            if (ticketsAsync.isLoading && !ticketsAsync.hasValue)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              )
            else if (filteredList.isEmpty)
              const SliverFillRemaining(child: _ComplaintsEmptyState())
            else ...[
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final ticket = filteredList[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _ComplaintPreviewCard(ticket: ticket),
                    );
                  }, childCount: filteredList.length),
                ),
              ),
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: _ComplaintsUpToDateCard(),
                ),
              ),
            ],
            const SliverToBoxAdapter(
              child: SizedBox(height: 40),
            ), // Bottom padding
          ],
        ),
      ),
    );
  }
}

class _ComplaintStatusTabs extends ConsumerWidget {
  final int openCount;
  final int resolvedCount;

  const _ComplaintStatusTabs({
    required this.openCount,
    required this.resolvedCount,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(supportTabProvider);

    return Container(
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: context.colors.cardBorder, width: 0.5),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          Expanded(
            child: _buildTab(
              context,
              ref,
              'Open Complaints',
              openCount,
              tab == 'Open Complaints',
            ),
          ),
          Expanded(
            child: _buildTab(
              context,
              ref,
              'Resolved',
              resolvedCount,
              tab == 'Resolved',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTab(
    BuildContext context,
    WidgetRef ref,
    String title,
    int count,
    bool isSelected,
  ) {
    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        ref.read(supportTabProvider.notifier).state = title;
      },
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? AdminColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              title,
              style: GoogleFonts.inter(
                color: isSelected ? Colors.white : context.colors.text,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                fontSize: 12,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: isSelected
                    ? (title == 'Open Complaints'
                          ? const Color(0xFFF59E0B)
                          : const Color(0xFF16A36A))
                    : context.colors.surfaceAlt,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$count',
                style: GoogleFonts.inter(
                  color: isSelected ? Colors.white : context.colors.textMuted,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ComplaintSearchField extends ConsumerWidget {
  const _ComplaintSearchField();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final search = ref.watch(supportSearchProvider);

    return Row(
      children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: context.colors.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: context.colors.cardBorder, width: 0.5),
            ),
            child: TextField(
              onChanged: (val) =>
                  ref.read(supportSearchProvider.notifier).state = val,
              decoration: InputDecoration(
                hintText: 'Search complaints or ticket ID...',
                hintStyle: GoogleFonts.inter(
                  color: context.colors.textMuted,
                  fontSize: 13,
                ),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: context.colors.textMuted,
                  size: 18,
                ),
                suffixIcon: search.isNotEmpty
                    ? IconButton(
                        icon: Icon(
                          Icons.close_rounded,
                          color: context.colors.textMuted,
                          size: 18,
                        ),
                        onPressed: () {
                          ref.read(supportSearchProvider.notifier).state = '';
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
              style: GoogleFonts.inter(
                color: context.colors.text,
                fontSize: 13,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Container(
          decoration: BoxDecoration(
            color: context.colors.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: context.colors.cardBorder, width: 0.5),
          ),
          child: PopupMenuButton<String>(
            icon: Icon(
              Icons.tune_rounded,
              color: context.colors.primary,
              size: 20,
            ),
            color: context.colors.surface,
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            onSelected: (val) {
              ref.read(supportSortProvider.notifier).state = val;
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'newest',
                child: Text(
                  'Newest first',
                  style: GoogleFonts.inter(
                    color: context.colors.text,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              PopupMenuItem(
                value: 'oldest',
                child: Text(
                  'Oldest first',
                  style: GoogleFonts.inter(
                    color: context.colors.text,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ComplaintRoleFilters extends ConsumerWidget {
  final int allCount;
  final int usersCount;
  final int captainsCount;

  const _ComplaintRoleFilters({
    required this.allCount,
    required this.usersCount,
    required this.captainsCount,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roleFilter = ref.watch(supportRoleProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Row(
        children: [
          Expanded(
            child: _buildChip(
              context,
              ref,
              'All',
              allCount,
              AdminColors.primary,
              roleFilter == 'All',
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildChip(
              context,
              ref,
              'Users',
              usersCount,
              const Color(0xFF2563EB),
              roleFilter == 'Users',
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildChip(
              context,
              ref,
              'Captains',
              captainsCount,
              const Color(0xFF7C3AED),
              roleFilter == 'Captains',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChip(
    BuildContext context,
    WidgetRef ref,
    String title,
    int count,
    Color brandColor,
    bool isSelected,
  ) {
    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        ref.read(supportRoleProvider.notifier).state = title;
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? brandColor : brandColor.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              title,
              style: GoogleFonts.inter(
                color: isSelected ? Colors.white : brandColor,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                fontSize: 11,
              ),
            ),
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.white.withValues(alpha: 0.2)
                    : Colors.white.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$count',
                style: GoogleFonts.inter(
                  color: isSelected ? Colors.white : brandColor,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ComplaintPreviewCard extends StatelessWidget {
  final Map<String, dynamic> ticket;

  const _ComplaintPreviewCard({required this.ticket});

  @override
  Widget build(BuildContext context) {
    final isResolved = ticket['status'] == 'resolved';
    final role = ticket['reporterRole'] as String? ?? 'user';
    final isCaptain = role.toLowerCase() == 'captain';

    final roleColor = isCaptain
        ? const Color(0xFF7C3AED)
        : const Color(0xFF2563EB);
    final statusColor = isResolved
        ? const Color(0xFF16A36A)
        : const Color(0xFFF59E0B);
    final statusText = isResolved ? 'Resolved' : 'Open';

    final id = ticket['id'] as String? ?? '';
    final shortId = id.length > 8
        ? id.substring(0, 8).toUpperCase()
        : id.toUpperCase();

    final subject = ticket['subject'] as String? ?? 'No Subject';
    final message = ticket['message'] as String? ?? 'No message provided';
    final createdAt = ticket['createdAt'] as Timestamp?;
    final dateStr = createdAt != null
        ? DateFormat('MMM d, yyyy • h:mm a').format(createdAt.toDate())
        : '';

    return InkWell(
      onTap: () {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (ctx) => _ComplaintDetailSheet(ticket: ticket),
        );
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: context.colors.cardBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status Border
            Container(
              height: 3,
              decoration: BoxDecoration(
                color: statusColor,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(14),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          statusText,
                          style: GoogleFonts.inter(
                            color: statusColor,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Ticket #$shortId',
                        style: GoogleFonts.inter(
                          color: context.colors.textMuted,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: context.colors.textMuted,
                        size: 16,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    subject,
                    style: GoogleFonts.inter(
                      color: AdminColors.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF4F7FB),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.format_quote_rounded,
                          color: const Color(0xFF2563EB),
                          size: 14,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            message,
                            style: GoogleFonts.inter(
                              color: const Color(0xFF0B1F3A),
                              fontSize: 11,
                              height: 1.4,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 14,
                        backgroundColor: roleColor.withValues(alpha: 0.1),
                        child: Text(
                          isCaptain ? 'C' : 'U',
                          style: GoogleFonts.inter(
                            color: roleColor,
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Submitted by',
                            style: GoogleFonts.inter(
                              color: context.colors.textMuted,
                              fontSize: 8,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            isCaptain ? 'Captain' : 'User',
                            style: GoogleFonts.inter(
                              color: context.colors.text,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: roleColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          isCaptain ? 'Captain' : 'User',
                          style: GoogleFonts.inter(
                            color: roleColor,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today_outlined,
                        color: context.colors.textMuted,
                        size: 12,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        dateStr,
                        style: GoogleFonts.inter(
                          color: context.colors.textMuted,
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Divider(color: context.colors.cardBorder, height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 12.0,
                vertical: 10.0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'View & respond',
                    style: GoogleFonts.inter(
                      color: const Color(0xFF2563EB),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_rounded,
                    color: const Color(0xFF2563EB),
                    size: 14,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ComplaintDetailSheet extends ConsumerStatefulWidget {
  final Map<String, dynamic> ticket;

  const _ComplaintDetailSheet({required this.ticket});

  @override
  ConsumerState<_ComplaintDetailSheet> createState() =>
      _ComplaintDetailSheetState();
}

class _ComplaintDetailSheetState extends ConsumerState<_ComplaintDetailSheet> {
  final _resolutionController = TextEditingController();

  void _resolveTicket() {
    final msg = _resolutionController.text.trim();
    if (msg.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please enter a resolution message'),
          backgroundColor: context.colors.error,
        ),
      );
      return;
    }

    ref.read(adminRepositoryProvider).resolveTicket(widget.ticket['id'], msg);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Complaint resolved successfully'),
        backgroundColor: context.colors.success,
      ),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.ticket;
    final isResolved = t['status'] == 'resolved';
    final subject = t['subject'] as String? ?? 'No Subject';
    final message = t['message'] as String? ?? 'No message provided';
    final role = t['reporterRole'] as String? ?? 'user';
    final isCaptain = role.toLowerCase() == 'captain';
    final userId = t['userId'] as String? ?? '';
    final createdAt = t['createdAt'] as Timestamp?;
    final dateStr = createdAt != null
        ? DateFormat('MMM d, yyyy • h:mm a').format(createdAt.toDate())
        : '';

    return Container(
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.92,
        minChildSize: 0.5,
        maxChildSize: 0.92,
        builder: (_, controller) => SafeArea(
          bottom: false,
          child: Column(
            children: [
              const SizedBox(height: 12),
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: context.colors.cardBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView(
                  controller: controller,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: isResolved
                                ? const Color(0xFF16A36A).withValues(alpha: 0.1)
                                : const Color(
                                    0xFFF59E0B,
                                  ).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            isResolved ? 'Resolved' : 'Open Complaint',
                            style: GoogleFonts.inter(
                              color: isResolved
                                  ? const Color(0xFF16A36A)
                                  : const Color(0xFFF59E0B),
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Text(
                          dateStr,
                          style: GoogleFonts.inter(
                            color: context.colors.textMuted,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      subject,
                      style: GoogleFonts.inter(
                        color: AdminColors.primary,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Original Message',
                      style: GoogleFonts.inter(
                        color: context.colors.textMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: context.colors.background,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: context.colors.cardBorder),
                      ),
                      child: Text(
                        message,
                        style: GoogleFonts.inter(
                          color: context.colors.text,
                          fontSize: 13,
                          height: 1.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Submitter Details',
                      style: GoogleFonts.inter(
                        color: context.colors.textMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: context.colors.background,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: context.colors.cardBorder),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _DetailRow(
                            title: 'Role',
                            value: isCaptain ? 'Captain' : 'User',
                          ),
                          const SizedBox(height: 8),
                          _DetailRow(
                            title: 'Account ID',
                            value: userId.isEmpty
                                ? 'Unknown'
                                : AppUser.shortId(userId),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    if (isResolved) ...[
                      Text(
                        'Resolution',
                        style: GoogleFonts.inter(
                          color: context.colors.textMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(
                            0xFF16A36A,
                          ).withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: const Color(
                              0xFF16A36A,
                            ).withValues(alpha: 0.2),
                          ),
                        ),
                        child: Text(
                          t['resolutionMessage'] as String? ??
                              'No details provided.',
                          style: GoogleFonts.inter(
                            color: const Color(0xFF16A36A),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ] else ...[
                      Text(
                        'Resolve Complaint',
                        style: GoogleFonts.inter(
                          color: context.colors.textMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _resolutionController,
                        maxLines: 3,
                        decoration: InputDecoration(
                          hintText: 'Enter your resolution message...',
                          hintStyle: GoogleFonts.inter(
                            color: context.colors.textMuted,
                            fontSize: 13,
                          ),
                          filled: true,
                          fillColor: context.colors.background,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(
                              color: context.colors.cardBorder,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(
                              color: AdminColors.primary,
                            ),
                          ),
                        ),
                        style: GoogleFonts.inter(
                          color: context.colors.text,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Contact feature coming soon',
                                    ),
                                  ),
                                );
                              },
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                side: BorderSide(
                                  color: context.colors.cardBorder,
                                ),
                              ),
                              child: Text(
                                'Contact ${isCaptain ? 'Captain' : 'User'}',
                                style: GoogleFonts.inter(
                                  color: context.colors.text,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _resolveTicket,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF16A36A),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                elevation: 0,
                              ),
                              child: Text(
                                'Mark Resolved',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String title;
  final String value;
  const _DetailRow({required this.title, required this.value});
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: GoogleFonts.inter(
            color: context.colors.textMuted,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.inter(
            color: context.colors.text,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _ComplaintsUpToDateCard extends StatelessWidget {
  const _ComplaintsUpToDateCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF16A36A).withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF16A36A).withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: Color(0xFF16A36A),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            "You're up to date",
            style: GoogleFonts.inter(
              color: const Color(0xFF16A36A),
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            "All complaints are shown above.",
            style: GoogleFonts.inter(
              color: context.colors.textMuted,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _ComplaintsEmptyState extends StatelessWidget {
  const _ComplaintsEmptyState();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.inbox_outlined,
          color: context.colors.textMuted.withValues(alpha: 0.3),
          size: 64,
        ),
        const SizedBox(height: 16),
        Text(
          "No complaints found",
          style: GoogleFonts.inter(
            color: context.colors.text,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          "There are no complaints matching the selected filters.",
          style: GoogleFonts.inter(
            color: context.colors.textMuted,
            fontSize: 13,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
