import 'package:flutter/material.dart';

import '../dashboard_palette.dart';
import '../dashboard_theme.dart';

/// Semantic color accessors — never use raw hex in widgets.
abstract final class DashboardColors {
  static Color background(BuildContext context) =>
      dashboardColors(context).background;

  static Color card(BuildContext context) => dashboardColors(context).card;

  static Color cardElevated(BuildContext context) =>
      dashboardColors(context).cardElevated;

  static Color border(BuildContext context) => dashboardColors(context).border;

  static Color textPrimary(BuildContext context) =>
      dashboardColors(context).textPrimary;

  static Color textMuted(BuildContext context) =>
      dashboardColors(context).textMuted;

  static Color sidebar(BuildContext context) =>
      dashboardColors(context).sidebar;

  static Color accent(BuildContext context) =>
      Theme.of(context).colorScheme.primary;

  static Color accentGold(BuildContext context) => DashboardPalette.gold;

  static Color success(BuildContext context) => DashboardPalette.success;

  static Color warning(BuildContext context) => DashboardPalette.warning;

  static Color danger(BuildContext context) => DashboardPalette.danger;

  static Color chartGrid(BuildContext context) =>
      dashboardColors(context).chartGrid;

  static Color photoScrim(BuildContext context) => const Color(0xFF0D1117);
}
