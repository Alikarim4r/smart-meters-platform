import 'package:flutter/material.dart';

import '../../theme/design_system/dashboard_design_system.dart';

class ExecutiveKpi {
  const ExecutiveKpi({
    required this.label,
    required this.value,
    required this.icon,
    this.accent,
    this.emphasize = false,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color? accent;
  final bool emphasize;
}

/// Compact executive KPI row — calm, equal height, minimal shadow.
class ExecutiveKpiStrip extends StatelessWidget {
  const ExecutiveKpiStrip({
    super.key,
    required this.items,
  });

  final List<ExecutiveKpi> items;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 720;
        final narrow = constraints.maxWidth < 520;
        // Phones: 2×2 grid — never stack four tall tiles.
        if (narrow || !wide) {
          final cols = wide ? items.length : 2;
          final gap = DashboardSpacing.sm;
          final tileWidth = cols == 1
              ? constraints.maxWidth
              : (constraints.maxWidth - gap) / 2;
          return Wrap(
            spacing: gap,
            runSpacing: gap,
            children: [
              for (final item in items)
                SizedBox(
                  width: tileWidth,
                  child: _KpiTile(item: item, compact: narrow),
                ),
            ],
          );
        }
        return Row(
          children: [
            for (var i = 0; i < items.length; i++) ...[
              if (i > 0) const SizedBox(width: DashboardSpacing.sm),
              Expanded(child: _KpiTile(item: items[i])),
            ],
          ],
        );
      },
    );
  }
}

class _KpiTile extends StatelessWidget {
  const _KpiTile({required this.item, this.compact = false});

  final ExecutiveKpi item;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final accent = item.accent ?? DashboardColors.accent(context);
    return AnimatedContainer(
      duration: DashboardMotion.card,
      height: compact ? 72 : DashboardLayout.kpiHeight,
      padding: EdgeInsets.symmetric(
        horizontal: compact ? DashboardSpacing.sm : DashboardSpacing.md,
        vertical: compact ? DashboardSpacing.xs : DashboardSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: DashboardColors.card(context),
        borderRadius: BorderRadius.circular(DashboardRadius.card),
        border: Border.all(
          color: item.emphasize
              ? accent.withValues(alpha: 0.25)
              : DashboardColors.border(context).withValues(alpha: 0.4),
        ),
        boxShadow: DashboardShadows.none,
      ),
      child: Row(
        children: [
          Icon(
            item.icon,
            size: compact ? DashboardIcons.sm : DashboardIcons.md,
            color: accent,
          ),
          SizedBox(width: compact ? DashboardSpacing.xs : DashboardSpacing.sm),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: DashboardTypography.kpiValue(context).copyWith(
                    fontSize: compact
                        ? 18
                        : (item.emphasize ? 22 : 20),
                  ),
                ),
                Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: DashboardTypography.label(context).copyWith(
                    fontSize: compact ? 10 : null,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
