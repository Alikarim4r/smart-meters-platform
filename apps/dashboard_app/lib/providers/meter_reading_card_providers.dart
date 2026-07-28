import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_meters_core/smart_meters_core.dart';

import '../providers/alert_providers.dart';
import '../providers/chart_providers.dart';
import '../utils/dashboard_date_range.dart';
import '../utils/efficiency_metric.dart';
import '../utils/meter_reading_filters.dart';
import '../utils/site_system_navigation.dart';
import '../utils/utility_chart_type.dart';

final networkMapLayerProvider =
    StateProvider<NetworkMapLayer>((ref) => NetworkMapLayer.allOverlay);

/// Server fetch key — date/utility only (no search/sort/filter).
class MeterReadingCardsDataQuery {
  const MeterReadingCardsDataQuery({
    required this.siteId,
    required this.utilityKey,
    required this.businessDate,
    this.previousBusinessDate,
    this.rangeStart,
  });

  final String siteId;
  final String utilityKey;
  final DateTime businessDate;
  final DateTime? previousBusinessDate;
  final DateTime? rangeStart;

  bool get isRangeMode =>
      rangeStart != null && !isSameDashboardDay(rangeStart!, businessDate);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MeterReadingCardsDataQuery &&
          siteId == other.siteId &&
          utilityKey == other.utilityKey &&
          businessDate == other.businessDate &&
          previousBusinessDate == other.previousBusinessDate &&
          rangeStart == other.rangeStart;

  @override
  int get hashCode => Object.hash(
        siteId,
        utilityKey,
        businessDate,
        previousBusinessDate,
        rangeStart,
      );
}

class MeterReadingCardsQuery {
  const MeterReadingCardsQuery({
    required this.siteId,
    required this.utilityKey,
    required this.businessDate,
    this.previousBusinessDate,
    this.rangeStart,
    this.search,
    this.sourceCode,
    this.statusFilter = MeterCardStatusFilter.all,
    this.sort = MeterCardSort.meterCode,
    this.sortAscending = true,
  });

  final String siteId;
  final String utilityKey;
  final DateTime businessDate;
  final DateTime? previousBusinessDate;
  final DateTime? rangeStart;
  final String? search;
  final String? sourceCode;
  final MeterCardStatusFilter statusFilter;
  final MeterCardSort sort;
  final bool sortAscending;

  bool get isRangeMode =>
      rangeStart != null && !isSameDashboardDay(rangeStart!, businessDate);

