import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../admin_design.dart';
import '../admin_providers.dart';
import '../widgets/admin_common_widgets.dart';

class SupportScreen extends ConsumerStatefulWidget {
  const SupportScreen({super.key});

  @override
  ConsumerState<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends ConsumerState<SupportScreen> {
  String _selectedTab = 'Open Complaints';
  String _roleFilter = 'All';

  @override
  Widget build(BuildContext context) {
    final ticketsAsync = ref.watch(supportTicketsProvider);

    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        title: Text('Support & Complaints', style: TextStyle(color: context.colors.text, fontWeight: FontWeight.w800, fontSize: 16)),
        backgroundColor: context.colors.surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        iconTheme: IconThemeData(color: context.colors.text),
      ),
      body: AsyncPage(
        loading: ticketsAsync.isLoading,
        error: ticketsAsync.error,
        child: Builder(
          builder: (context) {
            final tickets = ticketsAsync.value ?? [];
            final roleFilteredTickets = tickets.where((t) {
              if (_roleFilter == 'All') return true;
              final role = t['reporterRole'] as String? ?? 'user';
              return role.toLowerCase() == _roleFilter.toLowerCase();
            }).toList();

            final openTickets = roleFilteredTickets.where((t) => t['status'] != 'resolved').toList();
            final resolvedTickets = roleFilteredTickets.where((t) => t['status'] == 'resolved').toList();

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                  child: _buildToggle(),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      _buildFilterChip('All'),
                      const SizedBox(width: 8),
                      _buildFilterChip('User'),
                      const SizedBox(width: 8),
                      _buildFilterChip('Captain'),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: _selectedTab == 'Open Complaints'
                      ? _TicketList(tickets: openTickets, isOpen: true)
                      : _TicketList(tickets: resolvedTickets, isOpen: false),
                ),
              ],
            );
          }
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label) {
    final isSelected = _roleFilter == label;
    return InkWell(
      onTap: () => setState(() => _roleFilter = label),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? context.colors.text : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? context.colors.text : context.colors.cardBorder),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? context.colors.surface : context.colors.textMuted,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildToggle() {
    return Container(
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.colors.cardBorder),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: () => setState(() => _selectedTab = 'Open Complaints'),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: _selectedTab == 'Open Complaints' ? context.colors.adminAccent : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: Text('Open Complaints', style: TextStyle(
                  color: _selectedTab == 'Open Complaints' ? Colors.black : context.colors.text,
                  fontWeight: _selectedTab == 'Open Complaints' ? FontWeight.w800 : FontWeight.w600,
                )),
              ),
            ),
          ),
          Expanded(
            child: InkWell(
              onTap: () => setState(() => _selectedTab = 'Resolved'),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: _selectedTab == 'Resolved' ? context.colors.adminAccent : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: Text('Resolved', style: TextStyle(
                  color: _selectedTab == 'Resolved' ? Colors.black : context.colors.text,
                  fontWeight: _selectedTab == 'Resolved' ? FontWeight.w800 : FontWeight.w600,
                )),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TicketList extends ConsumerWidget {
  final List<Map<String, dynamic>> tickets;
  final bool isOpen;

  const _TicketList({required this.tickets, required this.isOpen});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (tickets.isEmpty) {
      return Center(
        child: Text(
          isOpen ? 'No open complaints. Great job!' : 'No resolved complaints yet.',
          style: TextStyle(color: context.colors.textMuted),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: tickets.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final ticket = tickets[index];
        return _TicketCard(ticket: ticket, isOpen: isOpen);
      },
    );
  }
}

class _TicketCard extends ConsumerStatefulWidget {
  final Map<String, dynamic> ticket;
  final bool isOpen;

  const _TicketCard({required this.ticket, required this.isOpen});

  @override
  ConsumerState<_TicketCard> createState() => _TicketCardState();
}

class _TicketCardState extends ConsumerState<_TicketCard> {
  final _resolutionController = TextEditingController();

  void _resolveTicket() {
    final msg = _resolutionController.text.trim();
    if (msg.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Please enter a resolution message'), backgroundColor: context.colors.error));
      return;
    }
    
    ref.read(adminRepositoryProvider).resolveTicket(widget.ticket['id'], msg);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Complaint resolved successfully'), backgroundColor: context.colors.success));
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.ticket;
    final role = t['reporterRole'] as String? ?? 'user';
    final subject = t['subject'] as String? ?? 'No Subject';
    final message = t['message'] as String? ?? 'No message content';
    final userId = t['userId'] as String? ?? 'Unknown User';
    final createdAt = t['createdAt'] as Timestamp?;
    final dateStr = createdAt != null ? DateFormat('MMM d, yyyy • h:mm a').format(createdAt.toDate()) : '';
    
    return Container(
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.colors.cardBorder),
      ),
      child: ExpansionTile(
        shape: const RoundedRectangleBorder(side: BorderSide.none),
        collapsedShape: const RoundedRectangleBorder(side: BorderSide.none),
        title: Text(subject, style: TextStyle(color: context.colors.text, fontWeight: FontWeight.w700, fontSize: 16)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text('Role: ${role.toUpperCase()} • ID: $userId\n$dateStr', style: TextStyle(color: context.colors.textMuted, fontSize: 12)),
        ),
        childrenPadding: const EdgeInsets.all(16).copyWith(top: 0),
        expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Divider(color: context.colors.cardBorder),
          const SizedBox(height: 12),
          Text(message, style: TextStyle(color: context.colors.text, fontSize: 14)),
          const SizedBox(height: 16),
          if (widget.isOpen) ...[
            TextField(
              controller: _resolutionController,
              decoration: InputDecoration(
                hintText: 'Resolution message...',
                filled: true,
                fillColor: context.colors.background,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _resolveTicket,
              style: ElevatedButton.styleFrom(
                minimumSize: Size.zero,
                backgroundColor: context.colors.success,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Mark as Resolved', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: context.colors.success.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: context.colors.success.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Resolution:', style: TextStyle(color: context.colors.success, fontWeight: FontWeight.w700, fontSize: 13)),
                  const SizedBox(height: 4),
                  Text(t['resolutionMessage'] as String? ?? 'No details provided.', style: TextStyle(color: context.colors.text, fontSize: 14)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
