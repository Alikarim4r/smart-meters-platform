import '../domain/period_windows.dart';
import '../models/anomaly_result.dart';

/// Deterministic periodic consumption anomaly detection.
///
/// Labels: Unusual Consumption / Requires Review — never Confirmed Fault.
/// Anomaly ≠ Fault.
class PeriodicAnomalyService {
  const PeriodicAnomalyService();

  static const method = 'conservation_periodic_anomaly_v1';

  /// % change vs previous period to flag unusual increase/decrease.
  static const unusualChangeThresholdPct = 25.0;

  /// % above baseline to flag farAboveBaseline.
  static const farAboveBaselineThresholdPct = 20.0;

  /// Consecutive high/low periods for repeated pattern.
  static const repeatedPatternMinPeriods = 3;

  /// Cap severity at medium when confidence is below this.
  static const lowConfidenceCapThreshold = 60;

  /// Critical requires confidence at/above this (else warn + cap).
  static const criticalMinConfidence = 70;

  static const lowConfidenceWarning =
      'Low confidence — not a confirmed fault';

  ConsumptionAnomalyResult detect({
    required double? currentConsumption,
    required double? previousConsumption,
    required DateTime periodStart,
    required DateTime periodEnd,
    required double completeness,
    required int confidence,
    required List<String> meterIds,
    double? baseline,
    double? target,
    List<double?> historicalPeriodConsumptions = const [],
    DateTime? calculatedAt,
  }) {
    final start = dateOnly(periodStart);
    final end = dateOnly(periodEnd);
    final warnings = <String>[];

    if (currentConsumption == null || completeness < 0.5) {
      return ConsumptionAnomalyResult(
        detected: false,
        kind: null,
        severity: AnomalySeverity.info,
        statusLabel: ConsumptionAnomalyResult.insufficientData,
        reason: 'Insufficient Data: current period consumption unavailable '
            'or completeness below 50%.',
        confidenceScore: confidence.clamp(0, 100),
        completeness: completeness,
        periodStart: start,
        periodEnd: end,
        referenceMethod: method,
        contributingMeterIds: meterIds,
        warnings: warnings,
        currentValue: currentConsumption,
      );
    }

    // Priority: repeated → target → baseline → vs previous.
    AnomalyKind? kind;
    String reason = ConsumptionAnomalyResult.noAnomaly;
    var pctChange = null as double?;
    var reference = null as double?;
    var magnitudePct = 0.0;

    final repeated = _detectRepeated(
      current: currentConsumption,
      historical: historicalPeriodConsumptions,
    );
    if (repeated != null) {
      kind = repeated.kind;
      reason = repeated.reason;
      magnitudePct = repeated.magnitudePct;
      reference = repeated.reference;
    } else if (target != null && currentConsumption > target) {
      kind = AnomalyKind.aboveTarget;
      reference = target;
      pctChange = target == 0
          ? null
          : ((currentConsumption - target) / target) * 100.0;
      magnitudePct = pctChange?.abs() ?? 100;
      reason =
          'Current consumption above target '
          '(${currentConsumption.toStringAsFixed(2)} > ${target.toStringAsFixed(2)}).';
    } else if (baseline != null && baseline > 0) {
      final vsBase =
          ((currentConsumption - baseline) / baseline) * 100.0;
      if (vsBase > farAboveBaselineThresholdPct) {
        kind = AnomalyKind.farAboveBaseline;
        reference = baseline;
        pctChange = vsBase;
        magnitudePct = vsBase.abs();
        reason =
            'Current consumption is ${vsBase.toStringAsFixed(1)}% above baseline '
            '(threshold ${farAboveBaselineThresholdPct.toStringAsFixed(0)}%).';
      }
    }

    if (kind == null &&
        previousConsumption != null &&
        previousConsumption > 0) {
      final vsPrev =
          ((currentConsumption - previousConsumption) / previousConsumption) *
              100.0;
      pctChange = vsPrev;
      reference = previousConsumption;
      if (vsPrev > unusualChangeThresholdPct) {
        kind = AnomalyKind.unusualIncrease;
        magnitudePct = vsPrev.abs();
        reason =
            'Unusual increase of ${vsPrev.toStringAsFixed(1)}% vs previous period '
            '(threshold ${unusualChangeThresholdPct.toStringAsFixed(0)}%).';
      } else if (vsPrev < -unusualChangeThresholdPct) {
        kind = AnomalyKind.unusualDecrease;
        magnitudePct = vsPrev.abs();
        reason =
            'Unusual decrease of ${vsPrev.abs().toStringAsFixed(1)}% vs previous period '
            '(threshold ${unusualChangeThresholdPct.toStringAsFixed(0)}%).';
      }
    } else if (kind == null &&
        previousConsumption != null &&
        previousConsumption == 0 &&
        currentConsumption > 0) {
      kind = AnomalyKind.suddenChange;
      reference = previousConsumption;
      magnitudePct = 100;
      reason =
          'Sudden change: previous period was 0 while current > 0 — Requires Review.';
    }

    if (kind == null) {
      return ConsumptionAnomalyResult(
        detected: false,
        kind: null,
        severity: AnomalySeverity.info,
        statusLabel: ConsumptionAnomalyResult.noAnomaly,
        reason: reason,
        confidenceScore: confidence.clamp(0, 100),
        completeness: completeness,
        periodStart: start,
        periodEnd: end,
        referenceMethod: method,
        contributingMeterIds: meterIds,
        warnings: warnings,
        currentValue: currentConsumption,
        referenceValue: reference,
        percentageChange: pctChange,
      );
    }

    var severity = _severityFromMagnitude(magnitudePct);
    severity = _applyConfidenceGuards(
      severity: severity,
      confidence: confidence,
      warnings: warnings,
    );

    final statusLabel = severity.index >= AnomalySeverity.high.index
        ? ConsumptionAnomalyResult.requiresReview
        : ConsumptionAnomalyResult.unusualConsumption;

    assert(
      statusLabel != ConsumptionAnomalyResult.forbiddenConfirmedFault,
      'Anomaly labels must never be Confirmed Fault',
    );

    return ConsumptionAnomalyResult(
      detected: true,
      kind: kind,
      severity: severity,
      statusLabel: statusLabel,
      reason: reason,
      confidenceScore: confidence.clamp(0, 100),
      completeness: completeness,
      periodStart: start,
      periodEnd: end,
      referenceMethod: method,
      contributingMeterIds: meterIds,
      warnings: warnings,
      currentValue: currentConsumption,
      referenceValue: reference,
      percentageChange: pctChange,
    );
  }

