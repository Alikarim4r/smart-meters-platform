import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_meters_core/smart_meters_core.dart';

import '../../l10n/app_strings.dart';
import '../../providers/chart_providers.dart';
import '../../providers/dashboard_providers.dart';
import '../../providers/meter_reading_card_providers.dart';
import '../../theme/design_system/dashboard_design_system.dart';
import '../../utils/chart_period_selection.dart';
import '../../utils/dashboard_date_range.dart';
import '../../utils/meter_reading_filters.dart';
import '../../utils/site_system_navigation.dart';
import '../../widgets/chart/chart_type_selector.dart';
import '../../widgets/dashboard_widgets.dart';
import '../../widgets/enterprise/analytics_workspace.dart';
import '../../widgets/enterprise/enterprise_section.dart';
import '../../widgets/enterprise/executive_kpi_strip.dart';
import '../../widgets/enterprise/meter_filter_toolbar.dart';
import '../../widgets/premium/skeleton_loaders.dart';
import '../../widgets/premium/utility_colors.dart';
import 'meter_readings_section.dart';
import 'efficiency_metric_cards.dart';

/// Utility page — enterprise visual hierarchy: overview → KPIs → filters → meters → analytics.
class UtilitySystemPanel extends ConsumerWidget {
  const UtilitySystemPanel({
    super.key,
    required this.siteId,
    required this.system,
    required this.useDesktop,
    this.showCopSection = false,
  });

  final String siteId;
  final UtilitySystemKey system;
  final bool useDesktop;
  final bool showCopSection;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppStrings.of(context);
    final padding = DashboardLayout.pagePadding(useDesktop);
    final dateSelection = ref.watch(siteDateSelectionProvider(siteId));
    final categoriesAsync =
        ref.watch(siteCategoriesSummaryForMonthProvider(siteId));
    final filterKey = meterCardFilterKey(siteId, system.categoryCode);

    final categorySummary = categoriesAsync.valueOrNull == null
        ? null
        : categorySummaryForUtility(categoriesAsync.value!, system);

    final unitCode = categorySummary?.category.baseUnitCode.isNotEmpty == true
        ? categorySummary!.category.baseUnitCode
        : system.defaultUnit;

    // KPIs from category summary only — don't wait on heavy meter-card fetch.
    final cardStats = (
      submitted: categorySummary?.readingsSubmittedToday ?? 0,
      pending: categorySummary?.pendingToday ?? 0,
      total: categorySummary?.meterCount ?? 0,
    );

    if (categoriesAsync.hasError) {
      return DashboardErrorState(
        title: s.couldNotLoadUtility,
        message: s.pleaseRefreshOrChangeDate,
        onRetry: () =>
            ref.invalidate(siteCategoriesSummaryForMonthProvider(siteId)),
      );
    }

    if (categoriesAsync.hasValue && categorySummary == null) {
      return DashboardEmptyState(
        title: s.noMetersAtSite(system),
        subtitle: s.addMetersHint(system),
      );
    }

