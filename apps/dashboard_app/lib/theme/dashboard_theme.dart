import 'package:flutter/material.dart';

import 'design_system/dashboard_radius.dart';

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
    background: Color(0xFFFFFFFF),
    card: Color(0xFFFFFFFF),
    cardElevated: Color(0xFFF7F9FC),
    border: Color(0xFFE2E6EB),
    textPrimary: Color(0xFF1B2430),
    textMuted: Color(0xFF5C6775),
    navy: Color(0xFF1B2430),
    navyMuted: Color(0xFF3D5A80),
    sidebar: Color(0xFF1B2430),
    sidebarBorder: Color(0xFF273141),
    inputFill: Color(0xFFFFFFFF),
    dialog: Color(0xFFFFFFFF),
    meterPatternOpacity: 0,
    chartGrid: Color(0xFFE2E6EB),
    infoSurface: Color(0xFFEEF2F6),
    infoBorder: Color(0xFFE2E6EB),
  );

  static const dark = DashboardThemeColors(
    background: Color(0xFF07111F),
    card: Color(0xFF12233A),
    cardElevated: Color(0xFF1A314D),
    border: Color(0xFF2C4566),
    textPrimary: Color(0xFFF3EFE4),
    textMuted: Color(0xFFB7C5D8),
    navy: Color(0xFFF3EFE4),
    navyMuted: Color(0xFFB7C5D8),
    sidebar: Color(0xFF050B14),
    sidebarBorder: Color(0xFF152238),
    inputFill: Color(0xFF1A314D),
    dialog: Color(0xFF0E1A2C),
    meterPatternOpacity: 0,
    chartGrid: Color(0xFF2C4566),
    infoSurface: Color(0xFF12233A),
    infoBorder: Color(0xFF2C4566),
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
          meterPatternOpacity + (other.meterPatternOpacity - meterPatternOpacity) * t,
      chartGrid: Color.lerp(chartGrid, other.chartGrid, t)!,
      infoSurface: Color.lerp(infoSurface, other.infoSurface, t)!,
      infoBorder: Color.lerp(infoBorder, other.infoBorder, t)!,
    );
  }
}

ThemeData buildDashboardLightTheme() {
  const colors = DashboardThemeColors.light;
  final colorScheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF1B2430),
    brightness: Brightness.light,
    primary: const Color(0xFF3D5A80),
    onPrimary: Colors.white,
    secondary: const Color(0xFFD9E2EC),
    onSecondary: const Color(0xFF1B2430),
    surface: Colors.white,
    onSurface: colors.textPrimary,
    surfaceContainerLowest: Colors.white,
    surfaceContainerLow: Colors.white,
    surfaceContainer: Colors.white,
    surfaceContainerHigh: const Color(0xFFF7F9FC),
    surfaceContainerHighest: const Color(0xFFF3F5F8),
    surfaceTint: Colors.transparent,
    secondaryContainer: const Color(0xFFD9E2EC).withValues(alpha: 0.55),
    onSecondaryContainer: const Color(0xFF1B2430),
    outline: colors.border,
  );
  return _buildTheme(colors: colors, colorScheme: colorScheme);
}

ThemeData buildDashboardDarkTheme() {
  const colors = DashboardThemeColors.dark;
  final colorScheme = ColorScheme.dark(
    primary: const Color(0xFF3D5A80),
    onPrimary: Colors.white,
    secondary: const Color(0xFFD9E2EC),
    onSecondary: const Color(0xFF1B2430),
    surface: colors.card,
    onSurface: colors.textPrimary,
    onSurfaceVariant: colors.textMuted,
    outline: colors.border,
    outlineVariant: const Color(0xFF24344C),
    surfaceContainerHighest: colors.cardElevated,
    surfaceContainerHigh: const Color(0xFF1A314D),
    surfaceContainer: colors.card,
    surfaceContainerLow: const Color(0xFF0E1A2C),
    surfaceContainerLowest: colors.background,
    secondaryContainer: const Color(0xFF3D5A80).withValues(alpha: 0.22),
    onSecondaryContainer: const Color(0xFFD9E2EC),
    error: const Color(0xFFF07178),
    onError: const Color(0xFF1A0A0C),
  );
  return _buildTheme(colors: colors, colorScheme: colorScheme);
}

