import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_meters_core/smart_meters_core.dart';

import '../../l10n/conservation_strings.dart';
import '../../providers/chart_providers.dart';
import '../../providers/conservation_providers.dart';
import '../../providers/dashboard_providers.dart';
import '../../theme/dashboard_theme.dart';
import '../../theme/design_system/dashboard_colors.dart';
import '../../utils/chart_period_selection.dart';
import '../chart_widgets.dart';

/// Lazy-loaded conservation charts: period, COP, anomaly history, benchmark, balance.
class ConservationTrendsSection extends ConsumerWidget {
  const ConservationTrendsSection({
    super.key,
    required this.siteId,
    this.useDesktop = false,
  });

  final String siteId;
  final bool useDesktop;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ConservationStrings.of(context);
    final periodOn =
        ref.watch(conservationPeriodCompareEnabledProvider(siteId)).valueOrNull ??
            false;
    final anomaliesOn = ref
            .watch(conservationPeriodicAnomaliesEnabledProvider(siteId))
            .valueOrNull ??
        false;
    final copOn = ref
            .watch(conservationCopConservationEnabledProvider(siteId))
            .valueOrNull ??
        false;
    final benchmarkingOn = ref
            .watch(conservationBenchmarkingEnabledProvider(siteId))
            .valueOrNull ??
        false;
    final intensityOn =
        ref.watch(conservationIntensityEnabledProvider(siteId)).valueOrNull ??
            false;
    final waterBalanceOn = ref
            .watch(conservationWaterBalanceEnabledProvider(siteId))
            .valueOrNull ??
        false;
    final energyBalanceOn = ref
            .watch(conservationEnergyBalanceEnabledProvider(siteId))
            .valueOrNull ??
        false;

    final children = <Widget>[
      if (periodOn) _PeriodComparisonChartBlock(siteId: siteId),
      if (copOn) _CopTrendChartBlock(siteId: siteId),
      if (anomaliesOn) _AnomalyHistoryChartBlock(siteId: siteId),
      if (benchmarkingOn || intensityOn)
        _BenchmarkChartBlock(siteId: siteId),
      if (waterBalanceOn || energyBalanceOn)
        _BalanceShareChartBlock(siteId: siteId),
    ];

    if (children.isEmpty) {
      return Text(s.chartNoData);
    }

    if (useDesktop && children.length > 1) {
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          for (final child in children)
            SizedBox(
              width: children.length == 1
                  ? double.infinity
                  : (MediaQuery.sizeOf(context).width > 1100 ? 480 : 360),
              child: child,
            ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const SizedBox(height: 12),
          children[i],
        ],
      ],
    );
  }
}

class _ChartCard extends StatelessWidget {
  const _ChartCard({
    required this.title,
    required this.child,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: DashboardColors.card(context),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.55),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(
                subtitle!,
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).hintColor,
                ),
              ),
            ],
            const SizedBox(height: 10),
            SizedBox(height: 220, child: child),
          ],
        ),
      ),
    );
  }
}

class _PeriodComparisonChartBlock extends ConsumerWidget {
  const _PeriodComparisonChartBlock({required this.siteId});
  final String siteId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ConservationStrings.of(context);
    final async = ref.watch(conservationPeriodComparisonsProvider(siteId));
    return _ChartCard(
      title: s.chartPeriodComparison,
      subtitle: s.previousPeriod,
      child: async.when(
        loading: () => const ChartLoadingSkeleton(),
        error: (e, _) => ChartErrorPlaceholder(
          message: s.friendlyLoadError(e),
          onRetry: () =>
              ref.invalidate(conservationPeriodComparisonsProvider(siteId)),
        ),
        data: (bundles) {
          final groups = <({String label, double? current, double? comparison})>[
            for (final b in bundles)
              if (!b.previous.isInsufficient &&
                  (b.previous.currentValue != null ||
                      b.previous.comparisonValue != null))
                (
                  label: b.utilityLabel,
                  current: b.previous.currentValue,
                  comparison: b.previous.comparisonValue,
                ),
          ];
          if (groups.isEmpty) {
            return ChartEmptyPlaceholder(message: s.chartNoData);
          }
          return _DualSeriesBarChart(
            groups: groups,
            currentLabel: s.current,
            comparisonLabel: s.previousPeriod,
          );
        },
      ),
    );
  }
}

class _CopTrendChartBlock extends ConsumerWidget {
  const _CopTrendChartBlock({required this.siteId});
  final String siteId;

