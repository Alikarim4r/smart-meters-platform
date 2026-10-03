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

  /// Dashboard — sapphire on graphite. Executive analytics, calm and precise.
  static const dashboard = AppBrandPalette(
    id: 'dashboard',
    primary: Color(0xFF141B26),
    accent: Color(0xFF2D4E80),
    accentSoft: Color(0xFFDDE5F1),
    accentDeep: Color(0xFF1F3A63),
    onAccent: Color(0xFFFFFFFF),
    surface: Color(0xFFFFFFFF),
    ink: Color(0xFF141B26),
    inkMuted: Color(0xFF566173),
    borderLight: Color(0xFFE1E5EB),
    iconWellTop: Color(0xFFF3F6FA),
    iconWellBottom: Color(0xFFDCE4F0),
    iconGlyph: Color(0xFF1F3A63),
    canvasDark: Color(0xFF0A0F17),
    surfaceDark: Color(0xFF121A26),
    surfaceDarkHigh: Color(0xFF1A2433),
    borderDark: Color(0xFF2A3647),
    textDark: Color(0xFFEEF2F7),
    textDarkMuted: Color(0xFFA7B1C0),
  );

  /// Entry — deep malachite. Field-first, tactile, unmistakable.
  static const entry = AppBrandPalette(
    id: 'entry',
    primary: Color(0xFF0A5C59),
    accent: Color(0xFF0D7A74),
    accentSoft: Color(0xFFDBEFEC),
    accentDeep: Color(0xFF07504C),
    onAccent: Color(0xFFFFFFFF),
    surface: Color(0xFFFFFFFF),
    ink: Color(0xFF122120),
    inkMuted: Color(0xFF536462),
    borderLight: Color(0xFFDDE6E4),
    iconWellTop: Color(0xFFF1F8F7),
    iconWellBottom: Color(0xFFD3E9E5),
    iconGlyph: Color(0xFF0A5C59),
    canvasDark: Color(0xFF081211),
    surfaceDark: Color(0xFF0F1D1C),
    surfaceDarkHigh: Color(0xFF172928),
    borderDark: Color(0xFF274140),
    textDark: Color(0xFFECF4F3),
    textDarkMuted: Color(0xFFA3B8B5),
  );

  /// Admin — garnet. Authoritative executive control.
  static const admin = AppBrandPalette(
    id: 'admin',
    primary: Color(0xFF5E2232),
    accent: Color(0xFF7D2E43),
    accentSoft: Color(0xFFF4E3E8),
    accentDeep: Color(0xFF5A1F30),
    onAccent: Color(0xFFFFFFFF),
    surface: Color(0xFFFFFFFF),
    ink: Color(0xFF221519),
    inkMuted: Color(0xFF68585D),
    borderLight: Color(0xFFE8DFE2),
    iconWellTop: Color(0xFFFBF4F6),
    iconWellBottom: Color(0xFFEDD5DC),
    iconGlyph: Color(0xFF6B2638),
    canvasDark: Color(0xFF120B0D),
    surfaceDark: Color(0xFF1C1316),
    surfaceDarkHigh: Color(0xFF271B1F),
    borderDark: Color(0xFF3F2D33),
    textDark: Color(0xFFF6EFF1),
    textDarkMuted: Color(0xFFBCAAB0),
  );
}
