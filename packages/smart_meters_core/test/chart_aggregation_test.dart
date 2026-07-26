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
}