  static const _periodState = UtilityChartPeriodState(
    kind: UtilityChartPeriodKind.last30Days,
    preferChipOverCustomRange: true,
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ConservationStrings.of(context);
    final dateSelection = ref.watch(siteDateSelectionProvider(siteId));
    final groupsAsync = ref.watch(siteCopGroupsProvider(siteId));

    return _ChartCard(
      title: s.chartCopTrend,
      subtitle: s.copTrendNote,
      child: groupsAsync.when(
        loading: () => const ChartLoadingSkeleton(),
        error: (e, _) => ChartErrorPlaceholder(
          message: s.friendlyLoadError(e),
          onRetry: () => ref.invalidate(siteCopGroupsProvider(siteId)),
        ),
        data: (groups) {
          final active = groups.where((g) => g.isActive).toList();
          if (active.isEmpty) {
            return ChartEmptyPlaceholder(message: s.chartNoData);
          }
          final group = active.first;
          final query = CopChartQuery(
            copGroupId: group.id,
            periodState: _periodState,
            businessDate: dateOnly(dateSelection.endDate),
          );
          final trendAsync = ref.watch(copTrendProvider(query));
          return trendAsync.when(
            loading: () => const ChartLoadingSkeleton(),
            error: (e, _) => ChartErrorPlaceholder(
              message: s.friendlyLoadError(e),
              onRetry: () => ref.invalidate(copTrendProvider(query)),
            ),
            data: (result) => CopTrendLineChart(
              result: result,
              period: ChartPeriod.last30Days,
            ),
          );
        },
      ),
    );
  }
}

