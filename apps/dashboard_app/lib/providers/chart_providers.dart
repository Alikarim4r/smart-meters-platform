import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_meters_core/smart_meters_core.dart';

import '../utils/chart_period_selection.dart';
import '../utils/dashboard_date_range.dart';
import '../utils/dashboard_filters.dart';
import 'dashboard_providers.dart';

final siteChartPeriodProvider =
    StateProvider.autoDispose.family<ChartPeriod, String>((ref, siteId) {
  return ChartPeriod.weekly;
});

/// Site date selection — kept alive so Week/Month/Year choices are not reset
/// when analytics sections remount.
///
/// Important: use [Ref.read] (not watch) for the business date. Watching would
/// recreate this provider and wipe the user's Week/Month/Year selection.
final siteDateSelectionProvider =
    StateProvider.family<DashboardDateSelection, String>((ref, siteId) {
  ref.keepAlive();
  return defaultDateSelectionForSite(
    siteId,
    ref.read(businessDateProvider),
  );
});

/// Legacy alias — prefer [siteDateSelectionProvider].
@Deprecated('Use siteDateSelectionProvider')
DashboardChartMonth chartMonthFromSelection(DashboardDateSelection selection) {
  return switch (selection.preset) {
    DashboardDatePreset.march2026 => DashboardChartMonth.march2026,
    DashboardDatePreset.april2026 => DashboardChartMonth.april2026,
    DashboardDatePreset.may2026 => DashboardChartMonth.may2026,
    _ => DashboardChartMonth.current,
  };
}

final siteCategoriesSummaryForMonthProvider =
    FutureProvider.autoDispose.family<List<SiteCategorySummary>, String>(
  (ref, siteId) async {
    final selection = ref.watch(siteDateSelectionProvider(siteId));
    return ref.read(dashboardRepositoryProvider).getSiteCategoriesSummary(
          siteId: siteId,
          businessDate: selection.selectedBusinessDate,
        );
  },
);

/// Chart period chips per utility analytics section (independent of meter dates).
final utilityChartPeriodProvider =
    StateProvider.autoDispose.family<UtilityChartPeriodState, String>((ref, key) {
  // Lighter default: last 7 days (daily) via weekly period mapping.
  // last30Days remains available as an explicit chip.
  return const UtilityChartPeriodState(
    kind: UtilityChartPeriodKind.last7Days,
  );
});

@Deprecated('Use utilityChartPeriodProvider')
final categoryChartPeriodProvider =
    StateProvider.autoDispose.family<ChartPeriod, String>((ref, key) {
  return ChartPeriod.weekly;
});

final copChartPeriodProvider =
    StateProvider.autoDispose.family<ChartPeriod, String>((ref, copGroupId) {
  return ChartPeriod.weekly;
});

final siteConsumptionTrendProvider = FutureProvider.autoDispose
    .family<SiteConsumptionTrend, SiteChartQuery>((ref, query) async {
  final DateTime businessDate = resolveBusinessDate(
    override: query.businessDate,
    fallback: ref.watch(businessDateProvider),
  );
  return ref.read(dashboardRepositoryProvider).getSiteConsumptionTrend(
        siteId: query.siteId,
        period: query.period,
        businessDate: businessDate,
      );
});

final siteTodayCompletionProvider =
    FutureProvider.autoDispose.family<TodayReadingProgress, String>(
  (ref, siteId) async {
    return ref.read(dashboardRepositoryProvider).getTodayCompletion(
          siteId: siteId,
          businessDate: ref.watch(businessDateProvider),
        );
  },
);

final categoryChartBundleProvider = FutureProvider.autoDispose
    .family<CategoryChartBundle, CategoryChartQuery>((ref, query) async {
  // Keep chart results for the session so remounts don't refetch immediately.
  final link = ref.keepAlive();
  Timer? disposeTimer;
  ref.onCancel(() {
    disposeTimer?.cancel();
    disposeTimer = Timer(const Duration(minutes: 5), link.close);
  });
  ref.onResume(() => disposeTimer?.cancel());
  ref.onDispose(() => disposeTimer?.cancel());

  final DateTime businessDate = resolveBusinessDate(
    override: query.businessDate,
    fallback: ref.watch(businessDateProvider),
  );
  final range = query.rangeOverride ??
      resolveUtilityChartPeriodRange(
        state: query.periodState,
        anchorDate: businessDate,
      );
  final legacyPeriod =
      query.rangeOverride?.period ?? legacyChartPeriodForState(query.periodState);

  if (kDebugMode) {
    debugPrint(
      '[chart] fetch start category=${query.categoryId} '
      'range=${range.from.toIso8601String().substring(0, 10)}..'
      '${range.to.toIso8601String().substring(0, 10)} '
      'bucket=${range.bucket.name}',
    );
  }
  final stopwatch = Stopwatch()..start();

  try {
    final bundle = await ref.read(dashboardRepositoryProvider).getCategoryChartBundle(
          siteId: query.siteId,
          categoryId: query.categoryId,
          period: legacyPeriod,
          businessDate: businessDate,
          rangeOverride: range,
        );

    if (kDebugMode) {
      debugPrint(
        '[chart] fetch end ${stopwatch.elapsedMilliseconds}ms '
        'points=${bundle.trend.points.length} '
        'nonzero=${bundle.trend.points.where((p) => p.value > 0).length}',
      );
    }
    return bundle;
  } catch (error, stack) {
    if (kDebugMode) {
      debugPrint(
        '[chart] fetch FAILED ${stopwatch.elapsedMilliseconds}ms error=$error',
      );
      debugPrint('$stack');
    }
    rethrow;
  }
});

