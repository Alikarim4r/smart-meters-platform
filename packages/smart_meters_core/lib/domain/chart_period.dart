import '../models/chart_models.dart';

enum ChartBucket { daily, monthly, yearly }

/// Resolved date range and bucket strategy for a chart period.
class ChartPeriodRange {
  const ChartPeriodRange({
    required this.period,
    required this.from,
    required this.to,
    required this.bucket,
  });

  final ChartPeriod period;
  final DateTime from;
  final DateTime to;
  final ChartBucket bucket;

  @override
  bool operator ==(Object other) =>
      other is ChartPeriodRange &&
      other.period == period &&
      other.from == from &&
      other.to == to &&
      other.bucket == bucket;

  @override
  int get hashCode => Object.hash(period, from, to, bucket);
}

ChartPeriodRange chartPeriodRange({
  required ChartPeriod period,
  required DateTime businessDate,
}) {
  switch (period) {
    case ChartPeriod.weekly:
      return ChartPeriodRange(
        period: period,
        from: businessDate.subtract(const Duration(days: 6)),
        to: businessDate,
        bucket: ChartBucket.daily,
      );
    case ChartPeriod.monthly:
      return ChartPeriodRange(
        period: period,
        from: DateTime(businessDate.year, businessDate.month, 1),
        to: businessDate,
        bucket: ChartBucket.daily,
      );
    case ChartPeriod.last30Days:
      return ChartPeriodRange(
        period: period,
        from: businessDate.subtract(const Duration(days: 30)),
        to: businessDate,
        bucket: ChartBucket.daily,
      );
    case ChartPeriod.yearly:
      return ChartPeriodRange(
        period: period,
        from: DateTime(businessDate.year - 4, 1, 1),
        to: businessDate,
        bucket: ChartBucket.yearly,
      );
  }
}

DateTime chartBucketKey({required DateTime date, required ChartBucket bucket}) {
  switch (bucket) {
    case ChartBucket.daily:
      return DateTime(date.year, date.month, date.day);
    case ChartBucket.monthly:
      return DateTime(date.year, date.month, 1);
    case ChartBucket.yearly:
      return DateTime(date.year, 1, 1);
  }
}

String chartBucketLabel({required DateTime date, required ChartBucket bucket}) {
  switch (bucket) {
    case ChartBucket.daily:
      return '${date.month}/${date.day}';
    case ChartBucket.monthly:
      const months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      return '${months[date.month - 1]} \'${(date.year % 100).toString().padLeft(2, '0')}';
    case ChartBucket.yearly:
      return '${date.year}';
  }
}

List<DateTime> chartBucketTimeline({required ChartPeriodRange range}) {
  final keys = <DateTime>[];
  switch (range.bucket) {
    case ChartBucket.daily:
      var cursor = range.from;
      while (!cursor.isAfter(range.to)) {
        keys.add(DateTime(cursor.year, cursor.month, cursor.day));
        cursor = cursor.add(const Duration(days: 1));
      }
    case ChartBucket.monthly:
      var cursor = DateTime(range.from.year, range.from.month, 1);
      final end = DateTime(range.to.year, range.to.month, 1);
      while (!cursor.isAfter(end)) {
        keys.add(cursor);
        final nextMonth = cursor.month == 12 ? 1 : cursor.month + 1;
        final nextYear = cursor.month == 12 ? cursor.year + 1 : cursor.year;
        cursor = DateTime(nextYear, nextMonth, 1);
      }
    case ChartBucket.yearly:
      for (var year = range.from.year; year <= range.to.year; year++) {
        keys.add(DateTime(year, 1, 1));
      }
  }
  return keys;
}

String formatChartAxisDate(DateTime date, ChartBucket bucket) {
  return chartBucketLabel(date: date, bucket: bucket);
}

String formatChartValue(double value) {
  if (value >= 1000000) {
    return '${(value / 1000000).toStringAsFixed(1)}M';
  }
  if (value >= 1000) {
    return '${(value / 1000).toStringAsFixed(1)}k';
  }
  if (value == value.roundToDouble()) {
    return value.toStringAsFixed(0);
  }
  return value.toStringAsFixed(1);
}

/// Period consumption for cumulative meters from endpoints.
///
/// Prefer [previousBeforePeriod] (reading just before the window). When missing
/// (e.g. history pruned), fall back to [firstInPeriod] so a single year/month
/// with data still shows YTD / MTD consumption instead of all zeros.
double periodConsumptionFromEndpoints({
  required double lastInPeriod,
  double? previousBeforePeriod,
  double? firstInPeriod,
}) {
  final baseline = previousBeforePeriod ?? firstInPeriod;
  if (baseline == null) return 0;
  final delta = lastInPeriod - baseline;
  return delta < 0 ? 0.0 : delta;
}

/// Inclusive [from]–[to] windows for each month/year bucket in a chart range.
List<({DateTime from, DateTime to})> chartBucketWindows({
  required DateTime from,
  required DateTime to,
  required ChartBucket bucket,
}) {
  switch (bucket) {
    case ChartBucket.daily:
      return [(from: from, to: to)];
    case ChartBucket.monthly:
      final windows = <({DateTime from, DateTime to})>[];
      var cursor = DateTime(from.year, from.month, 1);
      final lastMonth = DateTime(to.year, to.month, 1);
      while (!cursor.isAfter(lastMonth)) {
        final monthStart = cursor;
        final nextMonth = cursor.month == 12
            ? DateTime(cursor.year + 1, 1, 1)
            : DateTime(cursor.year, cursor.month + 1, 1);
        final monthEnd = nextMonth.subtract(const Duration(days: 1));
        final windowFrom = monthStart.isBefore(from) ? from : monthStart;
        final windowTo = monthEnd.isAfter(to) ? to : monthEnd;
        if (!windowFrom.isAfter(windowTo)) {
          windows.add((from: windowFrom, to: windowTo));
        }
        cursor = nextMonth;
      }
      return windows;
    case ChartBucket.yearly:
      final windows = <({DateTime from, DateTime to})>[];
      for (var year = from.year; year <= to.year; year++) {
        final yearStart = DateTime(year, 1, 1);
        final yearEnd = DateTime(year, 12, 31);
        final windowFrom = yearStart.isBefore(from) ? from : yearStart;
        final windowTo = yearEnd.isAfter(to) ? to : yearEnd;
        if (!windowFrom.isAfter(windowTo)) {
          windows.add((from: windowFrom, to: windowTo));
        }
      }
      return windows;
  }
}

/// Whether a full site-scoped daily scan is safe for the chart request.
bool preferSiteScopedChartScan({
  required int meterCount,
  required int spanDays,
  ChartBucket? bucket,
}) {
  if (bucket == ChartBucket.monthly || bucket == ChartBucket.yearly) {
    // Monthly/yearly charts use per-bucket latest-reading fetches instead.
    return false;
  }
  if (spanDays <= 45) return true;
  return meterCount <= 60 && spanDays <= 120;
}
