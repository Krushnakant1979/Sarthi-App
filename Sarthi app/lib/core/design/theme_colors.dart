import 'package:flutter/material.dart';

class AppThemeColors extends ThemeExtension<AppThemeColors> {
  final Color primary;
  final Color actionBlue;
  final Color liveTeal;
  final Color rapidoYellow;
  
  final Color background;
  final Color surface;
  final Color surfaceAlt;
  
  final Color text;
  final Color textMuted;
  final Color hint;
  
  final Color divider;
  final Color cardBorder;
  final Color iconBg;
  
  final Color success;
  final Color warning;
  final Color error;
  
  final Color adminAccent;
  final Color adminAccentDark;
  final Color adminInfo;

  const AppThemeColors({
    required this.primary,
    required this.actionBlue,
    required this.liveTeal,
    required this.rapidoYellow,
    required this.background,
    required this.surface,
    required this.surfaceAlt,
    required this.text,
    required this.textMuted,
    required this.hint,
    required this.divider,
    required this.cardBorder,
    required this.iconBg,
    required this.success,
    required this.warning,
    required this.error,
    required this.adminAccent,
    required this.adminAccentDark,
    required this.adminInfo,
  });

  @override
  AppThemeColors copyWith({
    Color? primary,
    Color? actionBlue,
    Color? liveTeal,
    Color? rapidoYellow,
    Color? background,
    Color? surface,
    Color? surfaceAlt,
    Color? text,
    Color? textMuted,
    Color? hint,
    Color? divider,
    Color? cardBorder,
    Color? iconBg,
    Color? success,
    Color? warning,
    Color? error,
    Color? adminAccent,
    Color? adminAccentDark,
    Color? adminInfo,
  }) {
    return AppThemeColors(
      primary: primary ?? this.primary,
      actionBlue: actionBlue ?? this.actionBlue,
      liveTeal: liveTeal ?? this.liveTeal,
      rapidoYellow: rapidoYellow ?? this.rapidoYellow,
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceAlt: surfaceAlt ?? this.surfaceAlt,
      text: text ?? this.text,
      textMuted: textMuted ?? this.textMuted,
      hint: hint ?? this.hint,
      divider: divider ?? this.divider,
      cardBorder: cardBorder ?? this.cardBorder,
      iconBg: iconBg ?? this.iconBg,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      error: error ?? this.error,
      adminAccent: adminAccent ?? this.adminAccent,
      adminAccentDark: adminAccentDark ?? this.adminAccentDark,
      adminInfo: adminInfo ?? this.adminInfo,
    );
  }

  @override
  AppThemeColors lerp(ThemeExtension<AppThemeColors>? other, double t) {
    if (other is! AppThemeColors) return this;
    return AppThemeColors(
      primary: Color.lerp(primary, other.primary, t)!,
      actionBlue: Color.lerp(actionBlue, other.actionBlue, t)!,
      liveTeal: Color.lerp(liveTeal, other.liveTeal, t)!,
      rapidoYellow: Color.lerp(rapidoYellow, other.rapidoYellow, t)!,
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceAlt: Color.lerp(surfaceAlt, other.surfaceAlt, t)!,
      text: Color.lerp(text, other.text, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      hint: Color.lerp(hint, other.hint, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
      cardBorder: Color.lerp(cardBorder, other.cardBorder, t)!,
      iconBg: Color.lerp(iconBg, other.iconBg, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      error: Color.lerp(error, other.error, t)!,
      adminAccent: Color.lerp(adminAccent, other.adminAccent, t)!,
      adminAccentDark: Color.lerp(adminAccentDark, other.adminAccentDark, t)!,
      adminInfo: Color.lerp(adminInfo, other.adminInfo, t)!,
    );
  }

  static const AppThemeColors light = AppThemeColors(
    primary: Color(0xFF0B2545),
    actionBlue: Color(0xFF1565C0),
    liveTeal: Color(0xFF00A6A6),
    rapidoYellow: Color(0xFFFFD633),
    background: Color(0xFFF5F8FB),
    surface: Colors.white,
    surfaceAlt: Color(0xFFF8F9FC),
    text: Color(0xFF111827),
    textMuted: Color(0xFF6B7280),
    hint: Color(0xFF9CA3AF),
    divider: Color(0xFFF3F4F6),
    cardBorder: Color(0xFFE5E7EB),
    iconBg: Color(0xFFF3F4F6),
    success: Color(0xFF16A34A),
    warning: Color(0xFFF59E0B),
    error: Color(0xFFD32F2F),
    adminAccent: Color(0xFFFFD633),
    adminAccentDark: Color(0xFFFFB300),
    adminInfo: Color(0xFF4F46E5),
  );

  static const AppThemeColors dark = AppThemeColors(
    primary: Color(0xFF4A90E2),
    actionBlue: Color(0xFF4A90E2),
    liveTeal: Color(0xFF00E5E5),
    rapidoYellow: Color(0xFFFFD633),
    background: Color(0xFF0F0F1A),
    surface: Color(0xFF1C1C2E),
    surfaceAlt: Color(0xFF252538),
    text: Colors.white,
    textMuted: Color(0xFF9CA3AF),
    hint: Color(0xFF6B7280),
    divider: Color(0xFF2D2D45),
    cardBorder: Color(0xFF2D2D45),
    iconBg: Color(0xFF2D2D45),
    success: Color(0xFF22C55E),
    warning: Color(0xFFFBBF24),
    error: Color(0xFFEF4444),
    adminAccent: Color(0xFFFFD633),
    adminAccentDark: Color(0xFFFFB300),
    adminInfo: Color(0xFF6366F1),
  );
}
