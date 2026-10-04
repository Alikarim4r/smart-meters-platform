import 'package:flutter/material.dart';

/// Shared design tokens for the Smart Meters product family.
///
/// Entry, Admin and Dashboard all build on these values so spacing, corner
/// hierarchy, depth and motion read as one product. App-specific personality
/// comes only from the accent palette in `AppBrandPalette`.

/// 4-point spacing rhythm.
abstract final class BrandSpace {
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 40;
  static const double huge = 48;

  /// Minimum accessible touch target (Material + WCAG 2.5.8).
  static const double touchTarget = 48;
}

/// Corner hierarchy: smaller elements get tighter corners, containers softer.
abstract final class BrandRadius {
  static const double badge = 4;
  static const double chip = 8;
  static const double control = 10;
  static const double card = 12;
  static const double dialog = 18;
  static const double sheet = 20;
  static const double pill = 999;
}

/// Depth is carried by hairlines on resting surfaces; shadows are reserved
/// for things that float above the page (menus, dialogs, snackbars).
abstract final class BrandShadows {
  static const _shade = Color(0xFF0B1220);

  static List<BoxShadow> resting({required bool isDark}) => [
    // Resting content belongs to the page plane. Hairlines and tone carry its
    // hierarchy; elevation is reserved for transient UI.
  ];

  static List<BoxShadow> raised({required bool isDark}) => [
    BoxShadow(
      color: _shade.withValues(alpha: isDark ? 0.34 : 0.05),
      blurRadius: 4,
      offset: const Offset(0, 1),
    ),
    BoxShadow(
      color: _shade.withValues(alpha: isDark ? 0.30 : 0.06),
      blurRadius: 24,
      offset: const Offset(0, 10),
    ),
  ];

  static List<BoxShadow> overlay({required bool isDark}) => [
    BoxShadow(
      color: _shade.withValues(alpha: isDark ? 0.45 : 0.10),
      blurRadius: 40,
      offset: const Offset(0, 18),
    ),
  ];
}

/// Motion durations; keep interactions quick and calm.
abstract final class BrandMotion {
  static const Duration quick = Duration(milliseconds: 140);
  static const Duration standard = Duration(milliseconds: 220);
  static const Duration emphasized = Duration(milliseconds: 360);
  static const Curve curve = Curves.easeOutCubic;

  /// Honors the platform reduce-motion setting for every shared transition.
  static Duration resolve(BuildContext context, Duration duration) =>
      MediaQuery.disableAnimationsOf(context) ? Duration.zero : duration;
}

/// Semantic status colors tuned for both themes (AA on their surfaces).
abstract final class BrandStatus {
  static Color success({required bool isDark}) =>
      isDark ? const Color(0xFF5CC79A) : const Color(0xFF1C7A52);
  static Color warning({required bool isDark}) =>
      isDark ? const Color(0xFFE8B45A) : const Color(0xFF9A6100);
  static Color danger({required bool isDark}) =>
      isDark ? const Color(0xFFF08C8C) : const Color(0xFFB3261E);
}

/// Type scale shared by all apps.
///
/// Letter spacing stays at zero on purpose: any tracking breaks Arabic cursive
/// joining, and every screen ships in Arabic as well as English. Hierarchy is
/// carried by size, weight and line height instead.
abstract final class BrandType {
  static TextTheme textTheme({required Color ink, required Color muted}) {
    TextStyle s(
      double size,
      FontWeight weight,
      double height, {
      Color? color,
    }) => TextStyle(
      fontSize: size,
      fontWeight: weight,
      height: height,
      letterSpacing: 0,
      color: color ?? ink,
    );

    return TextTheme(
      displayLarge: s(44, FontWeight.w300, 1.12),
      displayMedium: s(36, FontWeight.w300, 1.15),
      displaySmall: s(30, FontWeight.w400, 1.2),
      headlineLarge: s(28, FontWeight.w600, 1.22),
      headlineMedium: s(24, FontWeight.w600, 1.25),
      headlineSmall: s(20, FontWeight.w600, 1.3),
      titleLarge: s(18, FontWeight.w600, 1.32),
      titleMedium: s(15.5, FontWeight.w600, 1.38),
      titleSmall: s(14, FontWeight.w600, 1.4),
      bodyLarge: s(15.5, FontWeight.w400, 1.5),
      bodyMedium: s(14, FontWeight.w400, 1.5),
      bodySmall: s(12.5, FontWeight.w400, 1.45, color: muted),
      labelLarge: s(14, FontWeight.w600, 1.3),
      labelMedium: s(12.5, FontWeight.w600, 1.3),
      labelSmall: s(11.5, FontWeight.w500, 1.3, color: muted),
    );
  }
}
