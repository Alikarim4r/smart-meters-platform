import 'package:flutter/material.dart';
import 'package:smart_meters_core/smart_meters_core.dart';

import '../../theme/dashboard_theme.dart';

/// Quiet premium canvas that keeps data, not decoration, as the focal point.
class DashboardBackground extends StatelessWidget {
  const DashboardBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = dashboardColors(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return BrandSurfaceBackground(
      showMotif: false,
      child: DecoratedBox(
        decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            colors.background,
            Color.alphaBlend(
              colors.cardElevated.withValues(alpha: isDark ? 0.16 : 0.10),
              colors.background,
            ),
            colors.background,
          ],
          stops: const [0, 0.48, 1],
        ),
      ),
        child: child,
      ),
    );
  }
}
