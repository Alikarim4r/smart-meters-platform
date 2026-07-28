import 'package:flutter/foundation.dart';
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
import '../../utils/chart_point_transforms.dart';
import '../../utils/dashboard_date_range.dart';
import '../../utils/efficiency_metric.dart';
import '../../utils/site_system_navigation.dart';
import '../../utils/utility_chart_type.dart';
import '../chart/chart_period_controls.dart';
import '../chart/chart_type_selector.dart';
import '../chart/meter_comparison_selector.dart';
import '../chart_widgets.dart';
import '../premium/dashboard_date_quick_bar.dart';
import '../premium/premium_section_header.dart';

/// Analytics section — stacked toolbar rows; charts isolated from filter rebuilds.
class UtilityAnalyticsSection extends ConsumerWidget {
  const UtilityAnalyticsSection({
    super.key,
    required this.siteId,
    required this.system,
    required this.categoryId,
    required this.unitCode,
    required this.dateSelection,
    required this.onDateSelectionChanged,
    required this.useDesktop,
    this.compactHeader = false,
  });

  final String siteId;
  final UtilitySystemKey system;
  final String categoryId;
  final String unitCode;
  final DashboardDateSelection dateSelection;
  final ValueChanged<DashboardDateSelection> onDateSelectionChanged;
  final bool useDesktop;
  final bool compactHeader;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppStrings.of(context);
    final narrow = !useDesktop;
    final efficiencyMetric = system == UtilitySystemKey.btu
        ? ref.watch(selectedEfficiencyMetricProvider(siteId))
        : null;
    final inEfficiencyMode = efficiencyMetric != null;
    final sectionTitle = inEfficiencyMode
        ? (s.isAr
            ? 'تحليلات ${efficiencyMetric.labelAr}'
            : '${efficiencyMetric.labelEn} analysis')
        : s.utilityAnalytics(system);
    final sectionSubtitle = inEfficiencyMode
        ? (s.isAr
            ? 'اختر نوع المخطط للاتجاه المحدد'
            : 'Choose a chart type for the selected metric')
        : unitCode;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!compactHeader)
          PremiumSectionHeader(
            title: sectionTitle,
            subtitle: sectionSubtitle,
            showDivider: true,
          ),
        if (!compactHeader) const SizedBox(height: DashboardSpacing.sm),
        // On phones the site toolbar already owns the date picker.
        if (useDesktop) ...[
          AnalyticsControlPanel(
            child: DashboardDateQuickBar(
              selection: dateSelection,
              onChanged: (value) {
                onDateSelectionChanged(value);
                final periodKey = utilityChartPeriodKey(
                  siteId: siteId,
                  categoryCode: system.categoryCode,
                );
                final matched = chartPeriodStateForDateSelection(value);
                if (matched != null) {
                  ref.read(utilityChartPeriodProvider(periodKey).notifier).state =
                      matched;
                } else {
                  final current =
                      ref.read(utilityChartPeriodProvider(periodKey));
                  ref.read(utilityChartPeriodProvider(periodKey).notifier).state =
                      current.copyWith(preferChipOverCustomRange: false);
                }
              },
              siteId: siteId,
            ),
          ),
          const SizedBox(height: DashboardSpacing.sm),
        ],
        _PeriodRow(
          siteId: siteId,
          system: system,
          dateSelection: dateSelection,
        ),
        SizedBox(height: narrow ? DashboardSpacing.xs : DashboardSpacing.sm),
        _ChartTypeRow(
          siteId: siteId,
          categoryId: categoryId,
          system: system,
          dateSelection: dateSelection,
          efficiencyMode: inEfficiencyMode,
        ),
        if (!inEfficiencyMode) ...[
          SizedBox(height: narrow ? DashboardSpacing.xs : DashboardSpacing.sm),
          _ComparisonRow(
            siteId: siteId,
            categoryId: categoryId,
            system: system,
            dateSelection: dateSelection,
          ),
        ],
        SizedBox(height: narrow ? DashboardSpacing.sm : DashboardSpacing.md),
        Padding(
          padding: const EdgeInsets.only(bottom: DashboardSpacing.sm),
          child: _ChartPeriodLabel(
            siteId: siteId,
            system: system,
            dateSelection: dateSelection,
          ),
        ),
        RepaintBoundary(
          child: _AnalyticsChart(
            siteId: siteId,
            system: system,
            categoryId: categoryId,
            unitCode: unitCode,
            dateSelection: dateSelection,
            useDesktop: useDesktop,
            efficiencyMetric: efficiencyMetric,
          ),
        ),
      ],
    );
  }
}

