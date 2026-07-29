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

/// True only when both `conservation_module` and `water_balance` are enabled.
final conservationWaterBalanceEnabledProvider =
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
    flagKey: ConservationFeatureFlags.waterBalance,
    siteId: siteId,
  );
});

/// True only when both `conservation_module` and `energy_balance` are enabled.
final conservationEnergyBalanceEnabledProvider =
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
    flagKey: ConservationFeatureFlags.energyBalance,
    siteId: siteId,
  );
});

/// True only when both `conservation_module` and `benchmarking` are enabled.
final conservationBenchmarkingEnabledProvider =
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
    flagKey: ConservationFeatureFlags.benchmarking,
    siteId: siteId,
  );
});

/// True only when both `conservation_module` and `intensity` are enabled.
final conservationIntensityEnabledProvider =
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
    flagKey: ConservationFeatureFlags.intensity,
    siteId: siteId,
  );
});

/// True only when both `conservation_module` and `periodic_anomalies` are enabled.
final conservationPeriodicAnomaliesEnabledProvider =
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
    flagKey: ConservationFeatureFlags.periodicAnomalies,
    siteId: siteId,
  );
});

/// True only when both `conservation_module` and `cop_conservation` are enabled.
final conservationCopConservationEnabledProvider =
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
    flagKey: ConservationFeatureFlags.copConservation,
    siteId: siteId,
  );
});

/// Conservation nav/section visible when module + any P1/P2 child flag.
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
  if (await ref.watch(conservationVirtualMetersEnabledProvider(siteId).future)) {
    return true;
  }
  if (await ref.watch(conservationWaterBalanceEnabledProvider(siteId).future)) {
    return true;
  }
  if (await ref.watch(conservationEnergyBalanceEnabledProvider(siteId).future)) {
    return true;
  }
  if (await ref.watch(conservationBenchmarkingEnabledProvider(siteId).future)) {
    return true;
  }
  if (await ref.watch(conservationIntensityEnabledProvider(siteId).future)) {
    return true;
  }
  if (await ref
      .watch(conservationPeriodicAnomaliesEnabledProvider(siteId).future)) {
    return true;
  }
  return ref.watch(conservationCopConservationEnabledProvider(siteId).future);
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

// ---------------------------------------------------------------------------
// Phase 2 data providers (short-circuit empty when flags OFF)
// ---------------------------------------------------------------------------

class ConservationBalanceBundle {
  const ConservationBalanceBundle({
    required this.group,
    required this.result,
    required this.meterNamesById,
  });

  final BalanceGroup group;
  final BalanceResult result;
  final Map<String, String> meterNamesById;
}

class ConservationBenchmarkBundle {
  const ConservationBenchmarkBundle({
    required this.utilityLabel,
    required this.unitCode,
    required this.consumption,
    required this.snapshot,
    this.intensity,
    this.peerComparison,
    this.peerMedian,
    this.peerProfileCount = 0,
    this.warnings = const [],
  });

  final String utilityLabel;
  final String unitCode;
  final double? consumption;
  final BenchmarkSiteSnapshot snapshot;
  final IntensityResult? intensity;
  final BenchmarkComparisonResult? peerComparison;
  final double? peerMedian;
  final int peerProfileCount;
  final List<String> warnings;
}

class ConservationAnomalyBundle {
  const ConservationAnomalyBundle({
    required this.title,
    required this.result,
    this.unitCode,
  });

  final String title;
  final ConsumptionAnomalyResult result;
  final String? unitCode;
}

String _isoDate(DateTime d) {
  final x = dateOnly(d);
  return '${x.year.toString().padLeft(4, '0')}-'
      '${x.month.toString().padLeft(2, '0')}-'
      '${x.day.toString().padLeft(2, '0')}';
}

bool _meterMatchesUtility(Meter m, String utility) {
  final code = (m.categoryConfig?.code ?? m.category.dbValue).toLowerCase();
  return switch (utility) {
    'water' => code.contains('water'),
    'electricity' => code.contains('electric'),
    _ => false,
  };
}

