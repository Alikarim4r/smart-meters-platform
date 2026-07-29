import '../models/data_quality_result.dart';

/// Default confidence point deductions (deterministic, testable).
abstract final class ConfidenceDeltas {
  static const int base = 100;
  static const int missingRequiredPhoto = -20;
  static const int correctionInAnalysisPeriod = -10;
  static const int incompleteExpectedReadings = -15;
  static const int unusualConsumptionChange = -15;
  static const int readingRequiresReview = -10;
  static const int possibleRolloverOrReset = -5;
  static const int incompleteMeterGroup = -10;
}

/// Input reading for quality evaluation (read-only snapshot).
class QualityReadingInput {
  const QualityReadingInput({
    required this.readingId,
    required this.meterId,
    required this.readingDate,
    required this.rawValue,
    required this.normalizedValue,
    this.imageStoragePath,
  });

  final String readingId;
  final String meterId;
  final DateTime readingDate;
  final double rawValue;
  final double normalizedValue;
  final String? imageStoragePath;

  bool get hasPhoto =>
      imageStoragePath != null && imageStoragePath!.trim().isNotEmpty;
}

/// Per-meter evaluation context.
class QualityMeterInput {
  const QualityMeterInput({
    required this.meterId,
    required this.meterCode,
    required this.isActive,
    required this.includeInDashboard,
    required this.readings,
    this.expectedIntervalDays,
    this.meterMaxValue,
    this.correctionCountInPeriod = 0,
    this.wasReplacedOrResetInPeriod = false,
  });

  final String meterId;
  final String meterCode;
  final bool isActive;
  final bool includeInDashboard;

  /// Chronological readings intersecting the analysis window (+ prior for deltas).
  final List<QualityReadingInput> readings;

  /// Documented expected gap in days. Null = do not invent daily completeness.
  final int? expectedIntervalDays;

  /// Optional dial capacity for rollover heuristics.
  final double? meterMaxValue;

  final int correctionCountInPeriod;
  final bool wasReplacedOrResetInPeriod;
}

class DataQualityRuleContext {
  const DataQualityRuleContext({
    required this.siteId,
    required this.periodStart,
    required this.periodEnd,
    required this.meters,
    required this.photoRequired,
    required this.highConsumptionMultiplier,
    this.copGroupMemberCounts = const {},
  });

  final String siteId;
  final DateTime periodStart;
  final DateTime periodEnd;
  final List<QualityMeterInput> meters;
  final bool photoRequired;
  final double highConsumptionMultiplier;

  /// copGroupId → expected member count vs present readings (optional).
  final Map<String, ({int expected, int withReading})> copGroupMemberCounts;
}

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

int _daysBetween(DateTime a, DateTime b) =>
    _dateOnly(b).difference(_dateOnly(a)).inDays;

/// Median inter-reading gap in days from history (≥3 points), else null.
int? inferredIntervalDays(List<QualityReadingInput> readings) {
  if (readings.length < 3) return null;
  final sorted = [...readings]
    ..sort((a, b) => a.readingDate.compareTo(b.readingDate));
  final gaps = <int>[];
  for (var i = 1; i < sorted.length; i++) {
    final gap = _daysBetween(sorted[i - 1].readingDate, sorted[i].readingDate);
    if (gap > 0) gaps.add(gap);
  }
  if (gaps.isEmpty) return null;
  gaps.sort();
  return gaps[gaps.length ~/ 2];
}

/// Resolve expected interval: explicit policy/meter value wins; else inferred.
int? resolveExpectedIntervalDays(QualityMeterInput meter) {
  if (meter.expectedIntervalDays != null && meter.expectedIntervalDays! > 0) {
    return meter.expectedIntervalDays;
  }
  return inferredIntervalDays(meter.readings);
}

bool looksLikePossibleRollover({
  required double previous,
  required double current,
  double? meterMaxValue,
}) {
  if (previous <= 0) return false;
  if (current >= previous) return false;
  // Sharp drop to a small absolute value vs previous.
  final dropRatio = (previous - current) / previous;
  if (dropRatio >= 0.9 && current < previous * 0.1) return true;
  if (meterMaxValue != null && meterMaxValue > 0) {
    // Classic rollover: previous near max, current near zero.
    if (previous >= meterMaxValue * 0.8 && current <= meterMaxValue * 0.2) {
      return true;
    }
  }
  return false;
}

