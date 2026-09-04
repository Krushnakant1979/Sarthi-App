import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/design/tokens.dart';

class RatingScreen extends StatelessWidget {
  const RatingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.black,
            size: 20,
          ),
          onPressed: () => context.pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        children: [
          // Graphic Placeholder
          Container(
            height: 140,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.blue.shade50, Colors.white],
              ),
            ),
            child: Center(
              child: Icon(
                Icons.star_rounded,
                size: 80,
                color: context.colors.rapidoYellow,
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Section 1
          const Text(
            'How We Calculate Your Rating',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E3A8A), // Dark blue
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Your Sarthi App rating is an average based on your past trips, measured out of 5 stars. All ratings are completely anonymous—neither you nor your Captain will ever see the individual rating left for a specific ride.',
            style: TextStyle(fontSize: 13, color: Colors.black87, height: 1.5),
          ),
          const SizedBox(height: 32),

          // Section 2
          const Text(
            'Building a 5-Star Community',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E3A8A),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            "At Sarthi App, mutual respect is key. Both riders and Captains rate each other from 1 to 5 stars. Here's how you can ensure a great experience for everyone on the road:",
            style: TextStyle(fontSize: 13, color: Colors.black87, height: 1.5),
          ),
          const SizedBox(height: 32),

          // List Items
          _buildRatingItem(
            icon: Icons.chat_bubble_outline_rounded,
            iconBgColor: Colors.blue.shade100,
            iconColor: Colors.blue.shade800,
            title: 'Respect Your Captain',
            description:
                "Understanding the effort that goes into every ride helps build a stronger community. Treating your Captain's time and vehicle with respect ensures a premium experience.",
          ),
          const SizedBox(height: 24),

          _buildRatingItem(
            icon: Icons.watch_later_outlined,
            iconBgColor: Colors.teal.shade100,
            iconColor: Colors.teal.shade800,
            title: 'Punctuality Matters',
            description:
                "Double-check your pickup location before booking and be ready when your Captain arrives. Being on time helps everyone reach their destination smoothly.",
          ),
          const SizedBox(height: 24),

          _buildRatingItem(
            icon: Icons.security_rounded,
            iconBgColor: Colors.purple.shade100,
            iconColor: Colors.purple.shade800,
            title: 'Safety First',
            description:
                "Always prioritize safety. Both you and your Captain share the responsibility of following traffic laws to ensure a secure and comfortable journey.",
          ),
          const SizedBox(height: 24),

          _buildRatingItem(
            icon: Icons.handshake_outlined,
            iconBgColor: Colors.green.shade100,
            iconColor: Colors.green.shade800,
            title: 'Common Courtesy',
            description:
                "A simple 'Hello' or 'Thank you' can brighten someone's day. Treat your Captain with the same politeness you expect in return.",
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildRatingItem({
    required IconData icon,
    required Color iconBgColor,
    required Color iconColor,
    required String title,
    required String description,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: iconBgColor,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          description,
          style: const TextStyle(
            fontSize: 13,
            color: Colors.black54,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}
