import '../../domain/chart_period.dart';
import '../../domain/unit_conversion.dart';
import '../domain/period_windows.dart';
import '../models/actual_vs_baseline_result.dart';
import '../models/calculation_meta.dart';
import '../models/conservation_baseline.dart';
import 'period_comparison_service.dart';

/// Read-only Actual vs Baseline. Labels are Above/Below Baseline — never Saving.
class ActualVsBaselineService {
  const ActualVsBaselineService();

  static const method = 'conservation_actual_vs_baseline_v1';

  /// Minimum completeness for a trustworthy Actual period (0–1).
  static const minActualCompleteness = 0.5;

  ActualVsBaselineResult evaluate({
    required ConservationBaseline baseline,
    required List<PeriodMeterReadingSeries> meters,
    required DateTime analysisPeriodStart,
    required DateTime analysisPeriodEnd,
    DateTime? analysisAsOf,
  }) {
    final periodStart = dateOnly(analysisPeriodStart);
    final periodEnd = dateOnly(analysisPeriodEnd);
    final asOf = dateOnly(analysisAsOf ?? DateTime.now());
    final effectiveEnd = asOf.isBefore(periodEnd) ? asOf : periodEnd;

    final baselineCompleteness = baseline.dataCompleteness ?? 0.0;
    final baselineConfidence = baseline.confidenceScore ?? 0;

    if (baseline.status != ConservationBaselineStatus.approved &&
        baseline.status != ConservationBaselineStatus.superseded) {
      // Prefer approved; allow superseded only if caller intentionally passes it.
      if (baseline.status == ConservationBaselineStatus.draft ||
          baseline.status == ConservationBaselineStatus.archived) {
        return _insufficient(
          baseline: baseline,
          asOf: asOf,
          periodStart: periodStart,
          periodEnd: periodEnd,
          reason:
              'Baseline status ${baseline.status.dbValue} is not usable for '
              'Actual vs Baseline (need approved).',
          actualCompleteness: 0,
          actualConfidence: 0,
          baselineCompleteness: baselineCompleteness,
          baselineConfidence: baselineConfidence,
        );
      }
    }

    final incompatible = <PeriodMeterReadingSeries>[];
    final conversionFactors = <String, double>{};

    for (final m in meters) {
      // Identical codes (even custom ones) stay compatible 1:1.
      final factor = m.unitCode == baseline.unitCode
          ? 1.0
          : UnitConversion.factor(m.unitCode, baseline.unitCode);
      if (factor == null) {
        incompatible.add(m);
      } else {
        conversionFactors[m.meterId] = factor;
      }
    }

    if (incompatible.isNotEmpty) {
      return _insufficient(
        baseline: baseline,
        asOf: asOf,
        periodStart: periodStart,
        periodEnd: periodEnd,
        reason: 'Incompatible meter units for baseline unit ${baseline.unitCode}.',
        actualCompleteness: 0,
        actualConfidence: 0,
        baselineCompleteness: baselineCompleteness,
        baselineConfidence: baselineConfidence,
      );
    }

    final actual = _computeActual(
      meters: meters,
      periodStart: periodStart,
      periodEnd: effectiveEnd,
      conversionFactors: conversionFactors,
    );

    // Combined confidence = min(baseline, actual) — conservative.
    final combinedConfidence =
        actual.confidence < baselineConfidence
            ? actual.confidence
            : baselineConfidence;
    final combinedCompleteness = actual.completeness < baselineCompleteness
        ? actual.completeness
        : baselineCompleteness;

    if (!actual.hasValidEndpoints || actual.value == null) {
      return _insufficient(
        baseline: baseline,
        asOf: asOf,
        periodStart: periodStart,
        periodEnd: periodEnd,
        reason:
            'Insufficient Data: no valid boundary readings for the actual '
            'analysis window (do not invent periodStart-1).',
        actualCompleteness: actual.completeness,
        actualConfidence: actual.confidence,
        baselineCompleteness: baselineCompleteness,
        baselineConfidence: baselineConfidence,
        actualValue: actual.value,
      );
    }

    if (actual.completeness < minActualCompleteness) {
      return _insufficient(
        baseline: baseline,
        asOf: asOf,
        periodStart: periodStart,
        periodEnd: periodEnd,
        reason:
            'Insufficient Data: actual completeness '
            '${(actual.completeness * 100).toStringAsFixed(0)}% is too low '
            '(baseline quality alone is not enough).',
        actualCompleteness: actual.completeness,
        actualConfidence: actual.confidence,
        baselineCompleteness: baselineCompleteness,
        baselineConfidence: baselineConfidence,
        actualValue: actual.value,
      );
    }

    final absolute = actual.value! - baseline.baselineValue;
    final pct = baseline.baselineValue == 0
        ? null
        : (absolute / baseline.baselineValue) * 100.0;
    final standing = _standing(absolute);
    final label = _label(standing);

    final meta = CalculationMeta(
      calculationMethod: method,
      periodStart: periodStart,
      periodEnd: periodEnd,
      dataCompleteness: combinedCompleteness,
      confidenceScore: combinedConfidence,
      baselineVersion: '${baseline.versionNumber}',
      calculatedAt: DateTime.now().toUtc(),
      notes: [
        'baseline_id=${baseline.id}',
        'baseline_version=${baseline.versionNumber}',
        'baseline_method=${baseline.calculationMethod.dbValue}',
        'baseline_completeness=$baselineCompleteness',
        'baseline_confidence=$baselineConfidence',
        'actual_completeness=${actual.completeness}',
        'actual_confidence=${actual.confidence}',
        'combined_confidence=min(baseline,actual)=$combinedConfidence',
        'analysis_as_of=${_iso(asOf)}',
        'effective_end=${_iso(effectiveEnd)}',
        'note=Gap is Above/Below Baseline — never Saving.',
        'note=Targets and Baselines are separate concepts.',
      ],
    );

    return ActualVsBaselineResult(
      status: ActualVsBaselineStatus.ok,
      standing: standing,
      actualValue: actual.value,
      baselineValue: baseline.baselineValue,
      absoluteVariance: absolute,
      percentageVariance: pct,
      directionLabel: label,
      unitCode: baseline.unitCode,
      completeness: combinedCompleteness,
      confidenceScore: combinedConfidence,
      actualCompleteness: actual.completeness,
      actualConfidence: actual.confidence,
      baselineCompleteness: baselineCompleteness,
      baselineConfidence: baselineConfidence,
      periodStart: periodStart,
      periodEnd: periodEnd,
      analysisAsOf: asOf,
      baselineVersion: baseline.versionNumber,
      baselineId: baseline.id,
      calculationMethod: baseline.calculationMethod,
      calculatedAt: meta.calculatedAt,
      meta: meta,
      siteId: baseline.siteId,
      message: label,
    );
  }

