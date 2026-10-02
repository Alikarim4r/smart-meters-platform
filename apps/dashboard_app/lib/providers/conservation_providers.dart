import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_meters_core/smart_meters_core.dart';

import '../utils/site_system_navigation.dart';
import 'chart_providers.dart';
import 'dashboard_providers.dart';

/// One network round-trip for all conservation flags for a site.
/// All per-flag providers below read from this cached map.
final conservationFlagMapProvider =
    FutureProvider.autoDispose.family<Map<String, bool>, String>((ref, siteId) async {
  final summary =
      await ref.watch(siteDashboardSummaryProvider(siteId).future);
  final flags = ConservationFeatureFlagRepository(
    ref.read(supabaseClientProvider),
  );
  return flags.resolvedEnabledByKey(
    organizationId: summary.site.organizationId,
    siteId: siteId,
  );
});

Future<bool> _conservationFlagOn(
  Ref ref,
  String siteId,
  String flagKey, {
  String? requireAlso,
}) async {
  final map = await ref.watch(conservationFlagMapProvider(siteId).future);
  if (!(map[ConservationFeatureFlags.conservationModule] ?? false)) {
    return false;
  }
  if (flagKey == ConservationFeatureFlags.conservationModule) return true;
  if (requireAlso != null && !(map[requireAlso] ?? false)) return false;
  return map[flagKey] ?? false;
}

/// True when master conservation module flag is ON (defaults OFF).
final conservationModuleEnabledProvider =
    FutureProvider.autoDispose.family<bool, String>((ref, siteId) async {
  final map = await ref.watch(conservationFlagMapProvider(siteId).future);
  return map[ConservationFeatureFlags.conservationModule] ?? false;
});

/// True only when both `conservation_module` and `period_compare` are enabled.
final conservationPeriodCompareEnabledProvider =
    FutureProvider.autoDispose.family<bool, String>((ref, siteId) {
  return _conservationFlagOn(ref, siteId, ConservationFeatureFlags.periodCompare);
});

/// True only when both `conservation_module` and `targets` are enabled.
final conservationTargetsEnabledProvider =
    FutureProvider.autoDispose.family<bool, String>((ref, siteId) {
  return _conservationFlagOn(ref, siteId, ConservationFeatureFlags.targets);
});

/// True only when both `conservation_module` and `baseline` are enabled.
final conservationBaselineEnabledProvider =
    FutureProvider.autoDispose.family<bool, String>((ref, siteId) {
  return _conservationFlagOn(ref, siteId, ConservationFeatureFlags.baseline);
});

/// True only when both `conservation_module` and `virtual_meters` are enabled.
final conservationVirtualMetersEnabledProvider =
    FutureProvider.autoDispose.family<bool, String>((ref, siteId) {
  return _conservationFlagOn(ref, siteId, ConservationFeatureFlags.virtualMeters);
});

/// True only when both `conservation_module` and `water_balance` are enabled.
final conservationWaterBalanceEnabledProvider =
    FutureProvider.autoDispose.family<bool, String>((ref, siteId) {
  return _conservationFlagOn(ref, siteId, ConservationFeatureFlags.waterBalance);
});

/// True only when both `conservation_module` and `energy_balance` are enabled.
final conservationEnergyBalanceEnabledProvider =
    FutureProvider.autoDispose.family<bool, String>((ref, siteId) {
  return _conservationFlagOn(ref, siteId, ConservationFeatureFlags.energyBalance);
});

/// True only when both `conservation_module` and `benchmarking` are enabled.
final conservationBenchmarkingEnabledProvider =
    FutureProvider.autoDispose.family<bool, String>((ref, siteId) {
  return _conservationFlagOn(ref, siteId, ConservationFeatureFlags.benchmarking);
});

/// True only when both `conservation_module` and `intensity` are enabled.
final conservationIntensityEnabledProvider =
    FutureProvider.autoDispose.family<bool, String>((ref, siteId) {
  return _conservationFlagOn(ref, siteId, ConservationFeatureFlags.intensity);
});

/// True only when both `conservation_module` and `periodic_anomalies` are enabled.
final conservationPeriodicAnomaliesEnabledProvider =
    FutureProvider.autoDispose.family<bool, String>((ref, siteId) {
  return _conservationFlagOn(
    ref,
    siteId,
    ConservationFeatureFlags.periodicAnomalies,
  );
});

