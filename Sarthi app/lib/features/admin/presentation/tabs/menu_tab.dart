import 'package:flutter/material.dart';
import '../admin_design.dart';
import '../screens/support_screen.dart';
import '../screens/analytics_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/pricing_screen.dart';
import '../screens/offers_screen.dart';

class MenuTab extends StatelessWidget {
  const MenuTab({super.key});

  @override
  Widget build(BuildContext context) {
    final items = [
      (title: 'Analytics & Heatmaps', icon: Icons.analytics_rounded, color: context.colors.adminInfo, page: const AnalyticsScreen(), subtitle: 'Export reports & view demand'),
      (title: 'Pricing & Surge', icon: Icons.currency_rupee_rounded, color: context.colors.adminAccent, page: const PricingScreen(), subtitle: 'Manage base fares & multipliers'),
      (title: 'Offers & Promos', icon: Icons.local_offer_rounded, color: context.colors.error, page: const OffersScreen(), subtitle: 'Create discounts & coupons'),
      (title: 'Settings & Zones', icon: Icons.settings_rounded, color: context.colors.textMuted, page: const SettingsScreen(), subtitle: 'Geofencing & platform config'),
      (title: 'Support & Complaints', icon: Icons.support_agent_rounded, color: context.colors.warning, page: const SupportScreen(), subtitle: 'Handle complaints & disputes'),
    ];

    return ListView.separated(
      padding: const EdgeInsets.only(left: 20, right: 20, top: 20, bottom: 100),
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final item = items[index];
        return InkWell(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => item.page)),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: context.colors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: context.colors.cardBorder),
            ),
            child: Row(children: [
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                  color: item.color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: item.color.withValues(alpha: 0.3)),
                ),
                child: Icon(item.icon, color: item.color, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.title, style: TextStyle(color: context.colors.text, fontWeight: FontWeight.w700, fontSize: 16)),
                    const SizedBox(height: 4),
                    Text(item.subtitle, style: TextStyle(color: context.colors.textMuted, fontSize: 13)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: context.colors.textMuted),
            ]),
          ),
        );
      },
    );
  }
}
