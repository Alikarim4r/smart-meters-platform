import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_theme.dart';
import 'brand_chrome.dart';

/// Shared themes: warm cream/gold light + luxurious midnight/gold dark.
abstract final class BrandTheme {
  static ThemeData light() {
    final base = AppTheme.light();
    final colorScheme = base.colorScheme.copyWith(
      primary: BrandChrome.accent,
      onPrimary: BrandChrome.onAccent,
      secondary: AppColors.goldSoft,
      onSecondary: BrandChrome.ink,
      onSurface: BrandChrome.ink,
      secondaryContainer: AppColors.goldSoft.withValues(alpha: 0.55),
      onSecondaryContainer: BrandChrome.ink,
      outline: BrandChrome.borderLight,
    );

    return base.copyWith(
      colorScheme: colorScheme,
      // Transparent so [BrandSurfaceBackground] from MaterialApp.builder shows.
      scaffoldBackgroundColor: Colors.transparent,
      drawerTheme: const DrawerThemeData(
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
          side: const BorderSide(color: BrandChrome.borderLight),
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
          side: const WidgetStatePropertyAll(
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
        labelStyle: const TextStyle(
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
              const TextStyle(fontSize: 12, color: BrandChrome.ink),
        ),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: BrandChrome.iconGlyph);
          }
          return const IconThemeData(color: BrandChrome.inkMuted);
        }),
      ),
      cardTheme: base.cardTheme.copyWith(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: BrandChrome.borderLight),
        ),
      ),
      inputDecorationTheme: base.inputDecorationTheme.copyWith(
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: BrandChrome.accent, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: BrandChrome.borderLight),
        ),
      ),
      textTheme: base.textTheme.apply(
        bodyColor: BrandChrome.ink,
        displayColor: BrandChrome.ink,
      ),
      listTileTheme: const ListTileThemeData(iconColor: BrandChrome.iconGlyph),
      iconTheme: const IconThemeData(color: BrandChrome.iconGlyph),
    );
  }

  /// Deep midnight navy with gold accents.
  static ThemeData dark() {
    const surfaceElevated = BrandChrome.surfaceDark;
    const surfaceHigh = BrandChrome.surfaceDarkHigh;
    const border = BrandChrome.borderDark;
    const textPrimary = BrandChrome.textDark;
    const textMuted = BrandChrome.textDarkMuted;

    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.navy,
      brightness: Brightness.dark,
      primary: AppColors.gold,
      onPrimary: AppColors.navy,
      secondary: AppColors.goldSoft,
      onSecondary: AppColors.navy,
      surface: surfaceElevated,
      onSurface: textPrimary,
      outline: border,
      surfaceContainerHighest: surfaceHigh,
      secondaryContainer: AppColors.gold.withValues(alpha: 0.22),
      onSecondaryContainer: AppColors.goldSoft,
    );

    return ThemeData(
      colorScheme: colorScheme,
      useMaterial3: true,
      scaffoldBackgroundColor: Colors.transparent,
      appBarTheme: const AppBarTheme(
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
          side: const BorderSide(color: border),
        ),
        margin: EdgeInsets.zero,
      ),
      drawerTheme: const DrawerThemeData(backgroundColor: surfaceElevated),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.gold,
          foregroundColor: AppColors.navy,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textPrimary,
          side: const BorderSide(color: border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return AppColors.gold.withValues(alpha: 0.24);
            }
            return Colors.transparent;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return AppColors.goldSoft;
            }
            return textMuted;
          }),
          iconColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return AppColors.goldSoft;
            }
            return textMuted;
          }),
          side: const WidgetStatePropertyAll(BorderSide(color: border)),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surfaceElevated,
        indicatorColor: AppColors.gold.withValues(alpha: 0.28),
        labelTextStyle: const WidgetStatePropertyAll(
          TextStyle(fontSize: 12, color: textPrimary),
        ),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: AppColors.goldSoft);
          }
          return const IconThemeData(color: textMuted);
        }),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppColors.gold,
        foregroundColor: AppColors.navy,
        extendedPadding: const EdgeInsets.symmetric(horizontal: 18),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceHigh,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.gold, width: 1.5),
        ),
      ),
      dividerTheme: const DividerThemeData(color: border, thickness: 1),
      listTileTheme: const ListTileThemeData(iconColor: textMuted),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.gold.withValues(alpha: 0.14),
        labelStyle: const TextStyle(
          color: AppColors.goldSoft,
          fontWeight: FontWeight.w600,
          fontSize: 11,
        ),
        side: BorderSide(color: AppColors.gold.withValues(alpha: 0.4)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      textTheme: const TextTheme(
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
