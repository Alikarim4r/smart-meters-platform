import 'package:flutter/material.dart';

import 'app_theme.dart';
import 'brand_chrome.dart';

/// Shared themes driven by the active [BrandChrome] palette.
abstract final class BrandTheme {
  static ThemeData light() {
    final base = AppTheme.light();
    final colorScheme = base.colorScheme.copyWith(
      primary: BrandChrome.accent,
      onPrimary: BrandChrome.onAccent,
      secondary: BrandChrome.accentSoft,
      onSecondary: BrandChrome.ink,
      surface: Colors.white,
      onSurface: BrandChrome.ink,
      surfaceContainerLowest: Colors.white,
      surfaceContainerLow: Colors.white,
      surfaceContainer: Colors.white,
      surfaceContainerHigh: const Color(0xFFF7F8FA),
      surfaceContainerHighest: const Color(0xFFF2F4F7),
      surfaceTint: Colors.transparent,
      secondaryContainer: BrandChrome.accentSoft.withValues(alpha: 0.55),
      onSecondaryContainer: BrandChrome.ink,
      outline: BrandChrome.borderLight,
    );

    return base.copyWith(
      colorScheme: colorScheme,
      scaffoldBackgroundColor: Colors.transparent,
      drawerTheme: DrawerThemeData(
        backgroundColor: BrandChrome.canvasLight,
      ),
      appBarTheme: base.appBarTheme.copyWith(
        backgroundColor: BrandChrome.canvasLight,
        foregroundColor: BrandChrome.ink,
        surfaceTintColor: Colors.transparent,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: BrandChrome.accent,
          foregroundColor: BrandChrome.onAccent,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: BrandChrome.ink,
          side: BorderSide(color: BrandChrome.borderLight),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return BrandChrome.accent.withValues(alpha: 0.22);
            }
            return Colors.transparent;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return BrandChrome.ink;
            }
            return BrandChrome.inkMuted;
          }),
          iconColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return BrandChrome.iconGlyph;
            }
            return BrandChrome.inkMuted;
          }),
          side: WidgetStatePropertyAll(
            BorderSide(color: BrandChrome.borderLight),
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        selectedColor: BrandChrome.accent.withValues(alpha: 0.28),
        checkmarkColor: BrandChrome.onAccent,
        labelStyle: TextStyle(
          color: BrandChrome.ink,
          fontWeight: FontWeight.w600,
          fontSize: 11,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: BrandChrome.accent,
        foregroundColor: BrandChrome.onAccent,
        extendedPadding: const EdgeInsets.symmetric(horizontal: 18),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      navigationBarTheme: base.navigationBarTheme.copyWith(
        backgroundColor: BrandChrome.canvasLight,
        indicatorColor: BrandChrome.accent.withValues(alpha: 0.28),
        labelTextStyle: WidgetStatePropertyAll(
          base.navigationBarTheme.labelTextStyle
                  ?.resolve({})
                  ?.copyWith(color: BrandChrome.ink) ??
              TextStyle(fontSize: 12, color: BrandChrome.ink),
        ),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: BrandChrome.iconGlyph);
          }
          return IconThemeData(color: BrandChrome.inkMuted);
        }),
      ),
      cardTheme: base.cardTheme.copyWith(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: BrandChrome.borderLight),
        ),
      ),
      inputDecorationTheme: base.inputDecorationTheme.copyWith(
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: BrandChrome.accent, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: BrandChrome.borderLight),
        ),
      ),
      textTheme: base.textTheme.apply(
        bodyColor: BrandChrome.ink,
        displayColor: BrandChrome.ink,
      ),
      listTileTheme: ListTileThemeData(iconColor: BrandChrome.iconGlyph),
      iconTheme: IconThemeData(color: BrandChrome.iconGlyph),
    );
  }

  static ThemeData dark() {
    final surfaceElevated = BrandChrome.surfaceDark;
    final surfaceHigh = BrandChrome.surfaceDarkHigh;
    final border = BrandChrome.borderDark;
    final textPrimary = BrandChrome.textDark;
    final textMuted = BrandChrome.textDarkMuted;

    final colorScheme = ColorScheme.fromSeed(
      seedColor: BrandChrome.primary,
      brightness: Brightness.dark,
      primary: BrandChrome.accent,
      onPrimary: BrandChrome.onAccent,
      secondary: BrandChrome.accentSoft,
      onSecondary: BrandChrome.primary,
      surface: surfaceElevated,
      onSurface: textPrimary,
      outline: border,
      surfaceContainerHighest: surfaceHigh,
      secondaryContainer: BrandChrome.accent.withValues(alpha: 0.22),
      onSecondaryContainer: BrandChrome.accentSoft,
    );

    return ThemeData(
      colorScheme: colorScheme,
      useMaterial3: true,
      scaffoldBackgroundColor: Colors.transparent,
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 1,
        centerTitle: false,
        backgroundColor: surfaceElevated,
        foregroundColor: textPrimary,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: surfaceElevated,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: border),
        ),
        margin: EdgeInsets.zero,
      ),
      drawerTheme: DrawerThemeData(backgroundColor: surfaceElevated),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: BrandChrome.accent,
          foregroundColor: BrandChrome.onAccent,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textPrimary,
          side: BorderSide(color: border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return BrandChrome.accent.withValues(alpha: 0.24);
            }
            return Colors.transparent;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return BrandChrome.accentSoft;
            }
            return textMuted;
          }),
          iconColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return BrandChrome.accentSoft;
            }
            return textMuted;
          }),
          side: WidgetStatePropertyAll(BorderSide(color: border)),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surfaceElevated,
        indicatorColor: BrandChrome.accent.withValues(alpha: 0.28),
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(fontSize: 12, color: textPrimary),
        ),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: BrandChrome.accentSoft);
          }
          return IconThemeData(color: textMuted);
        }),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: BrandChrome.accent,
        foregroundColor: BrandChrome.onAccent,
        extendedPadding: const EdgeInsets.symmetric(horizontal: 18),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceHigh,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: BrandChrome.accent, width: 1.5),
        ),
      ),
      dividerTheme: DividerThemeData(color: border, thickness: 1),
      listTileTheme: ListTileThemeData(iconColor: textMuted),
      chipTheme: ChipThemeData(
        backgroundColor: BrandChrome.accent.withValues(alpha: 0.14),
        labelStyle: TextStyle(
          color: BrandChrome.accentSoft,
          fontWeight: FontWeight.w600,
          fontSize: 11,
        ),
        side: BorderSide(color: BrandChrome.accent.withValues(alpha: 0.4)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      textTheme: TextTheme(
        headlineSmall: TextStyle(
          color: textPrimary,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
        ),
        titleLarge: TextStyle(color: textPrimary, fontWeight: FontWeight.w700),
        titleMedium: TextStyle(color: textPrimary, fontWeight: FontWeight.w600),
        titleSmall: TextStyle(color: textPrimary, fontWeight: FontWeight.w700),
        bodyMedium: TextStyle(color: textPrimary),
        bodySmall: TextStyle(color: textMuted),
      ),
    );
  }
}