/// True only when both `conservation_module` and `cop_conservation` are enabled.
final conservationCopConservationEnabledProvider =
    FutureProvider.autoDispose.family<bool, String>((ref, siteId) {
  return _conservationFlagOn(
    ref,
    siteId,
    ConservationFeatureFlags.copConservation,
  );
});

/// True only when both `conservation_module` and `opportunities` are enabled.
final conservationOpportunitiesEnabledProvider =
    FutureProvider.autoDispose.family<bool, String>((ref, siteId) {
  return _conservationFlagOn(ref, siteId, ConservationFeatureFlags.opportunities);
});

/// True only when module ∧ opportunities ∧ investigations.
final conservationInvestigationsEnabledProvider =
    FutureProvider.autoDispose.family<bool, String>((ref, siteId) {
  return _conservationFlagOn(
    ref,
    siteId,
    ConservationFeatureFlags.investigations,
    requireAlso: ConservationFeatureFlags.opportunities,
  );
});

/// True only when module ∧ opportunities ∧ actions.
final conservationActionsEnabledProvider =
    FutureProvider.autoDispose.family<bool, String>((ref, siteId) {
  return _conservationFlagOn(
    ref,
    siteId,
    ConservationFeatureFlags.actions,
    requireAlso: ConservationFeatureFlags.opportunities,
  );
});

/// True only when module ∧ opportunities ∧ evidence.
final conservationEvidenceEnabledProvider =
    FutureProvider.autoDispose.family<bool, String>((ref, siteId) {
  return _conservationFlagOn(
    ref,
    siteId,
    ConservationFeatureFlags.evidence,
    requireAlso: ConservationFeatureFlags.opportunities,
  );
});

/// True only when `conservation_module` ∧ `savings_estimation`.
final conservationSavingsEstimationEnabledProvider =
    FutureProvider.autoDispose.family<bool, String>((ref, siteId) {
  return _conservationFlagOn(
    ref,
    siteId,
    ConservationFeatureFlags.savingsEstimation,
  );
});

/// True only when `conservation_module` ∧ `savings_verification`.
final conservationSavingsVerificationEnabledProvider =
    FutureProvider.autoDispose.family<bool, String>((ref, siteId) {
  return _conservationFlagOn(
    ref,
    siteId,
    ConservationFeatureFlags.savingsVerification,
  );
});

/// True only when `conservation_module` ∧ `cost_roi`.
final conservationCostRoiEnabledProvider =
    FutureProvider.autoDispose.family<bool, String>((ref, siteId) {
  return _conservationFlagOn(ref, siteId, ConservationFeatureFlags.costRoi);
});

/// True only when `conservation_module` ∧ `conservation_reports`.
final conservationReportsEnabledProvider =
    FutureProvider.autoDispose.family<bool, String>((ref, siteId) {
  return _conservationFlagOn(
    ref,
    siteId,
    ConservationFeatureFlags.conservationReports,
  );
});

/// Keys that make the Conservation nav/section visible (any one is enough).
const _conservationSectionChildKeys = <String>[
  ConservationFeatureFlags.periodCompare,
  ConservationFeatureFlags.targets,
  ConservationFeatureFlags.baseline,
  ConservationFeatureFlags.virtualMeters,
  ConservationFeatureFlags.waterBalance,
  ConservationFeatureFlags.energyBalance,
  ConservationFeatureFlags.benchmarking,
  ConservationFeatureFlags.intensity,
  ConservationFeatureFlags.periodicAnomalies,
  ConservationFeatureFlags.copConservation,
  ConservationFeatureFlags.opportunities,
  ConservationFeatureFlags.investigations,
  ConservationFeatureFlags.actions,
  ConservationFeatureFlags.savingsEstimation,
  ConservationFeatureFlags.savingsVerification,
  ConservationFeatureFlags.costRoi,
  ConservationFeatureFlags.conservationReports,
  ConservationFeatureFlags.weatherNormalization,
  ConservationFeatureFlags.occupancyNormalization,
  ConservationFeatureFlags.savingPersistence,
  ConservationFeatureFlags.carbonAccounting,
  ConservationFeatureFlags.portfolioOptimization,
  ConservationFeatureFlags.forecasting,
  ConservationFeatureFlags.recommendationEngine,
];

/// Conservation nav/section visible when module + any P1–P5 child flag.
final conservationSectionVisibleProvider =
    FutureProvider.autoDispose.family<bool, String>((ref, siteId) async {
  final map = await ref.watch(conservationFlagMapProvider(siteId).future);
  if (!(map[ConservationFeatureFlags.conservationModule] ?? false)) {
    return false;
  }
  for (final key in _conservationSectionChildKeys) {
    if (map[key] ?? false) return true;
  }
  return false;
});

