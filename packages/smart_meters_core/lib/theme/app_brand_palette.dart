import 'package:flutter/material.dart';

/// Official per-app brand tokens. Switch with [BrandChrome.use].
///
/// Keep [legacy] unchanged so we can revert instantly after a trial.
class AppBrandPalette {
  const AppBrandPalette({
    required this.id,
    required this.primary,
    required this.accent,
    required this.accentSoft,
    required this.accentDeep,
    required this.onAccent,
    required this.surface,
    required this.ink,
    required this.inkMuted,
    required this.borderLight,
    required this.iconWellTop,
    required this.iconWellBottom,
    required this.iconGlyph,
    required this.canvasDark,
    required this.surfaceDark,
    required this.surfaceDarkHigh,
    required this.borderDark,
    required this.textDark,
    required this.textDarkMuted,
  });

  final String id;
  final Color primary;
  final Color accent;
  final Color accentSoft;
  final Color accentDeep;
  final Color onAccent;
  final Color surface;
  final Color ink;
  final Color inkMuted;
  final Color borderLight;
  final Color iconWellTop;
  final Color iconWellBottom;
  final Color iconGlyph;
  final Color canvasDark;
  final Color surfaceDark;
  final Color surfaceDarkHigh;
  final Color borderDark;
  final Color textDark;
  final Color textDarkMuted;

  /// Previous cream / navy / gold look.
  static const legacy = AppBrandPalette(
    id: 'legacy',
    primary: Color(0xFF0B1F3A),
    accent: Color(0xFFC9A227),
    accentSoft: Color(0xFFF5E6B8),
    accentDeep: Color(0xFFA88412),
    onAccent: Color(0xFF2C2208),
    surface: Color(0xFFF7F3EA),
    ink: Color(0xFF3F3426),
    inkMuted: Color(0xFF7A6A55),
    borderLight: Color(0xFFE8D9B0),
    iconWellTop: Color(0xFFFFF6E0),
    iconWellBottom: Color(0xFFE8C96A),
    iconGlyph: Color(0xFF8A6A1A),
    canvasDark: Color(0xFF07111F),
    surfaceDark: Color(0xFF12233A),
    surfaceDarkHigh: Color(0xFF1A314D),
    borderDark: Color(0xFF2C4566),
    textDark: Color(0xFFF3EFE4),
    textDarkMuted: Color(0xFFB7C5D8),
  );

  /// Trial B — Dashboard: charcoal + cool slate, white canvas, no gold.
  static const dashboard = AppBrandPalette(
    id: 'dashboard',
    primary: Color(0xFF1B2430),
    accent: Color(0xFF3D5A80),
    accentSoft: Color(0xFFD9E2EC),
    accentDeep: Color(0xFF2B405C),
    onAccent: Color(0xFFFFFFFF),
    surface: Color(0xFFFFFFFF),
    ink: Color(0xFF1B2430),
    inkMuted: Color(0xFF5C6775),
    borderLight: Color(0xFFE2E6EB),
    iconWellTop: Color(0xFFEEF2F6),
    iconWellBottom: Color(0xFF9AAFCB),
    iconGlyph: Color(0xFF1B2430),
    canvasDark: Color(0xFF0E131A),
    // Match KPI tiles (Total meters) so panel cards read as solid navy.
    surfaceDark: Color(0xFF12233A),
    surfaceDarkHigh: Color(0xFF1A314D),
    borderDark: Color(0xFF2C4566),
    textDark: Color(0xFFF5F7FA),
    textDarkMuted: Color(0xFFB0B8C4),
  );

  /// Trial B — Entry: official turquoise, white canvas, no gold.
  static const entry = AppBrandPalette(
    id: 'entry',
    primary: Color(0xFF0E6B6A),
    accent: Color(0xFF14919B),
    accentSoft: Color(0xFFD5EEF0),
    accentDeep: Color(0xFF0A5251),
    onAccent: Color(0xFFFFFFFF),
    surface: Color(0xFFFFFFFF),
    ink: Color(0xFF0E3F3E),
    inkMuted: Color(0xFF5A7373),
    borderLight: Color(0xFFD5E3E3),
    iconWellTop: Color(0xFFEAF6F6),
    iconWellBottom: Color(0xFF7FBFBF),
    iconGlyph: Color(0xFF0E6B6A),
    canvasDark: Color(0xFF071A1A),
    surfaceDark: Color(0xFF0E2E2E),
    surfaceDarkHigh: Color(0xFF164040),
    borderDark: Color(0xFF2A5555),
    textDark: Color(0xFFEAF6F6),
    textDarkMuted: Color(0xFFA3C4C4),
  );

  /// Trial B — Admin: muted burgundy, white canvas, no gold.
  static const admin = AppBrandPalette(
    id: 'admin',
    primary: Color(0xFF6B2D3C),
    accent: Color(0xFF8B3A4A),
    accentSoft: Color(0xFFF0D9DE),
    accentDeep: Color(0xFF522230),
    onAccent: Color(0xFFFFFFFF),
    surface: Color(0xFFFFFFFF),
    ink: Color(0xFF3F1A24),
    inkMuted: Color(0xFF7A5A62),
    borderLight: Color(0xFFE6D5D9),
    iconWellTop: Color(0xFFF8ECEF),
    iconWellBottom: Color(0xFFC98A96),
    iconGlyph: Color(0xFF6B2D3C),
    canvasDark: Color(0xFF1A0E12),
    surfaceDark: Color(0xFF2A151C),
    surfaceDarkHigh: Color(0xFF3A1E28),
    borderDark: Color(0xFF5A3340),
    textDark: Color(0xFFF8F0F2),
    textDarkMuted: Color(0xFFC4A8B0),
  );
}
