import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:smart_meters_core/smart_meters_core.dart';

import '../l10n/app_strings.dart';
import '../theme/dashboard_theme.dart';
import '../utils/chart_point_transforms.dart';
import '../utils/dashboard_filters.dart';
import '../utils/utility_chart_type.dart';
import 'dashboard_widgets.dart';

TextStyle _chartAxisStyle(BuildContext context) => TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w600,
      color: chartLabelColor(context),
    );

/// Soft-cap Y so one outlier does not flatten the rest of the series.
double chartSoftMaxY(Iterable<double> values) {
  final positives = [
    for (final v in values)
      if (v.isFinite && v > 0) v,
  ]..sort();
  if (positives.isEmpty) return 1.0;
  final max = positives.last;
  if (positives.length < 4) return max * 1.15;
  final p90 = positives[((positives.length - 1) * 0.9).round()];
  if (p90 > 0 && max > p90 * 3.5) {
    return p90 * 1.5;
  }
  return max * 1.15;
}

String? _localizedPointLabel(
  BuildContext context,
  TimeSeriesPoint point, {
  ChartBucket? bucket,
}) {
  if (bucket == ChartBucket.daily) {
    final s = AppStrings.of(context);
    // Day-only labels on dense charts; month shown on first/last via caller.
    return '${point.date.day} ${s.monthAbbrev(point.date.month)}';
  }
  if (bucket == null) return point.label;
  return AppStrings.of(context).chartAxisLabel(date: point.date, bucket: bucket);
}

/// Show sparse bottom labels so dates never overlap (especially on phones).
int _bottomLabelStep(int pointCount, {int? maxLabels}) {
  final limit = maxLabels ?? () {
    if (pointCount <= 7) return pointCount;
    if (pointCount <= 14) return 5;
    if (pointCount <= 31) return 5;
    return 6;
  }();
  if (pointCount <= 1) return 1;
  if (pointCount <= limit) return 1;
  return (pointCount / limit).ceil();
}

double _bottomTitlesReservedSize(int pointCount) {
  if (pointCount > 14) return 28;
  if (pointCount > 8) return 26;
  return 24;
}

Widget _bottomAxisTitle({
  required BuildContext context,
  required TitleMeta meta,
  required double value,
  required int pointCount,
  required String? Function(int index) labelAt,
  int? maxLabels,
}) {
  final index = value.round();
  if (index < 0 || index >= pointCount) {
    return const SizedBox.shrink();
  }
  if ((value - index).abs() > 0.01) {
    return const SizedBox.shrink();
  }

  final step = _bottomLabelStep(pointCount, maxLabels: maxLabels);
  if (index % step != 0 && index != pointCount - 1 && index != 0) {
    return const SizedBox.shrink();
  }
  if (index == pointCount - 1 && index % step != 0) {
    final prev = (index ~/ step) * step;
    if (index - prev < (step * 0.55).ceil()) {
      return const SizedBox.shrink();
    }
  }

  final raw = labelAt(index) ?? '';
  if (raw.isEmpty) return const SizedBox.shrink();

  // On dense daily charts, show day number only (except endpoints keep month).
  final label = pointCount > 14 && index != 0 && index != pointCount - 1
      ? raw.split(RegExp(r'\s+')).first
      : raw;

  return SideTitleWidget(
    meta: meta,
    space: 4,
    child: Text(
      label,
      maxLines: 1,
      softWrap: false,
      overflow: TextOverflow.clip,
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: pointCount > 20 ? 9 : 10,
        fontWeight: FontWeight.w600,
        color: chartLabelColor(context),
      ),
    ),
  );
}

SideTitles _bottomSideTitles({
  required BuildContext context,
  required int pointCount,
  required String? Function(int index) labelAt,
  int? maxLabels,
}) {
  final step = _bottomLabelStep(pointCount, maxLabels: maxLabels);
  return SideTitles(
    showTitles: true,
    reservedSize: _bottomTitlesReservedSize(pointCount),
    interval: step.toDouble(),
    getTitlesWidget: (value, meta) => _bottomAxisTitle(
      context: context,
      meta: meta,
      value: value,
      pointCount: pointCount,
      labelAt: labelAt,
      maxLabels: maxLabels,
    ),
  );
}