({bool useCustom, ChartPeriodRange range}) _resolveChartRange({
  required UtilityChartPeriodState periodState,
  required DashboardDateSelection dateSelection,
}) {
  final matched = chartPeriodStateForDateSelection(dateSelection);
  final customRange = chartRangeForDateSelection(dateSelection);
  final dateImpliesCustom =
      matched == null && customRange != null && !dateSelection.isSingleDay;
  final useCustom =
      dateImpliesCustom && !periodState.preferChipOverCustomRange;
  final range = useCustom
      ? customRange
      : resolveUtilityChartPeriodRange(
          state: periodState,
          anchorDate: dateSelection.chartBusinessDate,
        );
  return (useCustom: useCustom, range: range);
}

class _PeriodRow extends ConsumerWidget {
  const _PeriodRow({
    required this.siteId,
    required this.system,
    required this.dateSelection,
  });

  final String siteId;
  final UtilitySystemKey system;
  final DashboardDateSelection dateSelection;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final periodKey = utilityChartPeriodKey(
      siteId: siteId,
      categoryCode: system.categoryCode,
    );
    final periodState = ref.watch(utilityChartPeriodProvider(periodKey));
    final resolved = _resolveChartRange(
      periodState: periodState,
      dateSelection: dateSelection,
    );

    return ChartPeriodControls(
      state: periodState,
      customRangeActive: resolved.useCustom,
      onChanged: (value) {
        if (kDebugMode) {
          debugPrint('[chart] period chip → ${value.kind.name}');
        }
        ref.read(utilityChartPeriodProvider(periodKey).notifier).state = value;
      },
    );
  }
}

class _ChartPeriodLabel extends ConsumerWidget {
  const _ChartPeriodLabel({
    required this.siteId,
    required this.system,
    required this.dateSelection,
  });

  final String siteId;
  final UtilitySystemKey system;
  final DashboardDateSelection dateSelection;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppStrings.of(context);
    final periodKey = utilityChartPeriodKey(
      siteId: siteId,
      categoryCode: system.categoryCode,
    );
    final periodState = ref.watch(utilityChartPeriodProvider(periodKey));
    final resolved = _resolveChartRange(
      periodState: periodState,
      dateSelection: dateSelection,
    );
    final range = resolved.range;
    final chartRangeText =
        '${range.from.month}/${range.from.day} – ${range.to.month}/${range.to.day}';
    final chartLabel = resolved.useCustom
        ? dateSelection.displayLabel
        : '${s.chartPeriodKindLabel(periodState.kind)} ($chartRangeText)';
    final metersLabel = s.dateSelectionLabel(dateSelection);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${s.metersRange}: $metersLabel',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: DashboardColors.textMuted(context),
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 2),
        Text(
          '${s.chartRange}: $chartLabel',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: DashboardColors.textPrimary(context),
              ),
        ),
      ],
    );
  }
}

class _ChartTypeRow extends ConsumerWidget {
  const _ChartTypeRow({
    required this.siteId,
    required this.categoryId,
    required this.system,
    required this.dateSelection,
    this.efficiencyMode = false,
  });

  final String siteId;
  final String categoryId;
  final UtilitySystemKey system;
  final DashboardDateSelection dateSelection;
  final bool efficiencyMode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final comparisonKey = meterComparisonKey(
      siteId: siteId,
      categoryId: categoryId,
    );
    final comparisonSelection =
        ref.watch(meterComparisonSelectionProvider(comparisonKey));
    final isComparing = !efficiencyMode && comparisonSelection.isNotEmpty;
    final periodKey = utilityChartPeriodKey(
      siteId: siteId,
      categoryCode: system.categoryCode,
    );
    final periodState = ref.watch(utilityChartPeriodProvider(periodKey));
    final resolved = _resolveChartRange(
      periodState: periodState,
      dateSelection: dateSelection,
    );
    final chartTypeKey = efficiencyMode
        ? utilityChartTypeKey(siteId, 'efficiency')
        : utilityChartTypeKey(siteId, system.categoryCode);
    final chartType = ref.watch(utilityChartTypeProvider(chartTypeKey));
    final availableChartTypes = efficiencyMode
        ? chartTypesForEfficiency(bucket: resolved.range.bucket)
        : isComparing
            ? comparisonChartTypesForUtility(
                system,
                bucket: resolved.range.bucket,
              )
            : chartTypesForUtility(
                system,
                bucket: resolved.range.bucket,
                isComparing: false,
              );
    final activeChartType = availableChartTypes.contains(chartType)
        ? chartType
        : availableChartTypes.first;