List<DataQualityFinding> evaluateDataQualityRules(DataQualityRuleContext ctx) {
  final findings = <DataQualityFinding>[];
  final start = _dateOnly(ctx.periodStart);
  final end = _dateOnly(ctx.periodEnd);

  for (final meter in ctx.meters) {
    if (!meter.isActive || !meter.includeInDashboard) continue;

    final inPeriod = meter.readings
        .where((r) {
          final d = _dateOnly(r.readingDate);
          return !d.isBefore(start) && !d.isAfter(end);
        })
        .toList()
      ..sort((a, b) => a.readingDate.compareTo(b.readingDate));

    final interval = resolveExpectedIntervalDays(meter);
    if (interval != null) {
      findings.addAll(
        _missingExpectedReadings(
          meter: meter,
          inPeriod: inPeriod,
          intervalDays: interval,
          start: start,
          end: end,
        ),
      );
    }

    // Sequence checks need previous reading (may be before period).
    final chronological = [...meter.readings]
      ..sort((a, b) => a.readingDate.compareTo(b.readingDate));
    for (var i = 1; i < chronological.length; i++) {
      final prev = chronological[i - 1];
      final curr = chronological[i];
      final currDay = _dateOnly(curr.readingDate);
      if (currDay.isBefore(start) || currDay.isAfter(end)) continue;

      if (curr.normalizedValue < prev.normalizedValue) {
        findings.add(
          _lowerThanPreviousFinding(
            meter: meter,
            previous: prev,
            current: curr,
          ),
        );
      } else {
        final consumption = curr.normalizedValue - prev.normalizedValue;
        final days = _daysBetween(prev.readingDate, curr.readingDate);
        if (days <= 0) continue;
        // Build simple baseline from earlier consumptions in window.
        final priorConsumptions = <double>[];
        for (var j = 1; j < i; j++) {
          final a = chronological[j - 1];
          final b = chronological[j];
          if (b.normalizedValue >= a.normalizedValue) {
            priorConsumptions.add(b.normalizedValue - a.normalizedValue);
          }
        }
        if (priorConsumptions.length >= 2) {
          final avg =
              priorConsumptions.reduce((a, b) => a + b) /
              priorConsumptions.length;
          if (avg > 0 &&
              consumption > avg * ctx.highConsumptionMultiplier) {
            findings.add(
              DataQualityFinding(
                code: DataQualityFindingCode.unusualConsumptionChange,
                severity: DataQualitySeverity.warning,
                title: 'Unusual Consumption Change',
                detail:
                    'Consumption between readings is ${consumption.toStringAsFixed(1)} '
                    'vs recent average ${avg.toStringAsFixed(1)} '
                    '(>${ctx.highConsumptionMultiplier}×). Reading requires review.',
                meterId: meter.meterId,
                readingId: curr.readingId,
                readingDate: curr.readingDate,
                metadata: {
                  'consumption': consumption,
                  'recent_average': avg,
                  'multiplier': ctx.highConsumptionMultiplier,
                },
              ),
            );
          }
        }
      }
    }

    if (ctx.photoRequired) {
      for (final r in inPeriod) {
        if (!r.hasPhoto) {
          findings.add(
            DataQualityFinding(
              code: DataQualityFindingCode.missingRequiredPhoto,
              severity: DataQualitySeverity.warning,
              title: 'Missing Required Photo',
              detail:
                  'Policy requires a photo for meter ${meter.meterCode} on '
                  '${_dateOnly(r.readingDate).toIso8601String().substring(0, 10)}.',
              meterId: meter.meterId,
              readingId: r.readingId,
              readingDate: r.readingDate,
            ),
          );
        }
      }
    }

    if (meter.correctionCountInPeriod > 0) {
      findings.add(
        DataQualityFinding(
          code: DataQualityFindingCode.correctionInAnalysisPeriod,
          severity: DataQualitySeverity.info,
          title: 'Correction In Analysis Period',
          detail:
              '${meter.correctionCountInPeriod} correction(s) recorded for '
              'meter ${meter.meterCode} in the analysis window.',
          meterId: meter.meterId,
          metadata: {'correction_count': meter.correctionCountInPeriod},
        ),
      );
    }
  }

  for (final entry in ctx.copGroupMemberCounts.entries) {
    final expected = entry.value.expected;
    final withReading = entry.value.withReading;
    if (expected > 0 && withReading < expected) {
      findings.add(
        DataQualityFinding(
          code: DataQualityFindingCode.incompleteMeterGroup,
          severity: DataQualitySeverity.warning,
          title: 'Incomplete Meter Group',
          detail:
              'Group ${entry.key}: $withReading/$expected members have readings '
              'in the analysis window.',
          metadata: {
            'group_id': entry.key,
            'expected': expected,
            'with_reading': withReading,
          },
        ),
      );
    }
  }

  return findings;
}

