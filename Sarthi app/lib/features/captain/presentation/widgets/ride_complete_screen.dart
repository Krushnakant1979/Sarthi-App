import 'package:flutter/material.dart';

/// A full-screen overlay shown to the captain after they complete a ride.
class RideCompleteScreen extends StatefulWidget {
  final double fare;
  final String pickupAddress;
  final String dropoffAddress;
  final int distanceMeters;

  const RideCompleteScreen({
    super.key,
    required this.fare,
    required this.pickupAddress,
    required this.dropoffAddress,
    required this.distanceMeters,
  });

  @override
  State<RideCompleteScreen> createState() => _RideCompleteScreenState();
}

class _RideCompleteScreenState extends State<RideCompleteScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<double> _scaleAnim;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _scaleAnim = CurvedAnimation(parent: _animController, curve: Curves.elasticOut);
    _fadeAnim = CurvedAnimation(
      parent: _animController,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: const Interval(0.2, 1.0, curve: Curves.easeOut),
    ));
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final distanceKm = (widget.distanceMeters / 1000.0).toStringAsFixed(1);
    final fareStr = 'Rs.';

    return Scaffold(
      backgroundColor: const Color(0xFF0A0E21),
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: SlideTransition(
            position: _slideAnim,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                children: [
                  const Spacer(flex: 1),
                  // Success Badge
                  ScaleTransition(
                    scale: _scaleAnim,
                    child: Container(
                      width: 110,
                      height: 110,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: [Color(0xFF22C55E), Color(0xFF16A34A)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Color.fromRGBO(34, 197, 94, 0.4),
                            blurRadius: 30,
                            spreadRadius: 4,
                          ),
                        ],
                      ),
                      child: const Icon(Icons.check_rounded, color: Colors.white, size: 60),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Ride Completed!',
                    style: TextStyle(
                      color: Colors.white, fontSize: 30, fontWeight: FontWeight.w800, letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Great job! Your earnings have been credited.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xFF94A3B8), fontSize: 15),
                  ),
                  const SizedBox(height: 36),
                  // Earnings Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Color.fromRGBO(255,255,255,0.06)),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'AMOUNT EARNED',
                          style: TextStyle(
                            color: Color(0xFF64748B), fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          fareStr,
                          style: const TextStyle(
                            color: Color(0xFF4ADE80), fontSize: 54, fontWeight: FontWeight.w900, letterSpacing: -2,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                          decoration: BoxDecoration(
                            color: Color.fromRGBO(34,197,94,0.15),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.account_balance_wallet_outlined, color: Color(0xFF4ADE80), size: 14),
                              SizedBox(width: 5),
                              Text('Cash payment', style: TextStyle(color: Color(0xFF4ADE80), fontSize: 13, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Distance stat
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Color.fromRGBO(255,255,255,0.06)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Color.fromRGBO(96,165,250,0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.route_rounded, color: Color(0xFF60A5FA), size: 18),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('DISTANCE', style: TextStyle(color: Color(0xFF64748B), fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
                            const SizedBox(height: 2),
                            Text(' km', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Trip Route Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Color.fromRGBO(255,255,255,0.06)),
                    ),
                    child: Column(
                      children: [
                        _routeRow(icon: Icons.radio_button_checked, color: const Color(0xFF22C55E), label: 'PICKUP', address: widget.pickupAddress),
                        Padding(
                          padding: const EdgeInsets.only(left: 11),
                          child: Column(
                            children: List.generate(3, (i) => Container(
                              width: 2, height: 6,
                              margin: const EdgeInsets.symmetric(vertical: 2),
                              color: const Color(0xFF334155),
                            )),
                          ),
                        ),
                        _routeRow(icon: Icons.location_on, color: const Color(0xFFEF4444), label: 'DROP-OFF', address: widget.dropoffAddress),
                      ],
                    ),
                  ),
                  const Spacer(flex: 2),
                  // CTA Button
                  SizedBox(
                    width: double.infinity,
                    height: 58,
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF22C55E),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('Find next ride', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, letterSpacing: 0.3)),
                          SizedBox(width: 8),
                          Icon(Icons.arrow_forward_rounded, size: 20),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _routeRow({required IconData icon, required Color color, required String label, required String address}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: Color(0xFF64748B), fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.8)),
              const SizedBox(height: 3),
              Text(address, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500, height: 1.4), maxLines: 2, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ],
    );
  }
}