    return ChartTypeControls(
      child: ChartTypeSelector(
        types: availableChartTypes,
        selected: activeChartType,
        onChanged: (value) =>
            ref.read(utilityChartTypeProvider(chartTypeKey).notifier).state =
                value,
      ),
    );
  }
}

class _ComparisonRow extends ConsumerWidget {
  const _ComparisonRow({
    required this.siteId,
    required this.categoryId,
    required this.system,
    required this.dateSelection,
  });

  final String siteId;
  final String categoryId;
  final UtilitySystemKey system;
  final DashboardDateSelection dateSelection;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final comparisonKey = meterComparisonKey(
      siteId: siteId,
      categoryId: categoryId,
    );
    final meterDataQuery = MeterReadingCardsDataQuery(
      siteId: siteId,
      utilityKey: system.categoryCode,
      businessDate: dateSelection.meterQueryBusinessDate,
      previousBusinessDate: dateSelection.meterQueryPreviousDate,
      rangeStart: dateSelection.meterQueryRangeStart,
    );
    final meterCardsAsync =
        ref.watch(meterReadingCardsRawProvider(meterDataQuery));
    final meterCards =
        meterCardsAsync.valueOrNull ?? const <MeterReadingCardData>[];
    if (meterCards.isNotEmpty) {
      final allowedIds = meterCards.map((m) => m.meterId).toSet();
      final selected =
          ref.watch(meterComparisonSelectionProvider(comparisonKey));
      final pruned = selected.where(allowedIds.contains).toSet();
      final seeded = ref.watch(meterComparisonSeededProvider(comparisonKey));
      if (!seeded && pruned.isEmpty) {
        // Do not auto-seed comparison — that doubles chart fetches on open.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ref.read(meterComparisonSeededProvider(comparisonKey).notifier).state =
              true;
        });
      } else if (pruned.length != selected.length) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ref
              .read(meterComparisonSelectionProvider(comparisonKey).notifier)
              .state = pruned;
        });
      }
    }

    return AnalyticsControlPanel(
      padding: const EdgeInsets.symmetric(
        horizontal: DashboardSpacing.sm,
        vertical: DashboardSpacing.sm,
      ),
      child: MeterComparisonSelector(
        siteId: siteId,
        categoryId: categoryId,
        meters: meterCards,
        comparisonKey: comparisonKey,
      ),
    );
  }
}

class _AnalyticsChart extends ConsumerWidget {
  const _AnalyticsChart({
    required this.siteId,
    required this.system,
    required this.categoryId,
    required this.unitCode,
    required this.dateSelection,
    required this.useDesktop,
    this.efficiencyMetric,
  });

  final String siteId;
  final UtilitySystemKey system;
  final String categoryId;
  final String unitCode;
  final DashboardDateSelection dateSelection;
  final bool useDesktop;
  final EfficiencyMetric? efficiencyMetric;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppStrings.of(context);
    final periodKey = utilityChartPeriodKey(
      siteId: siteId,
      categoryCode: system.categoryCode,
    );
    final periodState = ref.watch(utilityChartPeriodProvider(periodKey));
    final inEfficiencyMode = efficiencyMetric != null;
    final chartTypeKeyName = inEfficiencyMode
        ? utilityChartTypeKey(siteId, 'efficiency')
        : utilityChartTypeKey(siteId, system.categoryCode);
    final chartType = ref.watch(utilityChartTypeProvider(chartTypeKeyName));
    final comparisonKey = meterComparisonKey(
      siteId: siteId,
      categoryId: categoryId,
    );
    final comparisonSelection =
        ref.watch(meterComparisonSelectionProvider(comparisonKey));

