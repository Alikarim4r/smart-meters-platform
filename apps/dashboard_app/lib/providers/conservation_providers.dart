import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_meters_core/smart_meters_core.dart';

import '../utils/site_system_navigation.dart';
import 'chart_providers.dart';
import 'dashboard_providers.dart';

/// True only when both `conservation_module` and `period_compare` are enabled
/// for the site's organization (site override wins). Defaults OFF.
final conservationPeriodCompareEnabledProvider =
    FutureProvider.autoDispose.family<bool, String>((ref, siteId) async {
  final summary =
      await ref.watch(siteDashboardSummaryProvider(siteId).future);
  final orgId = summary.site.organizationId;
  final flags = ConservationFeatureFlagRepository(
    ref.read(supabaseClientProvider),
  );
  final moduleOn = await flags.isEnabled(
    organizationId: orgId,
    flagKey: ConservationFeatureFlags.conservationModule,
    siteId: siteId,
  );
  if (!moduleOn) return false;
  return flags.isEnabled(
    organizationId: orgId,
    flagKey: ConservationFeatureFlags.periodCompare,
    siteId: siteId,
  );
});

class PeriodComparisonBundle {
  const PeriodComparisonBundle({
    required this.previous,
    required this.yoy,
    required this.unitCode,
    required this.utilityLabel,
  });

  final PeriodComparisonResult previous;
  final PeriodComparisonResult yoy;
  final String unitCode;
  final String utilityLabel;
}

/// Loads bounded readings and computes Previous + YoY per utility unit.
/// Short-circuits to empty when flags are OFF (no visual/data work).
final conservationPeriodComparisonsProvider = FutureProvider.autoDispose
    .family<List<PeriodComparisonBundle>, String>((ref, siteId) async {
  final enabled =
      await ref.watch(conservationPeriodCompareEnabledProvider(siteId).future);
  if (!enabled) return const [];

  final dateSelection = ref.watch(siteDateSelectionProvider(siteId));
  final currentStart = dateOnly(dateSelection.startDate);
  final currentEnd = dateOnly(dateSelection.endDate);
  final prev = previousPeriodOfEqualLength(currentStart, currentEnd);
  final yoy = samePeriodLastYear(currentStart, currentEnd);
  final windowStart = prev.start.isBefore(yoy.start) ? prev.start : yoy.start;
  // One day before earliest comparison start for endpoint baselines.
  final fetchFrom = windowStart.subtract(const Duration(days: 1));

  final client = ref.read(supabaseClientProvider);
  final meters =
      await ref.read(meterRepositoryProvider).getMetersForSite(siteId);
  final active = meters
      .where((m) => m.isActive && m.includeInDashboard)
      .toList();
  if (active.isEmpty) return const [];

  final meterIds = active.map((m) => m.id).toList();
  final fromIso =
      '${fetchFrom.year.toString().padLeft(4, '0')}-${fetchFrom.month.toString().padLeft(2, '0')}-${fetchFrom.day.toString().padLeft(2, '0')}';
  final toIso =
      '${currentEnd.year.toString().padLeft(4, '0')}-${currentEnd.month.toString().padLeft(2, '0')}-${currentEnd.day.toString().padLeft(2, '0')}';

  final rows = await client
      .from('meter_readings')
      .select('meter_id, reading_date, normalized_value')
      .eq('site_id', siteId)
      .inFilter('meter_id', meterIds)
      .gte('reading_date', fromIso)
      .lte('reading_date', toIso)
      .order('reading_date');

  final byMeter = <String, List<PeriodReadingPoint>>{};
  for (final row in (rows as List)) {
    final map = Map<String, dynamic>.from(row as Map);
    final id = map['meter_id'] as String;
    final date = DateTime.parse(map['reading_date'] as String);
    final value = (map['normalized_value'] as num).toDouble();
    byMeter.putIfAbsent(id, () => []).add(
          PeriodReadingPoint(date: date, value: value),
        );
  }

  const service = PeriodComparisonService();
  final bundles = <PeriodComparisonBundle>[];

  for (final system in UtilitySystemKey.values) {
    final unitMeters = active.where((m) {
      final code = (m.categoryConfig?.code ?? m.category.dbValue).toLowerCase();
      return switch (system) {
        UtilitySystemKey.water => code.contains('water'),
        UtilitySystemKey.electricity => code.contains('electric'),
        UtilitySystemKey.btu => code.contains('btu'),
        UtilitySystemKey.fuel => code.contains('fuel'),
      };
    }).toList();
    if (unitMeters.isEmpty) continue;

    final unitCode = system.defaultUnit;
    final series = [
      for (final m in unitMeters)
        PeriodMeterReadingSeries(
          meterId: m.id,
          unitCode: unitCode,
          // Values already normalized from DB.
          meterMultiplier: 1,
          readings: byMeter[m.id] ?? const [],
        ),
    ];

    bundles.add(
      PeriodComparisonBundle(
        utilityLabel: system.label,
        unitCode: unitCode,
        previous: service.compareMeters(
          type: PeriodComparisonType.previousPeriod,
          currentStart: currentStart,
          currentEnd: currentEnd,
          meters: series,
          unitCode: unitCode,
          siteId: siteId,
        ),
        yoy: service.compareMeters(
          type: PeriodComparisonType.samePeriodLastYear,
          currentStart: currentStart,
          currentEnd: currentEnd,
          meters: series,
          unitCode: unitCode,
          siteId: siteId,
        ),
      ),
    );
  }

  return bundles;
});