final meterComparisonProvider = FutureProvider.autoDispose
    .family<MeterComparisonResult, MeterComparisonQuery>((ref, query) async {
  if (query.meterIds.length < 2) {
    return const MeterComparisonResult(
      series: [],
      baseUnit: '',
      canCompare: false,
      warningMessage: 'Select at least two meters to compare.',
    );
  }

  final DateTime businessDate = resolveBusinessDate(
    override: query.businessDate,
    fallback: ref.watch(businessDateProvider),
  );
  final range = query.rangeOverride ??
      resolveUtilityChartPeriodRange(
        state: query.periodState,
        anchorDate: businessDate,
      );
  final legacyPeriod =
      query.rangeOverride?.period ?? legacyChartPeriodForState(query.periodState);

  return ref.read(dashboardRepositoryProvider).getMeterComparisonTrend(
        siteId: query.siteId,
        categoryId: query.categoryId,
        meterIds: query.meterIds,
        period: legacyPeriod,
        businessDate: businessDate,
        rangeOverride: range,
      );
});

final copTrendProvider = FutureProvider.autoDispose
    .family<CopTrendResult, CopChartQuery>((ref, query) async {
  final DateTime businessDate = resolveBusinessDate(
    override: query.businessDate,
    fallback: ref.watch(businessDateProvider),
  );
  final range = resolveUtilityChartPeriodRange(
    state: query.periodState,
    anchorDate: businessDate,
  );
  final legacyPeriod = legacyChartPeriodForState(query.periodState);

  return ref.read(dashboardRepositoryProvider).getCopTrend(
        copGroupId: query.copGroupId,
        period: legacyPeriod,
        businessDate: businessDate,
        rangeOverride: range,
      );
});

final selectedCategoryIdProvider =
    StateProvider.autoDispose.family<String?, String>((ref, siteId) => null);

final meterComparisonSelectionProvider =
    StateProvider.autoDispose.family<Set<String>, String>((ref, key) => {});

/// Once true for a comparison key, auto-seed of main meters will not re-run
/// (so clearing selection stays cleared until the page is disposed).
final meterComparisonSeededProvider =
    StateProvider.autoDispose.family<bool, String>((ref, key) => false);

class SiteChartQuery {
  const SiteChartQuery({
    required this.siteId,
    required this.period,
    this.businessDate,
  });

  final String siteId;
  final ChartPeriod period;
  final DateTime? businessDate;

  @override
  bool operator ==(Object other) =>
      other is SiteChartQuery &&
      other.siteId == siteId &&
      other.period == period &&
      other.businessDate == businessDate;

  @override
  int get hashCode => Object.hash(siteId, period, businessDate);
}

class CategoryChartQuery {
  const CategoryChartQuery({
    required this.siteId,
    required this.categoryId,
    required this.periodState,
    this.businessDate,
    this.rangeOverride,
  });

  final String siteId;
  final String categoryId;
  final UtilityChartPeriodState periodState;
  final DateTime? businessDate;
  final ChartPeriodRange? rangeOverride;

  @override
  bool operator ==(Object other) =>
      other is CategoryChartQuery &&
      other.siteId == siteId &&
      other.categoryId == categoryId &&
      other.periodState == periodState &&
      other.businessDate == businessDate &&
      other.rangeOverride == rangeOverride;

  @override
  int get hashCode => Object.hash(
        siteId,
        categoryId,
        periodState,
        businessDate,
        rangeOverride,
      );
}

class MeterComparisonQuery {
  const MeterComparisonQuery({
    required this.siteId,
    required this.categoryId,
    required this.meterIds,
    required this.periodState,
    this.businessDate,
    this.rangeOverride,
  });

  final String siteId;
  final String categoryId;
  final List<String> meterIds;
  final UtilityChartPeriodState periodState;
  final DateTime? businessDate;
  final ChartPeriodRange? rangeOverride;

  @override
  bool operator ==(Object other) =>
      other is MeterComparisonQuery &&
      other.siteId == siteId &&
      other.categoryId == categoryId &&
      _listEquals(other.meterIds, meterIds) &&
      other.periodState == periodState &&
      other.businessDate == businessDate &&
      other.rangeOverride == rangeOverride;

  @override
  int get hashCode => Object.hash(
        siteId,
        categoryId,
        Object.hashAll(meterIds),
        periodState,
        businessDate,
        rangeOverride,
      );
}

class CopChartQuery {
  const CopChartQuery({
    required this.copGroupId,
    required this.periodState,
    this.businessDate,
  });

  final String copGroupId;
  final UtilityChartPeriodState periodState;
  final DateTime? businessDate;

  @override
  bool operator ==(Object other) =>
      other is CopChartQuery &&
      other.copGroupId == copGroupId &&
      other.periodState == periodState &&
      other.businessDate == businessDate;

  @override
  int get hashCode => Object.hash(copGroupId, periodState, businessDate);
}

bool _listEquals(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

String meterComparisonKey({
  required String siteId,
  required String categoryId,
}) =>
    '$siteId::$categoryId';

String utilityChartPeriodKey({
  required String siteId,
  required String categoryCode,
}) =>
    '$siteId::$categoryCode';
