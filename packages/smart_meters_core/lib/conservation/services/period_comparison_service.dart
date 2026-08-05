import '../../domain/chart_period.dart';
import '../domain/period_windows.dart';
import '../models/calculation_meta.dart';
import '../models/period_comparison_result.dart';

export '../domain/period_windows.dart';

/// Minimum completeness (0–1) to treat a period as usable for % change.
const double kPeriodComparisonMinCompleteness = 0.5;

/// Minimum confidence to treat a period as usable for strong %-change claims.
const int kPeriodComparisonMinConfidence = 50;

/// Read-only period comparison (Previous / YoY). No DB writes.
class PeriodComparisonService {
  const PeriodComparisonService();

  /// Resolve the comparison window for [type] given the current inclusive range.
  DateTimeRangeInclusive resolveComparisonPeriod({
    required PeriodComparisonType type,
    required DateTime currentStart,
    required DateTime currentEnd,
  }) {
    return switch (type) {
      PeriodComparisonType.previousPeriod =>
        previousPeriodOfEqualLength(currentStart, currentEnd),
      PeriodComparisonType.samePeriodLastYear =>
        samePeriodLastYear(currentStart, currentEnd),
    };
  }

  /// Compare using pre-bounded consumption snapshots (preferred for callers
  /// that already fetched only the two windows + endpoint baselines).
  PeriodComparisonResult compareSnapshots({
    required PeriodComparisonType type,
    required DateTime currentStart,
    required DateTime currentEnd,
    required PeriodConsumptionSnapshot current,
    required PeriodConsumptionSnapshot comparison,
    required String unitCode,
    String? siteId,
    String calculationMethod = 'conservation_period_compare_v1',
    DateTime? calculatedAt,
  }) {
    final comparisonRange = DateTimeRangeInclusive(
      start: comparison.periodStart,
      end: comparison.periodEnd,
    );
    return _buildResult(
      type: type,
      currentStart: dateOnly(currentStart),
      currentEnd: dateOnly(currentEnd),
      comparisonRange: comparisonRange,
      current: current,
      comparison: comparison,
      unitCode: unitCode,
      siteId: siteId,
      calculationMethod: calculationMethod,
      calculatedAt: calculatedAt ?? DateTime.now().toUtc(),
    );
  }

  /// Compare from in-memory meter readings (tests / offline fixtures).
  ///
  /// Readings outside the needed windows are ignored. Callers that hit the DB
  /// should still restrict the query to current + comparison (+ one prior
  /// reading for baselines).
  PeriodComparisonResult compareMeters({
    required PeriodComparisonType type,
    required DateTime currentStart,
    required DateTime currentEnd,
    required List<PeriodMeterReadingSeries> meters,
    required String unitCode,
    String? siteId,
    DateTime? calculatedAt,
  }) {
    final cStart = dateOnly(currentStart);
    final cEnd = dateOnly(currentEnd);
    final comparisonRange = resolveComparisonPeriod(
      type: type,
      currentStart: cStart,
      currentEnd: cEnd,
    );

    final incompatible = meters.where((m) => m.unitCode != unitCode).toList();
    if (incompatible.isNotEmpty) {
      return PeriodComparisonResult.insufficient(
        type: type,
        unitCode: unitCode,
        siteId: siteId,
        currentStart: cStart,
        currentEnd: cEnd,
        comparisonStart: comparisonRange.start,
        comparisonEnd: comparisonRange.end,
        reason: 'Incompatible units in comparison scope '
            '(expected $unitCode).',
        calculatedAt: calculatedAt ?? DateTime.now().toUtc(),
      );
    }

    final currentSnap = _aggregateMeters(
      meters: meters,
      periodStart: cStart,
      periodEnd: cEnd,
    );
    final comparisonSnap = _aggregateMeters(
      meters: meters,
      periodStart: comparisonRange.start,
      periodEnd: comparisonRange.end,
    );

    return _buildResult(
      type: type,
      currentStart: cStart,
      currentEnd: cEnd,
      comparisonRange: comparisonRange,
      current: currentSnap,
      comparison: comparisonSnap,
      unitCode: unitCode,
      siteId: siteId,
      calculationMethod: 'conservation_period_compare_v1',
      calculatedAt: calculatedAt ?? DateTime.now().toUtc(),
    );
  }