LineTouchData _lineTouchData(BuildContext context) {
  final bg = chartTooltipBg(context);
  final fg = chartTooltipFg(context);
  return LineTouchData(
    enabled: true,
    handleBuiltInTouches: true,
    touchTooltipData: LineTouchTooltipData(
      getTooltipColor: (_) => bg,
      tooltipRoundedRadius: 8,
      tooltipPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      getTooltipItems: (spots) => [
        for (final spot in spots)
          LineTooltipItem(
            formatChartValue(spot.y),
            TextStyle(
              color: fg,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
      ],
    ),
  );
}

class ChartMonthSelector extends StatelessWidget {
  const ChartMonthSelector({
    super.key,
    required this.month,
    required this.onChanged,
  });

  final DashboardChartMonth month;
  final ValueChanged<DashboardChartMonth> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<DashboardChartMonth>(
      initialValue: month,
      isDense: true,
      decoration: const InputDecoration(
        labelText: 'Chart month',
        border: OutlineInputBorder(),
        isDense: true,
        contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      ),
      items: [
        for (final item in DashboardChartMonth.values)
          DropdownMenuItem(
            value: item,
            child: Text(item.label),
          ),
      ],
      onChanged: (value) {
        if (value != null) onChanged(value);
      },
    );
  }
}

class ChartPeriodSelector extends StatelessWidget {
  const ChartPeriodSelector({
    super.key,
    required this.period,
    required this.onChanged,
  });

  final ChartPeriod period;
  final ValueChanged<ChartPeriod> onChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final item in ChartPeriod.values)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: ChoiceChip(
                label: Text(item.label),
                selected: period == item,
                onSelected: (_) => onChanged(item),
              ),
            ),
        ],
      ),
    );
  }
}

class DashboardChartCard extends StatelessWidget {
  const DashboardChartCard({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.trailing,
    this.height = 240,
    this.scrollableChild = false,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Widget child;
  final double? height;
  final bool scrollableChild;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DashboardCard(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final narrow = constraints.maxWidth < 360;
          final header = narrow && trailing != null
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: chartLabelColor(context),
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    trailing!,
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (subtitle != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              subtitle!,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: chartLabelColor(context),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (trailing != null)
                      Flexible(
                        child: Align(
                          alignment: Alignment.topRight,
                          child: trailing!,
                        ),
                      ),
                  ],
                );

          Widget chartBody = child;
          final plotHeight = height ?? 220;
          if (scrollableChild) {
            chartBody = SizedBox(
              height: plotHeight,
              child: SingleChildScrollView(child: chartBody),
            );
          } else {
            chartBody = SizedBox(height: plotHeight, child: chartBody);
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              header,
              const SizedBox(height: 12),
              chartBody,
            ],
          );
        },
      ),
    );
  }
}

class ChartLoadingPlaceholder extends StatelessWidget {
  const ChartLoadingPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator());
  }
}

class ChartEmptyPlaceholder extends StatelessWidget {
  const ChartEmptyPlaceholder({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(color: chartLabelColor(context)),
        ),
      ),
    );
  }
}

class ChartErrorPlaceholder extends StatelessWidget {
  const ChartErrorPlaceholder({
    super.key,
    required this.message,
    this.onRetry,
  });

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: chartLabelColor(context)),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh, size: 18),
                label: Text(
                  Localizations.localeOf(context).languageCode == 'ar'
                      ? 'إعادة المحاولة'
                      : 'Retry',
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Lightweight chart-area loading state (no blur / heavy effects).
class ChartLoadingSkeleton extends StatelessWidget {
  const ChartLoadingSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: SizedBox(
        width: 28,
        height: 28,
        child: CircularProgressIndicator(strokeWidth: 2.5),
      ),
    );
  }
}

List<Color> _chartPalette(ThemeData theme) {
  return [
    theme.colorScheme.primary,
    theme.colorScheme.secondary,
    theme.colorScheme.tertiary,
    Colors.teal.shade700,
    Colors.orange.shade700,
    Colors.indigo.shade600,
    Colors.brown.shade600,
  ];
}

class MultiSeriesLineChart extends StatelessWidget {
  const MultiSeriesLineChart({
    super.key,
    required this.series,
    this.unitLabel,
  });

  final List<CategoryConsumptionSeries> series;
  final String? unitLabel;

