import 'package:flutter/material.dart';
import 'package:smart_meters_core/smart_meters_core.dart';

import '../../theme/dashboard_palette.dart';
import '../../theme/design_system/dashboard_design_system.dart';

class MeterStatusBadge extends StatelessWidget {
  const MeterStatusBadge({
    super.key,
    required this.label,
    required this.color,
    this.compact = false,
    this.muted = false,
  });

  final String label;
  final Color color;
  final bool compact;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final effectiveColor = muted ? DashboardPalette.textMuted : color;
    final fontSize = compact ? 10.0 : 11.0;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? DashboardSpacing.xs - 2 : DashboardSpacing.xs,
        vertical: compact ? DashboardSpacing.xxs - 1 : DashboardSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: effectiveColor.withValues(alpha: muted ? 0.06 : 0.08),
        borderRadius: BorderRadius.circular(DashboardRadius.chip),
      ),
      child: Text(
        label,
        style: DashboardTypography.chip(context).copyWith(
          fontSize: fontSize,
          color: effectiveColor,
        ),
      ),
    );
  }
}

class AlertSeverityBadge extends StatelessWidget {
  const AlertSeverityBadge({
    super.key,
    required this.severity,
    this.compact = false,
  });

  final AlertSeverity severity;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final color = switch (severity) {
      AlertSeverity.critical => DashboardPalette.danger,
      AlertSeverity.warning => DashboardPalette.warning,
      AlertSeverity.info => DashboardPalette.water,
    };
    return MeterStatusBadge(
      label: severity.label,
      color: color,
      compact: compact,
    );
  }
}
