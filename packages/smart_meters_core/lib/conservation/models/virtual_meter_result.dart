import '../models/calculation_meta.dart';
import '../../models/enums.dart';

enum VirtualMeterResultStatus { ok, insufficientData }

/// Derived virtual meter result — Residual / Balance Difference, never Leak.
class VirtualMeterResult {
  const VirtualMeterResult({
    required this.status,
    required this.calculationType,
    required this.value,
    required this.unitCode,
    required this.directionLabel,
    required this.completeness,
    required this.confidenceScore,
    required this.periodStart,
    required this.periodEnd,
    required this.calculatedAt,
    required this.meta,
    required this.contributingMeterIds,
    required this.missingMeterIds,
    required this.hierarchyDepth,
    this.parentContribution,
    this.childrenContribution,
    this.expressionSummary,
    this.message,
    this.warnings = const [],
  });

  final VirtualMeterResultStatus status;
  final CalculationType calculationType;
  final double? value;
  final String unitCode;

  /// Human label: Residual / Balance Difference / Sum of children / Insufficient Data.
  final String directionLabel;
  final double completeness;
  final int confidenceScore;
  final DateTime periodStart;
  final DateTime periodEnd;
  final DateTime calculatedAt;
  final CalculationMeta meta;
  final List<String> contributingMeterIds;
  final List<String> missingMeterIds;
  final int hierarchyDepth;
  final double? parentContribution;
  final double? childrenContribution;
  final String? expressionSummary;
  final String? message;
  final List<String> warnings;

  bool get isInsufficient => status == VirtualMeterResultStatus.insufficientData;
  bool get isNegativeResidual =>
      calculationType == CalculationType.parentMinusChildren &&
      value != null &&
      value! < 0;
}

/// Node input for calculator (physical leaf or nested virtual already expanded).
class VirtualMeterContributorInput {
  const VirtualMeterContributorInput({
    required this.meterId,
    required this.consumption,
    required this.hasValidEndpoints,
    required this.completeness,
    required this.confidence,
    required this.unitCode,
    this.readingSpanStart,
    this.readingSpanEnd,
    this.isMissing = false,
  });

  final String meterId;
  final double? consumption;
  final bool hasValidEndpoints;
  final double completeness;
  final int confidence;
  final String unitCode;
  final DateTime? readingSpanStart;
  final DateTime? readingSpanEnd;
  final bool isMissing;
}