    final isComparing = !inEfficiencyMode && comparisonSelection.isNotEmpty;
    final resolved = _resolveChartRange(
      periodState: periodState,
      dateSelection: dateSelection,
    );
    final rangeOverride = resolved.range;
    final availableChartTypes = inEfficiencyMode
        ? chartTypesForEfficiency(bucket: rangeOverride.bucket)
        : isComparing
            ? comparisonChartTypesForUtility(
                system,
                bucket: rangeOverride.bucket,
              )
            : chartTypesForUtility(
                system,
                bucket: rangeOverride.bucket,
                isComparing: false,
              );
    final activeChartType = availableChartTypes.contains(chartType)
        ? chartType
        : availableChartTypes.first;

    final chartQuery = CategoryChartQuery(
      siteId: siteId,
      categoryId: categoryId,
      periodState: periodState,
      businessDate: dateSelection.chartBusinessDate,
      rangeOverride: rangeOverride,
    );
    final bundleAsync = isComparing
        ? const AsyncValue<CategoryChartBundle>.loading()
        : ref.watch(categoryChartBundleProvider(chartQuery));

    final meterDataQuery = MeterReadingCardsDataQuery(
      siteId: siteId,
      utilityKey: system.categoryCode,
      businessDate: dateSelection.meterQueryBusinessDate,
      previousBusinessDate: dateSelection.meterQueryPreviousDate,
      rangeStart: dateSelection.meterQueryRangeStart,
    );
    final meterCardsAsync =
        ref.watch(meterReadingCardsRawProvider(meterDataQuery));
    final meterCards =
        meterCardsAsync.valueOrNull ?? const <MeterReadingCardData>[];

    final periodLabel = resolved.useCustom
        ? dateSelection.displayLabel
        : '${s.chartPeriodKindLabel(periodState.kind)} (${rangeOverride.from.month}/${rangeOverride.from.day} – ${rangeOverride.to.month}/${rangeOverride.to.day})';
    final emptyChartMessage = s.noReadingsForPeriod;

    if (inEfficiencyMode) {
      return DashboardAnimations.chartFade(
        key: ValueKey('efficiency-${efficiencyMetric!.name}-chart'),
        child: DashboardChartCard(
          title: s.isAr
              ? 'اتجاه ${efficiencyMetric!.labelAr}'
              : '${efficiencyMetric!.labelEn} trend',
          subtitle: '${efficiencyMetric!.unitLabel} · $periodLabel',
          height: useDesktop ? 420 : 300,
          child: _EfficiencyChartBody(
            siteId: siteId,
            metric: efficiencyMetric!,
            chartType: activeChartType,
            periodState: periodState,
            businessDate: dateSelection.chartBusinessDate,
            bucket: rangeOverride.bucket,
            emptyMessage: emptyChartMessage,
          ),
        ),
      );
    }

    if (isComparing) {
      return DashboardAnimations.chartFade(
        key: const ValueKey('meter-comparison-chart'),
        child: DashboardChartCard(
          title: s.comparisonChartTitle(activeChartType, system),
          subtitle: '$unitCode · $periodLabel',
          height: useDesktop ? 420 : 300,
          child: _ComparisonChart(
            chartType: activeChartType,
            siteId: siteId,
            categoryId: categoryId,
            meterIds: comparisonSelection.toList()..sort(),
            periodState: periodState,
            businessDate: dateSelection.chartBusinessDate,
            rangeOverride: rangeOverride,
          ),
        ),
      );
    }

    return DashboardAnimations.chartFade(
      key: const ValueKey('utility-chart'),
      child: DashboardChartCard(
        title: s.utilityChartTitle(activeChartType, system),
        subtitle: '$unitCode · $periodLabel',
        height: useDesktop ? 420 : 300,
        scrollableChild: activeChartType == UtilityChartType.ranking,
        child: _UtilityChartBody(
          chartType: activeChartType,
          bundleAsync: bundleAsync,
          meterCards: meterCards,
          system: system,
          unitCode: unitCode,
          emptyMessage: emptyChartMessage,
          siteId: siteId,
          periodState: periodState,
          businessDate: dateSelection.chartBusinessDate,
          chartQuery: chartQuery,
          bucket: rangeOverride.bucket,
        ),
      ),
    );
  }
}

class _UtilityChartBody extends ConsumerWidget {
  const _UtilityChartBody({
    required this.chartType,
    required this.bundleAsync,
    required this.meterCards,
    required this.system,
    required this.unitCode,
    required this.emptyMessage,
    required this.siteId,
    required this.periodState,
    required this.businessDate,
    required this.chartQuery,
    required this.bucket,
  });

