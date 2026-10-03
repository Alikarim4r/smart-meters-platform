import 'package:flutter/material.dart';
import 'package:smart_meters_core/smart_meters_core.dart';

/// Semantic dashboard colors for light and dark themes.
@immutable
class DashboardThemeColors extends ThemeExtension<DashboardThemeColors> {
  const DashboardThemeColors({
    required this.background,
    required this.card,
    required this.cardElevated,
    required this.border,
    required this.textPrimary,
    required this.textMuted,
    required this.navy,
    required this.navyMuted,
    required this.sidebar,
    required this.sidebarBorder,
    required this.inputFill,
    required this.dialog,
    required this.meterPatternOpacity,
    required this.chartGrid,
    required this.infoSurface,
    required this.infoBorder,
  });

  final Color background;
  final Color card;
  final Color cardElevated;
  final Color border;
  final Color textPrimary;
  final Color textMuted;
  final Color navy;
  final Color navyMuted;
  final Color sidebar;
  final Color sidebarBorder;
  final Color inputFill;
  final Color dialog;
  final double meterPatternOpacity;
  final Color chartGrid;
  final Color infoSurface;
  final Color infoBorder;

  static const light = DashboardThemeColors(
    background: Color(0xFFF6F8FB),
    card: Color(0xFFFFFFFF),
    cardElevated: Color(0xFFF1F4F8),
    border: Color(0xFFDCE2EA),
    textPrimary: Color(0xFF141B26),
    textMuted: Color(0xFF5B6677),
    navy: Color(0xFF1F3A63),
    navyMuted: Color(0xFF657A9A),
    sidebar: Color(0xFF0F1722),
    sidebarBorder: Color(0xFF202C3C),
    inputFill: Color(0xFFF8FAFC),
    dialog: Color(0xFFFFFFFF),
    meterPatternOpacity: 0,
    chartGrid: Color(0xFFE1E6ED),
    infoSurface: Color(0xFFEEF3F9),
    infoBorder: Color(0xFFD7E1EE),
  );

  static const dark = DashboardThemeColors(
    background: Color(0xFF080D14),
    card: Color(0xFF111925),
    cardElevated: Color(0xFF182333),
    border: Color(0xFF2A3647),
    textPrimary: Color(0xFFEEF2F7),
    textMuted: Color(0xFFA7B1C0),
    navy: Color(0xFFDDE5F1),
    navyMuted: Color(0xFF8EA4C3),
    sidebar: Color(0xFF070B11),
    sidebarBorder: Color(0xFF202B3A),
    inputFill: Color(0xFF162130),
    dialog: Color(0xFF101824),
    meterPatternOpacity: 0,
    chartGrid: Color(0xFF2A3647),
    infoSurface: Color(0xFF162130),
    infoBorder: Color(0xFF2A3A50),
  );

  static DashboardThemeColors of(BuildContext context) {
    return Theme.of(context).extension<DashboardThemeColors>() ?? light;
  }

  @override
  DashboardThemeColors copyWith({
    Color? background,
    Color? card,
    Color? cardElevated,
    Color? border,
    Color? textPrimary,
    Color? textMuted,
    Color? navy,
    Color? navyMuted,
    Color? sidebar,
    Color? sidebarBorder,
    Color? inputFill,
    Color? dialog,
    double? meterPatternOpacity,
    Color? chartGrid,
    Color? infoSurface,
    Color? infoBorder,
  }) {
    return DashboardThemeColors(
      background: background ?? this.background,
      card: card ?? this.card,
      cardElevated: cardElevated ?? this.cardElevated,
      border: border ?? this.border,
      textPrimary: textPrimary ?? this.textPrimary,
      textMuted: textMuted ?? this.textMuted,
      navy: navy ?? this.navy,
      navyMuted: navyMuted ?? this.navyMuted,
      sidebar: sidebar ?? this.sidebar,
      sidebarBorder: sidebarBorder ?? this.sidebarBorder,
      inputFill: inputFill ?? this.inputFill,
      dialog: dialog ?? this.dialog,
      meterPatternOpacity: meterPatternOpacity ?? this.meterPatternOpacity,
      chartGrid: chartGrid ?? this.chartGrid,
      infoSurface: infoSurface ?? this.infoSurface,
      infoBorder: infoBorder ?? this.infoBorder,
    );
  }

