import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_meters_core/smart_meters_core.dart';

import '../utils/site_system_navigation.dart';
import 'chart_providers.dart';
import 'dashboard_providers.dart';

/// True when master conservation module flag is ON (defaults OFF).
final conservationModuleEnabledProvider =
    FutureProvider.autoDispose.family<bool, String>((ref, siteId) async {
  final summary =
      await ref.watch(siteDashboardSummaryProvider(siteId).future);
  final flags = ConservationFeatureFlagRepository(
    ref.read(supabaseClientProvider),
  );
  return flags.isEnabled(
    organizationId: summary.site.organizationId,
    flagKey: ConservationFeatureFlags.conservationModule,
    siteId: siteId,
  );
});

/// True only when both `conservation_module` and `period_compare` are enabled.
final conservationPeriodCompareEnabledProvider =
    FutureProvider.autoDispose.family<bool, String>((ref, siteId) async {
  final moduleOn =
      await ref.watch(conservationModuleEnabledProvider(siteId).future);
  if (!moduleOn) return false;
  final summary =
      await ref.watch(siteDashboardSummaryProvider(siteId).future);
  final flags = ConservationFeatureFlagRepository(
    ref.read(supabaseClientProvider),
  );
  return flags.isEnabled(
    organizationId: summary.site.organizationId,
    flagKey: ConservationFeatureFlags.periodCompare,
    siteId: siteId,
  );
});

/// True only when both `conservation_module` and `targets` are enabled.
final conservationTargetsEnabledProvider =
    FutureProvider.autoDispose.family<bool, String>((ref, siteId) async {
  final moduleOn =
      await ref.watch(conservationModuleEnabledProvider(siteId).future);
  if (!moduleOn) return false;
  final summary =
      await ref.watch(siteDashboardSummaryProvider(siteId).future);
  final flags = ConservationFeatureFlagRepository(
    ref.read(supabaseClientProvider),
  );
  return flags.isEnabled(
    organizationId: summary.site.organizationId,
    flagKey: ConservationFeatureFlags.targets,
    siteId: siteId,
  );
});

/// True only when both `conservation_module` and `baseline` are enabled.
final conservationBaselineEnabledProvider =
    FutureProvider.autoDispose.family<bool, String>((ref, siteId) async {
  final moduleOn =
      await ref.watch(conservationModuleEnabledProvider(siteId).future);
  if (!moduleOn) return false;
  final summary =
      await ref.watch(siteDashboardSummaryProvider(siteId).future);
  final flags = ConservationFeatureFlagRepository(
    ref.read(supabaseClientProvider),
  );
  return flags.isEnabled(
    organizationId: summary.site.organizationId,
    flagKey: ConservationFeatureFlags.baseline,
    siteId: siteId,
  );
});

/// True only when both `conservation_module` and `virtual_meters` are enabled.
final conservationVirtualMetersEnabledProvider =
    FutureProvider.autoDispose.family<bool, String>((ref, siteId) async {
  final moduleOn =
      await ref.watch(conservationModuleEnabledProvider(siteId).future);
  if (!moduleOn) return false;
  final summary =
      await ref.watch(siteDashboardSummaryProvider(siteId).future);
  final flags = ConservationFeatureFlagRepository(
    ref.read(supabaseClientProvider),
  );
  return flags.isEnabled(
    organizationId: summary.site.organizationId,
    flagKey: ConservationFeatureFlags.virtualMeters,
    siteId: siteId,
  );
});

