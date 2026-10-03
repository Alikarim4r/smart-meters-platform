import 'package:flutter/material.dart';

import 'app_brand_palette.dart';
import 'brand_chrome.dart';
import 'brand_tokens.dart';

/// Shared Material themes for every Smart Meters app.
///
/// The structure (type scale, corners, depth, component behavior) is identical
/// across apps; only the accent palette changes. Pass [palette] to build for a
/// specific app; by default the active [BrandChrome] palette is used.
abstract final class BrandTheme {
  static ThemeData light({AppBrandPalette? palette}) =>
      _build(palette ?? BrandChrome.palette, Brightness.light);

  static ThemeData dark({AppBrandPalette? palette}) =>
      _build(palette ?? BrandChrome.palette, Brightness.dark);

  /// Accent lifted toward its soft tint so it stays legible on dark surfaces.
  static Color liftedAccent(AppBrandPalette p) =>
      Color.lerp(p.accent, p.accentSoft, 0.45)!;

  static ColorScheme colorScheme(AppBrandPalette p, Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final danger = BrandStatus.danger(isDark: isDark);
    if (!isDark) {
      return ColorScheme.fromSeed(
        seedColor: p.accent,
        brightness: Brightness.light,
      ).copyWith(
        primary: p.accent,
        onPrimary: p.onAccent,
        primaryContainer: p.accentSoft,
        onPrimaryContainer: p.accentDeep,
        secondary: p.accentSoft,
        onSecondary: p.ink,
        secondaryContainer: p.accentSoft.withValues(alpha: 0.55),
        onSecondaryContainer: p.ink,
        tertiary: p.primary,
        onTertiary: Colors.white,
        surface: p.surface,
        onSurface: p.ink,
        onSurfaceVariant: p.inkMuted,
        surfaceDim: const Color(0xFFE9ECF0),
        surfaceBright: Colors.white,
        surfaceContainerLowest: Colors.white,
        surfaceContainerLow: const Color(0xFFFAFBFC),
        surfaceContainer: const Color(0xFFF5F7F9),
        surfaceContainerHigh: const Color(0xFFF0F2F5),
        surfaceContainerHighest: const Color(0xFFE9ECF0),
        surfaceTint: Colors.transparent,
        outline: p.borderLight,
        outlineVariant: Color.lerp(p.borderLight, Colors.white, 0.45),
        inverseSurface: p.ink,
        onInverseSurface: Colors.white,
        inversePrimary: p.accentSoft,
        error: danger,
        onError: Colors.white,
        errorContainer: const Color(0xFFFBE9E7),
        onErrorContainer: const Color(0xFF7A1A14),
        shadow: const Color(0xFF0B1220),
        scrim: const Color(0xFF0B1220),
      );
    }
    final lifted = liftedAccent(p);
    return ColorScheme.fromSeed(
      seedColor: p.accent,
      brightness: Brightness.dark,
    ).copyWith(
      primary: lifted,
      onPrimary: p.canvasDark,
      primaryContainer: Color.alphaBlend(
        p.accent.withValues(alpha: 0.38),
        p.surfaceDark,
      ),
      onPrimaryContainer: p.accentSoft,
      secondary: p.accentSoft,
      onSecondary: p.primary,
      secondaryContainer: p.accent.withValues(alpha: 0.22),
      onSecondaryContainer: p.accentSoft,
      tertiary: p.accentSoft,
      onTertiary: p.canvasDark,
      surface: p.surfaceDark,
      onSurface: p.textDark,
      onSurfaceVariant: p.textDarkMuted,
      surfaceDim: p.canvasDark,
      surfaceBright: p.surfaceDarkHigh,
      surfaceContainerLowest: p.canvasDark,
      surfaceContainerLow: Color.lerp(p.canvasDark, p.surfaceDark, 0.5),
      surfaceContainer: p.surfaceDark,
      surfaceContainerHigh: p.surfaceDarkHigh,
      surfaceContainerHighest: Color.lerp(
        p.surfaceDarkHigh,
        p.borderDark,
        0.35,
      ),
      surfaceTint: Colors.transparent,
      outline: p.borderDark,
      outlineVariant: Color.lerp(p.borderDark, p.surfaceDark, 0.45),
      inverseSurface: p.textDark,
      onInverseSurface: p.canvasDark,
      inversePrimary: p.accent,
      error: danger,
      onError: const Color(0xFF2A0B0B),
      errorContainer: const Color(0xFF4A1A1A),
      onErrorContainer: const Color(0xFFFFDAD6),
      shadow: Colors.black,
      scrim: Colors.black,
    );
  }

