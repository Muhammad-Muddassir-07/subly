import 'package:flutter/material.dart';

/// Original Subly design system. Dark-first, restrained red accent.
/// Deliberately avoids YouTube's logo, wordmark or exact brand palette.
class AppColors {
  const AppColors._();

  static const background = Color(0xFF0B0B0C);
  static const surface = Color(0xFF161618);
  static const surfaceElevated = Color(0xFF1F1F22);
  static const border = Color(0xFF2A2A2E);
  static const textPrimary = Color(0xFFF5F5F7);
  static const textSecondary = Color(0xFF9A9AA3);
  static const accent = Color(0xFFE5484D);
  static const danger = Color(0xFFFF6B6B);
}

class AppTheme {
  const AppTheme._();

  static const _radius = 16.0;

  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData light() => _build(Brightness.light);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.accent,
      brightness: brightness,
    ).copyWith(
      primary: AppColors.accent,
      surface: isDark ? AppColors.surface : const Color(0xFFF7F7F8),
      onSurface: isDark ? AppColors.textPrimary : const Color(0xFF111113),
      error: AppColors.danger,
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: isDark ? AppColors.background : const Color(0xFFFFFFFF),
      fontFamily: null,
    );

    return base.copyWith(
      appBarTheme: AppBarTheme(
        backgroundColor: base.scaffoldBackgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: base.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
      ),
      cardTheme: CardThemeData(
        color: isDark ? AppColors.surface : const Color(0xFFF2F2F4),
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_radius)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: isDark ? AppColors.surface : const Color(0xFFF7F7F8),
        indicatorColor: AppColors.accent.withValues(alpha: 0.18),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: isDark ? AppColors.surfaceElevated : const Color(0xFFEDEDF0),
        selectedColor: AppColors.accent,
        labelStyle: TextStyle(
          color: isDark ? AppColors.textPrimary : const Color(0xFF111113),
          fontWeight: FontWeight.w600,
        ),
        side: BorderSide.none,
        shape: const StadiumBorder(),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? AppColors.surfaceElevated : const Color(0xFFEDEDF0),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      dividerTheme: DividerThemeData(
        color: isDark ? AppColors.border : const Color(0xFFE2E2E6),
        space: 1,
        thickness: 1,
      ),
    );
  }
}
