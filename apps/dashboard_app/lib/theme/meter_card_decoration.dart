import 'package:flutter/material.dart';
import 'package:smart_meters_core/smart_meters_core.dart';

import 'dashboard_palette.dart';
import 'design_system/dashboard_design_system.dart';
import '../utils/site_system_navigation.dart';

BoxDecoration meterCardDecoration({
  required BuildContext context,
  required String utilityKey,
  bool isMain = false,
}) {
  final accent = _utilityAccentColor(utilityKey);
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final borderColor = isMain
      ? accent.withValues(alpha: isDark ? 0.55 : 0.42)
      : BrandChrome.border(
          isDark: isDark,
          scheme: Theme.of(context).colorScheme,
        );
  final borderWidth = isMain ? 1.4 : 1.2;

  // Dark mode: keep meter cards translucent so the page motif shows through.
  if (isDark) {
    return BoxDecoration(
      borderRadius: BorderRadius.circular(DashboardRadius.card),
      color: BrandChrome.surfaceDark.withValues(alpha: 0.42),
      border: Border.all(color: borderColor, width: borderWidth),
    );
  }

  final base = brandCardDecoration(context, radius: DashboardRadius.card);
  return base.copyWith(
    border: Border.all(color: borderColor, width: borderWidth),
  );
}

/// Meter card shell — same brand wash as Entry cards.
class MeterGlassCard extends StatelessWidget {
  const MeterGlassCard({
    super.key,
    required this.utilityKey,
    required this.isMain,
    required this.child,
  });

  final String utilityKey;
  final bool isMain;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(DashboardRadius.card);
    return ClipRRect(
      borderRadius: radius,
      child: DecoratedBox(
        decoration: meterCardDecoration(
          context: context,
          utilityKey: utilityKey,
          isMain: isMain,
        ),
        child: child,
      ),
    );
  }
}

Widget meterCardAccentStrip({
  required String utilityKey,
  bool isMain = false,
}) {
  final accent = _utilityAccentColor(utilityKey);
  return Container(
    width: isMain ? 3 : 2,
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          accent.withValues(alpha: isMain ? 0.9 : 0.55),
          accent.withValues(alpha: isMain ? 0.45 : 0.25),
        ],
      ),
      borderRadius: const BorderRadius.horizontal(
        left: Radius.circular(DashboardRadius.card),
      ),
    ),
  );
}

Color _utilityAccentColor(String utilityKey) {
  return switch (utilityKey) {
    'water' => DashboardPalette.water,
    'electricity' => DashboardPalette.electricity,
    'btu' => DashboardPalette.btu,
    'fuel' => DashboardPalette.fuel,
    _ => DashboardPalette.navyMuted,
  };
}

String utilityKeyFromCard(MeterReadingCardData card) {
  final category = card.categoryName.toLowerCase();
  if (category.contains('water')) return UtilitySystemKey.water.categoryCode;
  if (category.contains('electric')) {
    return UtilitySystemKey.electricity.categoryCode;
  }
  if (category.contains('btu') || category.contains('cool')) {
    return UtilitySystemKey.btu.categoryCode;
  }
  return UtilitySystemKey.fuel.categoryCode;
}
