import '../models/anomaly_result.dart';

/// COP conservation trend helper — does NOT recompute COP formulas.
///
/// Detects declining COP across consecutive valid periods only.
/// Investigation notes are suggestions, never automatic root cause.
class CopConservationTrendService {
  const CopConservationTrendService();

  static const method = 'conservation_cop_trend_v1';

  static const possibleInvestigationNotes = <String>[
    'Check chilled/condenser water flow rates',
    'Inspect heat exchanger fouling / approach temperature',
    'Review condenser performance and ambient conditions',
    'Verify setpoint changes / operating schedule',
    'Validate meter / sensor data accuracy (not a confirmed fault)',
  ];

  ConsumptionAnomalyResult analyzeDeclining({
    required List<double?> copValuesChronological,
    int consecutiveRequired = 3,
    double minValidCop = 0.1,
    DateTime? periodStart,
    DateTime? periodEnd,
    int confidence = 80,
    double completeness = 1.0,
    List<String> meterIds = const [],
  }) {
    final start = periodStart ?? DateTime.now().toUtc();
    final end = periodEnd ?? start;
    final warnings = <String>[];
    final required = consecutiveRequired < 2 ? 2 : consecutiveRequired;

    final valid = <double>[];
    for (final v in copValuesChronological) {
      if (v != null && v >= minValidCop) {
        valid.add(v);
      }
    }

    if (valid.length < required) {
      return ConsumptionAnomalyResult(
        detected: false,
        kind: AnomalyKind.copDeclining,
        severity: AnomalySeverity.info,
        statusLabel: ConsumptionAnomalyResult.insufficientData,
        reason:
            'Insufficient Data: need at least $required valid COP values '
            '(>= $minValidCop); found ${valid.length}.',
        confidenceScore: confidence.clamp(0, 100),
        completeness: completeness,
        periodStart: start,
        periodEnd: end,
        referenceMethod: method,
        contributingMeterIds: meterIds,
        warnings: warnings,
        investigationNotes: const [],
      );
    }

    // Latest `required` valid COP values must be strictly declining.
    final tail = valid.sublist(valid.length - required);
    var declining = true;
    for (var j = 1; j < tail.length; j++) {
      if (tail[j] >= tail[j - 1]) {
        declining = false;
        break;
      }
    }

    if (!declining) {
      return ConsumptionAnomalyResult(
        detected: false,
        kind: AnomalyKind.copDeclining,
        severity: AnomalySeverity.info,
        statusLabel: ConsumptionAnomalyResult.noAnomaly,
        reason:
            'No declining COP trend across $required consecutive valid periods.',
        confidenceScore: confidence.clamp(0, 100),
        completeness: completeness,
        periodStart: start,
        periodEnd: end,
        referenceMethod: method,
        contributingMeterIds: meterIds,
        warnings: warnings,
        currentValue: valid.last,
        referenceValue: valid.first,
        investigationNotes: const [],
      );
    }

    final first = tail.first;
    final last = tail.last;
    final pct = first > 0 ? ((first - last) / first) * 100.0 : 0.0;

    warnings.add(
      'COP declining for $required consecutive valid periods — '
      'Requires Review (not a confirmed fault / root cause).',
    );

    return ConsumptionAnomalyResult(
      detected: true,
      kind: AnomalyKind.copDeclining,
      severity: pct >= 30
          ? AnomalySeverity.high
          : pct >= 15
              ? AnomalySeverity.medium
              : AnomalySeverity.low,
      statusLabel: ConsumptionAnomalyResult.requiresReview,
      reason:
          'COP declining for $required consecutive valid periods '
          '(${first.toStringAsFixed(2)} → ${last.toStringAsFixed(2)}, '
          '${pct.toStringAsFixed(1)}% drop).',
      confidenceScore: confidence.clamp(0, 100),
      completeness: completeness,
      periodStart: start,
      periodEnd: end,
      referenceMethod: method,
      contributingMeterIds: meterIds,
      warnings: warnings,
      currentValue: last,
      referenceValue: first,
      percentageChange: -pct,
      investigationNotes: possibleInvestigationNotes,
    );
  }
}