  @override
  Widget build(BuildContext context) {
    if (series.isEmpty || !series.any((s) => s.hasData)) {
      return ChartEmptyPlaceholder(
        message: AppStrings.of(context).noReadingsForPeriod,
      );
    }

    final theme = Theme.of(context);
    final colors = _chartPalette(theme);
    final maxPoints = series.map((s) => s.points.length).fold(0, (a, b) => a > b ? a : b);
    if (maxPoints == 0) {
      return ChartEmptyPlaceholder(
        message: AppStrings.of(context).noReadingsForPeriod,
      );
    }

    final chartMaxY = chartSoftMaxY(
      series.expand((s) => s.points.map((p) => p.value)),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final legendReserve = 56.0 + (unitLabel != null && unitLabel!.isNotEmpty ? 20 : 0);
        final plotHeight = constraints.maxHeight.isFinite
            ? (constraints.maxHeight - legendReserve).clamp(140.0, 360.0)
            : 220.0;

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: plotHeight,
              child: LineChart(
                LineChartData(
                  minY: 0,
                  maxY: chartMaxY,
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: chartMaxY / 4,
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
                      sideTitles: _bottomSideTitles(
                        context: context,
                        pointCount: maxPoints,
                        labelAt: (index) => series.first.points[index].label,
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  lineTouchData: _lineTouchData(context),
                  lineBarsData: [
                    for (var i = 0; i < series.length; i++)
                      LineChartBarData(
                        spots: [
                          for (var j = 0; j < series[i].points.length; j++)
                            FlSpot(
                              j.toDouble(),
                              series[i].points[j].value < 0
                                  ? 0
                                  : series[i].points[j].value,
                            ),
                        ],
                        isCurved: true,
                        preventCurveOverShooting: true,
                        color: colors[i % colors.length],
                        barWidth: 2.5,
                        dotData: FlDotData(show: series[i].points.length <= 14),
                        belowBarData: BarAreaData(show: false),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 6,
              children: [
                for (var i = 0; i < series.length; i++)
                  _LegendDot(
                    color: colors[i % colors.length],
                    label: series[i].categoryName,
                  ),
              ],
            ),
            if (unitLabel != null && unitLabel!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'Unit: $unitLabel',
                  style: TextStyle(fontSize: 11, color: chartLabelColor(context), fontWeight: FontWeight.w600),
                ),
              ),
          ],
        );
      },
    );
  }
}

class SingleSeriesLineChart extends StatelessWidget {
  const SingleSeriesLineChart({
    super.key,
    required this.points,
    required this.color,
    this.unitLabel,
    this.emptyMessage,
    this.isStep = false,
    this.bucket,
  });

  final List<TimeSeriesPoint> points;
  final Color color;
  final String? unitLabel;
  final String? emptyMessage;
  final bool isStep;
  final ChartBucket? bucket;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return ChartEmptyPlaceholder(message: emptyMessage ?? AppStrings.of(context).noReadingsForPeriod);
    }

    final chartMaxY = chartSoftMaxY(points.map((p) => p.value));

    return LayoutBuilder(
      builder: (context, constraints) {
        final legendReserve = unitLabel != null && unitLabel!.isNotEmpty ? 24.0 : 0.0;
        final plotHeight = constraints.maxHeight.isFinite
            ? (constraints.maxHeight - legendReserve).clamp(140.0, 360.0)
            : 220.0;

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: plotHeight,
              child: LineChart(
                LineChartData(
                  minY: 0,
                  maxY: chartMaxY,
                  minX: 0,
                  maxX: points.length <= 1 ? 1 : (points.length - 1).toDouble(),
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
                      sideTitles: _bottomSideTitles(
                        context: context,
                        pointCount: points.length,
                        labelAt: (index) => _localizedPointLabel(
                          context,
                          points[index],
                          bucket: bucket,
                        ),
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  lineTouchData: _lineTouchData(context),
                  lineBarsData: [
                    LineChartBarData(
                      spots: [
                        for (var i = 0; i < points.length; i++)
                          FlSpot(i.toDouble(), points[i].value.clamp(0, chartMaxY)),
                      ],
                      isCurved: !isStep,
                      preventCurveOverShooting: true,
                      isStepLineChart: isStep,
                      color: color,
                      barWidth: 2.5,
                      dotData: FlDotData(show: points.length <= 14),
                      belowBarData: BarAreaData(show: false),
                    ),
                  ],
                ),
              ),
            ),
            if (unitLabel != null && unitLabel!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  unitLabel!,
                  textAlign: TextAlign.center,
                  style: _chartAxisStyle(context),
                ),
              ),
          ],
        );
      },
    );
  }
}

class SingleSeriesBarChart extends StatelessWidget {
  const SingleSeriesBarChart({
    super.key,
    required this.points,
    required this.color,
    this.unitLabel,
    this.emptyMessage,
    this.bucket,
  });

