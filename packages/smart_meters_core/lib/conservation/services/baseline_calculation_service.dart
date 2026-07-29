import '../../domain/chart_period.dart';
import '../domain/baseline_approval_gates.dart';
import '../domain/period_windows.dart';
import '../models/calculation_meta.dart';
import '../models/conservation_baseline.dart';
import 'period_comparison_service.dart';

/// Preview / calculation result for a baseline draft (not an approval).
class BaselineCalculationResult {
  const BaselineCalculationResult({
    required this.baselineValue,
    required this.method,
    required this.completeness,
    required this.confidenceScore,
    required this.boundaryQuality,
    required this.referencePeriodStart,
    required this.referencePeriodEnd,
    required this.unitCode,
    required this.meta,
    required this.warnings,
    required this.canCompute,
    required this.metersContributing,
    required this.readingsContributing,
    required this.usedFirstInPeriodFallback,
    this.message,
  });

  final double? baselineValue;
  final BaselineCalculationMethod method;
  final double completeness;
  final int confidenceScore;
  final BaselineBoundaryQuality boundaryQuality;
  final DateTime referencePeriodStart;
  final DateTime referencePeriodEnd;
  final String unitCode;
  final CalculationMeta meta;
  final List<String> warnings;
  final bool canCompute;
  final int metersContributing;
  final int readingsContributing;
  final bool usedFirstInPeriodFallback;
  final String? message;

  bool get isInsufficient =>
      !canCompute ||
      boundaryQuality == BaselineBoundaryQuality.insufficient ||
      baselineValue == null;
}

/// Computes reading-derived or custom_fixed baseline values for P1D.
///
/// More conservative than Actual vs Target: first-in-period fallback is
/// labeled, confidence-penalized, and blocks formal approval via gates.
class BaselineCalculationService {
  const BaselineCalculationService();

  static const methodId = 'conservation_baseline_calc_v1';

  BaselineCalculationResult calculate({
    required BaselineCalculationMethod method,
    required DateTime referencePeriodStart,
    required DateTime referencePeriodEnd,
    required String unitCode,
    required List<PeriodMeterReadingSeries> meters,
    double? customFixedValue,
    String? baselineVersionLabel,
  }) {
    final start = dateOnly(referencePeriodStart);
    final end = dateOnly(referencePeriodEnd);
    final warnings = <String>[];

    if (end.isBefore(start)) {
      return _fail(
        method: method,
        start: start,
        end: end,
        unitCode: unitCode,
        reason: 'Invalid reference period (end before start).',
        version: baselineVersionLabel,
      );
    }

    if (method == BaselineCalculationMethod.customFixed) {
      final v = customFixedValue;
      if (v == null || v <= 0 || v.isNaN) {
        return _fail(
          method: method,
          start: start,
          end: end,
          unitCode: unitCode,
          reason: 'custom_fixed requires a positive baseline_value.',
          version: baselineVersionLabel,
          boundary: BaselineBoundaryQuality.notApplicable,
        );
      }
      final meta = CalculationMeta(
        calculationMethod: method.dbValue,
        periodStart: start,
        periodEnd: end,
        dataCompleteness: 1.0,
        confidenceScore: 80,
        baselineVersion: baselineVersionLabel,
        calculatedAt: DateTime.now().toUtc(),
        notes: [
          'method=custom_fixed',
          'boundary_quality=not_applicable',
          'note=Admin-specified reference value (not reading-derived).',
          'note=Targets and Baselines are separate concepts.',
        ],
      );
      return BaselineCalculationResult(
        baselineValue: v,
        method: method,
        completeness: 1.0,
        confidenceScore: 80,
        boundaryQuality: BaselineBoundaryQuality.notApplicable,
        referencePeriodStart: start,
        referencePeriodEnd: end,
        unitCode: unitCode,
        meta: meta,
        warnings: const [
          'custom_fixed: value set by administrator (not derived from readings).',
        ],
        canCompute: true,
        metersContributing: 0,
        readingsContributing: 0,
        usedFirstInPeriodFallback: false,
      );
    }

    final incompatible =
        meters.where((m) => m.unitCode != unitCode).toList();
    if (incompatible.isNotEmpty) {
      return _fail(
        method: method,
        start: start,
        end: end,
        unitCode: unitCode,
        reason: 'Unit mismatch for baseline unit $unitCode.',
        version: baselineVersionLabel,
      );
    }
    if (meters.isEmpty) {
      return _fail(
        method: method,
        start: start,
        end: end,
        unitCode: unitCode,
        reason: 'No meters in scope for baseline calculation.',
        version: baselineVersionLabel,
      );
    }

    var total = 0.0;
    var withEndpoints = 0;
    var withExactPre = 0;
    var withFallback = 0;
    var readingCount = 0;

    for (final meter in meters) {
      final endpoints = extractEndpoints(
        readings: meter.normalizedPoints,
        periodStart: start,
        periodEnd: end,
      );
      readingCount += endpoints.readingCountInPeriod;
      if (!endpoints.hasValidConsumptionEndpoints) continue;

      // Still compute via existing helper for draft preview, but classify
      // boundary quality separately (do not invent periodStart-1).
      total += periodConsumptionFromEndpoints(
        lastInPeriod: endpoints.lastInPeriod!,
        previousBeforePeriod: endpoints.previousBeforePeriod,
        firstInPeriod: endpoints.firstInPeriod,
      );
      withEndpoints++;
      if (endpoints.previousBeforePeriod != null) {
        withExactPre++;
      } else {
        withFallback++;
      }
    }

    final completeness =
        (withEndpoints / meters.length).clamp(0.0, 1.0).toDouble();
    var confidence = 100;
    if (withEndpoints == 0) confidence -= 50;
    if (completeness < 1.0) confidence -= 15;
    if (completeness < 0.8) confidence -= 20;
    if (readingCount == 0) confidence -= 20;

    final usedFallback = withFallback > 0;
    if (usedFallback) {
      confidence -= 25;
      warnings.add(
        'Boundary fallback: one or more meters lack a reading strictly before '
        'reference_period_start; first-in-period was used for draft preview only. '
        'This is not an exact/pre-period boundary and blocks formal approval.',
      );
    }

    BaselineBoundaryQuality quality;
    if (withEndpoints == 0) {
      quality = BaselineBoundaryQuality.insufficient;
    } else if (usedFallback) {
      quality = BaselineBoundaryQuality.firstInPeriodFallback;
    } else {
      quality = BaselineBoundaryQuality.exactPrePeriod;
    }

    confidence = confidence.clamp(0, 100);

    if (withEndpoints == 0) {
      return _fail(
        method: method,
        start: start,
        end: end,
        unitCode: unitCode,
        reason:
            'Insufficient Data: no valid boundary readings for the reference '
            'period (manual meters may lack periodStart-1 — do not invent it).',
        version: baselineVersionLabel,
        completeness: completeness,
        confidence: confidence,
        boundary: quality,
        warnings: warnings,
        readings: readingCount,
      );
    }

    final periodDays = inclusiveDayCount(start, end);
    double value;
    if (method == BaselineCalculationMethod.averageDaily) {
      if (periodDays <= 0) {
        return _fail(
          method: method,
          start: start,
          end: end,
          unitCode: unitCode,
          reason: 'average_daily requires a positive calendar day count.',
          version: baselineVersionLabel,
        );
      }
      value = total / periodDays;
    } else {
      value = total;
    }

    final meta = CalculationMeta(
      calculationMethod: method.dbValue,
      periodStart: start,
      periodEnd: end,
      dataCompleteness: completeness,
      confidenceScore: confidence,
      baselineVersion: baselineVersionLabel,
      calculatedAt: DateTime.now().toUtc(),
      notes: [
        'method=${method.dbValue}',
        'boundary_quality=${quality.dbValue}',
        'meters_contributing=$withEndpoints/${meters.length}',
        'meters_exact_pre_period=$withExactPre',
        'meters_first_in_period_fallback=$withFallback',
        'readings_in_period=$readingCount',
        'calendar_days=$periodDays',
        if (method == BaselineCalculationMethod.averageDaily)
          'note=average_daily uses inclusive calendar day count (not 30-day months).',
        'note=Targets and Baselines are separate concepts.',
        'note=Do not invent periodStart-1 readings.',
        ...warnings,
      ],
    );

    return BaselineCalculationResult(
      baselineValue: value,
      method: method,
      completeness: completeness,
      confidenceScore: confidence,
      boundaryQuality: quality,
      referencePeriodStart: start,
      referencePeriodEnd: end,
      unitCode: unitCode,
      meta: meta,
      warnings: warnings,
      canCompute: true,
      metersContributing: withEndpoints,
      readingsContributing: readingCount,
      usedFirstInPeriodFallback: usedFallback,
      message: usedFallback
          ? 'Draft preview used first-in-period fallback (not approvable as-is).'
          : null,
    );
  }