  @override
  DashboardThemeColors lerp(
    covariant ThemeExtension<DashboardThemeColors>? other,
    double t,
  ) {
    if (other is! DashboardThemeColors) return this;
    return DashboardThemeColors(
      background: Color.lerp(background, other.background, t)!,
      card: Color.lerp(card, other.card, t)!,
      cardElevated: Color.lerp(cardElevated, other.cardElevated, t)!,
      border: Color.lerp(border, other.border, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      navy: Color.lerp(navy, other.navy, t)!,
      navyMuted: Color.lerp(navyMuted, other.navyMuted, t)!,
      sidebar: Color.lerp(sidebar, other.sidebar, t)!,
      sidebarBorder: Color.lerp(sidebarBorder, other.sidebarBorder, t)!,
      inputFill: Color.lerp(inputFill, other.inputFill, t)!,
      dialog: Color.lerp(dialog, other.dialog, t)!,
      meterPatternOpacity:
          meterPatternOpacity +
          (other.meterPatternOpacity - meterPatternOpacity) * t,
      chartGrid: Color.lerp(chartGrid, other.chartGrid, t)!,
      infoSurface: Color.lerp(infoSurface, other.infoSurface, t)!,
      infoBorder: Color.lerp(infoBorder, other.infoBorder, t)!,
    );
  }
}

ThemeData buildDashboardLightTheme() => _buildTheme(
  colors: DashboardThemeColors.light,
  brightness: Brightness.light,
);

ThemeData buildDashboardDarkTheme() =>
    _buildTheme(colors: DashboardThemeColors.dark, brightness: Brightness.dark);

ThemeData _buildTheme({
  required DashboardThemeColors colors,
  required Brightness brightness,
}) {
  final isDark = brightness == Brightness.dark;
  final base = isDark
      ? BrandTheme.dark(palette: AppBrandPalette.dashboard)
      : BrandTheme.light(palette: AppBrandPalette.dashboard);
  final scheme = base.colorScheme;

  return base.copyWith(
    scaffoldBackgroundColor: Colors.transparent,
    cardColor: colors.card,
    dividerColor: colors.border,
    extensions: <ThemeExtension<dynamic>>[colors],
    appBarTheme: base.appBarTheme.copyWith(
      backgroundColor: colors.card.withValues(alpha: isDark ? 0.98 : 0.96),
      foregroundColor: colors.textPrimary,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      elevation: 0,
    ),
    cardTheme: base.cardTheme.copyWith(
      color: colors.card,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(BrandRadius.card),
        side: BorderSide(color: colors.border),
      ),
    ),
    inputDecorationTheme: base.inputDecorationTheme.copyWith(
      fillColor: colors.inputFill,
      labelStyle: base.textTheme.bodyMedium?.copyWith(color: colors.textMuted),
      hintStyle: base.textTheme.bodyMedium?.copyWith(color: colors.textMuted),
    ),
    dialogTheme: base.dialogTheme.copyWith(
      backgroundColor: colors.dialog,
      surfaceTintColor: Colors.transparent,
    ),
    bottomSheetTheme: base.bottomSheetTheme.copyWith(
      backgroundColor: colors.dialog,
      modalBackgroundColor: colors.dialog,
      surfaceTintColor: Colors.transparent,
    ),
    chipTheme: base.chipTheme.copyWith(
      backgroundColor: colors.cardElevated,
      selectedColor: scheme.primaryContainer,
      side: BorderSide(color: colors.border),
      labelStyle: base.textTheme.labelMedium?.copyWith(
        color: colors.textPrimary,
      ),
    ),
    popupMenuTheme: base.popupMenuTheme.copyWith(
      color: colors.card,
      surfaceTintColor: Colors.transparent,
    ),
    datePickerTheme: base.datePickerTheme.copyWith(
      backgroundColor: colors.dialog,
      headerBackgroundColor: colors.cardElevated,
      headerForegroundColor: colors.textPrimary,
    ),
    textTheme: BrandType.textTheme(
      ink: colors.textPrimary,
      muted: colors.textMuted,
    ),
  );
}

DashboardThemeColors dashboardColors(BuildContext context) =>
    DashboardThemeColors.of(context);

Color chartGridColor(BuildContext context) =>
    dashboardColors(context).chartGrid;

Color chartLabelColor(BuildContext context) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return isDark ? const Color(0xFFDDE5F1) : const Color(0xFF43506A);
}

Color chartTooltipBg(BuildContext context) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return isDark ? const Color(0xFF182333) : const Color(0xFF141B26);
}

Color chartTooltipFg(BuildContext context) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return isDark ? const Color(0xFFF3EFE4) : const Color(0xFFFFFFFF);
}
