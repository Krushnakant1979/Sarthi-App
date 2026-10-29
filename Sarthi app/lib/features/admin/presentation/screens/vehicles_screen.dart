import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../admin_design.dart';
import '../admin_providers.dart';

class VehiclesScreen extends ConsumerStatefulWidget {
  const VehiclesScreen({super.key});

  @override
  ConsumerState<VehiclesScreen> createState() => _VehiclesScreenState();
}

class _VehiclesScreenState extends ConsumerState<VehiclesScreen> {
  String _selectedCategory = 'all'; // 'all', 'cab', 'auto', 'bike', 'parcel'
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
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
              'Fleet & Vehicles Management',
              style: GoogleFonts.inter(
                color: AdminColors.textPrimary,
                fontWeight: FontWeight.w800,
                fontSize: 15,
              ),
            ),
            Text(
              'Active fleet overview categorized by service type',
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
      ),
      body: allUsersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error loading fleet: $err')),
        data: (users) {
          // Filter captains who have vehicle data
          final captains = users.where((u) => u.role.toLowerCase() == 'captain').toList();

          final cabsCount = captains.where((c) => (c.vehicleType ?? '').toLowerCase() == 'cab').length;
          final autosCount = captains.where((c) => (c.vehicleType ?? '').toLowerCase() == 'auto').length;
          final bikesCount = captains.where((c) => (c.vehicleType ?? '').toLowerCase() == 'bike').length;
          final parcelsCount = captains.where((c) => (c.vehicleType ?? '').toLowerCase() == 'parcel').length;

          // Apply category filter
          final filtered = captains.where((c) {
            final vType = (c.vehicleType ?? '').toLowerCase();
            if (_selectedCategory != 'all' && vType != _selectedCategory) return false;

            if (_searchQuery.isNotEmpty) {
              final q = _searchQuery.toLowerCase();
              return c.name.toLowerCase().contains(q) ||
                  (c.phone != null && c.phone!.contains(q)) ||
                  c.publicId.toLowerCase().contains(q) ||
                  (c.vehicleNumber != null && c.vehicleNumber!.toLowerCase().contains(q)) ||
                  (c.registrationNumber != null && c.registrationNumber!.toLowerCase().contains(q)) ||
                  vType.contains(q);
            }
            return true;
          }).toList();

          return Column(
            children: [
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
                          hintText: 'Search by captain, plate or vehicle...',
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
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          filled: false,
                          fillColor: Colors.transparent,
                          contentPadding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Category filters
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildCatChip('all', 'All Fleet (${captains.length})'),
                          const SizedBox(width: 8),
                          _buildCatChip('cab', 'Cabs ($cabsCount)'),
                          const SizedBox(width: 8),
                          _buildCatChip('auto', 'Autos ($autosCount)'),
                          const SizedBox(width: 8),
                          _buildCatChip('bike', 'Bikes ($bikesCount)'),
                          const SizedBox(width: 8),
                          _buildCatChip('parcel', 'Parcel ($parcelsCount)'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Fleet List
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.no_crash_outlined, size: 48, color: AdminColors.textSecondary.withValues(alpha: 0.3)),
                            const SizedBox(height: 12),
                            Text(
                              'No vehicles registered',
                              style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: AdminColors.textPrimary),
                            ),
                            Text(
                              'No active vehicles found under this category',
                              style: GoogleFonts.inter(fontSize: 12, color: AdminColors.textSecondary),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: filtered.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 12),
                        itemBuilder: (context, idx) {
                          final c = filtered[idx];
                          final vType = (c.vehicleType ?? '').toLowerCase();
                          final isVerified = c.verificationStatus.toLowerCase() == 'verified';

                          IconData iconData;
                          Color iconColor;
                          String typeName;

                          if (vType == 'cab') {
                            iconData = Icons.local_taxi_rounded;
                            iconColor = const Color(0xFF10B981);
                            typeName = 'Cab / Sedan';
                          } else if (vType == 'auto') {
                            iconData = Icons.electric_rickshaw_rounded;
                            iconColor = const Color(0xFFF59E0B);
                            typeName = 'Auto Rickshaw';
                          } else if (vType == 'bike') {
                            iconData = Icons.two_wheeler_rounded;
                            iconColor = const Color(0xFF38BDF8);
                            typeName = 'Bike Ride';
                          } else if (vType == 'parcel') {
                            iconData = Icons.inventory_2_rounded;
                            iconColor = const Color(0xFF8B5CF6);
                            typeName = 'Parcel Delivery';
                          } else {
                            iconData = Icons.help_outline_rounded;
                            iconColor = AdminColors.textSecondary;
                            typeName = 'Unconfigured Vehicle';
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
                            child: Row(
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: iconColor.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(iconData, color: iconColor, size: 22),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              typeName,
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
                                              color: isVerified
                                                  ? AdminColors.success.withValues(alpha: 0.1)
                                                  : const Color(0xFFF59E0B).withValues(alpha: 0.1),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              isVerified ? 'Active Fleet' : 'Pending Verification',
                                              style: GoogleFonts.inter(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w700,
                                                color: isVerified ? AdminColors.success : const Color(0xFFD97706),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Captain: ${c.name} (${c.phone ?? 'No phone'})',
                                        style: GoogleFonts.inter(fontSize: 12, color: AdminColors.textSecondary),
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Text(
                                            'Reg / ID: ${c.publicId}',
                                            style: GoogleFonts.inter(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w700,
                                              color: AdminColors.primary,
                                            ),
                                          ),
                                          if (c.ratingScore > 0) ...[
                                            const SizedBox(width: 10),
                                            const Icon(Icons.star_rounded, size: 14, color: Color(0xFFF59E0B)),
                                            const SizedBox(width: 2),
                                            Text(
                                              c.ratingScore.toStringAsFixed(1),
                                              style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700),
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
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCatChip(String key, String label) {
    final selected = _selectedCategory == key;
    return GestureDetector(
      onTap: () => setState(() => _selectedCategory = key),
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
