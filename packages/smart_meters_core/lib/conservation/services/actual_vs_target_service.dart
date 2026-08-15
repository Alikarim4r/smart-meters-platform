import '../../domain/chart_period.dart';
import '../models/actual_vs_target_result.dart';
import '../models/calculation_meta.dart';
import '../models/conservation_target.dart';
import 'period_comparison_service.dart';

/// Mechanical / manual meter boundary policy for Actual vs Target.
///
/// Do **not** invent a reading on `periodStart - 1 day`. Use the latest reading
/// strictly before the period when available; otherwise fall back to the first
/// reading **in** the period (same as [periodConsumptionFromEndpoints]). If
/// neither boundary exists → Insufficient Data.
enum MeterPeriodBoundaryPolicy {
  requireValidEndpoints,
}

/// Read-only Actual vs Target. Gap labels are Above/Below Target — never Saving.
class ActualVsTargetService {
  const ActualVsTargetService();

  static const method = 'conservation_actual_vs_target_v1';

  ActualVsTargetResult evaluate({
    required ConservationTarget target,
    required List<PeriodMeterReadingSeries> meters,
    DateTime? analysisAsOf,
    MeterPeriodBoundaryPolicy boundaryPolicy =
        MeterPeriodBoundaryPolicy.requireValidEndpoints,
  }) {
    final periodStart = dateOnly(target.periodStart);
    final periodEnd = dateOnly(target.periodEnd);
    final asOf = dateOnly(analysisAsOf ?? DateTime.now());
    final effectiveEnd = asOf.isBefore(periodEnd) ? asOf : periodEnd;

    final incompatible =
        meters.where((m) => m.unitCode != target.unitCode).toList();
    if (incompatible.isNotEmpty) {
      return _insufficient(
        target: target,
        asOf: asOf,
        effectiveEnd: effectiveEnd,
        reason: 'Incompatible meter units for target unit ${target.unitCode}.',
        completeness: 0,
        confidence: 0,
      );
    }

    final actual = _computeActual(
      meters: meters,
      periodStart: periodStart,
      periodEnd: effectiveEnd,
    );

    if (!actual.hasValidEndpoints || actual.value == null) {
      return _insufficient(
        target: target,
        asOf: asOf,
        effectiveEnd: effectiveEnd,
        reason:
            'Insufficient Data: no valid boundary readings for the analysis '
            'window (manual meters may lack a reading on the day before '
            'period start — do not invent periodStart-1).',
        completeness: actual.completeness,
        confidence: actual.confidence,
      );
    }

    final periodDays = inclusiveDayCount(periodStart, periodEnd);
    final elapsedDays = inclusiveDayCount(periodStart, effectiveEnd);
    final inProgress = effectiveEnd.isBefore(periodEnd);
    final proration =
        inProgress && periodDays > 0 ? (elapsedDays / periodDays) : 1.0;
    final mode = inProgress
        ? ActualVsTargetComparisonMode.periodToDateProrated
        : ActualVsTargetComparisonMode.fullPeriod;
    final effectiveTarget = target.targetValue * proration;

    if (actual.completeness < 0.5) {
      return _insufficient(
        target: target,
        asOf: asOf,
        effectiveEnd: effectiveEnd,
        reason:
            'Insufficient Data: actual completeness '
            '${(actual.completeness * 100).toStringAsFixed(0)}% is too low.',
        completeness: actual.completeness,
        confidence: actual.confidence,
        actualValue: actual.value,
        effectiveTarget: effectiveTarget,
        mode: mode,
        proration: proration,
      );
    }

    final absolute = actual.value! - effectiveTarget;
    final pctOfTarget =
        effectiveTarget == 0 ? null : (actual.value! / effectiveTarget) * 100.0;
    final standing = _standing(absolute);
    final label = _label(standing: standing, mode: mode);

    final meta = CalculationMeta(
      calculationMethod: method,
      periodStart: periodStart,
      periodEnd: periodEnd,
      dataCompleteness: actual.completeness,
      confidenceScore: actual.confidence,
      targetVersion: '${target.version}',
      calculatedAt: DateTime.now().toUtc(),
      notes: [
        'target_id=${target.id}',
        'target_version=${target.version}',
        'comparison_mode=${mode.name}',
        'analysis_as_of=${_iso(asOf)}',
        'effective_end=${_iso(effectiveEnd)}',
        'proration_factor=${proration.toStringAsFixed(4)}',
        'boundary_policy=${boundaryPolicy.name}',
        'note=Targets are separate from Baselines (P1D).',
        'note=Gap is Above/Below Target — never Saving.',
        if (inProgress)
          'note=Month/Year-to-date uses prorated target so partial actual '
              'is not compared to a full-period target misleadingly.',
      ],
    );

    return ActualVsTargetResult(
      status: ActualVsTargetStatus.ok,
      standing: standing,
      comparisonMode: mode,
      actualValue: actual.value,
      targetValue: target.targetValue,
      effectiveTargetValue: effectiveTarget,
      absoluteDifference: absolute,
      percentageOfTarget: pctOfTarget,
      directionLabel: label,
      unitCode: target.unitCode,
      completeness: actual.completeness,
      confidenceScore: actual.confidence,
      periodStart: periodStart,
      periodEnd: periodEnd,
      analysisAsOf: asOf,
      targetVersion: target.version,
      targetId: target.id,
      periodType: target.periodType,
      calculationMethod: method,
      calculatedAt: meta.calculatedAt,
      meta: meta,
      siteId: target.siteId,
      prorationFactor: proration,
      message: label,
    );
  }

