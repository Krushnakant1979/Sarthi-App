import 'package:flutter/material.dart';
import 'drag_handle.dart';

class CompletedBottomSheet extends StatelessWidget {
  final dynamic fare;
  final String paymentMethod;
  final String? captainId;
  final VoidCallback onDone;
  final void Function(String)? onRateCaptain;

  const CompletedBottomSheet({
    super.key,
    required this.fare,
    required this.paymentMethod,
    required this.captainId,
    required this.onDone,
    required this.onRateCaptain,
  });

  @override
  Widget build(BuildContext context) {
    final safeBottom = MediaQuery.of(context).padding.bottom;
    final bottomPadding = 64.0 + safeBottom + 24.0; // nav bar height + safe area + extra padding

    return Container(
      padding: EdgeInsets.fromLTRB(20, 0, 20, bottomPadding),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const DragHandle(),
          const SizedBox(height: 12), // Reduced gap
          
          // 1. Checkmark Circle
          Container(
            width: 56, // Reduced size
            height: 56,
            decoration: const BoxDecoration(
              color: Color(0xFFD1FADD),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  color: Color(0xFF22C55E),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_rounded, color: Colors.white, size: 28),
              ),
            ),
          ),
          const SizedBox(height: 12),
          
          // 2. Titles
          const Text(
            'Ride completed!',
            style: TextStyle(
              fontSize: 22, // Reduced font
              fontWeight: FontWeight.w900,
              color: Color(0xFF0F172A),
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Thanks for riding with Sarthi.',
            style: TextStyle(
              fontSize: 13, // Reduced font
              fontWeight: FontWeight.w500,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 16),
          
          // 3. Card for TOTAL PAID
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16), // Reduced padding
            decoration: BoxDecoration(
              color: const Color(0xFFF0F6FF),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                const Text(
                  'TOTAL PAID',
                  style: TextStyle(
                    fontSize: 11, // Reduced font
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF94A3B8),
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '₹${fare ?? 0}',
                  style: const TextStyle(
                    fontSize: 38, // Reduced font
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0F172A),
                    letterSpacing: -1.0,
                  ),
                ),
                const SizedBox(height: 12), // Reduced gap
                // Divider
                Container(
                  height: 1,
                  color: const Color(0xFFE2E8F0),
                ),
                const SizedBox(height: 12), // Reduced gap
                
                // Status & Payment row
                Row(
                  children: [
                    const Expanded(
                      child: Column(
                        children: [
                          Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 22),
                          SizedBox(height: 6),
                          Text(
                            'Status',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF64748B),
                            ),
                          ),
                          Text(
                            'Completed',
                            style: TextStyle(
                              fontSize: 14, // Reduced font
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF16A34A),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 44, // Reduced height
                      color: const Color(0xFFE2E8F0),
                    ),
                    Expanded(
                      child: Column(
                        children: [
                          const Icon(Icons.payments_outlined, color: Color(0xFF2563EB), size: 22),
                          const SizedBox(height: 6),
                          const Text(
                            'Payment',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF64748B),
                            ),
                          ),
                          Text(
                            paymentMethod,
                            style: const TextStyle(
                              fontSize: 14, // Reduced font
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16), // Reduced gap
          
          // 4. Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onDone,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF0F172A),
                    side: const BorderSide(color: Color(0xFF0F172A)),
                    padding: const EdgeInsets.symmetric(vertical: 14), // Reduced padding
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 14, // Reduced font
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  child: const Text('Done'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    if (captainId != null && onRateCaptain != null) {
                      onRateCaptain!(captainId!);
                    } else {
                      onDone();
                    }
                  },
                  icon: const Icon(Icons.star_border_rounded, color: Colors.white, size: 20),
                  label: const Text('Rate captain'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF005AFE),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14), // Reduced padding
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 14, // Reduced font
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
