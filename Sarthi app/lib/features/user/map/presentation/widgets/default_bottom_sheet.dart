import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../../core/design/tokens.dart';
import '../../../../shared/auth/presentation/auth_providers.dart';
import 'drag_handle.dart';
class DefaultBottomSheet extends ConsumerStatefulWidget {
  final Function(Map<String, dynamic> destination) onDestinationSelected;
  final VoidCallback onLocationPermissionRequested;
  final bool hasLocationPermission;
  final bool isLoadingLocation;

  const DefaultBottomSheet({
    super.key,
    required this.onDestinationSelected,
    required this.onLocationPermissionRequested,
    required this.hasLocationPermission,
    required this.isLoadingLocation,
  });

  @override
  ConsumerState<DefaultBottomSheet> createState() => _DefaultBottomSheetState();
}

class _DefaultBottomSheetState extends ConsumerState<DefaultBottomSheet> {
  int _currentHeroIndex = 0;
  Timer? _heroImageTimer;
  final List<String> _heroImages = [
    'assets/images/3d_scooter_hero.jpg',
    'assets/images/3d_car_hero.jpg',
    'assets/images/3d_auto_hero.jpg',
  ];

  @override
  void initState() {
    super.initState();
    _heroImageTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (mounted) {
        setState(() {
          _currentHeroIndex = (_currentHeroIndex + 1) % _heroImages.length;
        });
      }
    });
  }

  @override
  void dispose() {
    _heroImageTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(currentUserProvider);
    final homeAddress = userAsync.value?.homeAddress;
    final workAddress = userAsync.value?.workAddress;
    final userName = userAsync.value?.name.split(' ').first ?? 'User';

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag handle — centered
              const Center(child: DragHandle()),
              const SizedBox(height: 16),

              Text(
                'Good evening, $userName',
                style: const TextStyle(
                  fontSize: 8,
                  color: Color(0xFF6B7280),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Where are you going?',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: context.colors.primary,
                ),
              ),
              const SizedBox(height: 12),

              // ── 3D Hero Banner ───────────────────────────────────
              GestureDetector(
                onTap: () async {
                  final result = await context.push('/search');
                  if (result != null && result is Map<String, dynamic>) {
                    if (!context.mounted) return;
                    widget.onDestinationSelected(result);
                  }
                },
                child: Container(
                  height: 110,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0B2144), Color(0xFF1A3A6B)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0B2144).withValues(alpha: 0.45),
                        blurRadius: 24,
                        spreadRadius: 2,
                        offset: const Offset(0, 8),
                      ),
                      BoxShadow(
                        color: const Color(0xFF1A3A6B).withValues(alpha: 0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // Background decorative circles
                    Positioned(
                      right: -10,
                      top: -20,
                      child: Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.04),
                        ),
                      ),
                    ),
                    Positioned(
                      right: 60,
                      bottom: -30,
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.04),
                        ),
                      ),
                    ),
                    // Text content
                    Positioned(
                      left: 16,
                      top: 16,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Live badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFBBF24),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 5,
                                  height: 5,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF0B2144),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Text(
                                  'Live drivers nearby',
                                  style: TextStyle(
                                    color: Color(0xFF0B2144),
                                    fontSize: 8,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Book your ride',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Fast. Safe. Affordable.',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.65),
                              fontSize: 9,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // 3D scooter image — positioned to overflow top
                    Positioned(
                      right: 0,
                      top: -12,
                      bottom: -4,
                      child: ClipRRect(
                        borderRadius: const BorderRadius.only(
                          topRight: Radius.circular(18),
                          bottomRight: Radius.circular(18),
                        ),
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 600),
                          transitionBuilder:
                              (Widget child, Animation<double> animation) {
                                return FadeTransition(
                                  opacity: animation,
                                  child: child,
                                );
                              },
                          child: Image.asset(
                            _heroImages[_currentHeroIndex],
                            key: ValueKey<int>(_currentHeroIndex),
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) =>
                                const Icon(
                                  Icons.directions_car_rounded,
                                  color: Colors.white54,
                                  size: 80,
                                ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

              const SizedBox(height: 16),

              // Search destination bar inside bottom sheet
              GestureDetector(
                onTap: () async {
                  final result = await context.push('/search');
                  if (result != null && result is Map<String, dynamic>) {
                    if (!context.mounted) return;
                    widget.onDestinationSelected(result);
                  }
                },
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2563EB).withValues(alpha: 0.07),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xFF3B82F6).withValues(alpha: 0.5),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(
                              0xFF2563EB,
                            ).withValues(alpha: 0.12),
                            blurRadius: 14,
                            spreadRadius: 1,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: const Color(
                                0xFF2563EB,
                              ).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.route_outlined,
                              size: 18,
                              color: Color(0xFF2563EB),
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'Search destination',
                              style: TextStyle(
                                fontSize: 11,
                                color: Color(0xFF6B7280),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          Container(
                            width: 1,
                            height: 22,
                            color: const Color(
                              0xFF3B82F6,
                            ).withValues(alpha: 0.25),
                            margin: const EdgeInsets.symmetric(horizontal: 12),
                          ),
                          const Icon(
                            Icons.mic_none_rounded,
                            color: Color(0xFF3B82F6),
                            size: 22,
                          ),
                        ],
                      ),
                    ),
                    // Floating label
                    Positioned(
                      top: -9,
                      left: 20,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'Where to?',
                          style: TextStyle(
                            fontSize: 9,
                            color: Color(0xFF3B82F6),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Pickup Location Row
              GestureDetector(
                onTap: () async {
                  final result = await context.push('/search');
                  if (result != null && result is Map<String, dynamic>) {
                    if (!context.mounted) return;
                    widget.onDestinationSelected(result);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Color(0xFF2563EB),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Pickup: ',
                        style: TextStyle(fontSize: 9, color: Color(0xFF6B7280)),
                      ),
                      const Expanded(
                        child: Text(
                          'Current location',
                          style: TextStyle(
                            fontSize: 9,
                            color: Color(0xFF2563EB),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const Icon(
                        Icons.edit_outlined,
                        size: 16,
                        color: Color(0xFF6B7280),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Quick destinations — premium header row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 3,
                        height: 14,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF2563EB), Color(0xFF60A5FA)],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Quick destinations',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                          letterSpacing: -0.2,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'Saved places',
                      style: TextStyle(
                        fontSize: 9,
                        color: Color(0xFF2563EB),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Home & Work cards
              Row(
                children: [
                  Expanded(
                    child: _buildQuickRideCard(
                      context,
                      Icons.home_rounded,
                      'Home',
                      (homeAddress != null && homeAddress.containsKey('destination') && homeAddress['destination'] != null) ? (homeAddress['destination']['description'] ?? 'Add home address') : (homeAddress?['description'] ?? 'Add home address'),
                      onTap: () {
                        if (homeAddress != null) {
                          widget.onDestinationSelected(homeAddress);
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Please add a Home Address in your profile first.',
                              ),
                            ),
                          );
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildQuickRideCard(
                      context,
                      Icons.work_rounded,
                      'Work',
                      (workAddress != null && workAddress.containsKey('destination') && workAddress['destination'] != null) ? (workAddress['destination']['description'] ?? 'Add work address') : (workAddress?['description'] ?? 'Add work address'),
                      onTap: () {
                        if (workAddress != null) {
                          widget.onDestinationSelected(workAddress);
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Please add a Work Address in your profile first.',
                              ),
                            ),
                          );
                        }
                      },
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Vehicle carousel (Static Mock)
              Row(
                children: [
                  Expanded(
                    child: _buildMockVehicleCard(
                      context,
                      'Bike',
                      '3 min away',
                      Icons.motorcycle_rounded,
                      false,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildMockVehicleCard(
                      context,
                      'Auto',
                      '2 min away',
                      Icons.electric_rickshaw_rounded,
                      false,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildMockVehicleCard(
                      context,
                      'Cab',
                      '4 min away',
                      Icons.directions_car_rounded,
                      false,
                    ),
                  ),
                ],
              ),

              // Location permission banner
              if (!widget.hasLocationPermission && !widget.isLoadingLocation) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: context.colors.error.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: context.colors.error.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.location_off_rounded,
                        color: context.colors.error,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Location permission required.',
                          style: TextStyle(
                            color: context.colors.error,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: widget.onLocationPermissionRequested,
                        child: const Text('Grant'),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 36),
            ],
          ),
        ),

        Image.asset(
          'assets/images/promo_banner.png',
          width: double.infinity,
          fit: BoxFit.cover,
        ),

        SizedBox(
          height: 85 + MediaQuery.of(context).padding.bottom,
        ),
      ],
    );
  }

  Widget _buildMockVehicleCard(
    BuildContext context,
    String title,
    String eta,
    IconData icon,
    bool isSelected,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected ? context.colors.primary : const Color(0xFFE5E7EB),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 20, color: context.colors.primary),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 10,
                    color: context.colors.primary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        eta,
                        style: const TextStyle(
                          fontSize: 7,
                          color: Color(0xFF6B7280),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 2),
                    Container(
                      width: 4,
                      height: 4,
                      decoration: const BoxDecoration(
                        color: Color(0xFF16A34A),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickRideCard(
    BuildContext context,
    IconData icon,
    String title,
    String subtitle, {
    required VoidCallback onTap,
  }) {
    final isHome = title.toLowerCase() == 'home';
    final gradientColors = isHome
        ? [const Color(0xFF1D4ED8), const Color(0xFF3B82F6)]
        : [const Color(0xFF374151), const Color(0xFF6B7280)];

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isHome
                ? const Color(0xFF2563EB).withValues(alpha: 0.2)
                : const Color(0xFFE5E7EB),
          ),
          boxShadow: [
            BoxShadow(
              color: isHome
                  ? const Color(0xFF2563EB).withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            // Gradient icon container
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: gradientColors,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: gradientColors[0].withValues(alpha: 0.3),
                    blurRadius: 6,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Icon(icon, size: 18, color: Colors.white),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 8,
                      color: Color(0xFF9CA3AF),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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