  static ThemeData _build(AppBrandPalette p, Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final scheme = colorScheme(p, brightness);
    final ink = scheme.onSurface;
    final muted = scheme.onSurfaceVariant;
    final hairline = scheme.outline;
    final panel = isDark ? p.surfaceDark : p.surface;
    final glyph = isDark ? p.textDarkMuted : p.iconGlyph;
    final text = BrandType.textTheme(ink: ink, muted: muted);

    RoundedRectangleBorder rounded(double r, {BorderSide? side}) =>
        RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(r),
          side: side ?? BorderSide.none,
        );

    final controlShape = rounded(BrandRadius.control);
    const buttonMinSize = Size(64, BrandSpace.touchTarget);
    const buttonPadding = EdgeInsets.symmetric(
      horizontal: BrandSpace.lg,
      vertical: BrandSpace.sm,
    );

    final snackBackground = isDark
        ? Color.lerp(p.surfaceDarkHigh, p.borderDark, 0.4)!
        : p.ink;
    final snackForeground = isDark ? p.textDark : Colors.white;

    OutlineInputBorder field(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(BrandRadius.control),
          borderSide: BorderSide(color: color, width: width),
        );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      textTheme: text,
      scaffoldBackgroundColor: Colors.transparent,
      canvasColor: panel,
      cardColor: panel,
      dividerColor: scheme.outlineVariant,
      splashFactory: InkRipple.splashFactory,
      iconTheme: IconThemeData(color: glyph, size: 22),
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0.5,
        shadowColor: scheme.shadow.withValues(alpha: isDark ? 0.5 : 0.12),
        centerTitle: false,
        backgroundColor: panel,
        foregroundColor: ink,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: text.titleLarge,
        iconTheme: IconThemeData(color: ink, size: 22),
        actionsIconTheme: IconThemeData(color: ink, size: 22),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: panel,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        shape: rounded(BrandRadius.card, side: BorderSide(color: hairline)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          disabledBackgroundColor: ink.withValues(alpha: 0.08),
          disabledForegroundColor: ink.withValues(alpha: 0.38),
          minimumSize: buttonMinSize,
          padding: buttonPadding,
          textStyle: text.labelLarge,
          shape: controlShape,
          elevation: 0,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: scheme.primaryContainer,
          foregroundColor: scheme.onPrimaryContainer,
          minimumSize: buttonMinSize,
          padding: buttonPadding,
          textStyle: text.labelLarge,
          shape: controlShape,
          elevation: 0,
          shadowColor: Colors.transparent,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: ink,
          side: BorderSide(color: hairline),
          minimumSize: buttonMinSize,
          padding: buttonPadding,
          textStyle: text.labelLarge,
          shape: controlShape,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: isDark ? scheme.primary : p.accentDeep,
          minimumSize: const Size(48, BrandSpace.touchTarget),
          padding: const EdgeInsets.symmetric(horizontal: BrandSpace.md),
          textStyle: text.labelLarge,
          shape: controlShape,
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(48, 44)),
          textStyle: WidgetStatePropertyAll(text.labelMedium),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return scheme.primaryContainer;
            }
            return Colors.transparent;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return scheme.onPrimaryContainer;
            }
            return muted;
          }),
          iconColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return scheme.onPrimaryContainer;
            }
            return muted;
          }),
          side: WidgetStatePropertyAll(BorderSide(color: hairline)),
          shape: WidgetStatePropertyAll(controlShape),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        selectedColor: scheme.primaryContainer,
        disabledColor: ink.withValues(alpha: 0.06),
        checkmarkColor: scheme.onPrimaryContainer,
        deleteIconColor: muted,
        labelStyle: text.labelMedium?.copyWith(color: ink),
        secondaryLabelStyle: text.labelMedium?.copyWith(
          color: scheme.onPrimaryContainer,
        ),
        side: BorderSide(color: hairline),
        padding: const EdgeInsets.symmetric(horizontal: BrandSpace.xxs),
        labelPadding: const EdgeInsets.symmetric(horizontal: BrandSpace.xs),
        shape: rounded(BrandRadius.chip),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? p.surfaceDarkHigh : scheme.surfaceContainerLow,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: BrandSpace.md,
          vertical: 14,
        ),
        labelStyle: text.bodyMedium?.copyWith(color: muted),
        floatingLabelStyle: text.labelMedium?.copyWith(color: scheme.primary),
        hintStyle: text.bodyMedium?.copyWith(
          color: muted.withValues(alpha: 0.8),
        ),
        helperStyle: text.bodySmall,
        errorStyle: text.bodySmall?.copyWith(color: scheme.error),
        prefixIconColor: muted,
        suffixIconColor: muted,
        border: field(hairline),
        enabledBorder: field(hairline),
        disabledBorder: field(hairline.withValues(alpha: 0.5)),
        focusedBorder: field(scheme.primary, 1.6),
        errorBorder: field(scheme.error),
        focusedErrorBorder: field(scheme.error, 1.6),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        elevation: 0,
        backgroundColor: panel,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        indicatorColor: scheme.primaryContainer,
        indicatorShape: const StadiumBorder(),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return text.labelMedium?.copyWith(
            color: selected ? ink : muted,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: scheme.onPrimaryContainer, size: 24);
          }
          return IconThemeData(color: muted, size: 24);
        }),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: panel,
        indicatorColor: scheme.primaryContainer,
        indicatorShape: const StadiumBorder(),
        selectedIconTheme: IconThemeData(color: scheme.onPrimaryContainer),
        unselectedIconTheme: IconThemeData(color: muted),
        selectedLabelTextStyle: text.labelMedium?.copyWith(color: ink),
        unselectedLabelTextStyle: text.labelMedium?.copyWith(
          color: muted,
          fontWeight: FontWeight.w500,
        ),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: ink,
        unselectedLabelColor: muted,
        labelStyle: text.titleSmall,
        unselectedLabelStyle: text.titleSmall?.copyWith(
          fontWeight: FontWeight.w500,
        ),
        indicatorColor: scheme.primary,
        dividerColor: scheme.outlineVariant,
      ),
      drawerTheme: DrawerThemeData(
        backgroundColor: panel,
        surfaceTintColor: Colors.transparent,
        scrimColor: scheme.scrim.withValues(alpha: isDark ? 0.6 : 0.32),
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadiusDirectional.horizontal(
            end: Radius.circular(BrandRadius.dialog),
          ),
        ),
        endShape: const RoundedRectangleBorder(
          borderRadius: BorderRadiusDirectional.horizontal(
            start: Radius.circular(BrandRadius.dialog),
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: panel,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shadowColor: scheme.shadow.withValues(alpha: isDark ? 0.6 : 0.18),
        shape: rounded(
          BrandRadius.dialog,
          side: isDark ? BorderSide(color: hairline) : BorderSide.none,
        ),
        titleTextStyle: text.headlineSmall,
        contentTextStyle: text.bodyMedium?.copyWith(color: muted),
        insetPadding: const EdgeInsets.all(BrandSpace.xl),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: panel,
        modalBackgroundColor: panel,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        modalElevation: 8,
        shadowColor: scheme.shadow.withValues(alpha: 0.2),
        dragHandleColor: muted.withValues(alpha: 0.4),
        dragHandleSize: const Size(36, 4),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(BrandRadius.sheet),
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: snackBackground,
        contentTextStyle: text.bodyMedium?.copyWith(
          color: snackForeground,
          fontWeight: FontWeight.w500,
        ),
        actionTextColor: isDark ? scheme.primary : p.accentSoft,
        closeIconColor: snackForeground.withValues(alpha: 0.8),
        elevation: 6,
        insetPadding: const EdgeInsets.fromLTRB(
          BrandSpace.md,
          0,
          BrandSpace.md,
          BrandSpace.md,
        ),
        shape: rounded(
          BrandRadius.control,
          side: isDark ? BorderSide(color: p.borderDark) : BorderSide.none,
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: isDark ? p.textDark : p.ink,
          borderRadius: BorderRadius.circular(BrandRadius.badge + 2),
        ),
        textStyle: text.labelMedium?.copyWith(
          color: isDark ? p.canvasDark : Colors.white,
          fontWeight: FontWeight.w500,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: BrandSpace.sm,
          vertical: 6,
        ),
        waitDuration: const Duration(milliseconds: 400),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: isDark ? p.surfaceDarkHigh : p.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shadowColor: scheme.shadow.withValues(alpha: isDark ? 0.6 : 0.16),
        textStyle: text.bodyMedium,
        shape: rounded(BrandRadius.control, side: BorderSide(color: hairline)),
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: panel,
        surfaceTintColor: Colors.transparent,
        headerBackgroundColor: scheme.primaryContainer,
        headerForegroundColor: scheme.onPrimaryContainer,
        shape: rounded(BrandRadius.dialog),
      ),
      timePickerTheme: TimePickerThemeData(
        backgroundColor: panel,
        shape: rounded(BrandRadius.dialog),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: glyph,
        textColor: ink,
        minVerticalPadding: 10,
        shape: controlShape,
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        thickness: 1,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: scheme.primaryContainer,
        circularTrackColor: Colors.transparent,
        linearMinHeight: 4,
        borderRadius: BorderRadius.circular(BrandRadius.pill),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        elevation: 2,
        focusElevation: 3,
        hoverElevation: 3,
        highlightElevation: 4,
        extendedPadding: const EdgeInsets.symmetric(horizontal: BrandSpace.lg),
        extendedTextStyle: text.labelLarge,
        shape: rounded(BrandRadius.card),
      ),
      checkboxTheme: CheckboxThemeData(
        shape: rounded(BrandRadius.badge - 1),
        side: BorderSide(color: muted, width: 1.5),
      ),
      badgeTheme: BadgeThemeData(
        backgroundColor: scheme.error,
        textColor: scheme.onError,
      ),
    );
  }
}
