import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../admin_design.dart';
import '../admin_providers.dart';
import '../widgets/admin_common_widgets.dart';

class OffersScreen extends ConsumerWidget {
  const OffersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offersAsync = ref.watch(offersProvider);

    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        title: Text('Offers & Promos', style: TextStyle(color: context.colors.text, fontWeight: FontWeight.w800, fontSize: 16)),
        backgroundColor: context.colors.surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        iconTheme: IconThemeData(color: context.colors.text),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateOfferSheet(context, ref),
        backgroundColor: context.colors.adminAccent,
        foregroundColor: Colors.black,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Create Offer', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: AsyncPage(
        loading: offersAsync.isLoading,
        error: offersAsync.error,
        child: Builder(builder: (_) {
          final offers = offersAsync.value ?? [];
          
          if (offers.isEmpty) {
            return const EmptyState(icon: Icons.local_offer_outlined, title: 'No active offers', subtitle: 'Create a discount code to boost bookings.');
          }
          
          return ListView.separated(
            padding: const EdgeInsets.only(left: 20, right: 20, top: 20, bottom: 100),
            itemCount: offers.length,
            separatorBuilder: (_, _) => const SizedBox(height: 16),
            itemBuilder: (context, index) {
              final offer = offers[index];
              final isFlat = offer['type'] == 'flat';
              final valStr = isFlat ? '₹${offer['value']}' : '${offer['value']}%';
              
              DateTime? expiry;
              if (offer['expiryDate'] is Timestamp) {
                expiry = (offer['expiryDate'] as Timestamp).toDate();
              }
              final isExpired = expiry != null && expiry.isBefore(DateTime.now());

              return Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: context.colors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: isExpired ? context.colors.cardBorder : context.colors.adminAccent.withValues(alpha: 0.5)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(color: context.colors.background, borderRadius: BorderRadius.circular(8)),
                      child: Text(offer['code']?.toString() ?? '---', style: TextStyle(color: context.colors.text, fontWeight: FontWeight.w800, fontSize: 16, letterSpacing: 1)),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(offer['description']?.toString() ?? '', style: TextStyle(color: context.colors.text, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 4),
                          Text('Min Ride: ₹${offer['minAmount'] ?? 0}', style: TextStyle(color: context.colors.textMuted, fontSize: 12)),
                          if (expiry != null)
                            Text('Expires: ${DateFormat('d MMM, yyyy').format(expiry)}', style: TextStyle(color: isExpired ? context.colors.error : context.colors.success, fontSize: 12, fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ),
                    Text(valStr, style: TextStyle(color: isExpired ? context.colors.textMuted : context.colors.success, fontWeight: FontWeight.w800, fontSize: 24)),
                  ],
                ),
              );
            },
          );
        }),
      ),
    );
  }

  void _showCreateOfferSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.colors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => const CreateOfferSheet(),
    );
  }
}

class CreateOfferSheet extends ConsumerStatefulWidget {
  const CreateOfferSheet({super.key});

  @override
  ConsumerState<CreateOfferSheet> createState() => _CreateOfferSheetState();
}

class _CreateOfferSheetState extends ConsumerState<CreateOfferSheet> {
  final _formKey = GlobalKey<FormState>();
  final _code = TextEditingController();
  final _desc = TextEditingController();
  final _value = TextEditingController();
  final _min = TextEditingController();
  String _type = 'flat';
  DateTime _expiry = DateTime.now().add(const Duration(days: 30));
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: 24, right: 24, top: 24, bottom: MediaQuery.of(context).viewInsets.bottom + 24),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Create New Offer', style: TextStyle(color: context.colors.text, fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 20),
            TextFormField(
              controller: _code,
              textCapitalization: TextCapitalization.characters,
              style: TextStyle(color: context.colors.text),
              decoration: _inputDecoration('Coupon Code (e.g. FLAT50)'),
              validator: (v) => v == null || v.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _desc,
              style: TextStyle(color: context.colors.text),
              decoration: _inputDecoration('Description'),
              validator: (v) => v == null || v.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _type,
                    dropdownColor: context.colors.surfaceAlt,
                    style: TextStyle(color: context.colors.text),
                    decoration: _inputDecoration('Discount Type'),
                    items: const [
                      DropdownMenuItem(value: 'flat', child: Text('Flat Amount (₹)')),
                      DropdownMenuItem(value: 'percent', child: Text('Percentage (%)')),
                    ],
                    onChanged: (v) => setState(() => _type = v!),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _value,
                    keyboardType: TextInputType.number,
                    style: TextStyle(color: context.colors.text),
                    decoration: _inputDecoration('Value'),
                    validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _min,
              keyboardType: TextInputType.number,
              style: TextStyle(color: context.colors.text),
              decoration: _inputDecoration('Min Ride Amount (₹)'),
              validator: (v) => v == null || v.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: _expiry,
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (date != null) setState(() => _expiry = date);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                decoration: BoxDecoration(color: context.colors.background, borderRadius: BorderRadius.circular(14), border: Border.all(color: context.colors.cardBorder)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Expires: ${DateFormat('d MMM, yyyy').format(_expiry)}', style: TextStyle(color: context.colors.text)),
                    Icon(Icons.calendar_today_rounded, color: context.colors.textMuted, size: 20),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(backgroundColor: context.colors.adminAccent, foregroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                child: _saving ? const CircularProgressIndicator(color: Colors.black) : const Text('Publish Offer', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: context.colors.textMuted),
      filled: true, fillColor: context.colors.background,
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: context.colors.cardBorder)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: context.colors.adminAccent)),
      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: context.colors.error)),
      focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: context.colors.error)),
    );
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      await ref.read(adminRepositoryProvider).createOffer({
        'code': _code.text.trim().toUpperCase(),
        'description': _desc.text.trim(),
        'type': _type,
        'value': int.parse(_value.text.trim()),
        'minAmount': int.parse(_min.text.trim()),
        'expiryDate': Timestamp.fromDate(_expiry),
      });
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(backgroundColor: context.colors.success, content: Text('Offer created!')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(backgroundColor: context.colors.error, content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
