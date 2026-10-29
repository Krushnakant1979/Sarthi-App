import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../map/presentation/widgets/sarthi_logo.dart';
import '../../../../core/utils/location_service.dart';
import '../../map/data/ola_maps_repository.dart';

class ServicesScreen extends StatefulWidget {
  final VoidCallback? onProfileTap;
  const ServicesScreen({super.key, this.onProfileTap});

  @override
  State<ServicesScreen> createState() => _ServicesScreenState();
}

class _ServicesScreenState extends State<ServicesScreen> {
  static const _promoBanners = [
    'assets/images/ui_banner_safe_parcel.jpg',
    'assets/images/ui_banner_safe_ride.jpg',
    'assets/images/ui_banner_sarthi_app.jpg',
  ];

  int _currentPromoIndex = 0;
  Timer? _promoTimer;
  String _currentCityState = 'Detecting...';
  final LocationService _locationService = LocationService();

  @override
  void initState() {
    super.initState();
    _initLocation();

    _promoTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) {
        setState(() {
          _currentPromoIndex = (_currentPromoIndex + 1) % _promoBanners.length;
        });
      }
    });
  }

  @override
  void dispose() {
    _promoTimer?.cancel();
    super.dispose();
  }

  Future<void> _initLocation() async {
    final hasPermission = await _locationService.requestPermission();
    if (!hasPermission) return;

    // Quick fallback
    final lastPos = await _locationService.getLastKnownPosition();
    if (lastPos != null && mounted) {
      final cityState = await OlaMapsRepository().getCityAndState(
        lastPos.latitude,
        lastPos.longitude,
      );
      if (mounted) setState(() => _currentCityState = cityState);
    }

    // Accurate fetch
    final pos = await _locationService.getCurrentPosition();
    if (pos != null && mounted) {
      final cityState = await OlaMapsRepository().getCityAndState(
        pos.latitude,
        pos.longitude,
      );
      if (mounted) {
        setState(() {
          _currentCityState = cityState;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: CustomScrollView(
        slivers: [
          // ── App Bar ──────────────────────────────────────────────
          SliverAppBar(
            floating: false,
            pinned: true,
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            automaticallyImplyLeading: false,
            titleSpacing: 16,
            toolbarHeight: 60,
            title: Row(
              children: [
                // 1. Sarthi Logo
                const SarthiLogo(
                  size: 28,
                  showText: true,
                ),
                const Spacer(),

                // 2. Location Pill
                GestureDetector(
                  onTap: _initLocation,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFFE2E8F0),
                        width: 1.0,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: Color(0xFF22C55E),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 110),
                          child: Text(
                            _currentCityState,
                            style: const TextStyle(
                              color: Color(0xFF0F172A),
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 3),
                        const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          size: 14,
                          color: Color(0xFF64748B),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // 3. Notification Bell
                GestureDetector(
                  onTap: () => context.push('/notifications'),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFFE2E8F0),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.03),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.notifications_none_rounded,
                          size: 18,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      Positioned(
                        top: 2,
                        right: 2,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: const Color(0xFFEF4444),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white,
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // 4. Profile Avatar
                GestureDetector(
                  onTap: () {
                    if (widget.onProfileTap != null) {
                      widget.onProfileTap!();
                    } else {
                      context.push('/profile');
                    }
                  },
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [Color(0xFF0B2144), Color(0xFF1A3A6B)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0B2144).withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.person_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Scrollable Body Content ──────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 120),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // ── Header Title & Subtitle ────────────────────────
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ride & Delivery',
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0F172A),
                        letterSpacing: -0.6,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Choose your ride or send a package instantly',
                      style: TextStyle(
                        fontSize: 14,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // ── 2x2 Services Grid ──────────────────────────────
                LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth;
                    final crossAxisCount = width >= 800 ? 4 : 2;
                    final aspectRatio = width >= 800
                        ? 0.95
                        : width >= 600
                            ? 1.25
                            : 0.80;

                    return GridView.count(
                      padding: EdgeInsets.zero,
                      crossAxisCount: crossAxisCount,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 14,
                      crossAxisSpacing: 14,
                      childAspectRatio: aspectRatio,
                      children: [
                        _ServiceCard(
                          title: 'Bike',
                          subtitle: 'Fast solo rides',
                          imagePath: 'assets/images/3d_scooter_hero.jpg',
                          tag: 'Popular',
                          eta: 'ETA 2 mins',
                          onTap: () => context.push('/search'),
                        ),
                        _ServiceCard(
                          title: 'Auto',
                          subtitle: 'Everyday city travel',
                          imagePath: 'assets/images/3d_auto_hero.jpg',
                          eta: 'ETA 3 mins',
                          onTap: () => context.push('/search'),
                        ),
                        _ServiceCard(
                          title: 'Cab',
                          subtitle: 'Premium AC comfort',
                          imagePath: 'assets/images/3d_car_hero.jpg',
                          eta: 'ETA 4 mins',
                          onTap: () => context.push('/search'),
                        ),
                        _ServiceCard(
                          title: 'Parcel',
                          subtitle: 'Fast doorstep courier',
                          imagePath: 'assets/images/3d_parcel_delivery_new.jpg',
                          eta: 'Under 30m',
                          imageScale: 1.15,
                          onTap: () => context.push('/search'),
                        ),
                      ],
                    );
                  },
                ),

                const SizedBox(height: 24),

                // ── Rotating Promo Banner ──────────────────────────
                GestureDetector(
                  onTap: () => context.push('/search'),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0B2144).withValues(alpha: 0.10),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 800),
                        child: Image.asset(
                          _promoBanners[_currentPromoIndex],
                          key: ValueKey<int>(_currentPromoIndex),
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                // ── Why Sarthi? Section ────────────────────────────
                const Text(
                  'Why Sarthi?',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0F172A),
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 16),

                const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _FeatureItem(
                      icon: Icons.phone_iphone_rounded,
                      label: 'Easy booking',
                    ),
                    _FeatureItem(
                      icon: Icons.near_me_rounded,
                      label: 'Live tracking',
                    ),
                    _FeatureItem(
                      icon: Icons.headset_mic_rounded,
                      label: 'Help & support',
                    ),
                  ],
                ),
                const SizedBox(height: 100),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Tactile 3D Service Card ─────────────────────────────────────────
class _ServiceCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String imagePath;
  final String eta;
  final VoidCallback onTap;
  final String? tag;
  final double imageScale;

  const _ServiceCard({
    required this.title,
    required this.subtitle,
    required this.imagePath,
    required this.eta,
    required this.onTap,
    this.tag,
    this.imageScale = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: const Color(0xFFE2E8F0),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0B2144).withValues(alpha: 0.04),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Image Area with optional tag
            Expanded(
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 10, left: 8, right: 8),
                      child: Transform.scale(
                        scale: imageScale,
                        child: Image.asset(
                          imagePath,
                          fit: BoxFit.contain,
                          errorBuilder: (c, e, s) => const Icon(
                            Icons.directions_car_rounded,
                            color: Colors.black12,
                            size: 48,
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (tag != null)
                    Positioned(
                      top: 10,
                      left: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF3B82F6), Color(0xFF2563EB)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(6),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF2563EB).withValues(alpha: 0.20),
                              blurRadius: 4,
                              offset: const Offset(0, 1.5),
                            ),
                          ],
                        ),
                        child: Text(
                          tag!,
                          style: const TextStyle(
                            fontSize: 7.0,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Content Area: Title, Subtitle, ETA pill + Action arrow
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 12, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 17,
                      color: Color(0xFF0F172A),
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: Color(0xFF64748B),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: const Color(0xFFE2E8F0).withValues(alpha: 0.6),
                          ),
                        ),
                        child: Text(
                          eta,
                          style: const TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ),
                      Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF3B82F6), Color(0xFF2563EB)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF2563EB).withValues(alpha: 0.35),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.arrow_forward_rounded,
                          color: Colors.white,
                          size: 15,
                        ),
                      ),
                    ],
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

// ── Why Sarthi? Feature Item ────────────────────────────────────────
class _FeatureItem extends StatelessWidget {
  final IconData icon;
  final String label;

  const _FeatureItem({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFEFF6FF), Color(0xFFDBEAFE)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFFBFDBFE).withValues(alpha: 0.5),
              ),
            ),
            child: Icon(icon, color: const Color(0xFF2563EB), size: 24),
          ),
          const SizedBox(height: 10),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F172A),
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}
