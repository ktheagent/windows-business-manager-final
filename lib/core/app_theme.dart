import 'package:flutter/material.dart';

import 'premium_glass.dart';

class AppTheme {
  AppTheme._();

  static ThemeData light() {
    const primary = PremiumGlassPalette.navy;
    const accent = PremiumGlassPalette.sapphire;

    final scheme = ColorScheme.fromSeed(
      seedColor: accent,
      brightness: Brightness.light,
      primary: primary,
      secondary: accent,
      tertiary: PremiumGlassPalette.gold,
      surface: Colors.white,
    );

    final baseText = Typography.material2021().black.apply(
      bodyColor: PremiumGlassPalette.ink,
      displayColor: PremiumGlassPalette.ink,
      fontFamily: 'Segoe UI',
    );

    final rounded16 = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: Colors.transparent,
      canvasColor: Colors.white,
      hoverColor: accent.withValues(alpha: 0.16),
      focusColor: accent.withValues(alpha: 0.22),
      highlightColor: accent.withValues(alpha: 0.14),
      splashColor: accent.withValues(alpha: 0.12),
      fontFamily: 'Segoe UI',
      visualDensity: VisualDensity.standard,
      textTheme: baseText.copyWith(
        headlineSmall: baseText.headlineSmall?.copyWith(
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
        ),
        titleLarge: baseText.titleLarge?.copyWith(
          fontWeight: FontWeight.w800,
        ),
        titleMedium: baseText.titleMedium?.copyWith(
          fontWeight: FontWeight.w700,
        ),
        labelLarge: baseText.labelLarge?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
      appBarTheme: const AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: PremiumGlassPalette.ink,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: Colors.white.withValues(alpha: 0.94),
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.black.withValues(alpha: 0.10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(
            color: primary.withValues(alpha: 0.14),
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        elevation: 24,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.black.withValues(alpha: 0.22),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(26),
          side: BorderSide(
            color: primary.withValues(alpha: 0.12),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        hintStyle: const TextStyle(
          color: Color(0xFF4A5568),
          fontWeight: FontWeight.w500,
        ),
        labelStyle: const TextStyle(
          color: primary,
          fontWeight: FontWeight.w700,
        ),
        floatingLabelStyle: const TextStyle(
          color: primary,
          fontWeight: FontWeight.w800,
        ),
        prefixIconColor: primary,
        suffixIconColor: primary,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: primary.withValues(alpha: 0.34),
            width: 1.2,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: primary.withValues(alpha: 0.34),
            width: 1.2,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: accent,
            width: 2.2,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          foregroundColor: Colors.white,
          backgroundColor: accent,
          disabledForegroundColor: const Color(0xFF5A6472),
          disabledBackgroundColor: const Color(0xFFD7DDE5),
          padding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 14,
          ),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w800,
          ),
          shape: rounded16,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          foregroundColor: Colors.white,
          backgroundColor: accent,
          disabledForegroundColor: const Color(0xFF5A6472),
          disabledBackgroundColor: const Color(0xFFD7DDE5),
          elevation: 8,
          shadowColor: accent.withValues(alpha: 0.28),
          padding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 14,
          ),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w800,
          ),
          shape: rounded16,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          backgroundColor: Colors.white.withValues(alpha: 0.88),
          padding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 14,
          ),
          side: BorderSide(
            color: primary.withValues(alpha: 0.38),
            width: 1.25,
          ),
          shape: rounded16,
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: Colors.white,
        selectedColor: const Color(0xFFDCE8FF),
        disabledColor: const Color(0xFFE5E9EF),
        checkmarkColor: primary,
        side: BorderSide(
          color: primary.withValues(alpha: 0.30),
          width: 1.1,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
        ),
        labelStyle: const TextStyle(
          color: primary,
          fontWeight: FontWeight.w700,
        ),
      ),
      dataTableTheme: DataTableThemeData(
        headingRowColor: WidgetStatePropertyAll(
          primary.withValues(alpha: 0.10),
        ),
        dataRowColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const Color(0xFFDCE8FF);
          }
          if (states.contains(WidgetState.hovered)) {
            return const Color(0xFFEAF1FF);
          }
          return Colors.white;
        }),
        headingTextStyle: const TextStyle(
          fontWeight: FontWeight.w800,
          color: primary,
        ),
        dataTextStyle: const TextStyle(
          color: PremiumGlassPalette.ink,
          fontWeight: FontWeight.w500,
        ),
        dividerThickness: 0.9,
        dataRowMinHeight: 48,
      ),
      navigationRailTheme: const NavigationRailThemeData(
        backgroundColor: primary,
        indicatorColor: accent,
        selectedIconTheme: IconThemeData(
          color: Colors.white,
          size: 26,
        ),
        unselectedIconTheme: IconThemeData(
          color: Color(0xFFBCD6EF),
        ),
        selectedLabelTextStyle: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
        ),
        unselectedLabelTextStyle: TextStyle(
          color: Color(0xFFBCD6EF),
          fontWeight: FontWeight.w600,
        ),
        elevation: 0,
        labelType: NavigationRailLabelType.all,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: primary.withValues(alpha: 0.98),
        contentTextStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: primary.withValues(alpha: 0.12),
        thickness: 1,
      ),
      iconTheme: const IconThemeData(color: primary),
    );
  }
}
