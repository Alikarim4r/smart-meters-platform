import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Shared warm cream/gold chrome — Entry, Admin, and Dashboard brand language.
abstract final class BrandChrome {
  /// Warm ink for titles (not cold navy).
  static const ink = Color(0xFF3F3426);

  /// Soft secondary text.
  static const inkMuted = Color(0xFF7A6A55);

  /// Icon well fill (cream → soft gold).
  static const iconWellTop = Color(0xFFFFF6E0);
  static const iconWellBottom = Color(0xFFE8C96A);

  /// Icon glyph on the well.
  static const iconGlyph = Color(0xFF8A6A1A);

  /// Primary action / selected chip.
  static const accent = AppColors.gold;
  static const accentDeep = Color(0xFFA88412);
  static const onAccent = Color(0xFF2C2208);

  /// Card edge in light mode.
  static const borderLight = Color(0xFFE8D9B0);

  /// Scaffold / drawer canvas (light).
  static const canvasLight = Color(0xFFF7F3EA);

  /// Midnight surfaces (dark).
  static const canvasDark = Color(0xFF07111F);
  static const surfaceDark = Color(0xFF12233A);
  static const surfaceDarkHigh = Color(0xFF1A314D);
  static const borderDark = Color(0xFF2C4566);
  static const textDark = Color(0xFFF3EFE4);
  static const textDarkMuted = Color(0xFFB7C5D8);

  static LinearGradient get iconWellGradient => const LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [iconWellTop, iconWellBottom],
  );

  static LinearGradient cardWash({required bool isDark}) => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      isDark ? surfaceDark : Colors.white,
      AppColors.goldSoft.withValues(alpha: isDark ? 0.16 : 0.45),
    ],
  );

  static Color border({required bool isDark, required ColorScheme scheme}) =>
      isDark ? scheme.outline.withValues(alpha: 0.45) : borderLight;

  static Color titleColor({
    required bool isDark,
    required ColorScheme scheme,
  }) => isDark ? scheme.onSurface : ink;

  static Color mutedColor({
    required bool isDark,
    required ColorScheme scheme,
  }) => isDark ? scheme.onSurface.withValues(alpha: 0.62) : inkMuted;
}
