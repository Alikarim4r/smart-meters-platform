import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_meters_core/smart_meters_core.dart';

import '../../l10n/app_strings.dart';
import '../../providers/chart_providers.dart';
import '../../providers/dashboard_providers.dart';
import '../../providers/meter_reading_card_providers.dart';
import '../../theme/dashboard_palette.dart';
import '../../theme/design_system/dashboard_design_system.dart';
import '../../utils/chart_period_selection.dart';
import '../../utils/dashboard_date_range.dart';
import '../../utils/efficiency_metric.dart';

/// Two selectable cards — COP and EER — driving the analytics workspace below.
class EfficiencyMetricCards extends ConsumerWidget {
  const EfficiencyMetricCards({
    super.key,
    required this.siteId,
    required this.dateSelection,
  });

  final String siteId;
  final DashboardDateSelection dateSelection;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppStrings.of(context);
    final selected = ref.watch(selectedEfficiencyMetricProvider(siteId));
    final groupsAsync = ref.watch(siteCopGroupsProvider(siteId));

    return groupsAsync.when(
      loading: () => const SizedBox(
        height: 96,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      error: (_, _) => const SizedBox.shrink(),
      data: (groups) {
        if (groups.isEmpty) {
          return _ConfigHint(
            message: s.isAr
                ? 'اضبط عدادات الكفاءة (تبريد + كهرباء) من إعدادات السياسات في تطبيق الأدمن.'
                : 'Configure efficiency meters (cooling + electricity) in Admin policy settings.',
          );
        }
        final group = groups.first;
        final periodState = chartPeriodStateForDateSelection(dateSelection) ??
            const UtilityChartPeriodState(
              kind: UtilityChartPeriodKind.last30Days,
            );
        final query = CopChartQuery(
          copGroupId: group.id,
          periodState: periodState,
          businessDate: dateSelection.chartBusinessDate,
        );
        final trendAsync = ref.watch(copTrendProvider(query));

        return trendAsync.when(
          loading: () => const SizedBox(
            height: 96,
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          ),
          error: (_, _) => _ConfigHint(
            message: s.couldNotLoadChart,
          ),
          data: (result) {
            final copAvg = result.averageCop;
            final eerAvg = result.averageEer ??
                (copAvg == null ? null : copAvg * kCopToEerFactor);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  s.isAr ? 'كفاءة الطاقة' : 'Energy efficiency',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  s.isAr
                      ? 'اختر COP أو EER ثم اختر نوع المخطط أدناه'
                      : 'Select COP or EER, then choose a chart type below',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: DashboardSpacing.sm),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final wide = constraints.maxWidth >= 520;
                    final cards = [
                      _MetricCard(
                        metric: EfficiencyMetric.cop,
                        value: copAvg,
                        selected: selected == EfficiencyMetric.cop,
                        onTap: () => _toggle(ref, siteId, EfficiencyMetric.cop),
                      ),
                      _MetricCard(
                        metric: EfficiencyMetric.eer,
                        value: eerAvg,
                        selected: selected == EfficiencyMetric.eer,
                        onTap: () => _toggle(ref, siteId, EfficiencyMetric.eer),
                      ),
                    ];
                    if (wide) {
                      return Row(
                        children: [
                          Expanded(child: cards[0]),
                          const SizedBox(width: DashboardSpacing.sm),
                          Expanded(child: cards[1]),
                        ],
                      );
                    }
                    return Column(
                      children: [
                        cards[0],
                        const SizedBox(height: DashboardSpacing.sm),
                        cards[1],
                      ],
                    );
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _toggle(WidgetRef ref, String siteId, EfficiencyMetric metric) {
    final notifier = ref.read(selectedEfficiencyMetricProvider(siteId).notifier);
    final current = ref.read(selectedEfficiencyMetricProvider(siteId));
    notifier.state = current == metric ? null : metric;
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.metric,
    required this.value,
    required this.selected,
    required this.onTap,
  });

  final EfficiencyMetric metric;
  final double? value;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accent = DashboardPalette.btu;
    final bg = selected
        ? accent.withValues(alpha: isDark ? 0.28 : 0.12)
        : (isDark
            ? BrandChrome.surfaceDark
            : DashboardColors.card(context));

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(DashboardRadius.card),
        child: Ink(
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(DashboardRadius.card),
            border: Border.all(
              color: selected
                  ? accent.withValues(alpha: 0.85)
                  : DashboardColors.border(context).withValues(alpha: 0.4),
              width: selected ? 1.6 : 1,
            ),
          ),
          padding: const EdgeInsets.all(DashboardSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    metric == EfficiencyMetric.cop
                        ? Icons.speed_outlined
                        : Icons.energy_savings_leaf_outlined,
                    color: accent,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    s.isAr ? metric.labelAr : metric.labelEn,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const Spacer(),
                  if (selected)
                    Icon(Icons.check_circle, color: accent, size: 20),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                value == null ? '—' : value!.toStringAsFixed(2),
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: BrandChrome.titleColor(
                        isDark: isDark,
                        scheme: Theme.of(context).colorScheme,
                      ),
                    ),
              ),
              if (value != null) ...[
                const SizedBox(height: 6),
                Text(
                  s.isAr
                      ? _bandFor(metric, value!).labelAr(
                          metric == EfficiencyMetric.cop
                              ? EfficiencyMetricKind.cop
                              : EfficiencyMetricKind.eer,
                        )
                      : _bandFor(metric, value!).labelEn(
                          metric == EfficiencyMetric.cop
                              ? EfficiencyMetricKind.cop
                              : EfficiencyMetricKind.eer,
                        ),
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: accent,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  s.isAr
                      ? _bandFor(metric, value!).meaningAr(
                          metric == EfficiencyMetric.cop
                              ? EfficiencyMetricKind.cop
                              : EfficiencyMetricKind.eer,
                        )
                      : _bandFor(metric, value!).meaningEn(
                          metric == EfficiencyMetric.cop
                              ? EfficiencyMetricKind.cop
                              : EfficiencyMetricKind.eer,
                        ),
                  style: theme.textTheme.bodySmall,
                ),
              ] else ...[
                const SizedBox(height: 4),
                Text(
                  s.isAr ? metric.subtitleAr : metric.subtitleEn,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

EfficiencyBand _bandFor(EfficiencyMetric metric, double value) {
  return metric == EfficiencyMetric.eer
      ? classifyEer(value)
      : classifyCop(value);
}

class _ConfigHint extends StatelessWidget {
  const _ConfigHint({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(DashboardSpacing.md),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(DashboardRadius.card),
        border: Border.all(
          color: DashboardColors.border(context).withValues(alpha: 0.4),
        ),
      ),
      child: Text(message),
    );
  }
}
