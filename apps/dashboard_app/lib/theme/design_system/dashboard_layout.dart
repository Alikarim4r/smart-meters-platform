import '../dashboard_spacing.dart';

/// Page rhythm and structural spacing — never stack sections without gaps.
abstract final class DashboardLayout {
  static const double sidebarExpanded = 272;
  static const double sidebarCollapsed = 72;
  static const double navRowHeight = 48;
  static const double headerHeight = 56;
  static const double meterCardWidth = 332;
  static const double kpiHeight = 88;
  static const double analyticsMinHeight = 480;

  static const double sectionGap = DashboardSpacing.xxl;
  static const double blockGap = DashboardSpacing.xl;
  static const double itemGap = DashboardSpacing.md;

  static double pagePadding(bool desktop) =>
      desktop ? DashboardSpacing.xxl : DashboardSpacing.md;
}