  PeriodConsumptionSnapshot _aggregateMeters({
    required List<PeriodMeterReadingSeries> meters,
    required DateTime periodStart,
    required DateTime periodEnd,
  }) {
    var total = 0.0;
    var anyValid = false;
    var readingCount = 0;
    var expectedSlots = 0;
    var observedSlots = 0;
    var corrections = 0;
    var metersWithEndpoints = 0;

    for (final meter in meters) {
      corrections += meter.correctionCountInPeriod(
        periodStart: periodStart,
        periodEnd: periodEnd,
      );
      final endpoints = extractEndpoints(
        readings: meter.normalizedPoints,
        periodStart: periodStart,
        periodEnd: periodEnd,
      );
      readingCount += endpoints.readingCountInPeriod;

      if (meter.expectedIntervalDays != null &&
          meter.expectedIntervalDays! > 0) {
        final days = inclusiveDayCount(periodStart, periodEnd);
        final slots =
            (days / meter.expectedIntervalDays!).ceil().clamp(1, days) as int;
        expectedSlots += slots;
        observedSlots +=
            endpoints.readingCountInPeriod.clamp(0, slots) as int;
      }

      if (!endpoints.hasValidConsumptionEndpoints) {
        continue;
      }
      final consumption = periodConsumptionFromEndpoints(
        lastInPeriod: endpoints.lastInPeriod!,
        previousBeforePeriod: endpoints.previousBeforePeriod,
        firstInPeriod: endpoints.firstInPeriod,
      );
      total += consumption;
      anyValid = true;
      metersWithEndpoints++;
    }

    final completeness = expectedSlots > 0
        ? (observedSlots / expectedSlots).clamp(0.0, 1.0)
        : (meters.isEmpty
            ? 0.0
            : (anyValid
                ? (metersWithEndpoints / meters.length).clamp(0.0, 1.0)
                : 0.0));


    final confidence = _periodConfidence(
      hasValidEndpoints: anyValid,
      completeness: completeness,
      correctionCount: corrections,
      meterCount: meters.length,
      metersWithEndpoints: metersWithEndpoints,
    );

    return PeriodConsumptionSnapshot(
      periodStart: periodStart,
      periodEnd: periodEnd,
      value: anyValid ? total : null,
      hasValidEndpoints: anyValid,
      readingCount: readingCount,
      completeness: completeness,
      confidenceScore: confidence,
      correctionCount: corrections,
    );
  }

  int _periodConfidence({
    required bool hasValidEndpoints,
    required double completeness,
    required int correctionCount,
    required int meterCount,
    required int metersWithEndpoints,
  }) {
    var score = 100;
    if (!hasValidEndpoints) {
      score -= 40;
    }
    if (completeness < 1.0) {
      score -= 15;
    }
    if (completeness < kPeriodComparisonMinCompleteness) {
      score -= 20;
    }
    if (correctionCount > 0) {
      score -= 10;
    }
    if (meterCount > 0 && metersWithEndpoints < meterCount) {
      score -= 10;
    }
    return score.clamp(0, 100);
  }