  ({AnomalyKind kind, String reason, double magnitudePct, double? reference})?
      _detectRepeated({
    required double current,
    required List<double?> historical,
  }) {
    // historical = older → newer periods before current; we append current.
    final series = <double>[
      for (final v in historical)
        if (v != null) v,
      current,
    ];
    if (series.length < repeatedPatternMinPeriods) return null;

    final window = series.sublist(series.length - repeatedPatternMinPeriods);
    final mean = window.reduce((a, b) => a + b) / window.length;
    if (mean <= 0) return null;

    // All periods in window above mean of a longer history → repeated high.
    final histOnly = [
      for (final v in historical)
        if (v != null) v,
    ];
    if (histOnly.length < repeatedPatternMinPeriods) {
      // Use relative: each value >= 1.15 * min of window and rising/high band.
      final minW = window.reduce((a, b) => a < b ? a : b);
      final maxW = window.reduce((a, b) => a > b ? a : b);
      if (minW > 0 && maxW / minW < 1.5) {
        // Tight cluster — check if all are "high" relative to earlier history.
        if (histOnly.isNotEmpty) {
          final earlierMean =
              histOnly.reduce((a, b) => a + b) / histOnly.length;
          if (earlierMean > 0 && mean > earlierMean * 1.15) {
            return (
              kind: AnomalyKind.repeatedHigh,
              reason:
                  'Repeated high consumption across $repeatedPatternMinPeriods+ periods.',
              magnitudePct: ((mean - earlierMean) / earlierMean) * 100,
              reference: earlierMean,
            );
          }
          if (earlierMean > 0 && mean < earlierMean * 0.85) {
            return (
              kind: AnomalyKind.repeatedLow,
              reason:
                  'Repeated low consumption across $repeatedPatternMinPeriods+ periods.',
              magnitudePct: ((earlierMean - mean) / earlierMean) * 100,
              reference: earlierMean,
            );
          }
        }
      }
      return null;
    }

    final earlier = histOnly.sublist(
      0,
      histOnly.length - (repeatedPatternMinPeriods - 1).clamp(0, histOnly.length),
    );
    if (earlier.isEmpty) {
      // All history is the repeated window — compare last N vs prior N if possible.
      if (histOnly.length >= repeatedPatternMinPeriods * 2 - 1) {
        final prior = histOnly.sublist(
          0,
          histOnly.length - (repeatedPatternMinPeriods - 1),
        );
        final priorMean = prior.reduce((a, b) => a + b) / prior.length;
        if (priorMean > 0 && mean > priorMean * 1.15) {
          return (
            kind: AnomalyKind.repeatedHigh,
            reason:
                'Repeated high consumption across $repeatedPatternMinPeriods+ periods.',
            magnitudePct: ((mean - priorMean) / priorMean) * 100,
            reference: priorMean,
          );
        }
      }
      return null;
    }
    final earlierMean = earlier.reduce((a, b) => a + b) / earlier.length;
    if (earlierMean <= 0) return null;
    if (mean > earlierMean * 1.15) {
      return (
        kind: AnomalyKind.repeatedHigh,
        reason:
            'Repeated high consumption across $repeatedPatternMinPeriods+ periods.',
        magnitudePct: ((mean - earlierMean) / earlierMean) * 100,
        reference: earlierMean,
      );
    }
    if (mean < earlierMean * 0.85) {
      return (
        kind: AnomalyKind.repeatedLow,
        reason:
            'Repeated low consumption across $repeatedPatternMinPeriods+ periods.',
        magnitudePct: ((earlierMean - mean) / earlierMean) * 100,
        reference: earlierMean,
      );
    }
    return null;
  }

