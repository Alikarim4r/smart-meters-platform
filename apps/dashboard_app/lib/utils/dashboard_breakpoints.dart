import 'package:flutter/material.dart';

/// Layout breakpoints for Dashboard App (mobile / tablet / desktop).
abstract final class DashboardBreakpoints {
  static const double mobile = 700;
  static const double sidebar = 900;
  static const double desktop = 1200;
  static const double maxContentWidth = 1500;
  static const double maxContentWidthLarge = 1600;
  static const double largeDesktop = 1440;

  static double contentMaxWidth(BuildContext context) {
    final w = widthOf(context);
    if (w >= largeDesktop) return maxContentWidthLarge;
    if (isDesktop(context)) return maxContentWidth;
    return double.infinity;
  }

  static double widthOf(BuildContext context) =>
      MediaQuery.sizeOf(context).width;

  static bool isMobile(BuildContext context) => widthOf(context) < mobile;

  static bool useSidebar(BuildContext context) => widthOf(context) >= sidebar;

  static bool isDesktop(BuildContext context) => widthOf(context) >= desktop;

  static bool isTablet(BuildContext context) {
    final w = widthOf(context);
    return w >= mobile && w < desktop;
  }

  static int kpiColumns(BuildContext context) {
    final w = widthOf(context);
    if (w >= desktop) return 6;
    if (w >= sidebar) return 4;
    if (w >= mobile) return 3;
    return 2;
  }

  static int siteCardColumns(BuildContext context) {
    final w = widthOf(context);
    if (w >= desktop) return 3;
    if (w >= sidebar) return 2;
    return 1;
  }

  static double contentPadding(BuildContext context) {
    if (isDesktop(context)) return 32;
    if (useSidebar(context)) return 24;
    return 16;
  }
}
