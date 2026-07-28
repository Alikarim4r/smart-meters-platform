import '../models/chart_models.dart';
import '../models/meter.dart';
import 'chart_period.dart';

/// Consumption for charts is never negative.
///
/// A later reading smaller than an earlier one (meter reset / fault) yields a
/// negative daily delta in the DB — treat that as 0 on charts.
double nonNegativeConsumption(dynamic value) {
  final parsed = _toDouble(value);
  return parsed < 0 ? 0 : parsed;
}

/// Aggregate raw consumption rows into category time series.
List<CategoryConsumptionSeries> aggregateCategoryConsumption({
  required List<Map<String, dynamic>> rows,
  required ChartPeriodRange range,
}) {
  final byCategory = <String, _CategoryAccumulator>{};

  for (final row in rows) {
    final consumption = nonNegativeConsumption(row['daily_consumption']);
    final date = _dateOnlyFromReading(row['reading_date']);
    final from = DateTime(range.from.year, range.from.month, range.from.day);
    final to = DateTime(range.to.year, range.to.month, range.to.day);
    if (date.isBefore(from) || date.isAfter(to)) {
      continue;
    }

    final meterJson = row['meters'];
    if (meterJson is! Map) continue;
    final categoryJson = meterJson['meter_categories'];
    if (categoryJson is! Map) continue;

    final categoryId = meterJson['category_id'] as String? ?? '';
    if (categoryId.isEmpty) continue;

    final categoryName = categoryJson['name_en'] as String? ?? 'Unknown';
    final unitCode = categoryJson['base_unit_code'] as String? ?? '';

    final bucketDate = chartBucketKey(date: date, bucket: range.bucket);
    final acc = byCategory.putIfAbsent(
      categoryId,
      () => _CategoryAccumulator(
        categoryId: categoryId,
        categoryName: categoryName,
        unitCode: unitCode,
      ),
    );
    acc.values[bucketDate] = (acc.values[bucketDate] ?? 0) + consumption;
  }

  final timeline = chartBucketTimeline(range: range);
  return byCategory.values.map((acc) {
    final points = [
      for (final key in timeline)
        TimeSeriesPoint(
          date: key,
          value: nonNegativeConsumption(acc.values[key] ?? 0),
          label: chartBucketLabel(date: key, bucket: range.bucket),
        ),
    ];
    return CategoryConsumptionSeries(
      categoryId: acc.categoryId,
      categoryName: acc.categoryName,
      unitCode: acc.unitCode,
      points: points,
    );
  }).toList()..sort((a, b) => a.categoryName.compareTo(b.categoryName));
}

List<CategoryRankingItem> aggregateMeterRanking({
  required List<Map<String, dynamic>> rows,
  required String categoryId,
}) {
  final totals = <String, _MeterAccumulator>{};

  for (final row in rows) {
    final meterJson = row['meters'];
    if (meterJson is! Map) continue;
    if (meterJson['category_id'] != categoryId) continue;

    final meterId = row['meter_id'] as String;
    final consumption = nonNegativeConsumption(row['daily_consumption']);
    final acc = totals.putIfAbsent(
      meterId,
      () => _MeterAccumulator(
        meterId: meterId,
        meterName: meterJson['name_en'] as String? ?? 'Unknown',
        meterNameAr: meterJson['name_ar'] as String? ?? '',
        meterCode: meterJson['meter_code'] as String? ?? '',
      ),
    );
    acc.total += consumption;
  }

  final ranking =
      totals.values
          .map(
            (acc) => CategoryRankingItem(
              meterId: acc.meterId,
              meterName: acc.meterName,
              meterNameAr: acc.meterNameAr,
              meterCode: acc.meterCode,
              totalConsumption: nonNegativeConsumption(acc.total),
            ),
          )
          .toList()
        ..sort((a, b) => b.totalConsumption.compareTo(a.totalConsumption));
  return ranking;
}

