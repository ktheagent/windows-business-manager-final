import 'package:flutter/material.dart';

import 'premium_glass.dart';

class AppTheme {
  static ThemeData light() {
    const primary = PremiumGlassPalette.navy;
    const secondary = PremiumGlassPalette.sapphire;
    const accent = PremiumGlassPalette.gold;
    const border = Color(0xFFDCE6F4);
    const muted = PremiumGlassPalette.muted;

    final scheme = ColorScheme.fromSeed(
      seedColor: secondary,
      brightness: Brightness.light,
      primary: primary,
      secondary: secondary,
      tertiary: accent,
      surface: Colors.white,
    );

    final baseText = Typography.material2021().black.apply(
      bodyColor: PremiumGlassPalette.ink,
      displayColor: PremiumGlassPalette.ink,
      fontFamily: 'Segoe UI',
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: Colors.transparent,
      canvasColor: Colors.transparent,
      fontFamily: 'Segoe UI',
      visualDensity: VisualDensity.standard,
      textTheme: baseText.copyWith(
        headlineSmall: baseText.headlineSmall?.copyWith(
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
        ),
        titleLarge: baseText.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        titleMedium: baseText.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        labelLarge: baseText.labelLarge?.copyWith(fontWeight: FontWeight.w700),
      ),
      appBarTheme: const AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        backgroundColor: Colors.transparent,
        foregroundColor: PremiumGlassPalette.ink,
        surfaceTintColor: Colors.transparent,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.72),
        hintStyle: const TextStyle(color: muted),
        labelStyle: const TextStyle(color: muted, fontWeight: FontWeight.w600),
        prefixIconColor: primary,
        suffixIconColor: primary,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.82)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: secondary, width: 1.6),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: Colors.white.withValues(alpha: 0.72),
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.black.withValues(alpha: 0.08),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.78)),
        ),
      ),
      dialogTheme: DialogThemeData(
        elevation: 24,
        backgroundColor: Colors.white.withValues(alpha: 0.94),
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.black.withValues(alpha: 0.16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          foregroundColor: Colors.white,
          backgroundColor: secondary,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          foregroundColor: Colors.white,
          backgroundColor: secondary,
          elevation: 10,
          shadowColor: secondary.withValues(alpha: 0.28),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          side: BorderSide(color: primary.withValues(alpha: 0.18)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: Colors.white.withValues(alpha: 0.68),
        selectedColor: secondary.withValues(alpha: 0.14),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.82)),
        shape: RoundedRectangleBorder(borderRadius.circular(999)),
        labelStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
      dataTableTheme: DataTableThemeData(
        headingRowColor: WidgetStatePropertyAll(
          primary.withValues(alpha: 0.055),
        ),
        dataRowColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.hovered)) {
            return secondary.withValues(alpha: 0.055);
          }
          return Colors.white.withValues(alpha: 0.34);
        }),
        headingTextStyle: const TextStyle(
          fontWeight: FontWeight.w800,
          color: primary,
        ),
        dataTextStyle: const TextStyle(color: PremiumGlassPalette.ink),
        dividerThickness: 0.7,
        dataRowMinHeight: 48,
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: primary.withValues(alpha: 0.95),
        indicatorColor: Colors.white.withValues(alpha: 0.14),
        selectedIconTheme: const IconThemeData(color: Colors.white),
        unselectedIconTheme: const IconThemeData(color: Color(0xFFBCD6EF)),
        selectedLabelTextStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
        ),
        unselectedLabelTextStyle: const TextStyle(color: Color(0xFFBCD6EF)),
        elevation: 0,
        labelType: NavigationRailLabelType.all,
      ),
      dividerTheme: DividerThemeData(
        color: primary.withValues(alpha: 0.08),
        thickness: 1,
      ),
      iconTheme: const IconThemeData(color: primary),
      tooltipTheme: TooltipThemeData(
        preferBelow: false,
        decoration: BoxDecoration(
          color: primary.withValues(alpha: 0.96),
          borderRadius: BorderRadius.circular(12),
        ),
        textStyle: const TextStyle(color: Colors.white),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: primary.withValues(alpha: 0.96),
        contentTextStyle: const TextStyle(color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  AppTheme._();
}