PeriodConsumptionSnapshot _aggregateUtilityPeriod({
  required List<PeriodMeterReadingSeries> meters,
  required DateTime periodStart,
  required DateTime periodEnd,
}) {
  if (meters.isEmpty) {
    return PeriodConsumptionSnapshot(
      periodStart: periodStart,
      periodEnd: periodEnd,
      value: null,
      hasValidEndpoints: false,
      readingCount: 0,
      completeness: 0,
      confidenceScore: 0,
    );
  }
  const service = PeriodComparisonService();
  final r = service.compareMeters(
    type: PeriodComparisonType.previousPeriod,
    currentStart: periodStart,
    currentEnd: periodEnd,
    meters: meters,
    unitCode: meters.first.unitCode,
  );
  return PeriodConsumptionSnapshot(
    periodStart: periodStart,
    periodEnd: periodEnd,
    value: r.currentValue,
    hasValidEndpoints: r.currentValue != null,
    readingCount: 0,
    completeness: r.currentCompleteness,
    confidenceScore: r.currentPeriodConfidence,
  );
}

/// Active balance groups evaluated for the selected date range (flags OFF → []).
final conservationBalanceResultsProvider = FutureProvider.autoDispose
    .family<List<ConservationBalanceBundle>, String>((ref, siteId) async {
  final waterOn =
      await ref.watch(conservationWaterBalanceEnabledProvider(siteId).future);
  final energyOn =
      await ref.watch(conservationEnergyBalanceEnabledProvider(siteId).future);
  if (!waterOn && !energyOn) return const [];

  final groupRepo = BalanceGroupRepository(ref.read(supabaseClientProvider));
  final groups = await groupRepo.listForSite(siteId);
  final active = groups.where((g) {
    if (g.status != BalanceGroupStatus.active) return false;
    final u = g.utilityCode.toLowerCase();
    if (u == 'water') return waterOn;
    if (u == 'electricity') return energyOn;
    return false;
  }).toList();
  if (active.isEmpty) return const [];

  final dateSelection = ref.watch(siteDateSelectionProvider(siteId));
  final periodStart = dateOnly(dateSelection.startDate);
  final periodEnd = dateOnly(dateSelection.endDate);
  final meters =
      await ref.read(meterRepositoryProvider).getMetersForSite(siteId);
  final names = {
    for (final m in meters) m.id: m.nameEn.isNotEmpty ? m.nameEn : m.meterCode,
  };

  final meterIds = <String>{};
  for (final g in active) {
    meterIds.add(g.mainMeterId);
    meterIds.addAll(g.memberMeterIds);
  }

  final fetchFrom = periodStart.subtract(const Duration(days: 1));
  final byMeter = <String, List<PeriodReadingPoint>>{};
  if (meterIds.isNotEmpty) {
    final rows = await ref
        .read(supabaseClientProvider)
        .from('meter_readings')
        .select('meter_id, reading_date, normalized_value')
        .eq('site_id', siteId)
        .inFilter('meter_id', meterIds.toList())
        .gte('reading_date', _isoDate(fetchFrom))
        .lte('reading_date', _isoDate(periodEnd))
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
  const balance = BalanceService();
  final results = <ConservationBalanceBundle>[];

  for (final g in active) {
    final unit = g.unitCode;
    final childrenSeries = [
      for (final id in g.memberMeterIds)
        PeriodMeterReadingSeries(
          meterId: id,
          unitCode: unit,
          meterMultiplier: 1,
          readings: byMeter[id] ?? const [],
        ),
    ];
    final children = calculator.contributorsFromSeries(
      leaves: childrenSeries,
      periodStart: periodStart,
      periodEnd: periodEnd,
    );
    final main = calculator
        .contributorsFromSeries(
          leaves: [
            PeriodMeterReadingSeries(
              meterId: g.mainMeterId,
              unitCode: unit,
              meterMultiplier: 1,
              readings: byMeter[g.mainMeterId] ?? const [],
            ),
          ],
          periodStart: periodStart,
          periodEnd: periodEnd,
        )
        .single;
    results.add(
      ConservationBalanceBundle(
        group: g,
        result: balance.evaluate(
          utilityCode: g.utilityCode,
          unitCode: unit,
          mainMeterId: g.mainMeterId,
          children: children,
          main: main,
          periodStart: periodStart,
          periodEnd: periodEnd,
          balanceGroupId: g.id,
        ),
        meterNamesById: names,
      ),
    );
  }
  return results;
});

/// Site intensity / peer snapshot (benchmarking|intensity OFF → []).
final conservationBenchmarkProvider = FutureProvider.autoDispose
    .family<List<ConservationBenchmarkBundle>, String>((ref, siteId) async {
  final benchmarkingOn =
      await ref.watch(conservationBenchmarkingEnabledProvider(siteId).future);
  final intensityOn =
      await ref.watch(conservationIntensityEnabledProvider(siteId).future);
  if (!benchmarkingOn && !intensityOn) return const [];

  final summary =
      await ref.watch(siteDashboardSummaryProvider(siteId).future);
  final dateSelection = ref.watch(siteDateSelectionProvider(siteId));
  final periodStart = dateOnly(dateSelection.startDate);
  final periodEnd = dateOnly(dateSelection.endDate);
  final prev = previousPeriodOfEqualLength(periodStart, periodEnd);
  final fetchFrom = prev.start.subtract(const Duration(days: 1));

  final meters =
      await ref.read(meterRepositoryProvider).getMetersForSite(siteId);
  final active = meters
      .where((m) => m.isActive && m.includeInDashboard)
      .toList();
  if (active.isEmpty) return const [];

  final meterIds = active.map((m) => m.id).toList();
  final byMeter = <String, List<PeriodReadingPoint>>{};
  final rows = await ref
      .read(supabaseClientProvider)
      .from('meter_readings')
      .select('meter_id, reading_date, normalized_value')
      .eq('site_id', siteId)
      .inFilter('meter_id', meterIds)
      .gte('reading_date', _isoDate(fetchFrom))
      .lte('reading_date', _isoDate(periodEnd))
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

  final profileRepo =
      SiteConservationProfileRepository(ref.read(supabaseClientProvider));
  final profile = await profileRepo.get(siteId);

  const compare = PeriodComparisonService();
  const bench = BenchmarkingService();
  final bundles = <ConservationBenchmarkBundle>[];

  for (final system in [UtilitySystemKey.water, UtilitySystemKey.electricity]) {
    final unitMeters = active
        .where((m) => _meterMatchesUtility(m, system.categoryCode))
        .toList();
    if (unitMeters.isEmpty) continue;

    final unitCode = system.defaultUnit;
    final series = [
      for (final m in unitMeters)
        PeriodMeterReadingSeries(
          meterId: m.id,
          unitCode: unitCode,
          meterMultiplier: 1,
          readings: byMeter[m.id] ?? const [],
        ),
    ];
    final periodResult = compare.compareMeters(
      type: PeriodComparisonType.previousPeriod,
      currentStart: periodStart,
      currentEnd: periodEnd,
      meters: series,
      unitCode: unitCode,
      siteId: siteId,
    );

    final warnings = <String>[];
    final snapshot = BenchmarkSiteSnapshot(
      siteId: siteId,
      label: summary.site.nameEn,
      consumption: periodResult.currentValue ?? 0,
      unitCode: unitCode,
      confidenceScore: periodResult.currentPeriodConfidence,
      completeness: periodResult.currentCompleteness,
      floorAreaM2: profile?.floorAreaM2,
      occupancyCount: profile?.occupancyCount,
      peerGroup: profile?.peerGroup,
      previousConsumption: periodResult.comparisonValue,
    );

    IntensityResult? intensity;
    if (intensityOn && periodResult.currentValue != null) {
      intensity = bench.computeIntensity(
        consumption: periodResult.currentValue!,
        floorAreaM2: profile?.floorAreaM2,
        occupancy: profile?.occupancyCount,
      );
      if (intensity.missingNormalization) {
        warnings.add(IntensityResult.normalizationMissingMessage);
        warnings.add(BenchmarkingService.notNormalizedWarning);
      }
    } else if (intensityOn) {
      warnings.add(IntensityResult.normalizationMissingMessage);
    }

    var peerCount = 0;
    BenchmarkComparisonResult? peerComparison;
    if (benchmarkingOn && profile?.peerGroup != null) {
      final peers = await profileRepo.listByPeerGroup(profile!.peerGroup!);
      final orgId = summary.site.organizationId;
      final peerSiteIds = peers.map((p) => p.siteId).take(20).toList();
      if (peerSiteIds.isNotEmpty) {
        final siteRows = await ref
            .read(supabaseClientProvider)
            .from('sites')
            .select('id')
            .eq('organization_id', orgId)
            .inFilter('id', peerSiteIds);
        peerCount = (siteRows as List).length;
      }
      peerComparison = bench.comparePeers(
        sites: [snapshot],
        peerGroup: profile.peerGroup,
      );
      warnings.addAll(peerComparison.warnings);
      if (peerCount > 1) {
        warnings.add(
          'Peer profiles in group: $peerCount (median requires peer '
          'consumption — not computed for all sites on every render).',
        );
      }
    } else if (benchmarkingOn) {
      peerComparison = bench.comparePeers(sites: [snapshot]);
      warnings.addAll(peerComparison.warnings);
    }

    bundles.add(
      ConservationBenchmarkBundle(
        utilityLabel: system.label,
        unitCode: unitCode,
        consumption: periodResult.currentValue,
        snapshot: snapshot,
        intensity: intensity,
        peerComparison: peerComparison,
        peerProfileCount: peerCount,
        warnings: warnings,
      ),
    );
  }
  return bundles;
});

/// Periodic + COP anomalies (flags OFF → []).
final conservationAnomaliesProvider = FutureProvider.autoDispose
    .family<List<ConservationAnomalyBundle>, String>((ref, siteId) async {
  final periodicOn = await ref
      .watch(conservationPeriodicAnomaliesEnabledProvider(siteId).future);
  final copOn = await ref
      .watch(conservationCopConservationEnabledProvider(siteId).future);
  if (!periodicOn && !copOn) return const [];

  final dateSelection = ref.watch(siteDateSelectionProvider(siteId));
  final periodStart = dateOnly(dateSelection.startDate);
  final periodEnd = dateOnly(dateSelection.endDate);
  final results = <ConservationAnomalyBundle>[];

  if (periodicOn) {
    final windows = <DateTimeRangeInclusive>[];
    var cursorStart = periodStart;
    var cursorEnd = periodEnd;
    for (var i = 0; i < 6; i++) {
      final prev = previousPeriodOfEqualLength(cursorStart, cursorEnd);
      windows.insert(0, prev);
      cursorStart = prev.start;
      cursorEnd = prev.end;
    }
    final historyStart = windows.first.start.subtract(const Duration(days: 1));

    final meters =
        await ref.read(meterRepositoryProvider).getMetersForSite(siteId);
    final active = meters
        .where((m) => m.isActive && m.includeInDashboard)
        .toList();
    final meterIds = active.map((m) => m.id).toList();
    final byMeter = <String, List<PeriodReadingPoint>>{};
    if (meterIds.isNotEmpty) {
      final rows = await ref
          .read(supabaseClientProvider)
          .from('meter_readings')
          .select('meter_id, reading_date, normalized_value')
          .eq('site_id', siteId)
          .inFilter('meter_id', meterIds)
          .gte('reading_date', _isoDate(historyStart))
          .lte('reading_date', _isoDate(periodEnd))
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

    double? waterTarget;
    double? elecTarget;
    double? waterBaseline;
    double? elecBaseline;
    if (await ref.watch(conservationTargetsEnabledProvider(siteId).future)) {
      final targets = await ConservationTargetRepository(
        ref.read(supabaseClientProvider),
      ).listForSite(siteId, status: ConservationTargetStatus.active);
      for (final t in targets) {
        if (t.scopeType != ConservationTargetScopeType.site) continue;
        final u = t.unitCode.toLowerCase();
        if (u == 'kwh') {
          elecTarget ??= t.targetValue;
        } else if (u.contains('m3') || u == 'm³') {
          waterTarget ??= t.targetValue;
        }
      }
    }
    if (await ref.watch(conservationBaselineEnabledProvider(siteId).future)) {
      final baselines = await ConservationBaselineRepository(
        ref.read(supabaseClientProvider),
      ).listApprovedForSite(siteId);
      for (final b in baselines) {
        if (b.scopeType != ConservationBaselineScopeType.site) continue;
        final u = b.unitCode.toLowerCase();
        if (u == 'kwh') {
          elecBaseline ??= b.baselineValue;
        } else if (u.contains('m3') || u == 'm³') {
          waterBaseline ??= b.baselineValue;
        }
      }
    }

    const anomaly = PeriodicAnomalyService();
    for (final system in [UtilitySystemKey.water, UtilitySystemKey.electricity]) {
      final unitMeters = active
          .where((m) => _meterMatchesUtility(m, system.categoryCode))
          .toList();
      if (unitMeters.isEmpty) continue;
      final unitCode = system.defaultUnit;
      final series = [
        for (final m in unitMeters)
          PeriodMeterReadingSeries(
            meterId: m.id,
            unitCode: unitCode,
            meterMultiplier: 1,
            readings: byMeter[m.id] ?? const [],
          ),
      ];

      final historical = <double?>[];
      for (final w in windows) {
        final snap = _aggregateUtilityPeriod(
          meters: series,
          periodStart: w.start,
          periodEnd: w.end,
        );
        historical.add(snap.value);
      }
      final current = _aggregateUtilityPeriod(
        meters: series,
        periodStart: periodStart,
        periodEnd: periodEnd,
      );
      final previous = historical.isEmpty ? null : historical.last;

      final isWater = system == UtilitySystemKey.water;
      final detected = anomaly.detect(
        currentConsumption: current.value,
        previousConsumption: previous,
        periodStart: periodStart,
        periodEnd: periodEnd,
        completeness: current.completeness,
        confidence: current.confidenceScore,
        meterIds: unitMeters.map((m) => m.id).toList(),
        baseline: isWater ? waterBaseline : elecBaseline,
        target: isWater ? waterTarget : elecTarget,
        historicalPeriodConsumptions: historical,
      );
      results.add(
        ConservationAnomalyBundle(
          title: '${system.label} consumption',
          result: detected,
          unitCode: unitCode,
        ),
      );
    }
  }

  if (copOn) {
    final groups =
        await ref.read(dashboardRepositoryProvider).getCopGroupsForSite(siteId);
    const copService = CopConservationTrendService();
    final activeGroups = groups.where((g) => g.isActive).take(8).toList();
    for (final g in activeGroups) {
      final trend = await ref.read(dashboardRepositoryProvider).getCopTrend(
            copGroupId: g.id,
            period: ChartPeriod.last30Days,
            businessDate: periodEnd,
            rangeOverride: ChartPeriodRange(
              period: ChartPeriod.last30Days,
              from: periodEnd.subtract(const Duration(days: 89)),
              to: periodEnd,
              bucket: ChartBucket.daily,
            ),
          );
      final chronological = [for (final p in trend.points) p.cop];
      final bounded = chronological.length > 6
          ? chronological.sublist(chronological.length - 6)
          : chronological;
      final anomaly = copService.analyzeDeclining(
        copValuesChronological: bounded,
        periodStart: periodStart,
        periodEnd: periodEnd,
      );
      results.add(
        ConservationAnomalyBundle(
          title: 'COP trend · ${g.nameEn}',
          result: anomaly,
        ),
      );
    }
  }

  return results;
});