ThemeData _buildTheme({
  required DashboardThemeColors colors,
  required ColorScheme colorScheme,
}) {
  final base = ThemeData(
    useMaterial3: true,
    brightness: colorScheme.brightness,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: Colors.transparent,
    cardColor: colors.card,
    dividerColor: colors.border,
    dialogTheme: DialogThemeData(
      backgroundColor: colors.dialog,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DashboardRadius.dialog),
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: colors.dialog,
      surfaceTintColor: Colors.transparent,
      modalBackgroundColor: colors.dialog,
      dragHandleColor: colors.textMuted.withValues(alpha: 0.45),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return colors.textPrimary;
          }
          return colors.textMuted;
        }),
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const Color(0xFF3D5A80).withValues(
              alpha: colorScheme.brightness == Brightness.dark ? 0.24 : 0.22,
            );
          }
          return colors.inputFill;
        }),
        iconColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return colorScheme.brightness == Brightness.dark
                ? const Color(0xFFD9E2EC)
                : const Color(0xFF1B2430);
          }
          return colors.textMuted;
        }),
        side: WidgetStatePropertyAll(BorderSide(color: colors.border)),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DashboardRadius.control),
          ),
        ),
      ),
    ),
    radioTheme: RadioThemeData(
      fillColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return colorScheme.primary;
        }
        return colors.textMuted;
      }),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: colors.card,
      surfaceTintColor: Colors.transparent,
    ),
    chipTheme: ChipThemeData(
      backgroundColor: colors.cardElevated,
      selectedColor: const Color(0xFF3D5A80).withValues(alpha: 0.28),
      labelStyle: TextStyle(color: colors.textPrimary, fontSize: 12),
      side: BorderSide(color: colors.border),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DashboardRadius.chip + 2),
      ),
    ),
    dividerTheme: DividerThemeData(color: colors.border, thickness: 1),
    extensions: [colors],
  );
  return base.copyWith(
    appBarTheme: AppBarTheme(
      backgroundColor: colors.card,
      foregroundColor: colors.textPrimary,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: const Color(0xFF3D5A80),
        foregroundColor: colorScheme.brightness == Brightness.dark
            ? const Color(0xFF0B1F3A)
            : const Color(0xFF2C2208),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DashboardRadius.control),
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: colors.inputFill,
      labelStyle: TextStyle(color: colors.textMuted),
      hintStyle: TextStyle(color: colors.textMuted),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(DashboardRadius.control),
        borderSide: BorderSide(color: colors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(DashboardRadius.control),
        borderSide: BorderSide(color: colors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(DashboardRadius.control),
        borderSide: BorderSide(color: colorScheme.primary, width: 1),
      ),
    ),
    textTheme: base.textTheme.apply(
      bodyColor: colors.textPrimary,
      displayColor: colors.textPrimary,
    ),
    datePickerTheme: DatePickerThemeData(
      backgroundColor: colors.dialog,
      headerBackgroundColor: colors.cardElevated,
      headerForegroundColor: colors.textPrimary,
      dayForegroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return Colors.white;
        }
        return colors.textPrimary;
      }),
    ),
  );
}

DashboardThemeColors dashboardColors(BuildContext context) =>
    DashboardThemeColors.of(context);

Color chartGridColor(BuildContext context) => dashboardColors(context).chartGrid;

Color chartLabelColor(BuildContext context) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return isDark ? const Color(0xFFD5E0EE) : const Color(0xFF3F3426);
}

Color chartTooltipBg(BuildContext context) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return isDark ? const Color(0xFF12233A) : const Color(0xFF3F3426);
}

Color chartTooltipFg(BuildContext context) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return isDark ? const Color(0xFFF3EFE4) : const Color(0xFFFFFFFF);
}
