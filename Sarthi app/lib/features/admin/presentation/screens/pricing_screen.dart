import 'package:flutter/material.dart';
import '../tabs/pricing_tab.dart';
import '../admin_design.dart';
import 'package:google_fonts/google_fonts.dart';

class PricingScreen extends StatelessWidget {
  const PricingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        title: Text(
          'Pricing & Surge Fares',
          style: GoogleFonts.inter(
            color: context.colors.text,
            fontWeight: FontWeight.w800,
            fontSize: 15,
          ),
        ),
        backgroundColor: context.colors.surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        iconTheme: IconThemeData(color: context.colors.text),
        actions: [
          IconButton(
            icon: Icon(
              Icons.help_outline_rounded,
              color: context.colors.textMuted,
            ),
            tooltip: 'How fare is calculated',
            onPressed: () {
              showDialog(
                context: context,
                builder: (c) => AlertDialog(
                  backgroundColor: context.colors.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  title: Text(
                    'Fare Calculation',
                    style: GoogleFonts.inter(
                      color: context.colors.text,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  content: Text(
                    'Estimated Fare = (Base Fare + (Distance × Rate per km) + (Duration × Rate per minute)) × Surge Multiplier',
                    style: GoogleFonts.inter(color: context.colors.textMuted),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(c),
                      child: Text(
                        'Got it',
                        style: GoogleFonts.inter(
                          color: context.colors.adminAccent,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          SizedBox(width: 8),
        ],
      ),
      body: const PricingTab(),
    );
  }
}
