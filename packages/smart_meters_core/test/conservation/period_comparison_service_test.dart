import 'package:flutter_test/flutter_test.dart';
import 'package:smart_meters_core/conservation/conservation.dart';

PeriodReadingPoint p(DateTime d, double v) => PeriodReadingPoint(date: d, value: v);

PeriodMeterReadingSeries meter({
  required List<PeriodReadingPoint> readings,
  String unit = 'kWh',
  double multiplier = 1,
  int? expectedIntervalDays,
  List<DateTime> corrections = const [],
}) {
  return PeriodMeterReadingSeries(
    meterId: 'm1',
    unitCode: unit,
    readings: readings,
    meterMultiplier: multiplier,
    expectedIntervalDays: expectedIntervalDays,
    correctionDates: corrections,
  );
}

void main() {
  const service = PeriodComparisonService();
  final fixedNow = DateTime.utc(2026, 7, 29, 12);

  group('period windows', () {
    test('previous period equal length (Jul 1–29 → Jun 2–30)', () {
      final prev = previousPeriodOfEqualLength(
        DateTime(2026, 7, 1),
        DateTime(2026, 7, 29),
      );
      expect(prev.start, DateTime(2026, 6, 2));
      expect(prev.end, DateTime(2026, 6, 30));
      expect(prev.dayCount, 29);
      expect(
        inclusiveDayCount(DateTime(2026, 7, 1), DateTime(2026, 7, 29)),
        29,
      );
    });

    test('different month lengths stay equal day count', () {
      // Mar 1–31 (31 days) → previous Jan 29–Feb 28 2026 (31 days, non-leap)
      final prev = previousPeriodOfEqualLength(
        DateTime(2026, 3, 1),
        DateTime(2026, 3, 31),
      );
      expect(prev.dayCount, 31);
      expect(prev.end, DateTime(2026, 2, 28));
      expect(prev.start, DateTime(2026, 1, 29));
    });

    test('YoY same calendar span, not full month', () {
      final yoy = samePeriodLastYear(
        DateTime(2026, 7, 1),
        DateTime(2026, 7, 29),
      );
      expect(yoy.start, DateTime(2025, 7, 1));
      expect(yoy.end, DateTime(2025, 7, 29));
    });

    test('leap year Feb 29 maps to Feb 28 previous year', () {
      expect(shiftCalendarYears(DateTime(2024, 2, 29), -1), DateTime(2023, 2, 28));
      final yoy = samePeriodLastYear(
        DateTime(2024, 2, 1),
        DateTime(2024, 2, 29),
      );
      expect(yoy.start, DateTime(2023, 2, 1));
      expect(yoy.end, DateTime(2023, 2, 28));
    });
  });

  group('PeriodComparisonService', () {
    test('Example A: current > previous', () {
      // Current Jul 1–10: 200→300 = 100
      // Previous Jun 21–30: 100→150 = 50
      final result = service.compareMeters(
        type: PeriodComparisonType.previousPeriod,
        currentStart: DateTime(2026, 7, 1),
        currentEnd: DateTime(2026, 7, 10),
        unitCode: 'kWh',
        calculatedAt: fixedNow,
        meters: [
          meter(
            readings: [
              p(DateTime(2026, 6, 20), 100),
              p(DateTime(2026, 6, 30), 150),
              p(DateTime(2026, 7, 10), 300),
            ],
          ),
        ],
      );
      expect(result.status, PeriodComparisonStatus.ok);
      expect(result.currentValue, 150); // 300-150
      expect(result.comparisonValue, 50); // 150-100
      expect(result.absoluteDifference, 100);
      expect(result.percentageDifference, closeTo(200, 0.01));
      expect(result.directionLabel.toLowerCase(), contains('higher'));
      expect(result.directionLabel.toLowerCase(), isNot(contains('saving')));
      expect(result.comparisonPeriodStart, DateTime(2026, 6, 21));
      expect(result.comparisonPeriodEnd, DateTime(2026, 6, 30));
    });

    test('Example B: current < previous', () {
      final result = service.compareMeters(
        type: PeriodComparisonType.previousPeriod,
        currentStart: DateTime(2026, 7, 1),
        currentEnd: DateTime(2026, 7, 10),
        unitCode: 'm³',
        calculatedAt: fixedNow,
        meters: [
          meter(
            unit: 'm³',
            readings: [
              p(DateTime(2026, 6, 20), 100),
              p(DateTime(2026, 6, 30), 200),
              p(DateTime(2026, 7, 10), 220),
            ],
          ),
        ],
      );
      expect(result.currentValue, 20);
      expect(result.comparisonValue, 100);
      expect(result.absoluteDifference, -80);
      expect(result.percentageDifference, closeTo(-80, 0.01));
      expect(result.directionLabel.toLowerCase(), contains('lower'));
      expect(result.directionLabel.toLowerCase(), contains('decrease'));
      expect(result.directionLabel.toLowerCase(), isNot(contains('saving')));
    });

    test('Example C: insufficient historical data', () {
      final result = service.compareMeters(
        type: PeriodComparisonType.previousPeriod,
        currentStart: DateTime(2026, 7, 1),
        currentEnd: DateTime(2026, 7, 10),
        unitCode: 'kWh',
        calculatedAt: fixedNow,
        meters: [
          meter(
            readings: [
              p(DateTime(2026, 7, 5), 100),
              p(DateTime(2026, 7, 10), 140),
            ],
          ),
        ],
      );
      expect(result.isInsufficient, isTrue);
      expect(result.directionLabel, 'Insufficient Data');
      expect(result.percentageDisplay, 'N/A');
      expect(result.message!.toLowerCase(), contains('comparison'));
    });

    test('equal values → no significant change', () {
      final result = service.compareMeters(
        type: PeriodComparisonType.previousPeriod,
        currentStart: DateTime(2026, 7, 1),
        currentEnd: DateTime(2026, 7, 10),
        unitCode: 'kWh',
        calculatedAt: fixedNow,
        meters: [
          meter(
            readings: [
              p(DateTime(2026, 6, 20), 50),
              p(DateTime(2026, 6, 30), 100),
              p(DateTime(2026, 7, 10), 150),
            ],
          ),
        ],
      );
      expect(result.currentValue, 50);
      expect(result.comparisonValue, 50);
      expect(result.absoluteDifference, 0);
      expect(result.percentageDifference, 0);
      expect(result.directionLabel, 'No significant change');
    });

    test('previous value = 0 → percentage N/A, absolute kept', () {
      final result = service.compareSnapshots(
        type: PeriodComparisonType.previousPeriod,
        currentStart: DateTime(2026, 7, 1),
        currentEnd: DateTime(2026, 7, 10),
        unitCode: 'kWh',
        calculatedAt: fixedNow,
        current: PeriodConsumptionSnapshot(
          periodStart: DateTime(2026, 7, 1),
          periodEnd: DateTime(2026, 7, 10),
          value: 40,
          hasValidEndpoints: true,
          readingCount: 2,
          completeness: 1,
          confidenceScore: 100,
        ),
        comparison: PeriodConsumptionSnapshot(
          periodStart: DateTime(2026, 6, 21),
          periodEnd: DateTime(2026, 6, 30),
          value: 0,
          hasValidEndpoints: true,
          readingCount: 2,
          completeness: 1,
          confidenceScore: 100,
        ),
      );
      expect(result.percentageDifference, isNull);
      expect(result.percentageDisplay, 'N/A');
      expect(result.absoluteDifference, 40);
      expect(result.status, PeriodComparisonStatus.ok);
    });

    test('current = 0 with weak completeness → insufficient, not -100%', () {
      final result = service.compareSnapshots(
        type: PeriodComparisonType.previousPeriod,
        currentStart: DateTime(2026, 7, 1),
        currentEnd: DateTime(2026, 7, 10),
        unitCode: 'kWh',
        calculatedAt: fixedNow,
        current: PeriodConsumptionSnapshot(
          periodStart: DateTime(2026, 7, 1),
          periodEnd: DateTime(2026, 7, 10),
          value: 0,
          hasValidEndpoints: true,
          readingCount: 1,
          completeness: 0.6,
          confidenceScore: 40,
        ),
        comparison: PeriodConsumptionSnapshot(
          periodStart: DateTime(2026, 6, 21),
          periodEnd: DateTime(2026, 6, 30),
          value: 80,
          hasValidEndpoints: true,
          readingCount: 2,
          completeness: 1,
          confidenceScore: 95,
        ),
      );
      expect(result.isInsufficient, isTrue);
      expect(result.percentageDisplay, 'N/A');
      expect(result.message!.toLowerCase(), contains('low confidence'));
    });

    test('current = 0 with complete strong data → -100% decrease', () {
      final result = service.compareSnapshots(
        type: PeriodComparisonType.previousPeriod,
        currentStart: DateTime(2026, 7, 1),
        currentEnd: DateTime(2026, 7, 10),
        unitCode: 'kWh',
        calculatedAt: fixedNow,
        current: PeriodConsumptionSnapshot(
          periodStart: DateTime(2026, 7, 1),
          periodEnd: DateTime(2026, 7, 10),
          value: 0,
          hasValidEndpoints: true,
          readingCount: 2,
          completeness: 1,
          confidenceScore: 90,
        ),
        comparison: PeriodConsumptionSnapshot(
          periodStart: DateTime(2026, 6, 21),
          periodEnd: DateTime(2026, 6, 30),
          value: 50,
          hasValidEndpoints: true,
          readingCount: 2,
          completeness: 1,
          confidenceScore: 90,
        ),
      );
      expect(result.status, PeriodComparisonStatus.ok);
      expect(result.percentageDifference, -100);
      expect(result.directionLabel.toLowerCase(), contains('decrease'));
    });

    test('both values = 0 with complete data → 0%', () {
      final result = service.compareSnapshots(
        type: PeriodComparisonType.previousPeriod,
        currentStart: DateTime(2026, 7, 1),
        currentEnd: DateTime(2026, 7, 10),
        unitCode: 'kWh',
        calculatedAt: fixedNow,
        current: PeriodConsumptionSnapshot(
          periodStart: DateTime(2026, 7, 1),
          periodEnd: DateTime(2026, 7, 10),
          value: 0,
          hasValidEndpoints: true,
          readingCount: 2,
          completeness: 1,
          confidenceScore: 100,
        ),
        comparison: PeriodConsumptionSnapshot(
          periodStart: DateTime(2026, 6, 21),
          periodEnd: DateTime(2026, 6, 30),
          value: 0,
          hasValidEndpoints: true,
          readingCount: 2,
          completeness: 1,
          confidenceScore: 100,
        ),
      );
      expect(result.percentageDifference, 0);
      expect(result.percentageDisplay, '0%');
      expect(result.directionLabel, 'No significant change');
    });

    test('missing current data → insufficient', () {
      final result = service.compareMeters(
        type: PeriodComparisonType.previousPeriod,
        currentStart: DateTime(2026, 7, 1),
        currentEnd: DateTime(2026, 7, 10),
        unitCode: 'kWh',
        calculatedAt: fixedNow,
        meters: [
          meter(
            readings: [
              p(DateTime(2026, 6, 20), 10),
              p(DateTime(2026, 6, 30), 40),
            ],
          ),
        ],
      );
      expect(result.isInsufficient, isTrue);
    });

    test('partial current period via expected interval → insufficient', () {
      final result = service.compareMeters(
        type: PeriodComparisonType.previousPeriod,
        currentStart: DateTime(2026, 7, 1),
        currentEnd: DateTime(2026, 7, 28),
        unitCode: 'kWh',
        calculatedAt: fixedNow,
        meters: [
          meter(
            expectedIntervalDays: 7,
            readings: [
              p(DateTime(2026, 5, 30), 0),
              p(DateTime(2026, 6, 7), 10),
              p(DateTime(2026, 6, 14), 20),
              p(DateTime(2026, 6, 21), 30),
              p(DateTime(2026, 6, 28), 40),
              // Only one reading in current 28-day window → low completeness
              p(DateTime(2026, 7, 28), 50),
            ],
          ),
        ],
      );
      expect(result.currentCompleteness, lessThan(0.5));
      expect(result.isInsufficient, isTrue);
    });

    test('Same Period Last Year', () {
      final result = service.compareMeters(
        type: PeriodComparisonType.samePeriodLastYear,
        currentStart: DateTime(2026, 7, 1),
        currentEnd: DateTime(2026, 7, 29),
        unitCode: 'kWh',
        calculatedAt: fixedNow,
        meters: [
          meter(
            readings: [
              p(DateTime(2025, 6, 30), 100),
              p(DateTime(2025, 7, 29), 200),
              p(DateTime(2026, 6, 30), 300),
              p(DateTime(2026, 7, 29), 450),
            ],
          ),
        ],
      );
      expect(result.comparisonPeriodStart, DateTime(2025, 7, 1));
      expect(result.comparisonPeriodEnd, DateTime(2025, 7, 29));
      expect(result.currentValue, 150);
      expect(result.comparisonValue, 100);
      expect(result.directionLabel.toLowerCase(), contains('last year'));
    });

    test('corrections in a period reduce that period confidence', () {
      final result = service.compareMeters(
        type: PeriodComparisonType.previousPeriod,
        currentStart: DateTime(2026, 7, 1),
        currentEnd: DateTime(2026, 7, 10),
        unitCode: 'kWh',
        calculatedAt: fixedNow,
        meters: [
          meter(
            corrections: [DateTime(2026, 7, 5)],
            readings: [
              p(DateTime(2026, 6, 20), 100),
              p(DateTime(2026, 6, 30), 150),
              p(DateTime(2026, 7, 10), 200),
            ],
          ),
        ],
      );
      expect(result.currentPeriodConfidence, lessThan(100));
      expect(result.comparisonPeriodConfidence, 100);
      expect(
        result.confidenceScore,
        result.currentPeriodConfidence,
      ); // min
    });

    test('combined confidence uses min of both periods', () {
      final result = service.compareSnapshots(
        type: PeriodComparisonType.previousPeriod,
        currentStart: DateTime(2026, 7, 1),
        currentEnd: DateTime(2026, 7, 10),
        unitCode: 'kWh',
        calculatedAt: fixedNow,
        current: PeriodConsumptionSnapshot(
          periodStart: DateTime(2026, 7, 1),
          periodEnd: DateTime(2026, 7, 10),
          value: 100,
          hasValidEndpoints: true,
          readingCount: 2,
          completeness: 1,
          confidenceScore: 95,
        ),
        comparison: PeriodConsumptionSnapshot(
          periodStart: DateTime(2026, 6, 21),
          periodEnd: DateTime(2026, 6, 30),
          value: 80,
          hasValidEndpoints: true,
          readingCount: 2,
          completeness: 1,
          confidenceScore: 50,
        ),
      );
      expect(result.confidenceScore, 50);
      expect(result.meta.notes.any((n) => n.contains('combined_confidence')), isTrue);
    });

    test('meter with only one historical reading → insufficient', () {
      final result = service.compareMeters(
        type: PeriodComparisonType.previousPeriod,
        currentStart: DateTime(2026, 7, 1),
        currentEnd: DateTime(2026, 7, 10),
        unitCode: 'kWh',
        calculatedAt: fixedNow,
        meters: [
          meter(readings: [p(DateTime(2026, 7, 10), 42)]),
        ],
      );
      expect(result.isInsufficient, isTrue);
    });

    test('multiplier > 1 applies to normalized consumption', () {
      final result = service.compareMeters(
        type: PeriodComparisonType.previousPeriod,
        currentStart: DateTime(2026, 7, 1),
        currentEnd: DateTime(2026, 7, 10),
        unitCode: 'kWh',
        calculatedAt: fixedNow,
        meters: [
          meter(
            multiplier: 10,
            readings: [
              p(DateTime(2026, 6, 20), 1),
              p(DateTime(2026, 6, 30), 2),
              p(DateTime(2026, 7, 10), 5),
            ],
          ),
        ],
      );
      // normalized: 10, 20, 50 → prev 10, current 30
      expect(result.comparisonValue, 10);
      expect(result.currentValue, 30);
    });

    test('multiple readings in period use endpoints only', () {
      final result = service.compareMeters(
        type: PeriodComparisonType.previousPeriod,
        currentStart: DateTime(2026, 7, 1),
        currentEnd: DateTime(2026, 7, 10),
        unitCode: 'kWh',
        calculatedAt: fixedNow,
        meters: [
          meter(
            readings: [
              p(DateTime(2026, 6, 20), 0),
              p(DateTime(2026, 6, 25), 5),
              p(DateTime(2026, 6, 30), 10),
              p(DateTime(2026, 7, 2), 12),
              p(DateTime(2026, 7, 5), 15),
              p(DateTime(2026, 7, 10), 20),
            ],
          ),
        ],
      );
      expect(result.comparisonValue, 10); // 10-0
      expect(result.currentValue, 10); // 20-10
    });

    test('no valid consumption endpoints → insufficient', () {
      final result = service.compareMeters(
        type: PeriodComparisonType.previousPeriod,
        currentStart: DateTime(2026, 7, 1),
        currentEnd: DateTime(2026, 7, 10),
        unitCode: 'kWh',
        calculatedAt: fixedNow,
        meters: const [],
      );
      expect(result.isInsufficient, isTrue);
    });

    test('incompatible units rejected', () {
      final result = service.compareMeters(
        type: PeriodComparisonType.previousPeriod,
        currentStart: DateTime(2026, 7, 1),
        currentEnd: DateTime(2026, 7, 10),
        unitCode: 'kWh',
        calculatedAt: fixedNow,
        meters: [
          meter(unit: 'kWh', readings: [p(DateTime(2026, 7, 10), 1)]),
          meter(unit: 'm³', readings: [p(DateTime(2026, 7, 10), 1)]),
        ],
      );
      expect(result.isInsufficient, isTrue);
      expect(result.message!.toLowerCase(), contains('unit'));
    });

    test('result carries required metadata fields', () {
      final result = service.compareMeters(
        type: PeriodComparisonType.previousPeriod,
        currentStart: DateTime(2026, 7, 1),
        currentEnd: DateTime(2026, 7, 10),
        unitCode: 'BTU',
        calculatedAt: fixedNow,
        meters: [
          meter(
            unit: 'BTU',
            readings: [
              p(DateTime(2026, 6, 20), 100),
              p(DateTime(2026, 6, 30), 150),
              p(DateTime(2026, 7, 10), 200),
            ],
          ),
        ],
      );
      expect(result.calculationMethod, isNotEmpty);
      expect(result.periodStart, isNotNull);
      expect(result.periodEnd, isNotNull);
      expect(result.comparisonPeriodStart, isNotNull);
      expect(result.comparisonPeriodEnd, isNotNull);
      expect(result.calculatedAt, fixedNow);
      expect(result.meta.confidenceScore, result.confidenceScore);
    });
  });
}