  AnomalySeverity _severityFromMagnitude(double magnitudePct) {
    if (magnitudePct >= 75) return AnomalySeverity.critical;
    if (magnitudePct >= 50) return AnomalySeverity.high;
    if (magnitudePct >= 35) return AnomalySeverity.medium;
    if (magnitudePct >= unusualChangeThresholdPct) return AnomalySeverity.low;
    return AnomalySeverity.info;
  }

  AnomalySeverity _applyConfidenceGuards({
    required AnomalySeverity severity,
    required int confidence,
    required List<String> warnings,
  }) {
    var s = severity;
    if (confidence < lowConfidenceCapThreshold &&
        s.index > AnomalySeverity.medium.index) {
      s = AnomalySeverity.medium;
      if (!warnings.contains(lowConfidenceWarning)) {
        warnings.add(lowConfidenceWarning);
      }
    }
    if (s == AnomalySeverity.critical && confidence < criticalMinConfidence) {
      s = AnomalySeverity.high;
      if (!warnings.contains(lowConfidenceWarning)) {
        warnings.add(lowConfidenceWarning);
      } else {
        warnings.add(
          'Critical severity suppressed: confidence $confidence < $criticalMinConfidence.',
        );
      }
    }
    // Never Critical without the low-confidence warning when confidence < 70.
    if (s == AnomalySeverity.critical &&
        confidence < criticalMinConfidence &&
        !warnings.contains(lowConfidenceWarning)) {
      warnings.add(lowConfidenceWarning);
    }
    return s;
  }
}
