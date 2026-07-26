import 'package:flutter/material.dart';

import '../../l10n/app_strings.dart';
import '../../theme/design_system/dashboard_design_system.dart';
import '../../theme/dashboard_theme.dart';
import '../../theme/glass_surface.dart';
import '../../utils/chart_period_selection.dart';

class AnalyticsControlPanel extends StatelessWidget {
  const AnalyticsControlPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(DashboardSpacing.sm),
  });

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return GlassSurface(
      padding: padding,
      borderRadius: DashboardRadius.control + 2,
      useBlur: false,
      child: child,
    );
  }
}

class ChartPeriodControls extends StatelessWidget {
  const ChartPeriodControls({
    super.key,
    required this.state,
    required this.onChanged,
    this.customRangeActive = false,
  });

  final UtilityChartPeriodState state;
  final ValueChanged<UtilityChartPeriodState> onChanged;

  /// When true, a non-preset custom range drives the chart.
  final bool customRangeActive;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    return AnalyticsControlPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(s.period, style: DashboardTypography.sectionTitle(context)),
          const SizedBox(height: DashboardSpacing.xs),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final kind in UtilityChartPeriodKind.values)
                  Padding(
                    padding:
                        const EdgeInsets.only(right: DashboardSpacing.xs - 2),
                    child: _PeriodChip(
                      kind: kind,
                      state: state,
                      selected: !customRangeActive && state.kind == kind,
                      onChanged: onChanged,
                    ),
                  ),
                if (customRangeActive)
                  Padding(
                    padding:
                        const EdgeInsets.only(right: DashboardSpacing.xs - 2),
                    child: _CustomPeriodChip(label: s.customRange),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PeriodChip extends StatelessWidget {
  const _PeriodChip({
    required this.kind,
    required this.state,
    required this.selected,
    required this.onChanged,
  });

  final UtilityChartPeriodKind kind;
  final UtilityChartPeriodState state;
  final bool selected;
  final ValueChanged<UtilityChartPeriodState> onChanged;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final colors = dashboardColors(context);

    return ChoiceChip(
      label: Text(
        s.chartPeriodKindLabel(kind),
        style: TextStyle(
          fontSize: 12,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          color: selected ? colors.textPrimary : colors.textMuted,
        ),
      ),
      selected: selected,
      selectedColor: colors.cardElevated,
      backgroundColor: colors.background,
      side: BorderSide(
        color: selected
            ? DashboardColors.accent(context).withValues(alpha: 0.35)
            : colors.border.withValues(alpha: 0.6),
      ),
      onSelected: (_) {
        final next = state.selectKind(kind);
        if (next != state || !selected) onChanged(next);
      },
    );
  }
}

class _CustomPeriodChip extends StatelessWidget {
  const _CustomPeriodChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = dashboardColors(context);
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: colors.textPrimary,
        ),
      ),
      selected: true,
      selectedColor: colors.cardElevated,
      backgroundColor: colors.background,
      side: BorderSide(
        color: DashboardColors.accent(context).withValues(alpha: 0.35),
      ),
      onSelected: null,
    );
  }
}

class ChartTypeControls extends StatelessWidget {
  const ChartTypeControls({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    return AnalyticsControlPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(s.chartType, style: DashboardTypography.sectionTitle(context)),
          const SizedBox(height: DashboardSpacing.xs),
          child,
        ],
      ),
    );
  }
}
