import 'package:flutter/material.dart';
import '../tabs/pricing_tab.dart';
import '../admin_design.dart';

class PricingScreen extends StatelessWidget {
  const PricingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        title: Text('Pricing & Surge Fares', style: TextStyle(color: context.colors.text, fontWeight: FontWeight.w800, fontSize: 16)),
        backgroundColor: context.colors.surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        iconTheme: IconThemeData(color: context.colors.text),
      ),
      body: const PricingTab(),
    );
  }
}