/// True when `conservation_module` ∧ `weather_normalization`.
final conservationWeatherNormalizationEnabledProvider =
    FutureProvider.autoDispose.family<bool, String>((ref, siteId) {
  return _conservationFlagOn(
    ref,
    siteId,
    ConservationFeatureFlags.weatherNormalization,
  );
});

/// True when `conservation_module` ∧ `occupancy_normalization`.
final conservationOccupancyNormalizationEnabledProvider =
    FutureProvider.autoDispose.family<bool, String>((ref, siteId) {
  return _conservationFlagOn(
    ref,
    siteId,
    ConservationFeatureFlags.occupancyNormalization,
  );
});

/// True when `conservation_module` ∧ `saving_persistence`.
final conservationSavingPersistenceEnabledProvider =
    FutureProvider.autoDispose.family<bool, String>((ref, siteId) {
  return _conservationFlagOn(
    ref,
    siteId,
    ConservationFeatureFlags.savingPersistence,
  );
});

/// True when `conservation_module` ∧ `carbon_accounting`.
final conservationCarbonAccountingEnabledProvider =
    FutureProvider.autoDispose.family<bool, String>((ref, siteId) {
  return _conservationFlagOn(
    ref,
    siteId,
    ConservationFeatureFlags.carbonAccounting,
  );
});

/// True when `conservation_module` ∧ `portfolio_optimization`.
final conservationPortfolioOptimizationEnabledProvider =
    FutureProvider.autoDispose.family<bool, String>((ref, siteId) {
  return _conservationFlagOn(
    ref,
    siteId,
    ConservationFeatureFlags.portfolioOptimization,
  );
});

/// True when `conservation_module` ∧ `forecasting`.
final conservationForecastingEnabledProvider =
    FutureProvider.autoDispose.family<bool, String>((ref, siteId) {
  return _conservationFlagOn(ref, siteId, ConservationFeatureFlags.forecasting);
});

/// True when `conservation_module` ∧ `recommendation_engine`.
final conservationRecommendationEngineEnabledProvider =
    FutureProvider.autoDispose.family<bool, String>((ref, siteId) {
  return _conservationFlagOn(
    ref,
    siteId,
    ConservationFeatureFlags.recommendationEngine,
  );
});

/// Portfolio totals from M&V rows.
///
/// Verified Saving and Cost Avoided totals use **status=verified only** —
/// never estimated/draft/pending. Missing tariff → cost total stays N/A
/// when no verified row has a non-null cost_avoided.
class ConservationMvPortfolioTotals {
  const ConservationMvPortfolioTotals({
    required this.estimatedSavingTotal,
    required this.verifiedSavingTotal,
    required this.costAvoidedTotal,
    required this.verificationPendingCount,
    required this.estimatedCount,
    required this.verifiedCount,
  });

  /// Sum of [MeasurementVerification.estimatedSavingQuantity] where present
  /// (active non-superseded/archived preferred; callers pass filtered list).
  final double estimatedSavingTotal;

  /// Sum of verified_saving_quantity for status=verified only.
  final double verifiedSavingTotal;

  /// Sum of cost_avoided for verified rows with a tariff. Null = N/A.
  final double? costAvoidedTotal;

  final int verificationPendingCount;
  final int estimatedCount;
  final int verifiedCount;
}

/// Verified totals ONLY from status=verified (never estimated/draft).
ConservationMvPortfolioTotals computeMvPortfolioTotals(
  List<MeasurementVerification> rows,
) {
  var estimatedTotal = 0.0;
  var estimatedCount = 0;
  var verifiedTotal = 0.0;
  var verifiedCount = 0;
  double? costTotal;
  var pendingCount = 0;

  for (final row in rows) {
    if (row.status == MvStatus.superseded || row.status == MvStatus.archived) {
      continue;
    }
    if (row.estimatedSavingQuantity != null) {
      estimatedTotal += row.estimatedSavingQuantity!;
      estimatedCount++;
    }
    if (row.status == MvStatus.verificationPending) {
      pendingCount++;
    }
    if (row.status == MvStatus.verified) {
      verifiedCount++;
      final v = row.verifiedSavingQuantity ?? 0;
      // Negatives never enter Verified Savings Total (clamped qty is ≥ 0).
      if (v > 0) verifiedTotal += v;
      if (row.costAvoided != null) {
        costTotal = (costTotal ?? 0) + row.costAvoided!;
      }
    }
  }

  return ConservationMvPortfolioTotals(
    estimatedSavingTotal: estimatedTotal,
    verifiedSavingTotal: verifiedTotal,
    costAvoidedTotal: costTotal,
    verificationPendingCount: pendingCount,
    estimatedCount: estimatedCount,
    verifiedCount: verifiedCount,
  );
}

