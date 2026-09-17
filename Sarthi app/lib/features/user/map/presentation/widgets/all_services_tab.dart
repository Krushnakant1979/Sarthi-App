import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AllServicesTab extends StatelessWidget {
  const AllServicesTab({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 48, 16, 120),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Services',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 32),
            Wrap(
              spacing: 24,
              runSpacing: 24,
              children: [
                _buildNewServiceItem(context, 'assets/images/auto.png', 'Auto'),
                _buildNewServiceItem(context, 'assets/images/cab.png', 'Cab'),
                _buildNewServiceItem(context, 'assets/images/bike.png', 'Bike'),
              ],
            ),
            const SizedBox(height: 40),
            Expanded(
              child: Align(
                alignment: Alignment.topCenter,
                child: Image.asset(
                  'assets/images/Sarthi 2.png',
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNewServiceItem(BuildContext context, String imagePath, String label) {
    return GestureDetector(
      onTap: () => context.push('/search'),
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Center(
              child: Image.asset(
                imagePath,
                width: 50,
                height: 50,
                fit: BoxFit.contain,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
          ),
        ],
      ),
    );
  }
}
