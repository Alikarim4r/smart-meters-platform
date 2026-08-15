import '../models/calculation_meta.dart';
import '../models/conservation_baseline.dart';

enum ActualVsBaselineStatus { ok, insufficientData }

enum ActualVsBaselineStanding {
  aboveBaseline,
  belowBaseline,
  onBaseline,
  insufficientData,
}

/// Actual vs Baseline — gap is Above/Below Baseline, never Saving.
class ActualVsBaselineResult {
  const ActualVsBaselineResult({
    required this.status,
    required this.standing,
    required this.actualValue,
    required this.baselineValue,
    required this.absoluteVariance,
    required this.percentageVariance,
    required this.directionLabel,
    required this.unitCode,
    required this.completeness,
    required this.confidenceScore,
    required this.actualCompleteness,
    required this.actualConfidence,
    required this.baselineCompleteness,
    required this.baselineConfidence,
    required this.periodStart,
    required this.periodEnd,
    required this.analysisAsOf,
    required this.baselineVersion,
    required this.baselineId,
    required this.calculationMethod,
    required this.calculatedAt,
    required this.meta,
    this.siteId,
    this.message,
  });

  final ActualVsBaselineStatus status;
  final ActualVsBaselineStanding standing;
  final double? actualValue;
  final double baselineValue;
  final double? absoluteVariance;
  final double? percentageVariance;
  final String directionLabel;
  final String unitCode;
  final double completeness;
  final int confidenceScore;
  final double actualCompleteness;
  final int actualConfidence;
  final double baselineCompleteness;
  final int baselineConfidence;
  final DateTime periodStart;
  final DateTime periodEnd;
  final DateTime analysisAsOf;
  final int baselineVersion;
  final String baselineId;
  final BaselineCalculationMethod calculationMethod;
  final DateTime calculatedAt;
  final CalculationMeta meta;
  final String? siteId;
  final String? message;

  bool get isInsufficient => status == ActualVsBaselineStatus.insufficientData;
}