/// M&V rows for the site (limit 50). Short-circuits to [] when both
/// savings_estimation and savings_verification are OFF.
final conservationMvListProvider = FutureProvider.autoDispose
    .family<List<MeasurementVerification>, String>((ref, siteId) async {
  final estimationOn = await ref
      .watch(conservationSavingsEstimationEnabledProvider(siteId).future);
  final verificationOn = await ref
      .watch(conservationSavingsVerificationEnabledProvider(siteId).future);
  if (!estimationOn && !verificationOn) return const [];

  return MeasurementVerificationRepository(
    ref.read(supabaseClientProvider),
  ).listForSite(siteId, limit: 50);
});

/// Opportunities for the site (limit 50, newest first). Never auto-generates.
/// Short-circuits to [] when opportunities flag is OFF.
final conservationOpportunitiesProvider = FutureProvider.autoDispose
    .family<List<ConservationOpportunity>, String>((ref, siteId) async {
  final enabled =
      await ref.watch(conservationOpportunitiesEnabledProvider(siteId).future);
  if (!enabled) return const [];

  return OpportunityRepository(ref.read(supabaseClientProvider)).listForSite(
    siteId,
    limit: 50,
  );
});

/// Result of an explicit user-triggered opportunity refresh.
class ConservationOpportunityRefreshResult {
  const ConservationOpportunityRefreshResult({
    required this.generation,
    required this.candidateCount,
  });

  final GenerationResult generation;
  final int candidateCount;
}