  final List<TimeSeriesPoint> points;
  final Color color;
  final String? unitLabel;
  final String? emptyMessage;
  final ChartBucket? bucket;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return ChartEmptyPlaceholder(message: emptyMessage ?? AppStrings.of(context).noReadingsForPeriod);
    }

    final chartMaxY = chartSoftMaxY(points.map((p) => p.value));

    return LayoutBuilder(
      builder: (context, constraints) {
        final plotHeight = constraints.maxHeight.isFinite
            ? constraints.maxHeight.clamp(140.0, 360.0)
            : 220.0;

        return SizedBox(
          height: plotHeight,
          child: BarChart(
            BarChartData(
              maxY: chartMaxY,
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
                  sideTitles: _bottomSideTitles(
                    context: context,
                    pointCount: points.length,
                    labelAt: (index) => _localizedPointLabel(
                      context,
                      points[index],
                      bucket: bucket,
                    ),
                  ),
                ),
              ),
              borderData: FlBorderData(show: false),
              barGroups: [
                for (var i = 0; i < points.length; i++)
                  BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: points[i].value.clamp(0, chartMaxY),
                        color: color,
                        width: points.length > 20 ? 6 : 12,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(3),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class SingleSeriesAreaChart extends StatelessWidget {
  const SingleSeriesAreaChart({
    super.key,
    required this.points,
    required this.color,
    this.unitLabel,
    this.emptyMessage,
    this.bucket,
  });

  final List<TimeSeriesPoint> points;
  final Color color;
  final String? unitLabel;
  final String? emptyMessage;
  final ChartBucket? bucket;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return ChartEmptyPlaceholder(message: emptyMessage ?? AppStrings.of(context).noReadingsForPeriod);
    }

    final chartMaxY = chartSoftMaxY(points.map((p) => p.value));

    return LayoutBuilder(
      builder: (context, constraints) {
        final plotHeight = constraints.maxHeight.isFinite
            ? constraints.maxHeight.clamp(140.0, 360.0)
            : 220.0;

        return SizedBox(
          height: plotHeight,
          child: LineChart(
            LineChartData(
              minY: 0,
              maxY: chartMaxY,
              minX: 0,
              maxX: points.length <= 1 ? 1 : (points.length - 1).toDouble(),
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
                  sideTitles: _bottomSideTitles(
                    context: context,
                    pointCount: points.length,
                    labelAt: (index) => _localizedPointLabel(
                      context,
                      points[index],
                      bucket: bucket,
                    ),
                  ),
                ),
              ),
              borderData: FlBorderData(show: false),
              lineTouchData: _lineTouchData(context),
              lineBarsData: [
                LineChartBarData(
                  spots: [
                    for (var i = 0; i < points.length; i++)
                      FlSpot(i.toDouble(), points[i].value < 0 ? 0 : points[i].value),
                  ],
                  isCurved: true,
                  preventCurveOverShooting: true,
                  color: color,
                  barWidth: 2,
                  dotData: const FlDotData(show: false),
                  belowBarData: BarAreaData(
                    show: true,
                    color: color.withValues(alpha: 0.18),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class HorizontalRankingBarChart extends StatelessWidget {
  const HorizontalRankingBarChart({
    super.key,
    required this.items,
    required this.unitLabel,
    this.maxItems = 6,
  });

  final List<CategoryRankingItem> items;
  final String unitLabel;
  final int maxItems;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty || !items.any((i) => i.totalConsumption > 0)) {
      return ChartEmptyPlaceholder(
        message: AppStrings.of(context).isAr ? 'لا توجد قراءات كافية لحساب الاستهلاك' : 'Not enough readings to calculate consumption',
      );
    }

    final theme = Theme.of(context);
    final visible = items.take(maxItems).toList();
    final maxValue = visible.fold<double>(
      0,
      (m, item) => item.totalConsumption > m ? item.totalConsumption : m,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final item in visible)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${AppStrings.of(context).localizedName(en: item.meterName, ar: item.meterNameAr)} (${item.meterCode})',
                        style: const TextStyle(fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Flexible(
                      child: Text(
                        '${formatChartValue(item.totalConsumption)} $unitLabel',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.primary,
                        ),
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.end,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: maxValue <= 0 ? 0 : item.totalConsumption / maxValue,
                    minHeight: 8,
                    backgroundColor: chartGridColor(context),
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class CategorySummaryBarChart extends StatelessWidget {
  const CategorySummaryBarChart({
    super.key,
    required this.series,
  });

  final List<CategoryConsumptionSeries> series;

  @override
  Widget build(BuildContext context) {
    final ranked = series
        .where((s) => s.totalConsumption > 0)
        .toList()
      ..sort((a, b) => b.totalConsumption.compareTo(a.totalConsumption));

    if (ranked.isEmpty) {
      return ChartEmptyPlaceholder(
        message: AppStrings.of(context).isAr ? 'لا توجد قراءات كافية لحساب الاستهلاك' : 'Not enough readings to calculate consumption',
      );
    }

    final theme = Theme.of(context);
    final maxValue = ranked.first.totalConsumption;

    return Column(
      children: [
        for (final item in ranked)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(item.categoryName)),
                    Flexible(
                      child: Text(
                        '${formatChartValue(item.totalConsumption)} ${item.unitCode}',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.primary,
                        ),
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.end,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: maxValue <= 0 ? 0 : item.totalConsumption / maxValue,
                    minHeight: 8,
                    backgroundColor: chartGridColor(context),
                    color: theme.colorScheme.secondary,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class CompletionDonutChart extends StatelessWidget {
  const CompletionDonutChart({
    super.key,
    required this.submitted,
    required this.pending,
    required this.total,
  });

  final int submitted;
  final int pending;
  final int total;

  @override
  Widget build(BuildContext context) {
    if (total <= 0) {
      return ChartEmptyPlaceholder(
        message: AppStrings.of(context).isAr ? 'لا توجد عدادات إدخال في هذا الموقع' : 'No entry meters at this site');
    }

    final theme = Theme.of(context);
    final sections = [
      PieChartSectionData(
        value: submitted.toDouble(),
        color: Colors.green.shade600,
        title: submitted > 0 ? '$submitted' : '',
        radius: 52,
        titleStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
      if (pending > 0)
        PieChartSectionData(
          value: pending.toDouble(),
          color: Colors.orange.shade600,
          title: '$pending',
          radius: 48,
          titleStyle: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
    ];

    return Column(
      children: [
        Expanded(
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 36,
              sections: sections,
            ),
          ),
        ),
        Text(
          '$submitted/$total submitted today',
          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        Text(
          pending > 0 ? '$pending pending' : 'All readings submitted',
          style: TextStyle(color: chartLabelColor(context), fontSize: 12),
        ),
      ],
    );
  }
}

class MeterComparisonLineChart extends StatelessWidget {
  const MeterComparisonLineChart({
    super.key,
    required this.result,
    this.isStep = false,
  });

  final MeterComparisonResult result;
  final bool isStep;

  @override
  Widget build(BuildContext context) {
    if (!result.canCompare) {
      return ChartEmptyPlaceholder(
        message: result.warningMessage ?? (AppStrings.of(context).isAr ? 'لا يمكن مقارنة الوحدات بأمان' : 'Units cannot be compared safely'),
      );
    }
    if (!result.hasData) {
      return ChartEmptyPlaceholder(
        message:
            result.warningMessage ?? (AppStrings.of(context).isAr ? 'لا توجد قراءات كافية لحساب الاستهلاك' : 'Not enough readings to calculate consumption'),
      );
    }

    final theme = Theme.of(context);
    final colors = _chartPalette(theme);
    final pointCount = result.series.first.points.length;
    final chartMaxY = chartSoftMaxY(
      result.series.expand((s) => s.points.map((p) => p.value)),
    );

    return Column(
      children: [
        Expanded(
          child: LineChart(
            LineChartData(
              minY: 0,
              maxY: chartMaxY,
              minX: 0,
              maxX: pointCount <= 1 ? 1 : (pointCount - 1).toDouble(),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                getDrawingHorizontalLine: (value) => FlLine(
                  color: chartGridColor(context),
                  strokeWidth: 1,
                ),
              ),
              titlesData: FlTitlesData(
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 40,
                    getTitlesWidget: (value, meta) => Text(
                      formatChartValue(value),
                      style: _chartAxisStyle(context),
                    ),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: _bottomSideTitles(
                    context: context,
                    pointCount: pointCount,
                    labelAt: (index) => result.series.first.points[index].label,
                  ),
                ),
              ),
              borderData: FlBorderData(show: false),
              lineTouchData: _lineTouchData(context),
              lineBarsData: [
                for (var i = 0; i < result.series.length; i++)
                  LineChartBarData(
                    spots: [
                      for (var j = 0; j < result.series[i].points.length; j++)
                        FlSpot(
                          j.toDouble(),
                          result.series[i].points[j].value < 0
                              ? 0
                              : result.series[i].points[j].value,
                        ),
                    ],
                    isCurved: !isStep,
                    preventCurveOverShooting: true,
                    isStepLineChart: isStep,
                    color: colors[i % colors.length],
                    barWidth: 2.5,
                    dotData: FlDotData(
                      show: !isStep && result.series[i].points.length <= 14,
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 6,
          children: [
            for (var i = 0; i < result.series.length; i++)
              _LegendDot(
                color: colors[i % colors.length],
                label: result.series[i].meterName,
              ),
          ],
        ),
        if (result.baseUnit.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              'Unit: ${result.baseUnit}',
              style: TextStyle(fontSize: 11, color: chartLabelColor(context), fontWeight: FontWeight.w600),
            ),
          ),
      ],
    );
  }
}

class MeterSharePieChart extends StatelessWidget {
  const MeterSharePieChart({
    super.key,
    required this.items,
    required this.unitLabel,
    this.emptyMessage,
  });

  final List<({String label, double value})> items;
  final String unitLabel;
  final String? emptyMessage;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return ChartEmptyPlaceholder(message: emptyMessage ?? AppStrings.of(context).noReadingsForPeriod);
    }
    final total = items.fold<double>(0, (sum, item) => sum + item.value);
    if (total <= 0) {
      return ChartEmptyPlaceholder(message: emptyMessage ?? AppStrings.of(context).noReadingsForPeriod);
    }
    final palette = _chartPalette(Theme.of(context));
    return Column(
      children: [
        Expanded(
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 36,
              sections: [
                for (var i = 0; i < items.length; i++)
                  PieChartSectionData(
                    value: items[i].value,
                    color: palette[i % palette.length],
                    title: items[i].value / total >= 0.08
                        ? '${((items[i].value / total) * 100).round()}%'
                        : '',
                    radius: 52,
                    titleStyle: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          runSpacing: 4,
          children: [
            for (var i = 0; i < items.length; i++)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: palette[i % palette.length],
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${items[i].label} (${formatChartValue(items[i].value)} $unitLabel)',
                    style: TextStyle(
                      fontSize: 11,
                      color: chartLabelColor(context),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ],
    );
  }
}

class MeterComparisonChart extends StatelessWidget {
  const MeterComparisonChart({
    super.key,
    required this.result,
    required this.chartType,
    this.bucket,
  });

  final MeterComparisonResult result;
  final UtilityChartType chartType;
  final ChartBucket? bucket;

  @override
  Widget build(BuildContext context) {
    return switch (chartType) {
      UtilityChartType.bar => MeterComparisonBarChart(result: result),
      UtilityChartType.area => MeterComparisonAreaChart(result: result),
      UtilityChartType.step =>
        MeterComparisonLineChart(result: result, isStep: true),
      UtilityChartType.cumulative => MeterComparisonLineChart(
          result: _transformComparisonSeries(
            result,
            cumulativeChartPoints,
          ),
        ),
      UtilityChartType.weekday => MeterComparisonBarChart(
          result: _transformComparisonSeries(
            result,
            (points) => weekdayAveragePoints(
              points,
              labels: [
                for (var i = 1; i <= 7; i++)
                  AppStrings.of(context).weekdayAbbrev(i),
              ],
            ),
          ),
        ),
      UtilityChartType.stackedBar =>
        MeterComparisonStackedBarChart(result: result),
      UtilityChartType.pie => MeterSharePieChart(
          items: [
            for (final series in result.series)
              if (series.periodTotal > 0)
                (
                  label: AppStrings.of(context).localizedName(
                    en: series.meterName,
                    ar: series.meterNameAr,
                  ),
                  value: series.periodTotal,
                ),
          ],
          unitLabel: result.baseUnit,
          emptyMessage:
              result.warningMessage ?? (AppStrings.of(context).isAr ? 'لا توجد قراءات كافية للمقارنة' : 'Not enough readings to compare'),
        ),
      _ => MeterComparisonLineChart(result: result),
    };
  }
}

MeterComparisonResult _transformComparisonSeries(
  MeterComparisonResult result,
  List<TimeSeriesPoint> Function(List<TimeSeriesPoint>) transform,
) {
  return MeterComparisonResult(
    series: [
      for (final series in result.series)
        MeterComparisonSeries(
          meterId: series.meterId,
          meterName: series.meterName,
          meterNameAr: series.meterNameAr,
          meterCode: series.meterCode,
          points: transform(series.points),
          periodTotal: series.periodTotal,
        ),
    ],
    baseUnit: result.baseUnit,
    canCompare: result.canCompare,
    warningMessage: result.warningMessage,
  );
}

class MeterComparisonStackedBarChart extends StatelessWidget {
  const MeterComparisonStackedBarChart({super.key, required this.result});

  final MeterComparisonResult result;

  @override
  Widget build(BuildContext context) {
    if (!result.canCompare || !result.hasData) {
      return MeterComparisonLineChart(result: result);
    }
    final theme = Theme.of(context);
    final colors = _chartPalette(theme);
    final pointCount = result.series.first.points.length;
    var maxY = 0.0;
    for (var j = 0; j < pointCount; j++) {
      var stack = 0.0;
      for (final series in result.series) {
        if (j < series.points.length) stack += series.points[j].value;
      }
      if (stack > maxY) maxY = stack;
    }
    final chartMaxY = maxY <= 0 ? 1.0 : chartSoftMaxY([maxY]);

    return Column(
      children: [
        Expanded(
          child: BarChart(
            BarChartData(
              maxY: chartMaxY,
              groupsSpace: 10,
              barGroups: [
                for (var j = 0; j < pointCount; j++)
                  BarChartGroupData(
                    x: j,
                    barRods: [
                      BarChartRodData(
                        toY: [
                          for (final series in result.series)
                            j < series.points.length
                                ? series.points[j].value
                                : 0.0,
                        ].fold<double>(0, (a, b) => a + b),
                        rodStackItems: [
                          for (var i = 0; i < result.series.length; i++)
                            BarChartRodStackItem(
                              i == 0
                                  ? 0
                                  : [
                                      for (var k = 0; k < i; k++)
                                        j < result.series[k].points.length
                                            ? result.series[k].points[j].value
                                            : 0.0,
                                    ].fold<double>(0, (a, b) => a + b),
                              [
                                for (var k = 0; k <= i; k++)
                                  j < result.series[k].points.length
                                      ? result.series[k].points[j].value
                                      : 0.0,
                              ].fold<double>(0, (a, b) => a + b),
                              colors[i % colors.length],
                            ),
                        ],
                        width: 14,
                        borderRadius: BorderRadius.circular(3),
                        color: colors.first,
                      ),
                    ],
                  ),
              ],
              titlesData: FlTitlesData(
                rightTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 40,
                    getTitlesWidget: (value, meta) => Text(
                      formatChartValue(value),
                      style: _chartAxisStyle(context),
                    ),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: _bottomSideTitles(
                    context: context,
                    pointCount: pointCount,
                    labelAt: (index) => result.series.first.points[index].label,
                  ),
                ),
              ),
              borderData: FlBorderData(show: false),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                getDrawingHorizontalLine: (value) => FlLine(
                  color: chartGridColor(context),
                  strokeWidth: 1,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          runSpacing: 4,
          children: [
            for (var i = 0; i < result.series.length; i++)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: colors[i % colors.length],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    result.series[i].meterCode,
                    style: TextStyle(
                      fontSize: 11,
                      color: chartLabelColor(context),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ],
    );
  }
}

class MeterComparisonBarChart extends StatelessWidget {
  const MeterComparisonBarChart({super.key, required this.result});

  final MeterComparisonResult result;

  @override
  Widget build(BuildContext context) {
    if (!result.canCompare || !result.hasData) {
      return MeterComparisonLineChart(result: result);
    }
    final theme = Theme.of(context);
    final colors = _chartPalette(theme);
    final pointCount = result.series.first.points.length;
    final chartMaxY = chartSoftMaxY(
      result.series.expand((s) => s.points.map((p) => p.value)),
    );

    return Column(
      children: [
        Expanded(
          child: BarChart(
            BarChartData(
              maxY: chartMaxY,
              groupsSpace: 12,
              barGroups: [
                for (var j = 0; j < pointCount; j++)
                  BarChartGroupData(
                    x: j,
                    barRods: [
                      for (var i = 0; i < result.series.length; i++)
                        BarChartRodData(
                          toY: j < result.series[i].points.length
                              ? result.series[i].points[j].value
                              : 0,
                          color: colors[i % colors.length],
                          width: 8,
                          borderRadius: BorderRadius.circular(3),
                        ),
                    ],
                  ),
              ],
              titlesData: FlTitlesData(
                rightTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 40,
                    getTitlesWidget: (value, meta) => Text(
                      formatChartValue(value),
                      style: _chartAxisStyle(context),
                    ),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: _bottomSideTitles(
                    context: context,
                    pointCount: result.series.first.points.length,
                    labelAt: (index) => result.series.first.points[index].label,
                  ),
                ),
              ),
              borderData: FlBorderData(show: false),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                getDrawingHorizontalLine: (value) => FlLine(
                  color: chartGridColor(context),
                  strokeWidth: 1,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 6,
          children: [
            for (var i = 0; i < result.series.length; i++)
              _LegendDot(
                color: colors[i % colors.length],
                label: result.series[i].meterName,
              ),
          ],
        ),
      ],
    );
  }
}

class MeterComparisonAreaChart extends StatelessWidget {
  const MeterComparisonAreaChart({super.key, required this.result});

  final MeterComparisonResult result;

  @override
  Widget build(BuildContext context) {
    if (!result.canCompare || !result.hasData) {
      return MeterComparisonLineChart(result: result);
    }
    final theme = Theme.of(context);
    final colors = _chartPalette(theme);
    final pointCount = result.series.first.points.length;
    final chartMaxY = chartSoftMaxY(
      result.series.expand((s) => s.points.map((p) => p.value)),
    );

    return Column(
      children: [
        Expanded(
          child: LineChart(
            LineChartData(
              minY: 0,
              maxY: chartMaxY,
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                getDrawingHorizontalLine: (value) => FlLine(
                  color: chartGridColor(context),
                  strokeWidth: 1,
                ),
              ),
              titlesData: FlTitlesData(
                rightTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 40,
                    getTitlesWidget: (value, meta) => Text(
                      formatChartValue(value),
                      style: _chartAxisStyle(context),
                    ),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: _bottomSideTitles(
                    context: context,
                    pointCount: pointCount,
                    labelAt: (index) => result.series.first.points[index].label,
                  ),
                ),
              ),
              borderData: FlBorderData(show: false),
              lineTouchData: _lineTouchData(context),
              lineBarsData: [
                for (var i = 0; i < result.series.length; i++)
                  LineChartBarData(
                    spots: [
                      for (var j = 0; j < result.series[i].points.length; j++)
                        FlSpot(j.toDouble(), result.series[i].points[j].value < 0 ? 0 : result.series[i].points[j].value),
                    ],
                    isCurved: true,
                    preventCurveOverShooting: true,
                    color: colors[i % colors.length],
                    barWidth: 2,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: colors[i % colors.length].withValues(alpha: 0.18),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 6,
          children: [
            for (var i = 0; i < result.series.length; i++)
              _LegendDot(
                color: colors[i % colors.length],
                label: result.series[i].meterName,
              ),
          ],
        ),
      ],
    );
  }
}

class CopTrendLineChart extends StatelessWidget {
  const CopTrendLineChart({
    super.key,
    required this.result,
    required this.period,
  });

  final CopTrendResult result;
  final ChartPeriod period;

  @override
  Widget build(BuildContext context) {
    if (!result.hasRequiredMeters) {
      return ChartEmptyPlaceholder(
        message: AppStrings.of(context).isAr ? 'COP يتطلب قراءات BTU والكهرباء' : 'COP requires both BTU and electricity readings',
      );
    }
    if (!result.hasData) {
      return ChartEmptyPlaceholder(
        message: result.emptyMessage ?? AppStrings.of(context).notEnoughReadingsForCop,
      );
    }

    final theme = Theme.of(context);
    final validPoints = result.points.where((p) => p.cop != null).toList();
    final chartMaxY = chartSoftMaxY(validPoints.map((p) => p.cop!));
    final bucket = chartPeriodRange(
      period: period,
      businessDate: qatarBusinessDate(),
    ).bucket;

    return Column(
      children: [
        Expanded(
          child: LineChart(
            LineChartData(
              minY: 0,
              maxY: chartMaxY,
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                getDrawingHorizontalLine: (value) => FlLine(
                  color: chartGridColor(context),
                  strokeWidth: 1,
                ),
              ),
              titlesData: FlTitlesData(
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 36,
                    getTitlesWidget: (value, meta) => Text(
                      value.toStringAsFixed(1),
                      style: _chartAxisStyle(context),
                    ),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: _bottomSideTitles(
                    context: context,
                    pointCount: result.points.length,
                    labelAt: (index) => chartBucketLabel(
                      date: result.points[index].date,
                      bucket: bucket,
                    ),
                  ),
                ),
              ),
              borderData: FlBorderData(show: false),
              lineTouchData: _lineTouchData(context),
              lineBarsData: [
                LineChartBarData(
                  spots: [
                    for (var i = 0; i < result.points.length; i++)
                      if (result.points[i].cop != null)
                        FlSpot(i.toDouble(), result.points[i].cop!),
                  ],
                  isCurved: true,
                  preventCurveOverShooting: true,
                  color: theme.colorScheme.primary,
                  barWidth: 2.5,
                  dotData: FlDotData(show: result.points.length <= 14),
                ),
              ],
            ),
          ),
        ),
        if (result.averageCop != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                Text(
                  'Avg ${result.averageCop!.toStringAsFixed(2)}',
                  style: TextStyle(fontSize: 12, color: chartLabelColor(context)),
                ),
                Text(
                  'Min ${result.minCop?.toStringAsFixed(2) ?? '—'}',
                  style: TextStyle(fontSize: 12, color: chartLabelColor(context)),
                ),
                Text(
                  'Max ${result.maxCop?.toStringAsFixed(2) ?? '—'}',
                  style: TextStyle(fontSize: 12, color: chartLabelColor(context)),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class CategoryCompletionBar extends StatelessWidget {
  const CategoryCompletionBar({
    super.key,
    required this.submitted,
    required this.total,
  });

  final int submitted;
  final int total;

  @override
  Widget build(BuildContext context) {
    if (total <= 0) {
      return const Text('No active meters in this category');
    }
    final pending = (total - submitted).clamp(0, total);
    final progress = total <= 0 ? 0.0 : submitted / total;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '$submitted/$total submitted today',
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Text('$pending pending'),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 10,
            backgroundColor: Colors.orange.shade100,
            color: Colors.green.shade600,
          ),
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
        Text(label, style: const TextStyle(fontSize: 11)),
      ],
    );
  }
}
