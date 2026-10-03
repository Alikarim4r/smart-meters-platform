import 'package:flutter_test/flutter_test.dart';
import 'package:smart_meters_core/smart_meters_core.dart';

void main() {
  final businessDate = DateTime(2026, 7, 4);

  test('chartPeriodRange weekly spans 7 days', () {
    final range = chartPeriodRange(
      period: ChartPeriod.weekly,
      businessDate: businessDate,
    );
    expect(range.from, DateTime(2026, 6, 28));
    expect(range.to, businessDate);
    expect(range.bucket, ChartBucket.daily);
  });

  test('chartPeriodRange yearly uses yearly buckets', () {
    final range = chartPeriodRange(
      period: ChartPeriod.yearly,
      businessDate: businessDate,
    );
    expect(range.from, DateTime(2022, 1, 1));
    expect(range.bucket, ChartBucket.yearly);
  });

  test('chartBucketWindows monthly covers each month clipped to range', () {
    final windows = chartBucketWindows(
      from: DateTime(2025, 11, 15),
      to: DateTime(2026, 2, 10),
      bucket: ChartBucket.monthly,
    );
    expect(windows.length, 4);
    expect(windows.first.from, DateTime(2025, 11, 15));
    expect(windows.first.to, DateTime(2025, 11, 30));
    expect(windows.last.from, DateTime(2026, 2, 1));
    expect(windows.last.to, DateTime(2026, 2, 10));
  });

  test('chartBucketWindows yearly covers each year clipped to range', () {
    final windows = chartBucketWindows(
      from: DateTime(2022, 6, 1),
      to: DateTime(2024, 3, 1),
      bucket: ChartBucket.yearly,
    );
    expect(windows.length, 3);
    expect(windows[0].from, DateTime(2022, 6, 1));
    expect(windows[0].to, DateTime(2022, 12, 31));
    expect(windows[2].from, DateTime(2024, 1, 1));
    expect(windows[2].to, DateTime(2024, 3, 1));
  });

  test('preferSiteScopedChartScan blocks monthly/yearly full scans', () {
    expect(
      preferSiteScopedChartScan(
        meterCount: 49,
        spanDays: 365,
        bucket: ChartBucket.monthly,
      ),
      isFalse,
    );
    expect(
      preferSiteScopedChartScan(
        meterCount: 49,
        spanDays: 30,
        bucket: ChartBucket.daily,
      ),
      isTrue,
    );
    expect(
      preferSiteScopedChartScan(
        meterCount: 49,
        spanDays: 200,
        bucket: ChartBucket.daily,
      ),
      isFalse,
    );
  });

  test('periodConsumptionFromEndpoints falls back to first-in-period', () {
    expect(
      periodConsumptionFromEndpoints(
        lastInPeriod: 150,
        previousBeforePeriod: 100,
        firstInPeriod: 110,
      ),
      50,
    );
    expect(
      periodConsumptionFromEndpoints(
        lastInPeriod: 150,
        previousBeforePeriod: null,
        firstInPeriod: 100,
      ),
      50,
    );
    expect(
      periodConsumptionFromEndpoints(
        lastInPeriod: 100,
        previousBeforePeriod: null,
        firstInPeriod: 100,
      ),
      0,
    );
    expect(
      periodConsumptionFromEndpoints(
        lastInPeriod: 100,
        previousBeforePeriod: null,
        firstInPeriod: null,
      ),
      0,
    );
  });

  test('aggregateCategoryConsumption groups by category and date', () {
    final range = chartPeriodRange(
      period: ChartPeriod.weekly,
      businessDate: businessDate,
    );
    final series = aggregateCategoryConsumption(
      range: range,
      rows: [
        {
          'reading_date': '2026-07-04',
          'daily_consumption': 10,
          'meters': {
            'category_id': 'cat-water',
            'meter_categories': {'name_en': 'Water', 'base_unit_code': 'm3'},
          },
        },
        {
          'reading_date': '2026-07-04',
          'daily_consumption': 5,
          'meters': {
            'category_id': 'cat-elec',
            'meter_categories': {
              'name_en': 'Electricity',
              'base_unit_code': 'kWh',
            },
          },
        },
      ],
    );

    expect(series.length, 2);
    expect(
      series.firstWhere((s) => s.categoryId == 'cat-water').totalConsumption,
      10,
    );
  });

  test('buildMeterComparison rejects mixed base units', () {
    final range = chartPeriodRange(
      period: ChartPeriod.weekly,
      businessDate: businessDate,
    );
    final result = buildMeterComparison(
      range: range,
      meterIds: ['m1', 'm2'],
      consumptionRows: const [],
      meters: [
        Meter(
          id: 'm1',
          siteId: 's1',
          meterCode: 'A',
          nameEn: 'A',
          nameAr: 'A',
          categoryId: 'c1',
          sourceId: 'src',
          unitId: 'u1',
          category: MeterCategory.water,
          source: MeterSource.other,
          unit: MeterUnit.m3,
          level: MeterLevel.main,
          unitToBaseFactor: 1,
          baseUnit: 'm3',
          meterMultiplier: 1,
          meterKind: MeterKind.physical,
          calculationType: CalculationType.directReading,
          isActive: true,
          includeInDashboard: true,
          sortOrder: 0,
        ),
        Meter(
          id: 'm2',
          siteId: 's1',
          meterCode: 'B',
          nameEn: 'B',
          nameAr: 'B',
          categoryId: 'c1',
          sourceId: 'src',
          unitId: 'u2',
          category: MeterCategory.water,
          source: MeterSource.other,
          unit: MeterUnit.liter,
          level: MeterLevel.main,
          unitToBaseFactor: 0.001,
          baseUnit: 'L',
          meterMultiplier: 1,
          meterKind: MeterKind.physical,
          calculationType: CalculationType.directReading,
          isActive: true,
          includeInDashboard: true,
          sortOrder: 1,
        ),
      ],
    );

    expect(result.canCompare, isFalse);
    expect(result.warningMessage, contains('base units'));
  });

  test('negative daily consumption is treated as zero on charts', () {
    final range = chartPeriodRange(
      period: ChartPeriod.weekly,
      businessDate: businessDate,
    );
    final series = aggregateCategoryConsumption(
      range: range,
      rows: [
        {
          'reading_date': '2026-07-04',
          'daily_consumption': -120.5,
          'meters': {
            'category_id': 'cat-water',
            'meter_categories': {'name_en': 'Water', 'base_unit_code': 'm3'},
          },
        },
        {
          'reading_date': '2026-07-03',
          'daily_consumption': 8,
          'meters': {
            'category_id': 'cat-water',
            'meter_categories': {'name_en': 'Water', 'base_unit_code': 'm3'},
          },
        },
      ],
    );

    expect(series, hasLength(1));
    final byDate = {
      for (final point in series.first.points) point.date: point.value,
    };
    expect(byDate[DateTime(2026, 7, 4)], 0);
    expect(byDate[DateTime(2026, 7, 3)], 8);
    expect(series.first.points.every((p) => p.value >= 0), isTrue);
    expect(nonNegativeConsumption(-1), 0);
    expect(nonNegativeConsumption(3.5), 3.5);
  });

  test('aggregateCopTrend converts units and derives EER from COP', () {
    final range = chartPeriodRange(
      period: ChartPeriod.weekly,
      businessDate: businessDate,
    );
    final points = aggregateCopTrend(
      range: range,
      btuWeights: const {'btu-1': 1},
      electricityWeights: const {'elec-1': 1},
      consumptionRows: [
        {
          'meter_id': 'btu-1',
          'reading_date': '2026-07-04',
          'daily_consumption': 3412.142, // 1 kWh thermal
          'meters': {'base_unit': 'btu'},
        },
        {
          'meter_id': 'elec-1',
          'reading_date': '2026-07-04',
          'daily_consumption': 0.5, // 0.5 kWh electric
          'meters': {'base_unit': 'kwh'},
        },
      ],
    );
    final day = points.firstWhere((p) => p.date == DateTime(2026, 7, 4));
    expect(day.cop, closeTo(2.0, 0.01));
    expect(day.eer, closeTo(2.0 * kCopToEerFactor, 0.01));
  });

  group('coolingToKwh conversion', () {
    test('preserves existing GJ/BTU/MWh behavior', () {
      expect(coolingToKwh(1, 'GJ'), closeTo(277.7777778, 0.001));
      expect(coolingToKwh(1, 'BTU'), closeTo(1 / 3412.142, 0.001));
      expect(coolingToKwh(1, 'MWh'), 1000);
      expect(coolingToKwh(1, 'kWh'), 1);
      expect(coolingToKwh(1, 'kw·h'), 1);
    });

    test('accepts the real DB BTU base unit "kWh thermal" 1:1', () {
      // meters.base_unit for the btu category is 'kWh thermal' (001/006).
      expect(coolingToKwh(42, 'kWh thermal'), 42);
      expect(coolingToKwh(42, 'kwh_thermal'), 42);
      expect(coolingToKwh(42, '  KWH THERMAL '), 42);
    });

    test('ton_hour / rt_hour catalog codes and aliases use the DB factor', () {
      const factor = UnitConversion.tonHourToKwhThermal; // 3.51685 (DB)
      expect(factor, 3.51685);
      for (final code in ['ton_hour', 'rt_hour', 'ton-hour', 'TRH', 'RTh']) {
        expect(coolingToKwh(1, code), closeTo(factor, 1e-12), reason: code);
      }
    });

    test('unknown / null / apparent-energy units return null (no crash)', () {
      expect(coolingToKwh(1, 'unknown'), isNull);
      expect(coolingToKwh(1, ''), isNull);
      expect(coolingToKwh(1, null), isNull);
      expect(coolingToKwh(1, 'kVAh'), isNull);
      expect(coolingToKwh(1, 'm3'), isNull);
    });
  });

  group('electricityToKwh conversion', () {
    test('kWh / MWh / Wh convert; case-insensitive', () {
      expect(electricityToKwh(1, 'kWh'), 1);
      expect(electricityToKwh(1, 'MWH'), 1000);
      expect(electricityToKwh(1000, 'wh'), closeTo(1, 1e-12));
    });

    test('kVAh / thermal / unknown / null never map to kWh', () {
      expect(electricityToKwh(1, 'kVAh'), isNull);
      expect(electricityToKwh(1, 'kvah'), isNull);
      expect(electricityToKwh(1, 'MVAh'), isNull);
      expect(electricityToKwh(1, 'kWh thermal'), isNull);
      expect(electricityToKwh(1, 'bogus'), isNull);
      expect(electricityToKwh(1, null), isNull);
    });
  });

  group('aggregateCopTrend with production-shaped rows', () {
    final range = ChartPeriodRange(
      period: ChartPeriod.weekly,
      from: DateTime(2026, 7, 1),
      to: DateTime(2026, 7, 3),
      bucket: ChartBucket.daily,
    );

    Map<String, dynamic> row(
      String meterId,
      String date,
      Object? consumption, {
      String? baseUnit,
      String? unitCode,
      String? status,
    }) =>
        {
          'meter_id': meterId,
          'reading_date': date,
          'daily_consumption': consumption,
          'consumption_status': ?status,
          'meters': {
            'base_unit': baseUnit,
            'unit_code': unitCode,
          },
        };

    test('BTU meter with base unit "kWh thermal" (ton_hour register) → COP',
        () {
      // Readings are normalized server-side: 100 ton-h × 3.51685 = 351.685.
      final points = aggregateCopTrend(
        range: range,
        btuWeights: const {'chw': 1},
        electricityWeights: const {'chiller': 1},
        consumptionRows: [
          row('chw', '2026-07-01', 351.685,
              baseUnit: 'kWh thermal', unitCode: 'ton_hour'),
          row('chiller', '2026-07-01', 100.0,
              baseUnit: 'kWh', unitCode: 'kwh'),
        ],
      );
      final day = points.firstWhere((p) => p.date == DateTime(2026, 7, 1));
      expect(day.cop, closeTo(3.51685, 1e-9));
      expect(day.btuConsumption, closeTo(351.685, 1e-9));
    });

    test('unknown or null cooling unit → no COP for that bucket, no crash', () {
      final points = aggregateCopTrend(
        range: range,
        btuWeights: const {'chw': 1},
        electricityWeights: const {'chiller': 1},
        consumptionRows: [
          row('chw', '2026-07-01', 300.0, baseUnit: 'furlongs'),
          row('chiller', '2026-07-01', 100.0, baseUnit: 'kWh'),
          row('chw', '2026-07-02', 300.0), // null unit
          row('chiller', '2026-07-02', 100.0, baseUnit: 'kWh'),
          row('chw', '2026-07-03', 300.0, baseUnit: 'kWh thermal'),
          row('chiller', '2026-07-03', 100.0, baseUnit: 'kWh'),
        ],
      );
      final byDate = {for (final p in points) p.date: p};
      expect(byDate[DateTime(2026, 7, 1)]!.cop, isNull);
      expect(byDate[DateTime(2026, 7, 1)]!.btuConsumption, isNull);
      expect(byDate[DateTime(2026, 7, 2)]!.cop, isNull);
      expect(byDate[DateTime(2026, 7, 3)]!.cop, closeTo(3.0, 1e-9));
      expect(averageCopValues(points), closeTo(3.0, 1e-9));
    });

    test('kVAh electricity meter (normalized into kWh base) → no COP', () {
      final points = aggregateCopTrend(
        range: range,
        btuWeights: const {'chw': 1},
        electricityWeights: const {'chiller': 1},
        consumptionRows: [
          row('chw', '2026-07-01', 300.0, baseUnit: 'kWh thermal'),
          row('chiller', '2026-07-01', 100.0,
              baseUnit: 'kWh', unitCode: 'kvah'),
        ],
      );
      expect(points.every((p) => p.cop == null), isTrue);
    });

    test('unverifiable cumulative drop invalidates the bucket', () {
      final points = aggregateCopTrend(
        range: range,
        btuWeights: const {'chw': 1},
        electricityWeights: const {'chiller': 1},
        consumptionRows: [
          row('chw', '2026-07-01', null,
              baseUnit: 'kWh thermal', status: 'reset_or_replacement'),
          row('chiller', '2026-07-01', 100.0, baseUnit: 'kWh'),
          row('chw', '2026-07-02', 20.0,
              baseUnit: 'kWh thermal', status: 'rollover'),
          row('chiller', '2026-07-02', 10.0,
              baseUnit: 'kWh', status: 'normal'),
        ],
      );
      final byDate = {for (final p in points) p.date: p};
      expect(byDate[DateTime(2026, 7, 1)]!.cop, isNull);
      expect(byDate[DateTime(2026, 7, 2)]!.cop, closeTo(2.0, 1e-9));
    });
  });
}
