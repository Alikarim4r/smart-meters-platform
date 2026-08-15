import '../models/calculation_meta.dart';
import '../models/conservation_target.dart';

enum ActualVsTargetStatus { ok, insufficientData }

enum ActualVsTargetStanding {
  aboveTarget,
  belowTarget,
  onTarget,
  insufficientData,
}

enum ActualVsTargetComparisonMode {
  /// Full target period closed (or analysis covers full period).
  fullPeriod,

  /// In-progress period: actual vs **prorated** target (MTD / YTD).
  periodToDateProrated,
}

/// Actual vs Target result — gap is Above/Below Target, never Saving.
class ActualVsTargetResult {
  const ActualVsTargetResult({
    required this.status,
    required this.standing,
    required this.comparisonMode,
    required this.actualValue,
    required this.targetValue,
    required this.effectiveTargetValue,
    required this.absoluteDifference,
    required this.percentageOfTarget,
    required this.directionLabel,
    required this.unitCode,
    required this.completeness,
    required this.confidenceScore,
    required this.periodStart,
    required this.periodEnd,
    required this.analysisAsOf,
    required this.targetVersion,
    required this.targetId,
    required this.periodType,
    required this.calculationMethod,
    required this.calculatedAt,
    required this.meta,
    this.siteId,
    this.message,
    this.prorationFactor,
  });

  final ActualVsTargetStatus status;
  final ActualVsTargetStanding standing;
  final ActualVsTargetComparisonMode comparisonMode;
  final double? actualValue;
  final double targetValue;

  /// Full target, or prorated target when [comparisonMode] is period-to-date.
  final double effectiveTargetValue;
  final double? absoluteDifference;
  final double? percentageOfTarget;
  final String directionLabel;
  final String unitCode;
  final double completeness;
  final int confidenceScore;
  final DateTime periodStart;
  final DateTime periodEnd;
  final DateTime analysisAsOf;
  final int targetVersion;
  final String targetId;
  final ConservationTargetPeriodType periodType;
  final String calculationMethod;
  final DateTime calculatedAt;
  final CalculationMeta meta;
  final String? siteId;
  final String? message;
  final double? prorationFactor;

  bool get isInsufficient => status == ActualVsTargetStatus.insufficientData;
}