  ({double? value, bool hasValidEndpoints, double completeness, int confidence})
      _computeActual({
    required List<PeriodMeterReadingSeries> meters,
    required DateTime periodStart,
    required DateTime periodEnd,
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
      total += periodConsumptionFromEndpoints(
        lastInPeriod: endpoints.lastInPeriod!,
        previousBeforePeriod: endpoints.previousBeforePeriod,
        firstInPeriod: endpoints.firstInPeriod,
      );
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

  ActualVsTargetStanding _standing(double absolute) {
    if (absolute.abs() < 1e-9) return ActualVsTargetStanding.onTarget;
    if (absolute > 0) return ActualVsTargetStanding.aboveTarget;
    return ActualVsTargetStanding.belowTarget;
  }

  String _label({
    required ActualVsTargetStanding standing,
    required ActualVsTargetComparisonMode mode,
  }) {
    final mtd = mode == ActualVsTargetComparisonMode.periodToDateProrated
        ? ' (vs prorated target, period-to-date)'
        : '';
    return switch (standing) {
      ActualVsTargetStanding.aboveTarget => 'Above Target$mtd',
      ActualVsTargetStanding.belowTarget => 'Below Target$mtd',
      ActualVsTargetStanding.onTarget => 'On Target$mtd',
      ActualVsTargetStanding.insufficientData => 'Insufficient Data',
    };
  }

  ActualVsTargetResult _insufficient({
    required ConservationTarget target,
    required DateTime asOf,
    required DateTime effectiveEnd,
    required String reason,
    required double completeness,
    required int confidence,
    double? actualValue,
    double? effectiveTarget,
    ActualVsTargetComparisonMode mode =
        ActualVsTargetComparisonMode.fullPeriod,
    double? proration,
  }) {
    final periodStart = dateOnly(target.periodStart);
    final periodEnd = dateOnly(target.periodEnd);
    final eff = effectiveTarget ?? target.targetValue;
    final meta = CalculationMeta(
      calculationMethod: method,
      periodStart: periodStart,
      periodEnd: periodEnd,
      dataCompleteness: completeness,
      confidenceScore: confidence,
      targetVersion: '${target.version}',
      calculatedAt: DateTime.now().toUtc(),
      notes: [reason],
    );
    return ActualVsTargetResult(
      status: ActualVsTargetStatus.insufficientData,
      standing: ActualVsTargetStanding.insufficientData,
      comparisonMode: mode,
      actualValue: actualValue,
      targetValue: target.targetValue,
      effectiveTargetValue: eff,
      absoluteDifference: null,
      percentageOfTarget: null,
      directionLabel: 'Insufficient Data',
      unitCode: target.unitCode,
      completeness: completeness,
      confidenceScore: confidence,
      periodStart: periodStart,
      periodEnd: periodEnd,
      analysisAsOf: asOf,
      targetVersion: target.version,
      targetId: target.id,
      periodType: target.periodType,
      calculationMethod: method,
      calculatedAt: meta.calculatedAt,
      meta: meta,
      siteId: target.siteId,
      message: reason,
      prorationFactor: proration,
    );
  }

  static String _iso(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
