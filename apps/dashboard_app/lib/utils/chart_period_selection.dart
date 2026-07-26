import 'package:smart_meters_core/smart_meters_core.dart';

/// Chart comparison windows available in analytics.
enum UtilityChartPeriodKind {
  /// Last 31 days — daily buckets (inclusive of today).
  last30Days,

  /// Last 12 months — monthly buckets for month-to-month comparison.
  twelveMonths,

  /// Last 5 calendar years — yearly buckets for year-to-year comparison.
  fiveYears,
}

/// Selected chart period (no double-tap / rolling toggle).
class UtilityChartPeriodState {
  const UtilityChartPeriodState({
    required this.kind,
    this.preferChipOverCustomRange = false,
  });

  final UtilityChartPeriodKind kind;

  /// When true, period chips win over a custom date-picker range for charts.
  final bool preferChipOverCustomRange;

  UtilityChartPeriodState copyWith({
    UtilityChartPeriodKind? kind,
    bool? preferChipOverCustomRange,
  }) {
    return UtilityChartPeriodState(
      kind: kind ?? this.kind,
      preferChipOverCustomRange:
          preferChipOverCustomRange ?? this.preferChipOverCustomRange,
    );
  }

  String get label => switch (kind) {
        UtilityChartPeriodKind.last30Days => 'Last 31 days',
        UtilityChartPeriodKind.twelveMonths => '12 months',
        UtilityChartPeriodKind.fiveYears => '5 years',
      };

  /// Select a period. Re-tapping the same kind still prefers chips over custom.
  UtilityChartPeriodState selectKind(UtilityChartPeriodKind tapped) {
    if (kind == tapped && preferChipOverCustomRange) return this;
    return UtilityChartPeriodState(
      kind: tapped,
      preferChipOverCustomRange: true,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is UtilityChartPeriodState &&
      kind == other.kind &&
      preferChipOverCustomRange == other.preferChipOverCustomRange;

  @override
  int get hashCode => Object.hash(kind, preferChipOverCustomRange);
}

DateTime _normalize(DateTime date) =>
    DateTime(date.year, date.month, date.day);

/// Saturday–Friday week containing [anchorDate].
({DateTime from, DateTime to}) saturdayFridayWeekContaining(DateTime anchorDate) {
  final day = _normalize(anchorDate);
  final daysSinceSaturday = (day.weekday + 1) % 7;
  final start = day.subtract(Duration(days: daysSinceSaturday));
  final end = start.add(const Duration(days: 6));
  return (from: start, to: end);
}

DateTime monthsBefore(DateTime day, int monthsBack) {
  var year = day.year;
  var month = day.month - monthsBack;
  while (month <= 0) {
    month += 12;
    year -= 1;
  }
  return DateTime(year, month, 1);
}

/// Resolves chart date range for dashboard utility analytics.
ChartPeriodRange resolveUtilityChartPeriodRange({
  required UtilityChartPeriodState state,
  required DateTime anchorDate,
}) {
  final day = _normalize(anchorDate);

  switch (state.kind) {
    case UtilityChartPeriodKind.last30Days:
      return ChartPeriodRange(
        period: ChartPeriod.last30Days,
        from: day.subtract(const Duration(days: 30)),
        to: day,
        bucket: ChartBucket.daily,
      );
    case UtilityChartPeriodKind.twelveMonths:
      return ChartPeriodRange(
        period: ChartPeriod.monthly,
        from: monthsBefore(day, 11),
        to: day,
        bucket: ChartBucket.monthly,
      );
    case UtilityChartPeriodKind.fiveYears:
      return ChartPeriodRange(
        period: ChartPeriod.yearly,
        from: DateTime(day.year - 4, 1, 1),
        to: day,
        bucket: ChartBucket.yearly,
      );
  }
}

/// Maps to legacy [ChartPeriod] for report export compatibility.
ChartPeriod legacyChartPeriodForState(UtilityChartPeriodState state) {
  return switch (state.kind) {
    UtilityChartPeriodKind.last30Days => ChartPeriod.last30Days,
    UtilityChartPeriodKind.twelveMonths => ChartPeriod.monthly,
    UtilityChartPeriodKind.fiveYears => ChartPeriod.yearly,
  };
}
