import 'package:flutter/material.dart';

import '../dashboard_theme.dart';

/// Semantic text styles derived from theme tokens.
abstract final class DashboardTypography {
  static TextStyle pageTitle(BuildContext context) =>
      Theme.of(context).textTheme.titleMedium!.copyWith(
            fontWeight: FontWeight.w800,
            color: dashboardColors(context).textPrimary,
            letterSpacing: -0.2,
          );

  static TextStyle sectionTitle(BuildContext context) =>
      Theme.of(context).textTheme.titleSmall!.copyWith(
            fontWeight: FontWeight.w700,
            color: dashboardColors(context).textPrimary,
          );

  static TextStyle label(BuildContext context) =>
      Theme.of(context).textTheme.labelMedium!.copyWith(
            fontWeight: FontWeight.w600,
            color: dashboardColors(context).textMuted,
            fontSize: 12,
          );

  static TextStyle meterCode(BuildContext context) =>
      Theme.of(context).textTheme.bodySmall!.copyWith(
            fontWeight: FontWeight.w500,
            color: dashboardColors(context).textMuted,
            fontSize: 12,
            height: 1.15,
          );

  static TextStyle meterName(BuildContext context) =>
      Theme.of(context).textTheme.titleSmall!.copyWith(
            fontWeight: FontWeight.w800,
            color: dashboardColors(context).textPrimary,
            height: 1.1,
            letterSpacing: -0.3,
          );

  static TextStyle kpiValue(BuildContext context) =>
      Theme.of(context).textTheme.titleLarge!.copyWith(
            fontWeight: FontWeight.w800,
            color: dashboardColors(context).textPrimary,
            fontSize: 22,
            height: 1.05,
            letterSpacing: -0.3,
          );

  static TextStyle chip(BuildContext context) => TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w600,
        color: dashboardColors(context).textPrimary,
      );
}
