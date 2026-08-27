import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../admin_design.dart';
import '../admin_providers.dart';
import '../widgets/admin_common_widgets.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _zoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _isEditingContacts = false;

  @override
  void dispose() {
    _zoneController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _saveContacts() {
    ref.read(adminRepositoryProvider).updateGlobalSettings({
      'supportEmail': _emailController.text.trim(),
      'supportPhone': _phoneController.text.trim(),
    });
    setState(() => _isEditingContacts = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Contacts updated successfully'), backgroundColor: context.colors.success));
  }

  void _addZone() {
    final city = _zoneController.text.trim();
    if (city.isNotEmpty) {
      ref.read(adminRepositoryProvider).addActiveZone(city);
      _zoneController.clear();
      FocusScope.of(context).unfocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(globalSettingsProvider);

    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        title: Text('Settings & Zones', style: TextStyle(color: context.colors.text, fontWeight: FontWeight.w800, fontSize: 16)),
        backgroundColor: context.colors.surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        iconTheme: IconThemeData(color: context.colors.text),
      ),
      body: AsyncPage(
        loading: settingsAsync.isLoading,
        error: settingsAsync.error,
        child: Builder(builder: (_) {
          final data = settingsAsync.value;
          if (data == null) return const SizedBox.shrink();

          final isActive = data['isPlatformActive'] as bool? ?? true;
          final email = data['supportEmail'] as String? ?? '';
          final phone = data['supportPhone'] as String? ?? '';
          final zones = List<String>.from(data['activeZones'] ?? []);

          if (!_isEditingContacts && _emailController.text.isEmpty && _phoneController.text.isEmpty) {
            _emailController.text = email;
            _phoneController.text = phone;
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildMasterSwitch(isActive),
                const SizedBox(height: 24),
                _buildContactDetails(email, phone),
                const SizedBox(height: 24),
                _buildOperationalZones(zones),
                const SizedBox(height: 40),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildMasterSwitch(bool isActive) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.colors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.power_settings_new_rounded, color: isActive ? context.colors.success : context.colors.error),
              const SizedBox(width: 8),
              Text('Master Kill Switch', style: TextStyle(color: context.colors.text, fontSize: 16, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 8),
          Text('Turn off the platform to prevent new rides during maintenance.', style: TextStyle(color: context.colors.textMuted, fontSize: 13)),
          const SizedBox(height: 16),
          Material(
            color: Colors.transparent,
            child: SwitchListTile(
              value: isActive,
              onChanged: (val) {
                ref.read(adminRepositoryProvider).updateGlobalSettings({'isPlatformActive': val});
              },
              title: Text(isActive ? 'Platform is Online' : 'Platform is Offline', style: TextStyle(color: isActive ? context.colors.success : context.colors.error, fontWeight: FontWeight.w700)),
              activeThumbColor: context.colors.success,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactDetails(String email, String phone) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.colors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.contact_support_rounded, color: context.colors.adminInfo, size: 20),
                  SizedBox(width: 8),
                  Text('Global Support Contacts', style: TextStyle(color: context.colors.text, fontSize: 16, fontWeight: FontWeight.w700)),
                ],
              ),
              IconButton(
                icon: Icon(_isEditingContacts ? Icons.close_rounded : Icons.edit_rounded, color: context.colors.textMuted, size: 20),
                onPressed: () {
                  setState(() {
                    _isEditingContacts = !_isEditingContacts;
                    if (!_isEditingContacts) {
                      _emailController.text = email;
                      _phoneController.text = phone;
                    }
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_isEditingContacts) ...[
            TextField(
              controller: _emailController,
              decoration: InputDecoration(
                labelText: 'Support Email',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _phoneController,
              decoration: InputDecoration(
                labelText: 'Support Phone',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _saveContacts,
              style: ElevatedButton.styleFrom(
                minimumSize: Size.zero,
                backgroundColor: context.colors.adminAccent,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Save Contacts', style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          ] else ...[
            _buildContactRow(Icons.email_rounded, email.isEmpty ? 'Not set' : email),
            const SizedBox(height: 12),
            _buildContactRow(Icons.phone_rounded, phone.isEmpty ? 'Not set' : phone),
          ],
        ],
      ),
    );
  }

  Widget _buildContactRow(IconData icon, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.colors.background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, color: context.colors.textMuted, size: 20),
          const SizedBox(width: 12),
          Text(value, style: TextStyle(color: context.colors.text, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildOperationalZones(List<String> zones) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.colors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.map_rounded, color: context.colors.warning, size: 20),
              SizedBox(width: 8),
              Text('Operational Zones', style: TextStyle(color: context.colors.text, fontSize: 16, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 8),
          Text('Whitelist cities where users can book rides.', style: TextStyle(color: context.colors.textMuted, fontSize: 13)),
          const SizedBox(height: 20),
          if (zones.isEmpty)
            Padding(
              padding: EdgeInsets.only(bottom: 16),
              child: Text('No active zones set. Service might be disabled everywhere depending on app logic.', style: TextStyle(color: context.colors.error, fontSize: 13)),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: zones.map((city) => Chip(
                label: Text(city, style: TextStyle(color: context.colors.text, fontWeight: FontWeight.w600)),
                backgroundColor: context.colors.background,
                deleteIcon: Icon(Icons.close_rounded, size: 16, color: context.colors.error),
                onDeleted: () => ref.read(adminRepositoryProvider).removeActiveZone(city),
                side: BorderSide(color: context.colors.cardBorder),
              )).toList(),
            ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _zoneController,
                  decoration: InputDecoration(
                    hintText: 'e.g. Pune, Mumbai',
                    hintStyle: TextStyle(color: context.colors.textMuted),
                    filled: true,
                    fillColor: context.colors.background,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: _addZone,
                style: ElevatedButton.styleFrom(
                  minimumSize: Size.zero,
                  backgroundColor: context.colors.text,
                  foregroundColor: context.colors.surface,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Add'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
