import 'package:flutter/material.dart';

class LegalScreen extends StatelessWidget {
  const LegalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Legal & Privacy')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Privacy Policy',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Last updated: Today\n\n'
              'Welcome to Sarthi App! We prioritize your privacy and safety.\n\n'
              '1. Location Data\n'
              'We collect and use your location data to provide ride-hailing services. '
              'This allows us to match you with nearby Captains and provide accurate navigation. '
              'Your location is only tracked while the app is actively in use or during an ongoing ride.\n\n'
              '2. Personal Information\n'
              'We collect your name, email, and phone number to create your profile and facilitate communication with Captains.\n\n'
              '3. Data Security\n'
              'Your data is securely stored using industry-standard encryption. We do not sell your personal data to third parties.\n\n'
              '4. Captain Background Checks\n'
              'All Captains on our platform undergo a verification process to ensure platform safety.\n\n'
              'For full details or to request account deletion, please contact our support team.',
            ),
            const SizedBox(height: 24),
            Text(
              'Terms of Service',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'By using Sarthi App, you agree to abide by our community guidelines. '
              'You agree to pay the final calculated fare upon ride completion. '
              'Sarthi App reserves the right to suspend accounts that violate safety guidelines or engage in fraudulent activity.',
            ),
          ],
        ),
      ),
    );
  }
}