List<DataQualityFinding> _missingExpectedReadings({
  required QualityMeterInput meter,
  required List<QualityReadingInput> inPeriod,
  required int intervalDays,
  required DateTime start,
  required DateTime end,
}) {
  if (inPeriod.isEmpty) {
    // Anchor: if no reading in period, expect at least one slot when interval fits.
    final periodDays = _daysBetween(start, end) + 1;
    if (periodDays < intervalDays) return const [];
    return [
      DataQualityFinding(
        code: DataQualityFindingCode.missingExpectedReading,
        severity: DataQualitySeverity.warning,
        title: 'Missing Expected Reading',
        detail:
            'Meter ${meter.meterCode} has no readings in the period; '
            'expected interval ≈ $intervalDays day(s).',
        meterId: meter.meterId,
        metadata: {'expected_interval_days': intervalDays},
      ),
    ];
  }

  final findings = <DataQualityFinding>[];
  // Gaps between consecutive in-period readings larger than 1.5× interval.
  for (var i = 1; i < inPeriod.length; i++) {
    final gap = _daysBetween(
      inPeriod[i - 1].readingDate,
      inPeriod[i].readingDate,
    );
    if (gap > (intervalDays * 1.5).ceil()) {
      findings.add(
        DataQualityFinding(
          code: DataQualityFindingCode.incompleteExpectedReadings,
          severity: DataQualitySeverity.warning,
          title: 'Incomplete Expected Readings',
          detail:
              'Gap of $gap days between readings on meter ${meter.meterCode} '
              '(expected ≈ $intervalDays).',
          meterId: meter.meterId,
          readingDate: inPeriod[i].readingDate,
          metadata: {
            'gap_days': gap,
            'expected_interval_days': intervalDays,
          },
        ),
      );
    }
  }
  return findings;
}

DataQualityFinding _lowerThanPreviousFinding({
  required QualityMeterInput meter,
  required QualityReadingInput previous,
  required QualityReadingInput current,
}) {
  if (meter.wasReplacedOrResetInPeriod) {
    return DataQualityFinding(
      code: DataQualityFindingCode.readingRequiresReview,
      severity: DataQualitySeverity.info,
      title: 'Reading Requires Review',
      detail:
          'Reading lower than previous on ${meter.meterCode}, but meter '
          'replacement/reset is flagged in this period — treat as review, not error.',
      meterId: meter.meterId,
      readingId: current.readingId,
      readingDate: current.readingDate,
      metadata: {
        'previous_value': previous.normalizedValue,
        'current_value': current.normalizedValue,
        'possible_cause': 'meter_replacement_or_reset',
      },
    );
  }

  if (meter.correctionCountInPeriod > 0) {
    return DataQualityFinding(
      code: DataQualityFindingCode.readingRequiresReview,
      severity: DataQualitySeverity.info,
      title: 'Reading Requires Review',
      detail:
          'Reading lower than previous on ${meter.meterCode}; correction history '
          'exists in the period — possible legitimate correction, not auto-rejected.',
      meterId: meter.meterId,
      readingId: current.readingId,
      readingDate: current.readingDate,
      metadata: {
        'previous_value': previous.normalizedValue,
        'current_value': current.normalizedValue,
        'possible_cause': 'correction_history',
      },
    );
  }

  if (looksLikePossibleRollover(
    previous: previous.normalizedValue,
    current: current.normalizedValue,
    meterMaxValue: meter.meterMaxValue,
  )) {
    return DataQualityFinding(
      code: DataQualityFindingCode.possibleRolloverOrReset,
      severity: DataQualitySeverity.info,
      title: 'Reading Requires Review',
      detail:
          'Sharp drop on ${meter.meterCode} may indicate meter rollover or reset. '
          'Manual confirmation required before treating as a data error.',
      meterId: meter.meterId,
      readingId: current.readingId,
      readingDate: current.readingDate,
      metadata: {
        'previous_value': previous.normalizedValue,
        'current_value': current.normalizedValue,
        'possible_cause': 'rollover_or_reset',
      },
    );
  }

  return DataQualityFinding(
    code: DataQualityFindingCode.readingRequiresReview,
    severity: DataQualitySeverity.warning,
    title: 'Reading Requires Review',
    detail:
        'Reading lower than previous on ${meter.meterCode} '
        '(${previous.normalizedValue} → ${current.normalizedValue}). '
        'Possible entry error — review required; not treated as confirmed data error.',
    meterId: meter.meterId,
    readingId: current.readingId,
    readingDate: current.readingDate,
    metadata: {
      'previous_value': previous.normalizedValue,
      'current_value': current.normalizedValue,
      'possible_cause': 'possible_entry_error',
    },
  );
}

/// Completeness ratio for meters with a known expected interval only.
/// Returns null when no meter has a known frequency (do not invent daily).
double? computeCompletenessRatio(DataQualityRuleContext ctx) {
  final start = _dateOnly(ctx.periodStart);
  final end = _dateOnly(ctx.periodEnd);
  var expectedSlots = 0;
  var observedSlots = 0;

  for (final meter in ctx.meters) {
    if (!meter.isActive || !meter.includeInDashboard) continue;
    final interval = resolveExpectedIntervalDays(meter);
    if (interval == null) continue;

    final inPeriod = meter.readings.where((r) {
      final d = _dateOnly(r.readingDate);
      return !d.isBefore(start) && !d.isAfter(end);
    }).length;

    final periodDays = _daysBetween(start, end) + 1;
    final slots = (periodDays / interval).ceil().clamp(1, periodDays);
    expectedSlots += slots;
    observedSlots += inPeriod.clamp(0, slots);
  }

  if (expectedSlots == 0) return null;
  return (observedSlots / expectedSlots).clamp(0.0, 1.0);
}