  MeterReadingCardsDataQuery get dataQuery => MeterReadingCardsDataQuery(
        siteId: siteId,
        utilityKey: utilityKey,
        businessDate: businessDate,
        previousBusinessDate: previousBusinessDate,
        rangeStart: rangeStart,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MeterReadingCardsQuery &&
          siteId == other.siteId &&
          utilityKey == other.utilityKey &&
          businessDate == other.businessDate &&
          previousBusinessDate == other.previousBusinessDate &&
          rangeStart == other.rangeStart &&
          search == other.search &&
          sourceCode == other.sourceCode &&
          statusFilter == other.statusFilter &&
          sort == other.sort &&
          sortAscending == other.sortAscending;

  @override
  int get hashCode => Object.hash(
        siteId,
        utilityKey,
        businessDate,
        previousBusinessDate,
        rangeStart,
        search,
        sourceCode,
        statusFilter,
        sort,
        sortAscending,
      );
}

final meterCardSearchProvider =
    StateProvider.family<String, String>((ref, key) => '');

final meterCardSourceFilterProvider =
    StateProvider.family<String?, String>((ref, key) => null);

final meterCardStatusFilterProvider =
    StateProvider.family<MeterCardStatusFilter, String>(
  (ref, key) => MeterCardStatusFilter.all,
);

final meterCardSortProvider =
    StateProvider.family<MeterCardSort, String>((ref, key) => MeterCardSort.meterCode);

final meterCardSortAscendingProvider =
    StateProvider.family<bool, String>((ref, key) => true);

/// Raw meter cards from repository — keyed by site/utility/date only.
final meterReadingCardsRawProvider = FutureProvider.autoDispose
    .family<List<MeterReadingCardData>, MeterReadingCardsDataQuery>(
  (ref, query) async {
    return ref.read(dashboardRepositoryProvider).getMeterReadingCardsForSite(
          siteId: query.siteId,
          utilityKey: query.utilityKey,
          businessDate: query.businessDate,
          previousBusinessDate: query.isRangeMode ? null : query.previousBusinessDate,
          rangeStart: query.isRangeMode ? query.rangeStart : null,
        );
  },
);

/// Filtered meter cards — search/sort/filter applied client-side; alerts enrich when ready.
final meterReadingCardsProvider = Provider.autoDispose
    .family<AsyncValue<List<MeterReadingCardData>>, MeterReadingCardsQuery>(
  (ref, query) {
    final rawAsync = ref.watch(meterReadingCardsRawProvider(query.dataQuery));
    final needsAlerts = query.statusFilter == MeterCardStatusFilter.hasAlert ||
        query.sort == MeterCardSort.alertsFirst;

    return rawAsync.when(
      loading: () => const AsyncLoading(),
      error: (e, st) => AsyncError(e, st),
      data: (cards) {
        var working = cards;
        if (needsAlerts) {
          final alertsAsync = ref.watch(siteAlertsProvider(query.siteId));
          working = alertsAsync.maybeWhen(
            data: (summary) => enrichMeterCardsWithAlerts(
              cards: cards,
              alerts: summary.alerts,
            ),
            orElse: () => cards,
          );
        }

        var filtered = applyMeterCardClientFilters(
          cards: working,
          statusFilter: query.statusFilter,
          sort: query.sort,
          ascending: query.sortAscending,
        );

        if (query.sourceCode != null && query.sourceCode!.isNotEmpty) {
          final code = query.sourceCode!.toLowerCase();
          filtered = filtered
              .where((c) => c.sourceCode.toLowerCase() == code)
              .toList();
        }

        final search = query.search?.trim().toLowerCase() ?? '';
        if (search.isNotEmpty) {
          filtered = filtered
              .where(
                (c) =>
                    c.meterCode.toLowerCase().contains(search) ||
                    c.meterName.toLowerCase().contains(search) ||
                    c.sourceName.toLowerCase().contains(search),
              )
              .toList();
        }

        return AsyncData(filtered);
      },
    );
  },
);

/// All utility meter cards for network schematic (current chart month anchor).
final siteNetworkMeterCardsProvider =
    FutureProvider.autoDispose.family<List<MeterReadingCardData>, String>(
  (ref, siteId) async {
    final selection = ref.watch(siteDateSelectionProvider(siteId));
    final businessDate = selection.meterQueryBusinessDate;

    final cards = <MeterReadingCardData>[];
    for (final system in UtilitySystemKey.values) {
      final utilityCards = await ref
          .read(dashboardRepositoryProvider)
          .getMeterReadingCardsForSite(
            siteId: siteId,
            utilityKey: system.categoryCode,
            businessDate: businessDate,
            previousBusinessDate:
                selection.meterQueryPreviousDate,
            rangeStart: selection.meterQueryRangeStart,
          );
      cards.addAll(utilityCards);
    }
    return cards;
  },
);

final utilityChartTypeProvider =
    StateProvider.autoDispose.family<UtilityChartType, String>(
  (ref, key) => UtilityChartType.line,
);

/// Selected COP/EER card on the BTU energy tab (`null` = normal consumption charts).
final selectedEfficiencyMetricProvider =
    StateProvider.autoDispose.family<EfficiencyMetric?, String>(
  (ref, siteId) => null,
);

final meterCardViewModeProvider =
    StateProvider.autoDispose.family<MeterCardViewMode, String>(
  (ref, key) => MeterCardViewMode.cards,
);

final waterSourceChipProvider =
    StateProvider.autoDispose.family<WaterSourceChip, String>(
  (ref, key) => WaterSourceChip.all,
);
