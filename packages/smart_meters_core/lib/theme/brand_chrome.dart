import 'package:flutter/material.dart';

import 'app_brand_palette.dart';

/// Shared brand chrome. Call [use] once at app startup to pick an official palette.
///
/// Revert to previous look with `BrandChrome.use(AppBrandPalette.legacy)`.
abstract final class BrandChrome {
  static AppBrandPalette _palette = AppBrandPalette.legacy;

  static AppBrandPalette get palette => _palette;

  static void use(AppBrandPalette palette) {
    _palette = palette;
  }

  static Color get ink => _palette.ink;
  static Color get inkMuted => _palette.inkMuted;
  static Color get iconWellTop => _palette.iconWellTop;
  static Color get iconWellBottom => _palette.iconWellBottom;
  static Color get iconGlyph => _palette.iconGlyph;
  static Color get accent => _palette.accent;
  static Color get accentDeep => _palette.accentDeep;
  static Color get onAccent => _palette.onAccent;
  static Color get borderLight => _palette.borderLight;
  static Color get canvasLight => _palette.surface;
  static Color get primary => _palette.primary;
  static Color get accentSoft => _palette.accentSoft;

  static Color get canvasDark => _palette.canvasDark;
  static Color get surfaceDark => _palette.surfaceDark;
  static Color get surfaceDarkHigh => _palette.surfaceDarkHigh;
  static Color get borderDark => _palette.borderDark;
  static Color get textDark => _palette.textDark;
  static Color get textDarkMuted => _palette.textDarkMuted;

  static LinearGradient get iconWellGradient => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [iconWellTop, iconWellBottom],
  );

  /// Quiet tonal panel. Product personality comes from controls and status,
  /// not decorative gradients behind operational content.
  static LinearGradient cardWash({required bool isDark}) {
    final flat = isDark
        ? Color.alphaBlend(accentSoft.withValues(alpha: 0.035), surfaceDark)
        : Color.alphaBlend(accentSoft.withValues(alpha: 0.035), Colors.white);
    return LinearGradient(colors: [flat, flat]);
  }

  static Color border({required bool isDark, required ColorScheme scheme}) =>
      isDark ? scheme.outline.withValues(alpha: 0.7) : borderLight;

  static Color titleColor({
    required bool isDark,
    required ColorScheme scheme,
  }) => isDark ? scheme.onSurface : ink;

  static Color mutedColor({
    required bool isDark,
    required ColorScheme scheme,
  }) => isDark ? scheme.onSurface.withValues(alpha: 0.62) : inkMuted;
}
