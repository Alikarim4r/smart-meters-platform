import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:smart_meters_core/smart_meters_core.dart';

import '../../l10n/app_strings.dart';
import '../../theme/dashboard_theme.dart';
import '../../utils/utility_chart_type.dart';
import '../chart_widgets.dart';

/// Per-utility chart view type — never mix units on one chart.
// UtilityChartType lives in utils/utility_chart_type.dart

extension UtilityChartTypeIcons on UtilityChartType {
  IconData get icon => switch (this) {
        UtilityChartType.line => Icons.show_chart_rounded,
        UtilityChartType.bar => Icons.bar_chart_rounded,
        UtilityChartType.area => Icons.area_chart_rounded,
        UtilityChartType.step => Icons.stairs_outlined,
        UtilityChartType.cumulative => Icons.trending_up_rounded,
        UtilityChartType.weekday => Icons.calendar_view_week_outlined,
        UtilityChartType.ranking => Icons.leaderboard_outlined,
        UtilityChartType.pie => Icons.pie_chart_outline_rounded,
        UtilityChartType.stackedBar => Icons.stacked_bar_chart_rounded,
        UtilityChartType.sourceSplit => Icons.donut_small_outlined,
        UtilityChartType.cop => Icons.speed_outlined,
      };
}

class ChartTypeSelector extends StatelessWidget {
  const ChartTypeSelector({
    super.key,
    required this.types,
    required this.selected,
    required this.onChanged,
  });

  final List<UtilityChartType> types;
  final UtilityChartType selected;
  final ValueChanged<UtilityChartType> onChanged;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final colors = dashboardColors(context);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final type in types)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: ChoiceChip(
                avatar: Icon(type.icon, size: 16),
                label: Text(s.chartTypeLabel(type)),
                selected: selected == type,
                selectedColor: colors.navy.withValues(alpha: 0.14),
                labelStyle: TextStyle(
                  fontSize: 12,
                  fontWeight:
                      selected == type ? FontWeight.w700 : FontWeight.w500,
                  color: selected == type
                      ? colors.textPrimary
                      : colors.textMuted,
                ),
                onSelected: (_) => onChanged(type),
              ),
            ),
        ],
      ),
    );
  }
}

class SourceSplitItem {
  const SourceSplitItem({
    required this.label,
    required this.value,
  });

  final String label;
  final double value;
}

List<SourceSplitItem> sourceSplitFromMeterCards(
  List<MeterReadingCardData> cards,
) {
  final totals = <String, double>{};
  for (final card in cards) {
    final consumption = card.consumptionValue;
    if (consumption == null || consumption <= 0) {
      continue;
    }
    final label =
        card.sourceName.trim().isEmpty ? card.sourceCode : card.sourceName;
    totals[label] = (totals[label] ?? 0) + consumption;
  }

  final items = [
    for (final entry in totals.entries)
      SourceSplitItem(label: entry.key, value: entry.value),
  ]..sort((a, b) => b.value.compareTo(a.value));
  return items;
}

/// Source split aligned to the chart period ranking (not meter-card day deltas).
List<SourceSplitItem> sourceSplitFromRanking({
  required List<CategoryRankingItem> ranking,
  required List<MeterReadingCardData> cards,
}) {
  final sourceByMeter = <String, String>{
    for (final card in cards)
      card.meterId: card.sourceName.trim().isEmpty
          ? card.sourceCode
          : card.sourceName,
  };
  final totals = <String, double>{};
  for (final item in ranking) {
    if (item.totalConsumption <= 0) continue;
    final label = sourceByMeter[item.meterId] ?? 'Unknown';
    totals[label] = (totals[label] ?? 0) + item.totalConsumption;
  }
  final items = [
    for (final entry in totals.entries)
      SourceSplitItem(label: entry.key, value: entry.value),
  ]..sort((a, b) => b.value.compareTo(a.value));
  return items;
}

class SourceSplitDonutChart extends StatelessWidget {
  const SourceSplitDonutChart({
    super.key,
    required this.items,
    required this.unitLabel,
    this.emptyMessage = 'No readings for the selected date range.',
  });

  final List<SourceSplitItem> items;
  final String unitLabel;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return ChartEmptyPlaceholder(message: emptyMessage);
    }

    final total = items.fold<double>(0, (sum, item) => sum + item.value);
    if (total <= 0) {
      return ChartEmptyPlaceholder(message: emptyMessage);
    }

    final palette = _chartPalette(Theme.of(context));
    final sections = <PieChartSectionData>[];
    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      sections.add(
        PieChartSectionData(
          value: item.value,
          color: palette[i % palette.length],
          title: item.value / total >= 0.08
              ? '${((item.value / total) * 100).round()}%'
              : '',
          radius: 52,
          titleStyle: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      );
    }

    return Column(
      children: [
        SizedBox(
          height: 180,
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 36,
              sections: sections,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          runSpacing: 6,
          alignment: WrapAlignment.center,
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
                    '${items[i].label}: ${formatChartValue(items[i].value)} $unitLabel',
                    style: const TextStyle(fontSize: 11),
                  ),
                ],
              ),
          ],
        ),
      ],
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
  ];
}

({int submitted, int pending, int total}) categoryStatsFromMeterCards(
  List<MeterReadingCardData> cards, {
  required bool rangeMode,
}) {
  final total = cards.length;
  final submitted = cards
      .where((card) => card.status == MeterReadingCardStatus.submittedOnDate)
      .length;
  final pending = cards
      .where((card) => card.status == MeterReadingCardStatus.pendingOnDate)
      .length;
  if (rangeMode) {
    return (submitted: submitted, pending: total - submitted, total: total);
  }
  return (submitted: submitted, pending: pending, total: total);
}

int completionPercentFromStats({required int submitted, required int total}) {
  if (total == 0) return 0;
  return ((submitted / total) * 100).round();
}

List<String> uniqueSourceOptionsFromCards(List<MeterReadingCardData> cards) {
  final sources = <String, String>{};
  for (final card in cards) {
    final code = card.sourceCode.trim().toLowerCase();
    if (code.isEmpty) continue;
    sources.putIfAbsent(code, () => card.sourceName);
  }
  final entries = sources.entries.toList()
    ..sort((a, b) => a.value.compareTo(b.value));
  return entries.map((e) => e.key).toList();
}

String sourceLabelForCode(String code, List<MeterReadingCardData> cards) {
  for (final card in cards) {
    if (card.sourceCode.toLowerCase() == code.toLowerCase()) {
      return card.sourceName;
    }
  }
  return code;
}