  BaselineCalculationResult _fail({
    required BaselineCalculationMethod method,
    required DateTime start,
    required DateTime end,
    required String unitCode,
    required String reason,
    String? version,
    double completeness = 0,
    int confidence = 0,
    BaselineBoundaryQuality boundary = BaselineBoundaryQuality.insufficient,
    List<String> warnings = const [],
    int readings = 0,
  }) {
    final meta = CalculationMeta(
      calculationMethod: method.dbValue,
      periodStart: start,
      periodEnd: end,
      dataCompleteness: completeness,
      confidenceScore: confidence,
      baselineVersion: version,
      calculatedAt: DateTime.now().toUtc(),
      notes: [reason, ...warnings],
    );
    return BaselineCalculationResult(
      baselineValue: null,
      method: method,
      completeness: completeness,
      confidenceScore: confidence,
      boundaryQuality: boundary,
      referencePeriodStart: start,
      referencePeriodEnd: end,
      unitCode: unitCode,
      meta: meta,
      warnings: [...warnings, reason],
      canCompute: false,
      metersContributing: 0,
      readingsContributing: readings,
      usedFirstInPeriodFallback:
          boundary == BaselineBoundaryQuality.firstInPeriodFallback,
      message: reason,
    );
  }
}

/// Convenience: evaluate approval gates against a calculation preview.
BaselineApprovalGateResult evaluateBaselineApprovalFromCalculation({
  required BaselineCalculationResult calc,
  required ConservationBaselineScopeType scopeType,
  String? scopeId,
  bool unitMismatch = false,
  bool crossSiteScope = false,
  bool hasCriticalDataQualityFindings = false,
  BaselineApprovalGates gates = BaselineApprovalGates.standard,
}) {
  return BaselineApprovalGateEvaluator(gates: gates).evaluate(
    status: ConservationBaselineStatus.draft,
    method: calc.method,
    baselineValue: calc.baselineValue,
    completeness: calc.completeness,
    confidence: calc.confidenceScore,
    boundaryQuality: calc.boundaryQuality,
    referenceStart: calc.referencePeriodStart,
    referenceEnd: calc.referencePeriodEnd,
    unitCode: calc.unitCode,
    scopeType: scopeType,
    scopeId: scopeId,
    unitMismatch: unitMismatch,
    crossSiteScope: crossSiteScope,
    hasCriticalDataQualityFindings: hasCriticalDataQualityFindings,
  );
}
