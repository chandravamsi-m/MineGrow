import 'package:flutter/material.dart';

@immutable
class MineGrowTokens extends ThemeExtension<MineGrowTokens> {
  const MineGrowTokens({
    required this.background,
    required this.surface,
    required this.surfaceElevated,
    required this.surfaceSoft,
    required this.border,
    required this.borderMuted,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.brandGold,
    required this.brandOrange,
    required this.brandPurple,
    required this.brandMagenta,
    required this.success,
    required this.warning,
    required this.danger,
  });

  final Color background;
  final Color surface;
  final Color surfaceElevated;
  final Color surfaceSoft;
  final Color border;
  final Color borderMuted;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color brandGold;
  final Color brandOrange;
  final Color brandPurple;
  final Color brandMagenta;
  final Color success;
  final Color warning;
  final Color danger;

  static const dark = MineGrowTokens(
    background: Color(0xFF050812),
    surface: Color(0xFF10141F),
    surfaceElevated: Color(0xFF171B27),
    surfaceSoft: Color(0xFF1D2230),
    border: Color(0xFF2A3040),
    borderMuted: Color(0xFF1E2431),
    textPrimary: Color(0xFFFFFFFF),
    textSecondary: Color(0xFFB7BECC),
    textMuted: Color(0xFF8D96AA),
    brandGold: Color(0xFFFDBA2D),
    brandOrange: Color(0xFFF59E0B),
    brandPurple: Color(0xFF7C4DFF),
    brandMagenta: Color(0xFFB45BA8),
    success: Color(0xFF22C55E),
    warning: Color(0xFFF59E0B),
    danger: Color(0xFFEF4444),
  );

  LinearGradient get primaryGradient => LinearGradient(
    colors: [brandGold, brandOrange, brandMagenta, brandPurple],
  );

