import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../admin_providers.dart';
import '../admin_design.dart';
import '../admin_dashboard_screen.dart';
import '../widgets/admin_common_widgets.dart';


class PricingTab extends ConsumerStatefulWidget {
  const PricingTab({super.key});
  @override
  ConsumerState<PricingTab> createState() => PricingTabState();
}


class PricingTabState extends ConsumerState<PricingTab> {
  final formKey = GlobalKey<FormState>();
  final base = TextEditingController();
  final km = TextEditingController();
  final minute = TextEditingController();
  final surge = TextEditingController();
  bool saving = false;
  String _vehicle = 'cab';

  @override
  void initState() { super.initState(); Future.microtask(_load); }
  Future<void> _load() async {
    try {
      final r = await ref.read(adminRepositoryProvider).getFareRules(_vehicle);
      if (!mounted) return;
      base.text = '${r['baseFare']}'; km.text = '${r['perKmFare']}'; minute.text = '${r['perMinuteFare']}'; surge.text = '${r['surgeMultiplier'] ?? 1.0}';
      setState(() {});
    } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e)))); }
  }
  @override
  void dispose() { base.dispose(); km.dispose(); minute.dispose(); surge.dispose(); super.dispose(); }
  String? _validate(String? v) {
    final n = int.tryParse(v ?? '');
    if (n == null) return 'Enter a whole number';
    if (n <= 0) return 'Value must be greater than zero';
    if (n > 10000) return 'Value is too large';
    return null;
  }
  String? _validateSurge(String? v) {
    final n = double.tryParse(v ?? '');
    if (n == null) return 'Enter a number (e.g. 1.5)';
    if (n < 1.0) return 'Surge must be at least 1.0';
    if (n > 5.0) return 'Surge is too large';
    return null;
  }
  @override
  Widget build(BuildContext context) {
    return ListView(padding: const EdgeInsets.all(20), children: [
      Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 560), child: Column(children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFF1A1D2E), Color(0xFF222539)], begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(20), border: Border.all(color: context.colors.cardBorder),
          ),
          child: Row(children: [
            Container(
              width: 56, height: 56,
              decoration: BoxDecoration(color: context.colors.adminAccent.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(16), border: Border.all(color: context.colors.adminAccent.withValues(alpha: 0.35))),
              child: Icon(Icons.price_change_rounded, color: context.colors.adminAccent, size: 28),
            ),
            const SizedBox(width: 16),
            const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Fare Configuration', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18)),
              SizedBox(height: 4),
              Text('Applied to new ride estimates immediately', style: TextStyle(color: Colors.white70, fontSize: 12)),
            ])),
          ]),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8, runSpacing: 8, alignment: WrapAlignment.center,
          children: [
            for (final v in ['auto', 'cab', 'bike', 'parcel'])
              AdminFilterChip(
                label: pretty(v),
                selected: _vehicle == v,
                onTap: () {
                  if (_vehicle == v) return;
                  setState(() => _vehicle = v);
                  _load();
                },
              ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(color: context.colors.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: context.colors.cardBorder)),
          child: Form(key: formKey, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            FareField(controller: base, label: 'Base fare', icon: Icons.flag_rounded, validator: _validate),
            const SizedBox(height: 16),
            FareField(controller: km, label: 'Rate per kilometre', icon: Icons.route_rounded, validator: _validate),
            const SizedBox(height: 16),
            FareField(controller: minute, label: 'Rate per minute', icon: Icons.schedule_rounded, validator: _validate),
            const SizedBox(height: 16),
            FareField(controller: surge, label: 'Surge Multiplier (1.0 = normal)', icon: Icons.electric_bolt_rounded, validator: _validateSurge),
            const SizedBox(height: 24),
            SizedBox(height: 52, child: ElevatedButton.icon(
              onPressed: saving ? null : _save,
              icon: saving
                  ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.black))
                  : const Icon(Icons.save_rounded, color: Colors.black),
              label: Text(saving ? 'Saving...' : 'Save Fare Rules', style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w700, fontSize: 15)),
              style: ElevatedButton.styleFrom(backgroundColor: context.colors.adminAccent, foregroundColor: Colors.black, disabledBackgroundColor: context.colors.cardBorder, disabledForegroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), elevation: 0),
            )),
          ])),
        ),
        const SizedBox(height: 12),
        Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.history_rounded, color: context.colors.textMuted, size: 14),
          SizedBox(width: 6),
          Text('Every update is recorded in the audit log.', style: TextStyle(color: context.colors.textMuted, fontSize: 12)),
        ]),
      ]))),
    ]);
  }
  Future<void> _save() async {
    if (!(formKey.currentState?.validate() ?? false)) return;
    final confirmed = await showDialog<bool>(context: context, builder: (c) => AlertDialog(
      backgroundColor: context.colors.surfaceAlt, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text('Update fare rules?', style: TextStyle(color: context.colors.text, fontWeight: FontWeight.w800)),
      content: Text('New rides will use these prices immediately.', style: TextStyle(color: context.colors.textMuted)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: Text('Cancel', style: TextStyle(color: context.colors.textMuted))),
        FilledButton(onPressed: () => Navigator.pop(c, true), style: FilledButton.styleFrom(backgroundColor: context.colors.adminAccent, foregroundColor: Colors.black), child: const Text('Update', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w700))),
      ],
    )) ?? false;
    if (!confirmed || !mounted) return;
    setState(() => saving = true);
    try {
      await ref.read(adminRepositoryProvider).updateFareRules(_vehicle, int.parse(base.text), int.parse(km.text), int.parse(minute.text), double.parse(surge.text));
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(backgroundColor: context.colors.success, content: Text('${pretty(_vehicle)} fare rules updated successfully.', style: const TextStyle(color: Colors.white))));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(backgroundColor: context.colors.error, content: Text(friendlyError(e), style: const TextStyle(color: Colors.white))));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }
}


class FareField extends StatelessWidget {
  const FareField({super.key, required this.controller, required this.label, required this.icon, required this.validator});
  final TextEditingController controller; final String label; final IconData icon; final String? Function(String?) validator;
  @override
  Widget build(BuildContext context) => TextFormField(
    controller: controller, keyboardType: TextInputType.number, validator: validator,
    style: TextStyle(color: context.colors.text), cursorColor: context.colors.adminAccent,
    decoration: InputDecoration(
      labelText: '$label (₹)', labelStyle: TextStyle(color: context.colors.textMuted),
      prefixIcon: Icon(icon, color: context.colors.textMuted, size: 20),
      filled: true, fillColor: context.colors.background,
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: context.colors.cardBorder)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: context.colors.adminAccent, width: 2)),
      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: context.colors.error)),
      focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: context.colors.error, width: 2)),
    ),
  );
}
