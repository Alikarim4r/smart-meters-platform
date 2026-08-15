import 'package:flutter_test/flutter_test.dart';
import 'package:smart_meters_core/conservation/conservation.dart';

PeriodReadingPoint p(DateTime d, double v) =>
    PeriodReadingPoint(date: d, value: v);

ConservationTarget target({
  DateTime? start,
  DateTime? end,
  double value = 100,
  String unit = 'kWh',
  int version = 1,
  ConservationTargetPeriodType periodType = ConservationTargetPeriodType.monthly,
}) {
  return ConservationTarget(
    id: 't1',
    siteId: 'site-1',
    scopeType: ConservationTargetScopeType.site,
    scopeId: null,
    periodType: periodType,
    periodStart: start ?? DateTime(2026, 7, 1),
    periodEnd: end ?? DateTime(2026, 7, 31),
    targetValue: value,
    unitCode: unit,
    version: version,
    status: ConservationTargetStatus.active,
  );
}

void main() {
  const service = ActualVsTargetService();

  group('ActualVsTargetService', () {
    test('above target (full period)', () {
      final result = service.evaluate(
        target: target(value: 50),
        analysisAsOf: DateTime(2026, 7, 31),
        meters: [
          PeriodMeterReadingSeries(
            meterId: 'm1',
            unitCode: 'kWh',
            readings: [
              p(DateTime(2026, 6, 30), 100),
              p(DateTime(2026, 7, 31), 200),
            ],
          ),
        ],
      );
      expect(result.status, ActualVsTargetStatus.ok);
      expect(result.actualValue, 100);
      expect(result.effectiveTargetValue, 50);
      expect(result.standing, ActualVsTargetStanding.aboveTarget);
      expect(result.directionLabel, 'Above Target');
      expect(result.directionLabel.toLowerCase(), isNot(contains('saving')));
      expect(result.meta.targetVersion, '1');
      expect(result.comparisonMode, ActualVsTargetComparisonMode.fullPeriod);
    });

    test('below target (full period)', () {
      final result = service.evaluate(
        target: target(value: 200),
        analysisAsOf: DateTime(2026, 7, 31),
        meters: [
          PeriodMeterReadingSeries(
            meterId: 'm1',
            unitCode: 'kWh',
            readings: [
              p(DateTime(2026, 6, 30), 100),
              p(DateTime(2026, 7, 31), 150),
            ],
          ),
        ],
      );
      expect(result.standing, ActualVsTargetStanding.belowTarget);
      expect(result.directionLabel, 'Below Target');
      expect(result.directionLabel.toLowerCase(), isNot(contains('saving')));
    });

    test('MTD prorates target — does not compare partial actual to full month',
        () {
      // July has 31 days; as-of Jul 10 => 10/31 of target 310 = 100
      final result = service.evaluate(
        target: target(value: 310),
        analysisAsOf: DateTime(2026, 7, 10),
        meters: [
          PeriodMeterReadingSeries(
            meterId: 'm1',
            unitCode: 'kWh',
            readings: [
              p(DateTime(2026, 6, 30), 0),
              p(DateTime(2026, 7, 10), 100),
            ],
          ),
        ],
      );
      expect(
        result.comparisonMode,
        ActualVsTargetComparisonMode.periodToDateProrated,
      );
      expect(result.effectiveTargetValue, closeTo(100, 0.01));
      expect(result.actualValue, 100);
      expect(result.standing, ActualVsTargetStanding.onTarget);
      expect(result.directionLabel, contains('prorated'));
      expect(result.prorationFactor, closeTo(10 / 31, 0.0001));
    });

    test('no boundary readings → insufficient (no invented periodStart-1)', () {
      final result = service.evaluate(
        target: target(),
        analysisAsOf: DateTime(2026, 7, 31),
        meters: [
          PeriodMeterReadingSeries(
            meterId: 'm1',
            unitCode: 'kWh',
            // Single reading in period with no prior and treated as both
            // first and last — wait, firstInPeriod fallback makes this valid.
            // True insufficient: empty readings.
            readings: const [],
          ),
        ],
      );
      expect(result.isInsufficient, isTrue);
      expect(result.message!.toLowerCase(), contains('boundary'));
    });

    test('first-in-period fallback allowed when no prior reading (mechanical)',
        () {
      // Matches existing periodConsumptionFromEndpoints semantics:
      // previousBefore missing → use firstInPeriod as baseline.
      final result = service.evaluate(
        target: target(value: 50),
        analysisAsOf: DateTime(2026, 7, 31),
        meters: [
          PeriodMeterReadingSeries(
            meterId: 'm1',
            unitCode: 'kWh',
            readings: [
              p(DateTime(2026, 7, 1), 10),
              p(DateTime(2026, 7, 31), 60),
            ],
          ),
        ],
      );
      expect(result.status, ActualVsTargetStatus.ok);
      expect(result.actualValue, 50); // 60-10
      expect(result.standing, ActualVsTargetStanding.onTarget);
    });

    test('single in-period reading uses first-as-baseline (existing semantics)',
        () {
      final result = service.evaluate(
        target: target(value: 50),
        analysisAsOf: DateTime(2026, 7, 31),
        meters: [
          PeriodMeterReadingSeries(
            meterId: 'm1',
            unitCode: 'kWh',
            readings: [p(DateTime(2026, 7, 15), 42)],
          ),
        ],
      );
      // previousBefore=null, first=last=42 → consumption 0 via existing helper.
      expect(result.status, ActualVsTargetStatus.ok);
      expect(result.actualValue, 0);
      expect(result.standing, ActualVsTargetStanding.belowTarget);
    });

    test('unit mismatch → insufficient', () {
      final result = service.evaluate(
        target: target(unit: 'kWh'),
        analysisAsOf: DateTime(2026, 7, 31),
        meters: [
          PeriodMeterReadingSeries(
            meterId: 'm1',
            unitCode: 'm³',
            readings: [
              p(DateTime(2026, 6, 30), 1),
              p(DateTime(2026, 7, 31), 2),
            ],
          ),
        ],
      );
      expect(result.isInsufficient, isTrue);
      expect(result.message!.toLowerCase(), contains('unit'));
    });

    test('annual target supported', () {
      final result = service.evaluate(
        target: target(
          start: DateTime(2026, 1, 1),
          end: DateTime(2026, 12, 31),
          value: 1200,
          periodType: ConservationTargetPeriodType.annual,
        ),
        analysisAsOf: DateTime(2026, 12, 31),
        meters: [
          PeriodMeterReadingSeries(
            meterId: 'm1',
            unitCode: 'kWh',
            readings: [
              p(DateTime(2025, 12, 31), 0),
              p(DateTime(2026, 12, 31), 1000),
            ],
          ),
        ],
      );
      expect(result.periodType, ConservationTargetPeriodType.annual);
      expect(result.standing, ActualVsTargetStanding.belowTarget);
      expect(result.actualValue, 1000);
    });

    test('YTD prorates annual target', () {
      final result = service.evaluate(
        target: target(
          start: DateTime(2026, 1, 1),
          end: DateTime(2026, 12, 31),
          value: 365,
          periodType: ConservationTargetPeriodType.annual,
        ),
        analysisAsOf: DateTime(2026, 1, 10),
        meters: [
          PeriodMeterReadingSeries(
            meterId: 'm1',
            unitCode: 'kWh',
            readings: [
              p(DateTime(2025, 12, 31), 0),
              p(DateTime(2026, 1, 10), 10),
            ],
          ),
        ],
      );
      expect(
        result.comparisonMode,
        ActualVsTargetComparisonMode.periodToDateProrated,
      );
      expect(result.effectiveTargetValue, closeTo(10, 0.01));
      expect(result.standing, ActualVsTargetStanding.onTarget);
    });
  });
}
