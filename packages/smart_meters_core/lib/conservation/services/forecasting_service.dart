import 'dart:math' as math;

import '../domain/forecast_methods.dart';

/// Explainable periodic forecasting. Insufficient history → no invented number.
class ForecastingService {
  const ForecastingService();

  static const minHistoryRunRate = 3;
  static const minHistorySeasonal = 6;

  ForecastComputation forecast({
    required String siteId,
    required String utilityType,
    required ForecastHorizon horizon,
    required ForecastMethod preferredMethod,
    required List<double> historyPeriods,
    double? annualTarget,
    double? tariffRate,
    String? budgetCurrency,
    bool usesNormalized = false,
  }) {
    final n = historyPeriods.length;
    final warnings = <String>[];

    if (n < minHistoryRunRate ||
        preferredMethod == ForecastMethod.insufficientHistory) {
      return ForecastComputation.insufficient(
        siteId: siteId,
        utilityType: utilityType,
        horizon: horizon,
        historyLength: n,
        usesNormalized: usesNormalized,
      );
    }

    if (preferredMethod == ForecastMethod.seasonalAverage &&
        n < minHistorySeasonal) {
      warnings.add('seasonal_fallback_to_run_rate');
    }

    final method = (preferredMethod == ForecastMethod.seasonalAverage &&
            n < minHistorySeasonal)
        ? ForecastMethod.runRate
        : preferredMethod;

    late final double expected;
    double? low;
    double? high;
    String? seasonality;

    switch (method) {
      case ForecastMethod.runRate:
        expected = _mean(historyPeriods);
        final spread = _std(historyPeriods);
        low = expected - spread;
        high = expected + spread;
      case ForecastMethod.rollingAverage:
        final window = historyPeriods.length >= 3
            ? historyPeriods.sublist(historyPeriods.length - 3)
            : historyPeriods;
        expected = _mean(window);
        low = expected * 0.9;
        high = expected * 1.1;
      case ForecastMethod.seasonalAverage:
        expected = _mean(historyPeriods);
        seasonality = 'simple_period_average';
        low = expected * 0.85;
        high = expected * 1.15;
      case ForecastMethod.simpleTrend:
      case ForecastMethod.normalizedTrend:
        expected = _trendNext(historyPeriods);
        low = expected * 0.88;
        high = expected * 1.12;
        if (method == ForecastMethod.normalizedTrend && !usesNormalized) {
          warnings.add('normalized_trend_without_normalized_input');
        }
      case ForecastMethod.insufficientHistory:
        return ForecastComputation.insufficient(
          siteId: siteId,
          utilityType: utilityType,
          horizon: horizon,
          historyLength: n,
          usesNormalized: usesNormalized,
        );
    }

    late final double projected;
    if (horizon == ForecastHorizon.annualConsumption ||
        horizon == ForecastHorizon.annualTarget) {
      projected = expected * 12;
      low = (low ?? expected) * 12;
      high = (high ?? expected) * 12;
    } else {
      projected = expected;
    }

    double? exceedance;
    if (annualTarget != null) {
      exceedance = projected - annualTarget;
    }

    double? budgetImpact;
    String? currency;
    if (tariffRate == null) {
      warnings.add('budget_impact_na_missing_tariff');
    } else if (exceedance != null && exceedance > 0) {
      budgetImpact = exceedance * tariffRate;
      currency = budgetCurrency ?? 'QAR';
    }

    final confidence = n >= 12
        ? 'high'
        : n >= 6
            ? 'medium'
            : 'low';

    return ForecastComputation(
      siteId: siteId,
      utilityType: utilityType,
      horizon: horizon,
      method: method,
      historyLength: n,
      expectedValue: projected,
      expectedLow: low,
      expectedHigh: high,
      targetValue: annualTarget,
      expectedTargetExceedance: exceedance,
      expectedBudgetImpact: budgetImpact,
      budgetCurrency: currency,
      confidence: confidence,
      seasonalityHandling: seasonality,
      usesNormalized: usesNormalized,
      status: 'computed',
      warnings: warnings,
      lineage: {
        'method': method.dbValue,
        'history_length': n,
        'horizon': horizon.dbValue,
        'uses_normalized': usesNormalized,
      },
    );
  }

  static double _mean(List<double> xs) =>
      xs.reduce((a, b) => a + b) / xs.length;

  static double _std(List<double> xs) {
    if (xs.length < 2) return 0;
    final m = _mean(xs);
    final v = xs.map((x) => (x - m) * (x - m)).reduce((a, b) => a + b) /
        (xs.length - 1);
    return math.sqrt(v);
  }

  static double _trendNext(List<double> xs) {
    if (xs.length < 2) return xs.first;
    final n = xs.length;
    var sumX = 0.0, sumY = 0.0, sumXY = 0.0, sumXX = 0.0;
    for (var i = 0; i < n; i++) {
      final x = i.toDouble();
      final y = xs[i];
      sumX += x;
      sumY += y;
      sumXY += x * y;
      sumXX += x * x;
    }
    final den = n * sumXX - sumX * sumX;
    if (den == 0) return _mean(xs);
    final slope = (n * sumXY - sumX * sumY) / den;
    final intercept = (sumY - slope * sumX) / n;
    return intercept + slope * n;
  }
}

class ForecastComputation {
  const ForecastComputation({
    required this.siteId,
    required this.utilityType,
    required this.horizon,
    required this.method,
    required this.historyLength,
    required this.confidence,
    required this.status,
    required this.warnings,
    required this.lineage,
    this.expectedValue,
    this.expectedLow,
    this.expectedHigh,
    this.targetValue,
    this.expectedTargetExceedance,
    this.expectedBudgetImpact,
    this.budgetCurrency,
    this.seasonalityHandling,
    this.usesNormalized = false,
  });

  final String siteId;
  final String utilityType;
  final ForecastHorizon horizon;
  final ForecastMethod method;
  final int historyLength;
  final double? expectedValue;
  final double? expectedLow;
  final double? expectedHigh;
  final double? targetValue;
  final double? expectedTargetExceedance;
  final double? expectedBudgetImpact;
  final String? budgetCurrency;
  final String confidence;
  final String? seasonalityHandling;
  final bool usesNormalized;
  final String status;
  final List<String> warnings;
  final Map<String, dynamic> lineage;

  bool get isInsufficientHistory => status == 'insufficient_history';

  factory ForecastComputation.insufficient({
    required String siteId,
    required String utilityType,
    required ForecastHorizon horizon,
    required int historyLength,
    required bool usesNormalized,
  }) {
    return ForecastComputation(
      siteId: siteId,
      utilityType: utilityType,
      horizon: horizon,
      method: ForecastMethod.insufficientHistory,
      historyLength: historyLength,
      expectedValue: null,
      confidence: 'insufficient',
      status: 'insufficient_history',
      usesNormalized: usesNormalized,
      warnings: const [ForecastLabels.insufficientHistory],
      lineage: {
        'method': ForecastMethod.insufficientHistory.dbValue,
        'history_length': historyLength,
      },
    );
  }
}