  ({double? value, bool hasValidEndpoints, double completeness, int confidence})
      _computeActual({
    required List<PeriodMeterReadingSeries> meters,
    required DateTime periodStart,
    required DateTime periodEnd,
    required Map<String, double> conversionFactors,
  }) {
    if (meters.isEmpty) {
      return (
        value: null,
        hasValidEndpoints: false,
        completeness: 0,
        confidence: 0,
      );
    }

    var total = 0.0;
    var withEndpoints = 0;
    var readingCount = 0;

    for (final meter in meters) {
      final endpoints = extractEndpoints(
        readings: meter.normalizedPoints,
        periodStart: periodStart,
        periodEnd: periodEnd,
      );
      readingCount += endpoints.readingCountInPeriod;
      if (!endpoints.hasValidConsumptionEndpoints) continue;
      
      final rawConsumption = periodConsumptionFromEndpoints(
        lastInPeriod: endpoints.lastInPeriod!,
        previousBeforePeriod: endpoints.previousBeforePeriod,
        firstInPeriod: endpoints.firstInPeriod,
      );
      final factor = conversionFactors[meter.meterId] ?? 1.0;
      total += rawConsumption * factor;
      withEndpoints++;
    }

    final completeness =
        (withEndpoints / meters.length).clamp(0.0, 1.0).toDouble();
    var confidence = 100;
    if (withEndpoints == 0) confidence -= 40;
    if (completeness < 1.0) confidence -= 15;
    if (completeness < 0.5) confidence -= 20;
    if (readingCount == 0) confidence -= 20;

    return (
      value: withEndpoints > 0 ? total : null,
      hasValidEndpoints: withEndpoints > 0,
      completeness: completeness,
      confidence: confidence.clamp(0, 100),
    );
  }

  ActualVsBaselineStanding _standing(double absolute) {
    if (absolute.abs() < 1e-9) return ActualVsBaselineStanding.onBaseline;
    if (absolute > 0) return ActualVsBaselineStanding.aboveBaseline;
    return ActualVsBaselineStanding.belowBaseline;
  }

  String _label(ActualVsBaselineStanding standing) => switch (standing) {
        ActualVsBaselineStanding.aboveBaseline => 'Above Baseline',
        ActualVsBaselineStanding.belowBaseline => 'Below Baseline',
        ActualVsBaselineStanding.onBaseline => 'On Baseline',
        ActualVsBaselineStanding.insufficientData => 'Insufficient Data',
      };

  ActualVsBaselineResult _insufficient({
    required ConservationBaseline baseline,
    required DateTime asOf,
    required DateTime periodStart,
    required DateTime periodEnd,
    required String reason,
    required double actualCompleteness,
    required int actualConfidence,
    required double baselineCompleteness,
    required int baselineConfidence,
    double? actualValue,
  }) {
    final combinedConfidence = actualConfidence < baselineConfidence
        ? actualConfidence
        : baselineConfidence;
    final combinedCompleteness = actualCompleteness < baselineCompleteness
        ? actualCompleteness
        : baselineCompleteness;
    final meta = CalculationMeta(
      calculationMethod: method,
      periodStart: periodStart,
      periodEnd: periodEnd,
      dataCompleteness: combinedCompleteness,
      confidenceScore: combinedConfidence,
      baselineVersion: '${baseline.versionNumber}',
      calculatedAt: DateTime.now().toUtc(),
      notes: [reason],
    );
    return ActualVsBaselineResult(
      status: ActualVsBaselineStatus.insufficientData,
      standing: ActualVsBaselineStanding.insufficientData,
      actualValue: actualValue,
      baselineValue: baseline.baselineValue,
      absoluteVariance: null,
      percentageVariance: null,
      directionLabel: 'Insufficient Data',
      unitCode: baseline.unitCode,
      completeness: combinedCompleteness,
      confidenceScore: combinedConfidence,
      actualCompleteness: actualCompleteness,
      actualConfidence: actualConfidence,
      baselineCompleteness: baselineCompleteness,
      baselineConfidence: baselineConfidence,
      periodStart: periodStart,
      periodEnd: periodEnd,
      analysisAsOf: asOf,
      baselineVersion: baseline.versionNumber,
      baselineId: baseline.id,
      calculationMethod: baseline.calculationMethod,
      calculatedAt: meta.calculatedAt,
      meta: meta,
      siteId: baseline.siteId,
      message: reason,
    );
  }

  static String _iso(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

}
