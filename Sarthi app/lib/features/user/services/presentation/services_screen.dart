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
      setState(() {
        _currentPromoIndex = (_currentPromoIndex + 1) % _promoBanners.length;
      });
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
      backgroundColor: const Color(0xFFF8FAFF),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            floating: false,
            pinned: true,
            backgroundColor: const Color(0xFF0B2144),
            elevation: 0,
            automaticallyImplyLeading: false,
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0B2144), Color(0xFF1A3A6B)],
                    ),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const SarthiLogo(size: 14),
                ),
                const SizedBox(width: 8),
                ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [Colors.white, Color(0xFFBFDBFE)],
                  ).createShader(bounds),
                  child: const Text(
                    'Sarthi',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                      color: Colors.white,
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 5,
                        height: 5,
                        decoration: const BoxDecoration(
                          color: Color(0xFF22C55E),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _currentCityState,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: () => context.push('/notifications'),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.25),
                          ),
                        ),
                        child: const Icon(
                          Icons.notifications_none_rounded,
                          size: 16,
                          color: Colors.white,
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
                              color: const Color(0xFF0B2144),
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () {
                    if (widget.onProfileTap != null) {
                      widget.onProfileTap!();
                    } else {
                      context.push('/profile');
                    }
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [Color(0xFF0B2144), Color(0xFF3B82F6)],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const CircleAvatar(
                      radius: 15,
                      backgroundColor: Colors.transparent,
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
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 120),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ride & delivery',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0F172A),
                        letterSpacing: -0.5,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Choose a ride or send a parcel.',
                      style: TextStyle(
                        fontSize: 14,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                
                LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth;
                    // We have exactly 4 services.
                    // To prevent an orphan card, we must use either 2 or 4 columns.
                    final crossAxisCount = width >= 800 ? 4 : 2;
                    
                    // Adjust aspect ratio so cards don't become ridiculously tall on tablets
                    final aspectRatio = width >= 800
                        ? 1.1 // Desktop / Large landscape tablet (4 columns)
                        : width >= 600
                            ? 1.5 // Tablet portrait (2 columns, make them flat and wide)
                            : 0.9; // Phone (2 columns, slightly tall)
                    return GridView.count(
                      padding: EdgeInsets.zero,
                      crossAxisCount: crossAxisCount,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: aspectRatio,
                      children: const [
                        _ServiceCard(
                          title: 'Bike',
                          subtitle: 'Quick solo rides',
                          imagePath: 'assets/images/3d_scooter_hero.jpg',
                          tag: 'Popular',
                        ),
                        _ServiceCard(
                          title: 'Auto',
                          subtitle: 'Everyday city rides',
                          imagePath: 'assets/images/3d_auto_hero.jpg',
                        ),
                        _ServiceCard(
                          title: 'Cab',
                          subtitle: 'Comfort for every trip',
                          imagePath: 'assets/images/3d_car_hero.jpg',
                        ),
                        _ServiceCard(
                          title: 'Parcel',
                          subtitle: 'Send packages',
                          imagePath: 'assets/images/3d_parcel_delivery_new.jpg',
                          imageScale: 1.15,
                        ),
                      ],
                    );
                  },
                ),
                
                const SizedBox(height: 24),
                
                // Rotating promo banner
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
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
                
                const SizedBox(height: 32),
                
                const Text(
                  'Why Sarthi?',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0F172A),
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 20),
                
                const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _FeatureItem(
                      icon: Icons.phone_android_rounded,
                      label: 'Easy booking',
                    ),
                    _FeatureItem(
                      icon: Icons.location_on_rounded,
                      label: 'Live tracking',
                    ),
                    _FeatureItem(
                      icon: Icons.headset_mic_rounded,
                      label: 'Help & support',
                    ),
                  ],
                ),
                const SizedBox(height: 110),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _ServiceCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String imagePath;
  final String? tag;
  final double imageScale;

  const _ServiceCard({
    required this.title,
    required this.subtitle,
    required this.imagePath,
    this.tag,
    this.imageScale = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/search'),
      behavior: HitTestBehavior.opaque,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFF1F5F9)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                children: [
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 12, left: 8, right: 8),
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
                      top: 12,
                      left: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0B2144),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          tag!,
                          style: const TextStyle(
                            fontSize: 7.0,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 12, 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                            color: Color(0xFF0F172A),
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF64748B),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0B2144).withValues(alpha: 0.06),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.arrow_forward_rounded,
                      color: Color(0xFF0B2144),
                      size: 16,
                    ),
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
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: const Color(0xFF0B2144).withValues(alpha: 0.06),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: const Color(0xFF0B2144), size: 24),
          ),
          const SizedBox(height: 12),
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
