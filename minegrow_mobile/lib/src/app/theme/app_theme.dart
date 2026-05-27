import 'package:flutter/material.dart';

import 'minegrow_tokens.dart';

abstract final class AppTheme {
  static final ThemeData dark = _buildDarkTheme();

  static ThemeData get light => dark;

  static ThemeData _buildDarkTheme() {
    const tokens = MineGrowTokens.dark;
    const metrics = MineGrowMetrics.standard;

    final colorScheme = ColorScheme.fromSeed(
      seedColor: tokens.brandGold,
      brightness: Brightness.dark,
      surface: tokens.background,
      primary: tokens.brandGold,
      secondary: tokens.brandPurple,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: tokens.background,
      extensions: const [tokens, metrics],
      textTheme: const TextTheme(
        displaySmall: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.w800,
          height: 1.05,
          letterSpacing: 0,
        ),
        headlineSmall: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          height: 1.18,
          letterSpacing: 0,
        ),
        titleLarge: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          height: 1.2,
          letterSpacing: 0,
        ),
        titleMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          height: 1.25,
          letterSpacing: 0,
        ),
        bodyLarge: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          height: 1.45,
          letterSpacing: 0,
        ),
        bodyMedium: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w400,
          height: 1.35,
          letterSpacing: 0,
        ),
        labelLarge: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          height: 1.2,
          letterSpacing: 0,
        ),
        labelSmall: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w400,
          height: 1.25,
          letterSpacing: 0,
        ),
      ).apply(bodyColor: tokens.textPrimary, displayColor: tokens.textPrimary),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: tokens.textPrimary,
        titleTextStyle: TextStyle(
          color: tokens.textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          height: 1.2,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: tokens.surfaceElevated,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(metrics.radiusMedium),
          borderSide: BorderSide(color: tokens.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(metrics.radiusMedium),
          borderSide: BorderSide(color: tokens.borderMuted),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(metrics.radiusMedium),
          borderSide: BorderSide(color: tokens.brandGold),
        ),
        hintStyle: TextStyle(color: tokens.textMuted, fontSize: 13),
      ),
    );
  }
}