MeterComparisonResult buildMeterComparison({
  required List<Meter> meters,
  required List<String> meterIds,
  required List<Map<String, dynamic>> consumptionRows,
  required ChartPeriodRange range,
}) {
  if (meterIds.length < 2) {
    return const MeterComparisonResult(
      series: [],
      baseUnit: '',
      canCompare: false,
      warningMessage: 'Select at least two meters to compare.',
    );
  }

  final selected = meters.where((m) => meterIds.contains(m.id)).toList();
  if (selected.length < 2) {
    return const MeterComparisonResult(
      series: [],
      baseUnit: '',
      canCompare: false,
      warningMessage: 'Selected meters were not found.',
    );
  }

  final categoryIds = selected.map((m) => m.categoryId).toSet();
  if (categoryIds.length > 1) {
    return const MeterComparisonResult(
      series: [],
      baseUnit: '',
      canCompare: false,
      warningMessage: 'Units cannot be compared safely across categories.',
    );
  }

  final baseUnits = selected
      .map((m) => m.baseUnit)
      .where((u) => u.isNotEmpty)
      .toSet();
  if (baseUnits.length > 1) {
    return MeterComparisonResult(
      series: [],
      baseUnit: '',
      canCompare: false,
      warningMessage:
          'Units cannot be compared safely. Meters use different base units.',
    );
  }

  final baseUnit =
      baseUnits.firstOrNull ??
      selected.first.categoryConfig?.baseUnitCode ??
      '';
  final timeline = chartBucketTimeline(range: range);
  final byMeter = {
    for (final meter in selected) meter.id: <DateTime, double>{},
  };

  for (final row in consumptionRows) {
    final meterId = row['meter_id'] as String;
    if (!byMeter.containsKey(meterId)) continue;
    final date = _dateOnlyFromReading(row['reading_date']);
    if (date.isBefore(range.from) || date.isAfter(range.to)) continue;
    final bucket = chartBucketKey(date: date, bucket: range.bucket);
    byMeter[meterId]![bucket] =
        (byMeter[meterId]![bucket] ?? 0) +
        nonNegativeConsumption(row['daily_consumption']);
  }

  final series = [
    for (final meter in selected)
      MeterComparisonSeries(
        meterId: meter.id,
        meterName: meter.nameEn,
        meterNameAr: meter.nameAr,
        meterCode: meter.meterCode,
        points: [
          for (final key in timeline)
            TimeSeriesPoint(
              date: key,
              value: nonNegativeConsumption(byMeter[meter.id]![key] ?? 0),
              label: chartBucketLabel(date: key, bucket: range.bucket),
            ),
        ],
        periodTotal: byMeter[meter.id]!.values.fold<double>(
          0,
          (s, v) => s + nonNegativeConsumption(v),
        ),
      ),
  ];

  final hasData = series.any((s) => s.points.any((p) => p.value > 0));
  return MeterComparisonResult(
    series: series,
    baseUnit: baseUnit,
    canCompare: true,
    warningMessage: hasData
        ? null
        : 'Not enough readings to calculate consumption for this period.',
  );
}

List<CopTrendPoint> aggregateCopTrend({
  required ChartPeriodRange range,
  required Map<String, double> btuWeights,
  required Map<String, double> electricityWeights,
  required List<Map<String, dynamic>> consumptionRows,
}) {
  final timeline = chartBucketTimeline(range: range);
  final btuByDate = <DateTime, double>{};
  final elecByDate = <DateTime, double>{};

  for (final row in consumptionRows) {
    final meterId = row['meter_id'] as String;
    final date = _dateOnlyFromReading(row['reading_date']);
    if (date.isBefore(range.from) || date.isAfter(range.to)) continue;
    final bucket = chartBucketKey(date: date, bucket: range.bucket);
    final consumption = nonNegativeConsumption(row['daily_consumption']);
    final unitCode = _meterBaseUnitCode(row['meters']);

    final btuWeight = btuWeights[meterId];
    if (btuWeight != null) {
      btuByDate[bucket] = (btuByDate[bucket] ?? 0) +
          coolingToKwh(consumption, unitCode) * btuWeight;
    }
    final elecWeight = electricityWeights[meterId];
    if (elecWeight != null) {
      elecByDate[bucket] = (elecByDate[bucket] ?? 0) +
          electricityToKwh(consumption, unitCode) * elecWeight;
    }
  }

  return [
    for (final key in timeline)
      _copPoint(date: key, btu: btuByDate[key], electricity: elecByDate[key]),
  ];
}