  final UtilityChartType chartType;
  final AsyncValue<CategoryChartBundle> bundleAsync;
  final List<MeterReadingCardData> meterCards;
  final UtilitySystemKey system;
  final String unitCode;
  final String emptyMessage;
  final String siteId;
  final UtilityChartPeriodState periodState;
  final DateTime businessDate;
  final CategoryChartQuery chartQuery;
  final ChartBucket bucket;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppStrings.of(context);

    if (chartType == UtilityChartType.sourceSplit) {
      return bundleAsync.when(
        loading: () => const ChartLoadingSkeleton(),
        error: (_, _) => ChartErrorPlaceholder(
          message: s.couldNotLoadChart,
          onRetry: () => ref.invalidate(categoryChartBundleProvider(chartQuery)),
        ),
        data: (bundle) => SourceSplitDonutChart(
          items: sourceSplitFromRanking(
            ranking: bundle.ranking,
            cards: meterCards,
          ),
          unitLabel: unitCode,
          emptyMessage: emptyMessage,
        ),
      );
    }

    return bundleAsync.when(
      loading: () => const ChartLoadingSkeleton(),
      error: (_, _) => ChartErrorPlaceholder(
        message: s.couldNotLoadChart,
        onRetry: () => ref.invalidate(categoryChartBundleProvider(chartQuery)),
      ),
      data: (bundle) => switch (chartType) {
        UtilityChartType.line => SingleSeriesLineChart(
            points: bundle.trend.points,
            color: system.accent,
            unitLabel: unitCode,
            emptyMessage: emptyMessage,
            bucket: bucket,
          ),
        UtilityChartType.bar => SingleSeriesBarChart(
            points: bundle.trend.points,
            color: system.accent,
            unitLabel: unitCode,
            emptyMessage: emptyMessage,
            bucket: bucket,
          ),
        UtilityChartType.area => SingleSeriesAreaChart(
            points: bundle.trend.points,
            color: system.accent,
            unitLabel: unitCode,
            emptyMessage: emptyMessage,
            bucket: bucket,
          ),
        UtilityChartType.step => SingleSeriesLineChart(
            points: bundle.trend.points,
            color: system.accent,
            unitLabel: unitCode,
            emptyMessage: emptyMessage,
            isStep: true,
            bucket: bucket,
          ),
        UtilityChartType.cumulative => SingleSeriesAreaChart(
            points: cumulativeChartPoints(bundle.trend.points),
            color: system.accent,
            unitLabel: unitCode,
            emptyMessage: emptyMessage,
            bucket: bucket,
          ),
        UtilityChartType.weekday => SingleSeriesBarChart(
            points: weekdayAveragePoints(
              bundle.trend.points,
              labels: [
                for (var i = 1; i <= 7; i++) s.weekdayAbbrev(i),
              ],
            ),
            color: system.accent,
            unitLabel: unitCode,
            emptyMessage: emptyMessage,
          ),
        UtilityChartType.ranking => HorizontalRankingBarChart(
            items: bundle.ranking,
            unitLabel: unitCode,
          ),
        UtilityChartType.pie => MeterSharePieChart(
            items: [
              for (final item in bundle.ranking)
                if (item.totalConsumption > 0)
                  (
                    label: s.localizedName(
                      en: item.meterName,
                      ar: item.meterNameAr,
                    ),
                    value: item.totalConsumption,
                  ),
            ],
            unitLabel: unitCode,
            emptyMessage: emptyMessage,
          ),
        UtilityChartType.stackedBar => SingleSeriesBarChart(
            points: bundle.trend.points,
            color: system.accent,
            unitLabel: unitCode,
            emptyMessage: emptyMessage,
            bucket: bucket,
          ),
        UtilityChartType.sourceSplit => const SizedBox.shrink(),
      },
    );
  }
}

class _ComparisonChart extends ConsumerWidget {
  const _ComparisonChart({
    required this.chartType,
    required this.siteId,
    required this.categoryId,
    required this.meterIds,
    required this.periodState,
    required this.businessDate,
    this.rangeOverride,
  });