  PeriodComparisonResult _buildResult({
    required PeriodComparisonType type,
    required DateTime currentStart,
    required DateTime currentEnd,
    required DateTimeRangeInclusive comparisonRange,
    required PeriodConsumptionSnapshot current,
    required PeriodConsumptionSnapshot comparison,
    required String unitCode,
    required String? siteId,
    required String calculationMethod,
    required DateTime calculatedAt,
  }) {
    final comparisonConfidence =
        current.confidenceScore < comparison.confidenceScore
            ? current.confidenceScore
            : comparison.confidenceScore;

    final meta = CalculationMeta(
      calculationMethod: calculationMethod,
      periodStart: currentStart,
      periodEnd: currentEnd,
      dataCompleteness: current.completeness,
      confidenceScore: comparisonConfidence,
      calculatedAt: calculatedAt,
      notes: [
        'comparison_type=${type.name}',
        'comparison_period=${comparisonRange.start.toIso8601String().substring(0, 10)}'
            '..${comparisonRange.end.toIso8601String().substring(0, 10)}',
        'current_confidence=${current.confidenceScore}',
        'comparison_confidence=${comparison.confidenceScore}',
        'combined_confidence=min(current,comparison)=$comparisonConfidence',
        'equal_length_days='
            '${inclusiveDayCount(currentStart, currentEnd)}',
      ],
    );

    final insufficient = _insufficientReason(
      current: current,
      comparison: comparison,
    );
    if (insufficient != null) {
      return PeriodComparisonResult(
        type: type,
        status: PeriodComparisonStatus.insufficientData,
        unitCode: unitCode,
        siteId: siteId,
        currentValue: current.value,
        comparisonValue: comparison.value,
        absoluteDifference: null,
        percentageDifference: null,
        percentageDisplay: 'N/A',
        directionLabel: 'Insufficient Data',
        currentCompleteness: current.completeness,
        comparisonCompleteness: comparison.completeness,
        confidenceScore: comparisonConfidence,
        currentPeriodConfidence: current.confidenceScore,
        comparisonPeriodConfidence: comparison.confidenceScore,
        periodStart: currentStart,
        periodEnd: currentEnd,
        comparisonPeriodStart: comparisonRange.start,
        comparisonPeriodEnd: comparisonRange.end,
        calculatedAt: calculatedAt,
        calculationMethod: calculationMethod,
        meta: meta,
        message: insufficient,
      );
    }

    final currentValue = current.value!;
    final comparisonValue = comparison.value!;
    final absolute = currentValue - comparisonValue;

    final percentage = _percentageDifference(
      currentValue: currentValue,
      comparisonValue: comparisonValue,
      currentCompleteness: current.completeness,
      currentConfidence: current.confidenceScore,
    );

    if (percentage.forceInsufficient) {
      return PeriodComparisonResult(
        type: type,
        status: PeriodComparisonStatus.insufficientData,
        unitCode: unitCode,
        siteId: siteId,
        currentValue: currentValue,
        comparisonValue: comparisonValue,
        absoluteDifference: absolute,
        percentageDifference: null,
        percentageDisplay: 'N/A',
        directionLabel: 'Insufficient Data',
        currentCompleteness: current.completeness,
        comparisonCompleteness: comparison.completeness,
        confidenceScore: comparisonConfidence,
        currentPeriodConfidence: current.confidenceScore,
        comparisonPeriodConfidence: comparison.confidenceScore,
        periodStart: currentStart,
        periodEnd: currentEnd,
        comparisonPeriodStart: comparisonRange.start,
        comparisonPeriodEnd: comparisonRange.end,
        calculatedAt: calculatedAt,
        calculationMethod: calculationMethod,
        meta: meta,
        message: percentage.reason,
      );
    }

    final direction = _directionLabel(
      type: type,
      absolute: absolute,
      percentage: percentage.value,
    );

    return PeriodComparisonResult(
      type: type,
      status: PeriodComparisonStatus.ok,
      unitCode: unitCode,
      siteId: siteId,
      currentValue: currentValue,
      comparisonValue: comparisonValue,
      absoluteDifference: absolute,
      percentageDifference: percentage.value,
      percentageDisplay: percentage.display,
      directionLabel: direction,
      currentCompleteness: current.completeness,
      comparisonCompleteness: comparison.completeness,
      confidenceScore: comparisonConfidence,
      currentPeriodConfidence: current.confidenceScore,
      comparisonPeriodConfidence: comparison.confidenceScore,
      periodStart: currentStart,
      periodEnd: currentEnd,
      comparisonPeriodStart: comparisonRange.start,
      comparisonPeriodEnd: comparisonRange.end,
      calculatedAt: calculatedAt,
      calculationMethod: calculationMethod,
      meta: meta,
      message: direction,
    );
  }

  String? _insufficientReason({
    required PeriodConsumptionSnapshot current,
    required PeriodConsumptionSnapshot comparison,
  }) {
    if (!current.hasValidEndpoints || current.value == null) {
      return 'Insufficient Data: current period has no valid consumption '
          'endpoints.';
    }
    if (!comparison.hasValidEndpoints || comparison.value == null) {
      return 'Insufficient Data: comparison period has no valid consumption '
          'endpoints.';
    }
    if (current.completeness < kPeriodComparisonMinCompleteness) {
      return 'Insufficient Data: current period completeness '
          '${(current.completeness * 100).toStringAsFixed(0)}% is below '
          '${(kPeriodComparisonMinCompleteness * 100).toStringAsFixed(0)}%.';
    }
    if (comparison.completeness < kPeriodComparisonMinCompleteness) {
      return 'Insufficient Data: comparison period completeness '
          '${(comparison.completeness * 100).toStringAsFixed(0)}% is below '
          '${(kPeriodComparisonMinCompleteness * 100).toStringAsFixed(0)}%.';
    }
    return null;
  }

  ({double? value, String display, bool forceInsufficient, String? reason})
      _percentageDifference({
    required double currentValue,
    required double comparisonValue,
    required double currentCompleteness,
    required int currentConfidence,
  }) {
    if (comparisonValue == 0) {
      if (currentValue == 0) {
        return (
          value: 0,
          display: '0%',
          forceInsufficient: false,
          reason: null,
        );
      }
      return (
        value: null,
        display: 'N/A',
        forceInsufficient: false,
        reason: null,
      );
    }

    if (currentValue == 0 && comparisonValue > 0) {
      final weakCurrent = currentCompleteness < 0.99 ||
          currentConfidence < kPeriodComparisonMinConfidence;
      if (weakCurrent) {
        return (
          value: null,
          display: 'N/A',
          forceInsufficient: true,
          reason:
              'Insufficient Data / Low Confidence: current period is 0 while '
              'comparison > 0, but current completeness/confidence is too weak '
              'to claim a full reduction.',
        );
      }
    }

    final pct = ((currentValue - comparisonValue) / comparisonValue) * 100.0;
    return (
      value: pct,
      display: '${pct.toStringAsFixed(1)}%',
      forceInsufficient: false,
      reason: null,
    );
  }

