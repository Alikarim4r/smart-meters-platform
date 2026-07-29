import 'calculation_meta.dart';

enum PeriodComparisonType {
  previousPeriod,
  samePeriodLastYear,
}

enum PeriodComparisonStatus {
  ok,
  insufficientData,
}

/// Result of a Previous-Period or YoY comparison (read-only derived).
class PeriodComparisonResult {
  const PeriodComparisonResult({
    required this.type,
    required this.status,
    required this.unitCode,
    required this.currentValue,
    required this.comparisonValue,
    required this.absoluteDifference,
    required this.percentageDifference,
    required this.percentageDisplay,
    required this.directionLabel,
    required this.currentCompleteness,
    required this.comparisonCompleteness,
    required this.confidenceScore,
    required this.currentPeriodConfidence,
    required this.comparisonPeriodConfidence,
    required this.periodStart,
    required this.periodEnd,
    required this.comparisonPeriodStart,
    required this.comparisonPeriodEnd,
    required this.calculatedAt,
    required this.calculationMethod,
    required this.meta,
    this.siteId,
    this.message,
  });

  final PeriodComparisonType type;
  final PeriodComparisonStatus status;
  final String unitCode;
  final String? siteId;

  final double? currentValue;
  final double? comparisonValue;
  final double? absoluteDifference;

  /// Null when percentage is undefined (e.g. previous = 0 and current ≠ 0).
  final double? percentageDifference;
  final String percentageDisplay;
  final String directionLabel;

  final double currentCompleteness;
  final double comparisonCompleteness;

  /// Conservative combined confidence: min(current, comparison).
  final int confidenceScore;
  final int currentPeriodConfidence;
  final int comparisonPeriodConfidence;

  final DateTime periodStart;
  final DateTime periodEnd;
  final DateTime comparisonPeriodStart;
  final DateTime comparisonPeriodEnd;
  final DateTime calculatedAt;
  final String calculationMethod;
  final CalculationMeta meta;
  final String? message;

  bool get isInsufficient => status == PeriodComparisonStatus.insufficientData;

  factory PeriodComparisonResult.insufficient({
    required PeriodComparisonType type,
    required String unitCode,
    required DateTime currentStart,
    required DateTime currentEnd,
    required DateTime comparisonStart,
    required DateTime comparisonEnd,
    required String reason,
    required DateTime calculatedAt,
    String? siteId,
    double currentCompleteness = 0,
    double comparisonCompleteness = 0,
    int confidenceScore = 0,
  }) {
    final meta = CalculationMeta(
      calculationMethod: 'conservation_period_compare_v1',
      periodStart: currentStart,
      periodEnd: currentEnd,
      dataCompleteness: currentCompleteness,
      confidenceScore: confidenceScore,
      calculatedAt: calculatedAt,
      notes: [reason],
    );
    return PeriodComparisonResult(
      type: type,
      status: PeriodComparisonStatus.insufficientData,
      unitCode: unitCode,
      siteId: siteId,
      currentValue: null,
      comparisonValue: null,
      absoluteDifference: null,
      percentageDifference: null,
      percentageDisplay: 'N/A',
      directionLabel: 'Insufficient Data',
      currentCompleteness: currentCompleteness,
      comparisonCompleteness: comparisonCompleteness,
      confidenceScore: confidenceScore,
      currentPeriodConfidence: confidenceScore,
      comparisonPeriodConfidence: confidenceScore,
      periodStart: currentStart,
      periodEnd: currentEnd,
      comparisonPeriodStart: comparisonStart,
      comparisonPeriodEnd: comparisonEnd,
      calculatedAt: calculatedAt,
      calculationMethod: 'conservation_period_compare_v1',
      meta: meta,
      message: reason,
    );
  }
}