  LinearGradient get walletGradient => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [brandPurple.withValues(alpha: 0.58), surface, background],
  );

  LinearGradient get principalGradient => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [brandOrange.withValues(alpha: 0.25), surfaceElevated, background],
  );

  LinearGradient get surfaceGradient => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [surfaceElevated, surface],
  );

  List<BoxShadow> get glowShadow => [
    BoxShadow(
      color: brandPurple.withValues(alpha: 0.18),
      blurRadius: 24,
      offset: const Offset(0, 14),
    ),
  ];

  @override
  MineGrowTokens copyWith({
    Color? background,
    Color? surface,
    Color? surfaceElevated,
    Color? surfaceSoft,
    Color? border,
    Color? borderMuted,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
    Color? brandGold,
    Color? brandOrange,
    Color? brandPurple,
    Color? brandMagenta,
    Color? success,
    Color? warning,
    Color? danger,
  }) {
    return MineGrowTokens(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceElevated: surfaceElevated ?? this.surfaceElevated,
      surfaceSoft: surfaceSoft ?? this.surfaceSoft,
      border: border ?? this.border,
      borderMuted: borderMuted ?? this.borderMuted,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
      brandGold: brandGold ?? this.brandGold,
      brandOrange: brandOrange ?? this.brandOrange,
      brandPurple: brandPurple ?? this.brandPurple,
      brandMagenta: brandMagenta ?? this.brandMagenta,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      danger: danger ?? this.danger,
    );
  }

  @override
  MineGrowTokens lerp(ThemeExtension<MineGrowTokens>? other, double t) {
    if (other is! MineGrowTokens) {
      return this;
    }

    return MineGrowTokens(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceElevated: Color.lerp(surfaceElevated, other.surfaceElevated, t)!,
      surfaceSoft: Color.lerp(surfaceSoft, other.surfaceSoft, t)!,
      border: Color.lerp(border, other.border, t)!,
      borderMuted: Color.lerp(borderMuted, other.borderMuted, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      brandGold: Color.lerp(brandGold, other.brandGold, t)!,
      brandOrange: Color.lerp(brandOrange, other.brandOrange, t)!,
      brandPurple: Color.lerp(brandPurple, other.brandPurple, t)!,
      brandMagenta: Color.lerp(brandMagenta, other.brandMagenta, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
    );
  }
}

@immutable
class MineGrowMetrics extends ThemeExtension<MineGrowMetrics> {
  const MineGrowMetrics({
    required this.screenPadding,
    required this.cardPadding,
    required this.compactPadding,
    required this.sectionGap,
    required this.cardGap,
    required this.fieldHeight,
    required this.otpWidth,
    required this.otpHeight,
    required this.bottomNavHeight,
    required this.radiusSmall,
    required this.radiusMedium,
    required this.radiusLarge,
  });

  final double screenPadding;
  final double cardPadding;
  final double compactPadding;
  final double sectionGap;
  final double cardGap;
  final double fieldHeight;
  final double otpWidth;
  final double otpHeight;
  final double bottomNavHeight;
  final double radiusSmall;
  final double radiusMedium;
  final double radiusLarge;

  static const standard = MineGrowMetrics(
    screenPadding: 20,
    cardPadding: 16,
    compactPadding: 12,
    sectionGap: 20,
    cardGap: 12,
    fieldHeight: 52,
    otpWidth: 48,
    otpHeight: 56,
    bottomNavHeight: 72,
    radiusSmall: 10,
    radiusMedium: 14,
    radiusLarge: 18,
  );

  @override
  MineGrowMetrics copyWith({
    double? screenPadding,
    double? cardPadding,
    double? compactPadding,
    double? sectionGap,
    double? cardGap,
    double? fieldHeight,
    double? otpWidth,
    double? otpHeight,
    double? bottomNavHeight,
    double? radiusSmall,
    double? radiusMedium,
    double? radiusLarge,
  }) {
    return MineGrowMetrics(
      screenPadding: screenPadding ?? this.screenPadding,
      cardPadding: cardPadding ?? this.cardPadding,
      compactPadding: compactPadding ?? this.compactPadding,
      sectionGap: sectionGap ?? this.sectionGap,
      cardGap: cardGap ?? this.cardGap,
      fieldHeight: fieldHeight ?? this.fieldHeight,
      otpWidth: otpWidth ?? this.otpWidth,
      otpHeight: otpHeight ?? this.otpHeight,
      bottomNavHeight: bottomNavHeight ?? this.bottomNavHeight,
      radiusSmall: radiusSmall ?? this.radiusSmall,
      radiusMedium: radiusMedium ?? this.radiusMedium,
      radiusLarge: radiusLarge ?? this.radiusLarge,
    );
  }

  @override
  MineGrowMetrics lerp(ThemeExtension<MineGrowMetrics>? other, double t) {
    if (other is! MineGrowMetrics) {
      return this;
    }

    return MineGrowMetrics(
      screenPadding: lerpDouble(screenPadding, other.screenPadding, t),
      cardPadding: lerpDouble(cardPadding, other.cardPadding, t),
      compactPadding: lerpDouble(compactPadding, other.compactPadding, t),
      sectionGap: lerpDouble(sectionGap, other.sectionGap, t),
      cardGap: lerpDouble(cardGap, other.cardGap, t),
      fieldHeight: lerpDouble(fieldHeight, other.fieldHeight, t),
      otpWidth: lerpDouble(otpWidth, other.otpWidth, t),
      otpHeight: lerpDouble(otpHeight, other.otpHeight, t),
      bottomNavHeight: lerpDouble(bottomNavHeight, other.bottomNavHeight, t),
      radiusSmall: lerpDouble(radiusSmall, other.radiusSmall, t),
      radiusMedium: lerpDouble(radiusMedium, other.radiusMedium, t),
      radiusLarge: lerpDouble(radiusLarge, other.radiusLarge, t),
    );
  }

  static double lerpDouble(double a, double b, double t) => a + (b - a) * t;
}

extension MineGrowThemeX on BuildContext {
  MineGrowTokens get tokens => Theme.of(this).extension<MineGrowTokens>()!;

  MineGrowMetrics get metrics => Theme.of(this).extension<MineGrowMetrics>()!;
}