/// Explicit refresh only — call from UI "Refresh opportunities", never on build.
///
/// Reads current balance / anomaly / target / baseline results from existing
/// providers (when those flags are ON), runs [OpportunityEngine], persists via
/// [OpportunityGenerationService], then invalidates [conservationOpportunitiesProvider].
Future<ConservationOpportunityRefreshResult> refreshConservationOpportunities(
  WidgetRef ref,
  String siteId,
) async {
  final enabled =
      await ref.read(conservationOpportunitiesEnabledProvider(siteId).future);
  if (!enabled) {
    return const ConservationOpportunityRefreshResult(
      generation: GenerationResult(created: 0, refreshed: 0, skipped: 0),
      candidateCount: 0,
    );
  }

  final dateSelection = ref.read(siteDateSelectionProvider(siteId));
  final periodStart = dateOnly(dateSelection.startDate);
  final periodEnd = dateOnly(dateSelection.endDate);

  final balances = await ref.read(conservationBalanceResultsProvider(siteId).future);
  final anomalies = await ref.read(conservationAnomaliesProvider(siteId).future);
  final targets = await ref.read(conservationActualVsTargetProvider(siteId).future);
  final baselines =
      await ref.read(conservationActualVsBaselineProvider(siteId).future);

  const engine = OpportunityEngine();
  final candidates = <OpportunityCandidate>[];

  // Group balance results by utility.
  final byUtilityBalances = <String, List<BalanceResult>>{};
  for (final b in balances) {
    final u = b.group.utilityCode.toLowerCase();
    byUtilityBalances.putIfAbsent(u, () => []).add(b.result);
  }

  final byUtilityAnomalies = <String, List<ConsumptionAnomalyResult>>{};
  for (final a in anomalies) {
    final title = a.title.toLowerCase();
    final u = title.contains('water')
        ? 'water'
        : title.contains('electric') || title.contains('cop')
            ? 'electricity'
            : 'unknown';
    byUtilityAnomalies.putIfAbsent(u, () => []).add(a.result);
  }

  final byUtilityTargets = <String, List<ActualVsTargetResult>>{};
  for (final t in targets) {
    final u = t.unitCode.toLowerCase().contains('m')
        ? 'water'
        : t.unitCode.toLowerCase().contains('kwh')
            ? 'electricity'
            : 'unknown';
    byUtilityTargets.putIfAbsent(u, () => []).add(t);
  }

  final byUtilityBaselines = <String, List<ActualVsBaselineResult>>{};
  for (final b in baselines) {
    final u = b.unitCode.toLowerCase().contains('m')
        ? 'water'
        : b.unitCode.toLowerCase().contains('kwh')
            ? 'electricity'
            : 'unknown';
    byUtilityBaselines.putIfAbsent(u, () => []).add(b);
  }

  final utilities = {
    ...byUtilityBalances.keys,
    ...byUtilityAnomalies.keys,
    ...byUtilityTargets.keys,
    ...byUtilityBaselines.keys,
  };
  if (utilities.isEmpty) {
    // Still allow engine pass with empty signals (no-op persist).
    utilities.add('water');
  }

  for (final utility in utilities) {
    candidates.addAll(
      engine.buildCandidatesFromSignals(
        siteId: siteId,
        utilityType: utility,
        anomalies: byUtilityAnomalies[utility] ?? const [],
        balances: byUtilityBalances[utility] ?? const [],
        actualVsTargets: byUtilityTargets[utility] ?? const [],
        actualVsBaselines: byUtilityBaselines[utility] ?? const [],
        defaultUnitCode: utility == 'water'
            ? 'm³'
            : utility == 'electricity'
                ? 'kWh'
                : null,
      ),
    );
  }

  final client = ref.read(supabaseClientProvider);
  final service = OpportunityGenerationService(
    repository: OpportunityRepository(client),
  );
  final generation = await service.refreshForSite(
    siteId: siteId,
    periodStart: periodStart,
    periodEnd: periodEnd,
    candidates: candidates,
    createdBy: client.auth.currentUser?.id,
  );

  ref.invalidate(conservationOpportunitiesProvider(siteId));
  return ConservationOpportunityRefreshResult(
    generation: generation,
    candidateCount: candidates.length,
  );
}

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
      .select('meter_id, reading_date, raw_value')
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
    final value = (map['raw_value'] as num).toDouble();
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
        PeriodMeterReadingSeries.fromMeter(
          meter: m,
          unitCode: unitCode,
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
        .select('meter_id, reading_date, raw_value')
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
              value: (map['raw_value'] as num).toDouble(),
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
        PeriodMeterReadingSeries.fromMeter(
          meter: m,
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
        .select('meter_id, reading_date, raw_value')
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
              value: (map['raw_value'] as num).toDouble(),
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
        PeriodMeterReadingSeries.fromMeter(
          meter: m,
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
        .select('meter_id, reading_date, raw_value')
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
              value: (map['raw_value'] as num).toDouble(),
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
        PeriodMeterReadingSeries.fromMeter(
          meter: byId[id]!,
          unitCode: unit,
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
              PeriodMeterReadingSeries.fromMeter(
                meter: byId[v.parentMeterId!]!,
                unitCode: unit,
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
    this.historicalPeriodConsumptions = const [],
    this.currentPeriodConsumption,
  });

  final String title;
  final ConsumptionAnomalyResult result;
  final String? unitCode;

  /// Prior equal-length windows (oldest → newest), for trend bars.
  final List<double?> historicalPeriodConsumptions;

  /// Current window total used for anomaly detection.
  final double? currentPeriodConsumption;
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
        .select('meter_id, reading_date, raw_value')
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
              value: (map['raw_value'] as num).toDouble(),
            ),
          );
    }
  }

  const calculator = VirtualMeterCalculator();
  const balance = BalanceService();
  final results = <ConservationBalanceBundle>[];
  final metersById = {for (final meter in meters) meter.id: meter};

  for (final g in active) {
    final unit = g.unitCode;
    final childrenSeries = [
      for (final id in g.memberMeterIds)
        PeriodMeterReadingSeries.fromMeter(
          meter: metersById[id]!,
          unitCode: unit,
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
            PeriodMeterReadingSeries.fromMeter(
              meter: metersById[g.mainMeterId]!,
              unitCode: unit,
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
      .select('meter_id, reading_date, raw_value')
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
            value: (map['raw_value'] as num).toDouble(),
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
        PeriodMeterReadingSeries.fromMeter(
          meter: m,
          unitCode: unitCode,
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
          .select('meter_id, reading_date, raw_value')
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
                value: (map['raw_value'] as num).toDouble(),
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
          PeriodMeterReadingSeries.fromMeter(
            meter: m,
            unitCode: unitCode,
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
          historicalPeriodConsumptions: historical,
          currentPeriodConsumption: current.value,
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
