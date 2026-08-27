import 'package:flutter/material.dart';

import 'theme_colors.dart';
export 'theme_colors.dart';

extension ThemeColorsExtension on BuildContext {
  AppThemeColors get colors => Theme.of(this).extension<AppThemeColors>()!;
}

class AppSpacing {
  static const double xxs = 4.0;
  static const double xs = 8.0;
  static const double s = 12.0;
  static const double m = 16.0;
  static const double l = 24.0;
  static const double xl = 32.0;
}

class AppThemeTokens {
  static const double cardRadius = 16.0;
  static const double buttonHeight = 52.0;
  static const double minTouchTarget = 48.0;
}