  String _directionLabel({
    required PeriodComparisonType type,
    required double absolute,
    required double? percentage,
  }) {
    final vs = switch (type) {
      PeriodComparisonType.previousPeriod => 'previous period',
      PeriodComparisonType.samePeriodLastYear => 'same period last year',
    };
    if (percentage == null && absolute != 0) {
      // Previous was 0 — absolute still meaningful.
      if (absolute > 0) return 'Higher than $vs';
      if (absolute < 0) return 'Lower than $vs';
    }
    if (absolute.abs() < 1e-9) {
      return 'No significant change';
    }
    if (absolute > 0) {
      return 'Higher than $vs · Increase';
    }
    return 'Lower than $vs · Decrease';
  }
}

/// One meter series for [PeriodComparisonService.compareMeters].
class PeriodMeterReadingSeries {
  const PeriodMeterReadingSeries({
    required this.meterId,
    required this.unitCode,
    required this.readings,
    this.meterMultiplier = 1.0,
    this.expectedIntervalDays,
    this.correctionDates = const [],
  });

  final String meterId;
  final String unitCode;
  final double meterMultiplier;
  final List<PeriodReadingPoint> readings;
  final int? expectedIntervalDays;
  final List<DateTime> correctionDates;

  List<PeriodReadingPoint> get normalizedPoints => [
        for (final r in readings)
          PeriodReadingPoint(
            date: r.date,
            value: r.value * meterMultiplier,
          ),
      ];

  int correctionCountInPeriod({
    required DateTime periodStart,
    required DateTime periodEnd,
  }) {
    var n = 0;
    for (final d in correctionDates) {
      final day = dateOnly(d);
      if (!day.isBefore(periodStart) && !day.isAfter(periodEnd)) n++;
    }
    return n;
  }
}

class PeriodReadingPoint {
  const PeriodReadingPoint({required this.date, required this.value});

  final DateTime date;
  final double value;
}

class PeriodEndpointExtraction {
  const PeriodEndpointExtraction({
    required this.previousBeforePeriod,
    required this.firstInPeriod,
    required this.lastInPeriod,
    required this.readingCountInPeriod,
  });

  final double? previousBeforePeriod;
  final double? firstInPeriod;
  final double? lastInPeriod;
  final int readingCountInPeriod;

  bool get hasValidConsumptionEndpoints =>
      lastInPeriod != null &&
      (previousBeforePeriod != null || firstInPeriod != null);
}

/// Extract endpoint normalized values for [periodConsumptionFromEndpoints].
PeriodEndpointExtraction extractEndpoints({
  required List<PeriodReadingPoint> readings,
  required DateTime periodStart,
  required DateTime periodEnd,
}) {
  final start = dateOnly(periodStart);
  final end = dateOnly(periodEnd);
  final sorted = [...readings]..sort((a, b) => a.date.compareTo(b.date));

  double? previousBefore;
  double? firstIn;
  double? lastIn;
  var count = 0;

  for (final r in sorted) {
    final d = dateOnly(r.date);
    if (d.isBefore(start)) {
      previousBefore = r.value;
      continue;
    }
    if (d.isAfter(end)) break;
    count++;
    firstIn ??= r.value;
    lastIn = r.value;
  }

  return PeriodEndpointExtraction(
    previousBeforePeriod: previousBefore,
    firstInPeriod: firstIn,
    lastInPeriod: lastIn,
    readingCountInPeriod: count,
  );
}

/// Aggregated consumption snapshot for one period.
class PeriodConsumptionSnapshot {
  const PeriodConsumptionSnapshot({
    required this.periodStart,
    required this.periodEnd,
    required this.value,
    required this.hasValidEndpoints,
    required this.readingCount,
    required this.completeness,
    required this.confidenceScore,
    this.correctionCount = 0,
  });

  final DateTime periodStart;
  final DateTime periodEnd;
  final double? value;
  final bool hasValidEndpoints;
  final int readingCount;
  final double completeness;
  final int confidenceScore;
  final int correctionCount;
}
