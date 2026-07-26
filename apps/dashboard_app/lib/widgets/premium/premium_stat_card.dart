import 'package:flutter/material.dart';

import '../../theme/design_system/dashboard_design_system.dart';
import '../../theme/dashboard_theme.dart';
import 'premium_dashboard_card.dart';

/// Compact executive KPI card for utility summaries.
class PremiumStatCard extends StatelessWidget {
  const PremiumStatCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.subtitle,
    this.accent,
    this.emphasize = false,
  });

  final String label;
  final String value;
  final String? subtitle;
  final IconData icon;
  final Color? accent;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final colors = dashboardColors(context);
    final color = accent ?? colors.navy;

    return SizedBox(
      height: 112,
      child: PremiumDashboardCard(
        padding: const EdgeInsets.all(DashboardSpacing.md - 2),
        borderColor: emphasize
            ? DashboardColors.accentGold(context).withValues(alpha: 0.2)
            : colors.border.withValues(alpha: 0.4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: colors.cardElevated,
                borderRadius: BorderRadius.circular(DashboardRadius.control - 1),
              ),
              child: Icon(icon, color: color, size: DashboardIcons.md - 2),
            ),
            const SizedBox(width: DashboardSpacing.sm),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: DashboardTypography.kpiValue(context),
                  ),
                  const SizedBox(height: DashboardSpacing.xxs - 1),
                  Text(
                    label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: DashboardTypography.label(context),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: DashboardSpacing.xxs - 1),
                    Text(
                      subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: DashboardTypography.label(context).copyWith(
                        color: color,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