/// Conservation nav/section visible when module + any P1B–P1E child flag.
final conservationSectionVisibleProvider =
    FutureProvider.autoDispose.family<bool, String>((ref, siteId) async {
  if (await ref.watch(conservationPeriodCompareEnabledProvider(siteId).future)) {
    return true;
  }
  if (await ref.watch(conservationTargetsEnabledProvider(siteId).future)) {
    return true;
  }
  if (await ref.watch(conservationBaselineEnabledProvider(siteId).future)) {
    return true;
  }
  return ref.watch(conservationVirtualMetersEnabledProvider(siteId).future);
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

/// Active targets evaluated for the site (flags OFF → empty).
final conservationActualVsTargetProvider = FutureProvider.autoDispose
    .family<List<ActualVsTargetResult>, String>((ref, siteId) async {
  final enabled =
      await ref.watch(conservationTargetsEnabledProvider(siteId).future);
  if (!enabled) return const [];

  final repo = ConservationTargetRepository(ref.read(supabaseClientProvider));
  final targets = await repo.listForSite(
    siteId,
    status: ConservationTargetStatus.active,
  );
  if (targets.isEmpty) return const [];

  final dateSelection = ref.watch(siteDateSelectionProvider(siteId));
  final asOf = dateOnly(dateSelection.endDate);

  final meters =
      await ref.read(meterRepositoryProvider).getMetersForSite(siteId);
  final active = meters
      .where((m) => m.isActive && m.includeInDashboard)
      .toList();

  // Bound fetch: earliest target start − 1 day through analysis as-of.
  // Note: −1 day is a fetch window only — service does not invent a reading
  // on periodStart−1; it uses the latest prior reading if present.
  DateTime fetchFrom = asOf;
  for (final t in targets) {
    final start = dateOnly(t.periodStart).subtract(const Duration(days: 1));
    if (start.isBefore(fetchFrom)) fetchFrom = start;
  }

  final meterIds = active.map((m) => m.id).toList();
  final fromIso =
      '${fetchFrom.year.toString().padLeft(4, '0')}-${fetchFrom.month.toString().padLeft(2, '0')}-${fetchFrom.day.toString().padLeft(2, '0')}';
  final toIso =
      '${asOf.year.toString().padLeft(4, '0')}-${asOf.month.toString().padLeft(2, '0')}-${asOf.day.toString().padLeft(2, '0')}';

  final byMeter = <String, List<PeriodReadingPoint>>{};
  if (meterIds.isNotEmpty) {
    final rows = await ref
        .read(supabaseClientProvider)
        .from('meter_readings')
        .select('meter_id, reading_date, normalized_value')
        .eq('site_id', siteId)
        .inFilter('meter_id', meterIds)
        .gte('reading_date', fromIso)
        .lte('reading_date', toIso)
        .order('reading_date');
    for (final row in (rows as List)) {
      final map = Map<String, dynamic>.from(row as Map);
      final id = map['meter_id'] as String;
      byMeter.putIfAbsent(id, () => []).add(
            PeriodReadingPoint(
              date: DateTime.parse(map['reading_date'] as String),
              value: (map['normalized_value'] as num).toDouble(),
            ),
          );
    }
  }

  const service = ActualVsTargetService();
  final results = <ActualVsTargetResult>[];
  for (final t in targets) {
    if (t.scopeType != ConservationTargetScopeType.site) continue;

    final matchingMeters = active.where((m) {
      final code = (m.categoryConfig?.code ?? m.category.dbValue).toLowerCase();
      final unit = t.unitCode;
      if (unit == 'kWh' || unit.toLowerCase() == 'kwh') {
        return code.contains('electric');
      }
      if (unit == 'm³' || unit.toLowerCase().contains('m3')) {
        return code.contains('water');
      }
      if (unit.toUpperCase() == 'BTU') return code.contains('btu');
      if (unit == 'L' || unit.toLowerCase() == 'l') {
        return code.contains('fuel');
      }
      return m.unitDisplayLabel == unit || m.baseUnit == unit;
    }).toList();

    final series = [
      for (final m in matchingMeters)
        PeriodMeterReadingSeries(
          meterId: m.id,
          unitCode: t.unitCode,
          readings: byMeter[m.id] ?? const [],
        ),
    ];
    results.add(
      service.evaluate(
        target: t,
        meters: series,
        analysisAsOf: asOf,
      ),
    );
  }
  return results;
});

/// Approved baselines only (no full history) → Actual vs Baseline.
final conservationActualVsBaselineProvider = FutureProvider.autoDispose
    .family<List<ActualVsBaselineResult>, String>((ref, siteId) async {
  final enabled =
      await ref.watch(conservationBaselineEnabledProvider(siteId).future);
  if (!enabled) return const [];

  final repo = ConservationBaselineRepository(ref.read(supabaseClientProvider));
  final baselines = await repo.listApprovedForSite(siteId);
  if (baselines.isEmpty) return const [];

  final dateSelection = ref.watch(siteDateSelectionProvider(siteId));
  final periodStart = dateOnly(dateSelection.startDate);
  final periodEnd = dateOnly(dateSelection.endDate);
  final asOf = dateOnly(dateSelection.endDate);

  final meters =
      await ref.read(meterRepositoryProvider).getMetersForSite(siteId);
  final active = meters
      .where((m) => m.isActive && m.includeInDashboard)
      .toList();

  DateTime fetchFrom = periodStart.subtract(const Duration(days: 1));

  final meterIds = active.map((m) => m.id).toList();
  final fromIso =
      '${fetchFrom.year.toString().padLeft(4, '0')}-${fetchFrom.month.toString().padLeft(2, '0')}-${fetchFrom.day.toString().padLeft(2, '0')}';
  final toIso =
      '${asOf.year.toString().padLeft(4, '0')}-${asOf.month.toString().padLeft(2, '0')}-${asOf.day.toString().padLeft(2, '0')}';

  final byMeter = <String, List<PeriodReadingPoint>>{};
  if (meterIds.isNotEmpty) {
    final rows = await ref
        .read(supabaseClientProvider)
        .from('meter_readings')
        .select('meter_id, reading_date, normalized_value')
        .eq('site_id', siteId)
        .inFilter('meter_id', meterIds)
        .gte('reading_date', fromIso)
        .lte('reading_date', toIso)
        .order('reading_date');
    for (final row in (rows as List)) {
      final map = Map<String, dynamic>.from(row as Map);
      final id = map['meter_id'] as String;
      byMeter.putIfAbsent(id, () => []).add(
            PeriodReadingPoint(
              date: DateTime.parse(map['reading_date'] as String),
              value: (map['normalized_value'] as num).toDouble(),
            ),
          );
    }
  }

  const service = ActualVsBaselineService();
  final results = <ActualVsBaselineResult>[];
  for (final b in baselines) {
    if (b.scopeType != ConservationBaselineScopeType.site) continue;
    final matchingMeters = active.where((m) {
      final code = (m.categoryConfig?.code ?? m.category.dbValue).toLowerCase();
      final unit = b.unitCode;
      if (unit == 'kWh' || unit.toLowerCase() == 'kwh') {
        return code.contains('electric');
      }
      if (unit == 'm³' || unit.toLowerCase().contains('m3')) {
        return code.contains('water');
      }
      if (unit.toUpperCase() == 'BTU') return code.contains('btu');
      if (unit == 'L' || unit.toLowerCase() == 'l') {
        return code.contains('fuel');
      }
      return m.unitDisplayLabel == unit || m.baseUnit == unit;
    }).toList();
    final series = [
      for (final m in matchingMeters)
        PeriodMeterReadingSeries(
          meterId: m.id,
          unitCode: b.unitCode,
          readings: byMeter[m.id] ?? const [],
        ),
    ];
    results.add(
      service.evaluate(
        baseline: b,
        meters: series,
        analysisPeriodStart: periodStart,
        analysisPeriodEnd: periodEnd,
        analysisAsOf: asOf,
      ),
    );
  }
  return results;
});

/// Lightweight virtual meter previews (flags OFF → empty).
final conservationVirtualMeterPreviewsProvider = FutureProvider.autoDispose
    .family<List<VirtualMeterResult>, String>((ref, siteId) async {
  final enabled =
      await ref.watch(conservationVirtualMetersEnabledProvider(siteId).future);
  if (!enabled) return const [];

  final vmRepo = VirtualMeterRepository(ref.read(supabaseClientProvider));
  final virtuals = await vmRepo.listVirtualMetersForSite(siteId);
  if (virtuals.isEmpty) return const [];

  final dateSelection = ref.watch(siteDateSelectionProvider(siteId));
  final periodStart = dateOnly(dateSelection.startDate);
  final periodEnd = dateOnly(dateSelection.endDate);
  final memberMap = await vmRepo.listMemberIdsForSite(siteId);
  final meters =
      await ref.read(meterRepositoryProvider).getMetersForSite(siteId);
  final byId = {for (final m in meters) m.id: m};

  final allLeafIds = <String>{};
  for (final v in virtuals) {
    final members = memberMap[v.id] ?? const <String>[];
    final expansion = const VirtualMeterValidation().expandLeaves(
      rootVirtualId: v.id,
      directMemberIds: members,
      metersById: byId,
      memberIdsByVirtualId: memberMap,
    );
    allLeafIds.addAll(expansion.leafMeterIds);
    if (v.parentMeterId != null) allLeafIds.add(v.parentMeterId!);
  }

  final fetchFrom = periodStart.subtract(const Duration(days: 1));
  final fromIso =
      '${fetchFrom.year.toString().padLeft(4, '0')}-${fetchFrom.month.toString().padLeft(2, '0')}-${fetchFrom.day.toString().padLeft(2, '0')}';
  final toIso =
      '${periodEnd.year.toString().padLeft(4, '0')}-${periodEnd.month.toString().padLeft(2, '0')}-${periodEnd.day.toString().padLeft(2, '0')}';
  final byMeter = <String, List<PeriodReadingPoint>>{};
  if (allLeafIds.isNotEmpty) {
    final rows = await ref
        .read(supabaseClientProvider)
        .from('meter_readings')
        .select('meter_id, reading_date, normalized_value')
        .eq('site_id', siteId)
        .inFilter('meter_id', allLeafIds.toList())
        .gte('reading_date', fromIso)
        .lte('reading_date', toIso)
        .order('reading_date');
    for (final row in (rows as List)) {
      final map = Map<String, dynamic>.from(row as Map);
      final id = map['meter_id'] as String;
      byMeter.putIfAbsent(id, () => []).add(
            PeriodReadingPoint(
              date: DateTime.parse(map['reading_date'] as String),
              value: (map['normalized_value'] as num).toDouble(),
            ),
          );
    }
  }

  const calculator = VirtualMeterCalculator();
  final results = <VirtualMeterResult>[];
  for (final v in virtuals) {
    final unit = v.baseUnit.isNotEmpty ? v.baseUnit : v.unit.dbValue;
    final expansion = const VirtualMeterValidation().expandLeaves(
      rootVirtualId: v.id,
      directMemberIds: memberMap[v.id] ?? const [],
      metersById: byId,
      memberIdsByVirtualId: memberMap,
    );
    if (expansion.issues.any((i) => i.isError)) {
      results.add(
        calculator.calculate(
          calculationType: v.calculationType,
          unitCode: unit,
          periodStart: periodStart,
          periodEnd: periodEnd,
          children: const [],
          hierarchyDepth: expansion.depth,
        ),
      );
      continue;
    }
    final leafSeries = [
      for (final id in expansion.leafMeterIds)
        PeriodMeterReadingSeries(
          meterId: id,
          unitCode: unit,
          meterMultiplier: 1,
          readings: byMeter[id] ?? const [],
        ),
    ];
    final children = calculator.contributorsFromSeries(
      leaves: leafSeries,
      periodStart: periodStart,
      periodEnd: periodEnd,
    );
    VirtualMeterContributorInput? parent;
    if (v.calculationType == CalculationType.parentMinusChildren &&
        v.parentMeterId != null) {
      parent = calculator
          .contributorsFromSeries(
            leaves: [
              PeriodMeterReadingSeries(
                meterId: v.parentMeterId!,
                unitCode: unit,
                meterMultiplier: 1,
                readings: byMeter[v.parentMeterId!] ?? const [],
              ),
            ],
            periodStart: periodStart,
            periodEnd: periodEnd,
          )
          .single;
    }
    results.add(
      calculator.calculate(
        calculationType: v.calculationType,
        unitCode: unit,
        periodStart: periodStart,
        periodEnd: periodEnd,
        children: children,
        parent: parent,
        hierarchyDepth: expansion.depth,
      ),
    );
  }
  return results;
});
