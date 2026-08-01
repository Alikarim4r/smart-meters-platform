enum ForecastMethod {
  runRate('run_rate'),
  seasonalAverage('seasonal_average'),
  rollingAverage('rolling_average'),
  simpleTrend('simple_trend'),
  normalizedTrend('normalized_trend'),
  insufficientHistory('insufficient_history');

  const ForecastMethod(this.dbValue);
  final String dbValue;

  static ForecastMethod fromDb(String value) => ForecastMethod.values.firstWhere(
        (e) => e.dbValue == value,
        orElse: () => ForecastMethod.insufficientHistory,
      );
}

enum ForecastHorizon {
  monthEnd('month_end'),
  annualTarget('annual_target'),
  annualConsumption('annual_consumption'),
  custom('custom');

  const ForecastHorizon(this.dbValue);
  final String dbValue;

  static ForecastHorizon fromDb(String value) => ForecastHorizon.values.firstWhere(
        (e) => e.dbValue == value,
        orElse: () => ForecastHorizon.monthEnd,
      );
}

abstract final class ForecastLabels {
  static const insufficientHistory = 'Insufficient History';
}
