import 'package:flutter/material.dart';

import '../../theme/design_system/dashboard_design_system.dart';
import '../../theme/dashboard_theme.dart';
import '../../theme/glass_surface.dart';

class PremiumDashboardCard extends StatelessWidget {
  const PremiumDashboardCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(DashboardSpacing.lg),
    this.margin,
    this.borderColor,
  });

  final Widget child;
  final EdgeInsets padding;
  final EdgeInsets? margin;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final colors = dashboardColors(context);

    return GlassSurface(
      margin: margin,
      padding: padding,
      borderRadius: DashboardRadius.card,
      borderColor: borderColor ?? colors.border.withValues(alpha: 0.45),
      useBlur: false,
      child: child,
    );
  }
}