class _AnomalyHistoryChartBlock extends ConsumerWidget {
  const _AnomalyHistoryChartBlock({required this.siteId});
  final String siteId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ConservationStrings.of(context);
    final async = ref.watch(conservationAnomaliesProvider(siteId));
    return _ChartCard(
      title: s.chartAnomalyHistory,
      child: async.when(
        loading: () => const ChartLoadingSkeleton(),
        error: (e, _) => ChartErrorPlaceholder(
          message: s.friendlyLoadError(e),
          onRetry: () =>
              ref.invalidate(conservationAnomaliesProvider(siteId)),
        ),
        data: (bundles) {
          final consumption = bundles
              .where(
                (b) =>
                    b.unitCode != null &&
                    (b.historicalPeriodConsumptions.any((v) => v != null) ||
                        b.currentPeriodConsumption != null),
              )
              .toList();
          if (consumption.isEmpty) {
            return ChartEmptyPlaceholder(message: s.chartNoData);
          }
          // One utility series at a time — prefer first with most points.
          final bundle = consumption.first;
          final points = <TimeSeriesPoint>[];
          final hist = bundle.historicalPeriodConsumptions;
          for (var i = 0; i < hist.length; i++) {
            final v = hist[i];
            if (v == null) continue;
            points.add(
              TimeSeriesPoint(
                date: DateTime(2000, 1, i + 1),
                value: v,
                label: '${s.chartPeriodN}${i + 1}',
              ),
            );
          }
          if (bundle.currentPeriodConsumption != null) {
            points.add(
              TimeSeriesPoint(
                date: DateTime(2000, 1, hist.length + 1),
                value: bundle.currentPeriodConsumption!,
                label: s.current,
              ),
            );
          }
          if (points.isEmpty) {
            return ChartEmptyPlaceholder(message: s.chartNoData);
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                bundle.title,
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).hintColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Expanded(
                child: SingleSeriesBarChart(
                  points: points,
                  color: Theme.of(context).colorScheme.primary,
                  unitLabel: bundle.unitCode,
                  emptyMessage: s.chartNoData,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _BenchmarkChartBlock extends ConsumerWidget {
  const _BenchmarkChartBlock({required this.siteId});
  final String siteId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ConservationStrings.of(context);
    final async = ref.watch(conservationBenchmarkProvider(siteId));
    return _ChartCard(
      title: s.chartBenchmarkPeers,
      child: async.when(
        loading: () => const ChartLoadingSkeleton(),
        error: (e, _) => ChartErrorPlaceholder(
          message: s.friendlyLoadError(e),
          onRetry: () =>
              ref.invalidate(conservationBenchmarkProvider(siteId)),
        ),
        data: (bundles) {
          final groups = <({String label, double? current, double? comparison})>[
            for (final b in bundles)
              if (b.consumption != null || b.peerMedian != null)
                (
                  label: b.utilityLabel,
                  current: b.consumption,
                  comparison: b.peerMedian,
                ),
          ];
          if (groups.isEmpty) {
            return ChartEmptyPlaceholder(message: s.chartNoData);
          }
          return _DualSeriesBarChart(
            groups: groups,
            currentLabel: s.chartThisSite,
            comparisonLabel: s.peerMedian,
          );
        },
      ),
    );
  }
}

class _BalanceShareChartBlock extends ConsumerWidget {
  const _BalanceShareChartBlock({required this.siteId});
  final String siteId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ConservationStrings.of(context);
    final async = ref.watch(conservationBalanceResultsProvider(siteId));
    return _ChartCard(
      title: s.chartBalanceShare,
      child: async.when(
        loading: () => const ChartLoadingSkeleton(),
        error: (e, _) => ChartErrorPlaceholder(
          message: s.friendlyLoadError(e),
          onRetry: () =>
              ref.invalidate(conservationBalanceResultsProvider(siteId)),
        ),
        data: (bundles) {
          final usable = bundles
              .where(
                (b) =>
                    !b.result.isInsufficient &&
                    ((b.result.mainConsumption ?? 0) > 0 ||
                        (b.result.childrenConsumption ?? 0) > 0),
              )
              .toList();
          if (usable.isEmpty) {
            return ChartEmptyPlaceholder(message: s.chartNoData);
          }
          // Prefer first group; show all as dual bars (main vs children sum).
          final groups = <({String label, double? current, double? comparison})>[
            for (final b in usable.take(4))
              (
                label: b.group.name,
                current: b.result.mainConsumption,
                comparison: b.result.childrenConsumption,
              ),
          ];
          return _DualSeriesBarChart(
            groups: groups,
            currentLabel: s.chartMainMeter,
            comparisonLabel: s.chartChildrenSum,
          );
        },
      ),
    );
  }
}

/// Grouped bars: current vs comparison per category label.
class _DualSeriesBarChart extends StatelessWidget {
  const _DualSeriesBarChart({
    required this.groups,
    required this.currentLabel,
    required this.comparisonLabel,
  });

  final List<({String label, double? current, double? comparison})> groups;
  final String currentLabel;
  final String comparisonLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentColor = theme.colorScheme.primary;
    final comparisonColor = theme.colorScheme.secondary;
    final values = <double>[
      for (final g in groups) ...[
        if (g.current != null && g.current!.isFinite) g.current!,
        if (g.comparison != null && g.comparison!.isFinite) g.comparison!,
      ],
    ];
    if (values.isEmpty) {
      return ChartEmptyPlaceholder(
        message: ConservationStrings.of(context).chartNoData,
      );
    }
    final maxY = chartSoftMaxY(values);

    return Column(
      children: [
        Expanded(
          child: BarChart(
            BarChartData(
              maxY: maxY,
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                getDrawingHorizontalLine: (value) => FlLine(
                  color: chartGridColor(context),
                  strokeWidth: 1,
                ),
              ),
              titlesData: FlTitlesData(
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 40,
                    getTitlesWidget: (value, meta) => Text(
                      formatChartValue(value),
                      style: TextStyle(
                        fontSize: 10,
                        color: chartLabelColor(context),
                      ),
                    ),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 28,
                    getTitlesWidget: (value, meta) {
                      final i = value.toInt();
                      if (i < 0 || i >= groups.length) {
                        return const SizedBox.shrink();
                      }
                      return Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          groups[i].label,
                          style: TextStyle(
                            fontSize: 10,
                            color: chartLabelColor(context),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              borderData: FlBorderData(show: false),
              barGroups: [
                for (var i = 0; i < groups.length; i++)
                  BarChartGroupData(
                    x: i,
                    barsSpace: 4,
                    barRods: [
                      BarChartRodData(
                        toY: (groups[i].current ?? 0).clamp(0, double.infinity),
                        width: 12,
                        color: currentColor,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(3),
                        ),
                      ),
                      BarChartRodData(
                        toY: (groups[i].comparison ?? 0)
                            .clamp(0, double.infinity),
                        width: 12,
                        color: comparisonColor,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(3),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 12,
          children: [
            _LegendDot(color: currentColor, label: currentLabel),
            _LegendDot(color: comparisonColor, label: comparisonLabel),
          ],
        ),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: chartLabelColor(context),
          ),
        ),
      ],
    );
  }
}
