/// Chart time window for dashboard monitoring.
enum ChartPeriod { weekly, monthly, last30Days, yearly }

extension ChartPeriodLabel on ChartPeriod {
  String get label => switch (this) {
    ChartPeriod.weekly => 'Weekly',
    ChartPeriod.monthly => 'Monthly',
    ChartPeriod.last30Days => 'Last 31 Days',
    ChartPeriod.yearly => 'Yearly',
  };
}

/// Single point on a consumption or COP trend chart.
class TimeSeriesPoint {
  const TimeSeriesPoint({required this.date, required this.value, this.label});

  final DateTime date;
  final double value;
  final String? label;
}

/// Consumption trend for one category over time.
class CategoryConsumptionSeries {
  const CategoryConsumptionSeries({
    required this.categoryId,
    required this.categoryName,
    required this.unitCode,
    required this.points,
  });

  final String categoryId;
  final String categoryName;
  final String unitCode;
  final List<TimeSeriesPoint> points;

  double get totalConsumption =>
      points.fold<double>(0, (sum, point) => sum + point.value);

  bool get hasData => points.isNotEmpty;
}

/// Site-wide consumption grouped by category.
class SiteConsumptionTrend {
  const SiteConsumptionTrend({required this.series, this.emptyMessage});

  final List<CategoryConsumptionSeries> series;
  final String? emptyMessage;

  bool get hasData => series.any((item) => item.hasData);
}

/// Meter ranking by total consumption in a period.
class CategoryRankingItem {
  const CategoryRankingItem({
    required this.meterId,
    required this.meterName,
    required this.meterCode,
    required this.totalConsumption,
    this.meterNameAr = '',
  });

  final String meterId;
  final String meterName;
  final String meterNameAr;
  final String meterCode;
  final double totalConsumption;
}

/// One meter line in a comparison chart.
class MeterComparisonSeries {
  const MeterComparisonSeries({
    required this.meterId,
    required this.meterName,
    required this.meterCode,
    required this.points,
    required this.periodTotal,
    this.meterNameAr = '',
  });

  final String meterId;
  final String meterName;
  final String meterNameAr;
  final String meterCode;
  final List<TimeSeriesPoint> points;
  final double periodTotal;
}

/// Multi-meter comparison result with unit safety checks.
class MeterComparisonResult {
  const MeterComparisonResult({
    required this.series,
    required this.baseUnit,
    required this.canCompare,
    this.warningMessage,
  });

  final List<MeterComparisonSeries> series;
  final String baseUnit;
  final bool canCompare;
  final String? warningMessage;

  bool get hasData => canCompare && series.any((s) => s.points.isNotEmpty);
}

/// COP value for a single day.
class CopTrendPoint {
  const CopTrendPoint({
    required this.date,
    this.cop,
    this.eer,
    this.btuConsumption,
    this.electricityConsumption,
  });

  final DateTime date;
  /// Coefficient of Performance (cooling kWh / electric kWh).
  final double? cop;
  /// Energy Efficiency Ratio ≈ COP × 3.412 (BTU/h per Watt).
  final double? eer;
  final double? btuConsumption;
  final double? electricityConsumption;
}

/// COP trend for a configured group.
class CopTrendResult {
  const CopTrendResult({
    required this.copGroupId,
    required this.copGroupName,
    required this.points,
    required this.btuMeterCount,
    required this.electricityMeterCount,
    this.averageCop,
    this.minCop,
    this.maxCop,
    this.averageEer,
    this.emptyMessage,
  });

  final String copGroupId;
  final String copGroupName;
  final List<CopTrendPoint> points;
  final int btuMeterCount;
  final int electricityMeterCount;
  final double? averageCop;
  final double? minCop;
  final double? maxCop;
  final double? averageEer;
  final String? emptyMessage;

  bool get hasData => points.any((point) => point.cop != null);

  bool get hasRequiredMeters => btuMeterCount > 0 && electricityMeterCount > 0;
}

/// Category-level chart bundle for the Categories tab.
class CategoryChartBundle {
  const CategoryChartBundle({
    required this.categoryId,
    required this.categoryName,
    required this.unitCode,
    required this.trend,
    required this.ranking,
    required this.submittedToday,
    required this.pendingToday,
    required this.meterCount,
    this.latestReadingAt,
  });

  final String categoryId;
  final String categoryName;
  final String unitCode;
  final CategoryConsumptionSeries trend;
  final List<CategoryRankingItem> ranking;
  final int submittedToday;
  final int pendingToday;
  final int meterCount;
  final DateTime? latestReadingAt;
}