/// Convert cooling energy to kWh thermal for COP/EER.
double coolingToKwh(double value, String? unitCode) {
  switch ((unitCode ?? '').trim().toLowerCase()) {
    case 'gj':
      return value * 277.7777778;
    case 'btu':
      return value / 3412.142;
    case 'mwh':
      return value * 1000;
    case 'kwh':
    case 'kw·h':
      return value;
    default:
      // Unknown cooling unit — treat as already thermal-kWh-compatible.
      return value;
  }
}

/// Convert electric energy to kWh.
double electricityToKwh(double value, String? unitCode) {
  switch ((unitCode ?? '').trim().toLowerCase()) {
    case 'mwh':
      return value * 1000;
    case 'wh':
      return value / 1000;
    case 'kwh':
    case 'kw·h':
      return value;
    default:
      return value;
  }
}

/// EER ≈ COP × 3.412 (dimensionless COP → BTU/Wh).
const kCopToEerFactor = 3.412;

CopTrendPoint _copPoint({
  required DateTime date,
  double? btu,
  double? electricity,
}) {
  if (btu == null || electricity == null || electricity <= 0 || btu <= 0) {
    return CopTrendPoint(
      date: date,
      btuConsumption: btu,
      electricityConsumption: electricity,
    );
  }
  final cop = btu / electricity;
  return CopTrendPoint(
    date: date,
    btuConsumption: btu,
    electricityConsumption: electricity,
    cop: cop,
    eer: cop * kCopToEerFactor,
  );
}

String? _meterBaseUnitCode(Object? metersMeta) {
  if (metersMeta is! Map) return null;
  final map = Map<String, dynamic>.from(metersMeta);
  final direct = map['base_unit'] as String?;
  if (direct != null && direct.trim().isNotEmpty) return direct;
  final categories = map['meter_categories'];
  if (categories is Map) {
    final code = categories['base_unit_code'] as String?;
    if (code != null && code.trim().isNotEmpty) return code;
  }
  return null;
}

double? averageCopValues(List<CopTrendPoint> points) {
  final values = points
      .map((p) => p.cop)
      .whereType<double>()
      .where((v) => v > 0)
      .toList();
  if (values.isEmpty) return null;
  return values.reduce((a, b) => a + b) / values.length;
}

double? averageEerValues(List<CopTrendPoint> points) {
  final values = points
      .map((p) => p.eer)
      .whereType<double>()
      .where((v) => v > 0)
      .toList();
  if (values.isEmpty) return null;
  return values.reduce((a, b) => a + b) / values.length;
}

double? minCopValues(List<CopTrendPoint> points) {
  final values = points
      .map((p) => p.cop)
      .whereType<double>()
      .where((v) => v > 0)
      .toList();
  if (values.isEmpty) return null;
  return values.reduce((a, b) => a < b ? a : b);
}

double? maxCopValues(List<CopTrendPoint> points) {
  final values = points
      .map((p) => p.cop)
      .whereType<double>()
      .where((v) => v > 0)
      .toList();
  if (values.isEmpty) return null;
  return values.reduce((a, b) => a > b ? a : b);
}

class _CategoryAccumulator {
  _CategoryAccumulator({
    required this.categoryId,
    required this.categoryName,
    required this.unitCode,
  });

  final String categoryId;
  final String categoryName;
  final String unitCode;
  final Map<DateTime, double> values = {};
}

class _MeterAccumulator {
  _MeterAccumulator({
    required this.meterId,
    required this.meterName,
    required this.meterNameAr,
    required this.meterCode,
  });

  final String meterId;
  final String meterName;
  final String meterNameAr;
  final String meterCode;
  double total = 0;
}

double _toDouble(dynamic value) {
  if (value is num) return value.toDouble();
  if (value == null) return 0;
  return double.parse(value as String);
}

/// Calendar date only — avoids UTC/local mismatches from `DateTime.parse`.
DateTime _dateOnlyFromReading(dynamic value) {
  if (value is DateTime) {
    return DateTime(value.year, value.month, value.day);
  }
  final raw = value as String;
  final parts = raw.split('T').first.split('-');
  return DateTime(
    int.parse(parts[0]),
    int.parse(parts[1]),
    int.parse(parts[2]),
  );
}