  final UtilityChartType chartType;
  final String siteId;
  final String categoryId;
  final List<String> meterIds;
  final UtilityChartPeriodState periodState;
  final DateTime businessDate;
  final ChartPeriodRange? rangeOverride;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppStrings.of(context);
    final query = MeterComparisonQuery(
      siteId: siteId,
      categoryId: categoryId,
      meterIds: meterIds,
      periodState: periodState,
      businessDate: businessDate,
      rangeOverride: rangeOverride,
    );
    final comparisonAsync = ref.watch(meterComparisonProvider(query));

    return comparisonAsync.when(
      loading: () => const ChartLoadingSkeleton(),
      error: (_, _) => ChartErrorPlaceholder(
        message: s.couldNotLoadComparison,
        onRetry: () => ref.invalidate(meterComparisonProvider(query)),
      ),
      data: (result) => MeterComparisonChart(
        result: result,
        chartType: chartType,
        bucket: rangeOverride?.bucket,
      ),
    );
  }
}


class _EfficiencyChartBody extends ConsumerWidget {
  const _EfficiencyChartBody({
    required this.siteId,
    required this.metric,
    required this.chartType,
    required this.periodState,
    required this.businessDate,
    required this.bucket,
    required this.emptyMessage,
  });

  final String siteId;
  final EfficiencyMetric metric;
  final UtilityChartType chartType;
  final UtilityChartPeriodState periodState;
  final DateTime businessDate;
  final ChartBucket bucket;
  final String emptyMessage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppStrings.of(context);
    final copAsync = ref.watch(siteCopGroupsProvider(siteId));
    return copAsync.when(
      loading: () => const ChartLoadingSkeleton(),
      error: (_, _) => ChartErrorPlaceholder(
        message: s.couldNotLoadChart,
        onRetry: () => ref.invalidate(siteCopGroupsProvider(siteId)),
      ),
      data: (groups) {
        if (groups.isEmpty) {
          return ChartEmptyPlaceholder(
            message: s.isAr
                ? 'اضبط عدادات الكفاءة من إعدادات السياسات في تطبيق الأدمن.'
                : 'Configure efficiency meters in Admin policy settings.',
          );
        }
        final group = groups.first;
        final query = CopChartQuery(
          copGroupId: group.id,
          periodState: periodState,
          businessDate: businessDate,
        );
        final trendAsync = ref.watch(copTrendProvider(query));
        return trendAsync.when(
          loading: () => const ChartLoadingSkeleton(),
          error: (_, _) => ChartErrorPlaceholder(
            message: s.couldNotLoadChart,
            onRetry: () => ref.invalidate(copTrendProvider(query)),
          ),
          data: (result) {
            if (!result.hasData) {
              return ChartEmptyPlaceholder(message: emptyMessage);
            }
            final raw = [
              for (final point in result.points)
                if ((metric == EfficiencyMetric.eer ? point.eer : point.cop) !=
                    null)
                  TimeSeriesPoint(
                    date: point.date,
                    value: (metric == EfficiencyMetric.eer
                        ? point.eer
                        : point.cop)!,
                    label: formatBusinessDate(point.date).substring(5),
                  ),
            ];
            final points = switch (chartType) {
              UtilityChartType.cumulative => cumulativeChartPoints(raw),
              UtilityChartType.weekday => weekdayAveragePoints(
                  raw,
                  labels: [
                    for (var i = 1; i <= 7; i++) s.weekdayAbbrev(i),
                  ],
                ),
              _ => raw,
            };
            final unit = metric.unitLabel;
            final color = DashboardPalette.btu;
            return switch (chartType) {
              UtilityChartType.bar || UtilityChartType.weekday =>
                SingleSeriesBarChart(
                  points: points,
                  color: color,
                  unitLabel: unit,
                  emptyMessage: emptyMessage,
                  bucket: bucket,
                ),
              UtilityChartType.area || UtilityChartType.cumulative =>
                SingleSeriesAreaChart(
                  points: points,
                  color: color,
                  unitLabel: unit,
                  emptyMessage: emptyMessage,
                  bucket: bucket,
                ),
              UtilityChartType.step => SingleSeriesLineChart(
                  points: points,
                  color: color,
                  unitLabel: unit,
                  emptyMessage: emptyMessage,
                  isStep: true,
                  bucket: bucket,
                ),
              _ => SingleSeriesLineChart(
                  points: points,
                  color: color,
                  unitLabel: unit,
                  emptyMessage: emptyMessage,
                  bucket: bucket,
                ),
            };
          },
        );
      },
    );
  }
}
