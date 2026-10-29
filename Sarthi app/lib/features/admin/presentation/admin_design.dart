import 'package:flutter/material.dart';
export '../../../core/design/tokens.dart';

class AdminColors {
  static const primary = Color(0xFF2563EB);
  static const secondary = Color(0xFF2563EB);
  static const accent = Color(0xFFFFC107);
  static const success = Color(0xFF16A36A);
  static const background = Color(0xFFF4F7FB);
  static const card = Color(0xFFFFFFFF);
  static const textPrimary = Color(0xFF0F172A);
  static const textSecondary = Color(0xFF6B778C);
  static const border = Color(0xFFE2E8F0);
  static const error = Color(0xFFDC2626);
  static const warning = Color(0xFFF59E0B);
}

// ─── Responsive Layout Utilities ──────────────────────────────────────────────
class AdminResponsive {
  static const double compactMax = 650.0;    // Standard phones, folded phones
  static const double mediumMax = 950.0;     // Foldables unfolded, small tablets
  static const double expandedMax = 1200.0;  // Large tablets, desktop

  static double screenWidth(BuildContext context) =>
      MediaQuery.sizeOf(context).width;

  static double screenHeight(BuildContext context) =>
      MediaQuery.sizeOf(context).height;

  static bool isCompact(BuildContext context) =>
      screenWidth(context) < compactMax;

  static bool isMedium(BuildContext context) {
    final w = screenWidth(context);
    return w >= compactMax && w < mediumMax;
  }

  static bool isExpanded(BuildContext context) =>
      screenWidth(context) >= mediumMax;

  static bool isWide(BuildContext context) =>
      screenWidth(context) >= compactMax;

  static bool isNarrow(BuildContext context) =>
      screenWidth(context) < 360.0; // Folded phone cover screens

  static T value<T>(
    BuildContext context, {
    required T compact,
    T? medium,
    T? expanded,
  }) {
    final w = screenWidth(context);
    if (w >= mediumMax && expanded != null) return expanded;
    if (w >= compactMax && medium != null) return medium;
    return compact;
  }

  static int columns(BuildContext context, {int compact = 1, int medium = 2, int expanded = 3}) {
    final w = screenWidth(context);
    if (w < compactMax) return compact;
    if (w < mediumMax) return medium;
    return expanded;
  }

  static const double maxContentWidth = 1200.0;
  static const double maxSheetWidth = 560.0;
  static const double maxDialogWidth = 500.0;
}

class ResponsiveCenter extends StatelessWidget {
  const ResponsiveCenter({
    super.key,
    required this.child,
    this.maxWidth = AdminResponsive.maxContentWidth,
    this.padding = EdgeInsets.zero,
  });

  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(
          padding: padding,
          child: child,
        ),
      ),
    );
  }
}

Widget buildResponsiveSheet(
  BuildContext context, {
  required Widget child,
  double maxWidth = AdminResponsive.maxSheetWidth,
}) {
  return Center(
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: child,
    ),
  );
}