    Future<void> onRefresh() async {
      ref.read(dashboardRepositoryProvider).invalidateSiteCaches(siteId);
      ref.invalidate(siteCategoriesSummaryForMonthProvider(siteId));
      ref.invalidate(siteDashboardSummaryProvider(siteId));
      final meterQuery = MeterReadingCardsQuery(
        siteId: siteId,
        utilityKey: system.categoryCode,
        businessDate: dateSelection.meterQueryBusinessDate,
        previousBusinessDate: dateSelection.meterQueryPreviousDate,
        rangeStart: dateSelection.meterQueryRangeStart,
      );
      ref.invalidate(meterReadingCardsRawProvider(meterQuery.dataQuery));
      if (categorySummary != null) {
        final periodState = chartPeriodStateForDateSelection(dateSelection) ??
            const UtilityChartPeriodState(
              kind: UtilityChartPeriodKind.last30Days,
            );
        ref.invalidate(
          categoryChartBundleProvider(
            CategoryChartQuery(
              siteId: siteId,
              categoryId: categorySummary.category.id,
              periodState: periodState,
              businessDate: dateSelection.chartBusinessDate,
              rangeOverride: chartRangeForDateSelection(dateSelection) ??
                  resolveUtilityChartPeriodRange(
                    state: periodState,
                    anchorDate: dateSelection.chartBusinessDate,
                  ),
            ),
          ),
        );
      }
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: EdgeInsets.fromLTRB(padding, padding, padding, 0),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                EnterpriseSection(
                  title: s.utilityTitle(system),
                  subtitle: s.utilityReadingsSubtitle(
                    system: system,
                    unitCode: unitCode,
                    selection: dateSelection,
                  ),
                ),
                if (categoriesAsync.isLoading && categorySummary == null)
                  const Row(
                    children: [
                      Expanded(child: StatCardSkeleton()),
                      SizedBox(width: DashboardSpacing.sm),
                      Expanded(child: StatCardSkeleton()),
                    ],
                  )
                else
                  ExecutiveKpiStrip(
                    items: [
                      ExecutiveKpi(
                        icon: Icons.speed_outlined,
                        label: s.totalMeters,
                        value: '${categorySummary?.meterCount ?? cardStats.total}',
                        accent: system.accent,
                      ),
                      ExecutiveKpi(
                        icon: Icons.check_circle_outline,
                        label: s.summarySubmitted(dateSelection),
                        value: '${cardStats.submitted}',
                        accent: DashboardUtilityColors.success,
                      ),
                      ExecutiveKpi(
                        icon: Icons.pending_actions_outlined,
                        label: s.summaryPending(dateSelection),
                        value: '${cardStats.pending}',
                      ),
                      ExecutiveKpi(
                        icon: Icons.donut_large_outlined,
                        label: s.summaryCompletion(dateSelection),
                        value: (categorySummary?.meterCount ?? cardStats.total) == 0
                            ? '—'
                            : '${completionPercentFromStats(submitted: cardStats.submitted, total: cardStats.total)}%',
                        accent: DashboardColors.accentGold(context),
                        emphasize: true,
                      ),
                    ],
                  ),
                SizedBox(height: DashboardLayout.sectionGap),
                MeterFilterToolbar(
                  filterKey: filterKey,
                  isWater: system == UtilitySystemKey.water,
                ),
                const SizedBox(height: DashboardLayout.blockGap),
              ]),
            ),
          ),
          SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: padding),
            sliver: MeterReadingsSliverSection(
              siteId: siteId,
              system: system,
              useDesktop: useDesktop,
              dateSelection: dateSelection,
              categoryId: categorySummary?.category.id,
            ),
          ),
          if (system == UtilitySystemKey.btu)
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                padding,
                DashboardLayout.sectionGap,
                padding,
                0,
              ),
              sliver: SliverToBoxAdapter(
                child: EfficiencyMetricCards(
                  siteId: siteId,
                  dateSelection: dateSelection,
                ),
              ),
            ),
          if (categorySummary != null)
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                padding,
                DashboardLayout.sectionGap,
                padding,
                padding +
                    DashboardSpacing.huge +
                    MediaQuery.viewPaddingOf(context).bottom,
              ),
              sliver: SliverToBoxAdapter(
                child: AnalyticsWorkspace(
                  siteId: siteId,
                  system: system,
                  categoryId: categorySummary.category.id,
                  unitCode: unitCode,
                  dateSelection: dateSelection,
                  onDateSelectionChanged: (value) {
                    ref.read(siteDateSelectionProvider(siteId).notifier).state =
                        value;
                    final matched = chartPeriodStateForDateSelection(value);
                    if (matched != null) {
                      final periodKey = utilityChartPeriodKey(
                        siteId: siteId,
                        categoryCode: system.categoryCode,
                      );
                      ref
                          .read(utilityChartPeriodProvider(periodKey).notifier)
                          .state = matched;
                    }
                  },
                  useDesktop: useDesktop,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
