import 'package:flutter/material.dart';

/// Single-shadow elevation system — no stacked glows.
abstract final class DashboardShadows {
  static List<BoxShadow> card(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return [
      BoxShadow(
        color: Colors.black.withValues(alpha: isDark ? 0.14 : 0.04),
        blurRadius: 10,
        offset: const Offset(0, 2),
      ),
    ];
  }

  static List<BoxShadow> header(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return [
      BoxShadow(
        color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
        blurRadius: 6,
        offset: const Offset(0, 1),
      ),
    ];
  }

  static List<BoxShadow> none = const [];
}
