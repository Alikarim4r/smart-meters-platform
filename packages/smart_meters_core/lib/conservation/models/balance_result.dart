import '../domain/reading_alignment.dart';
import 'balance_classification.dart';

enum BalanceResultStatus { ok, insufficientData }

/// Main − Σ children Balance Difference result.
///
/// Direction labels are restricted to Balance Difference / Unaccounted
/// Consumption / Residual. Never auto-labels Leak / Leakage / Water Loss /
/// Waste / Saving.
class BalanceResult {
  const BalanceResult({
    required this.calculationMethod,
    required this.periodStart,
    required this.periodEnd,
    required this.mainMeterId,
    required this.childMeterIds,
    required this.mainConsumption,
    required this.childrenConsumption,
    required this.balanceDifference,
    required this.balancePercentage,
    required this.dataCompleteness,
    required this.confidenceScore,
    required this.alignmentStatus,
    required this.missingMeterIds,
    required this.calculatedAt,
    required this.warnings,
    required this.utilityCode,
    required this.unitCode,
    required this.status,
    required this.reviewStatus,
    required this.directionLabel,
    required this.isNegative,
    this.balanceGroupId,
    this.humanClassification,
    this.message,
  });

  static const method = 'conservation_balance_v1';

  final String calculationMethod;
  final DateTime periodStart;
  final DateTime periodEnd;
  final String mainMeterId;
  final List<String> childMeterIds;
  final double? mainConsumption;
  final double? childrenConsumption;

  /// Main − Σ children. Null when insufficient data.
  final double? balanceDifference;

  /// (diff / main) * 100 when main > 0; otherwise null (N/A).
  final double? balancePercentage;

  final double dataCompleteness;
  final int confidenceScore;
  final ReadingAlignmentStatus alignmentStatus;
  final List<String> missingMeterIds;
  final DateTime calculatedAt;
  final List<String> warnings;
  final String utilityCode;
  final String unitCode;
  final BalanceResultStatus status;

  /// e.g. "Requires Review" / "OK".
  final String reviewStatus;

  /// Balance Difference / Unaccounted Consumption / Residual / Insufficient Data.
  final String directionLabel;

  final bool isNegative;
  final String? balanceGroupId;

  /// Optional human-reviewed classification — never auto Confirmed Leak.
  final BalanceClassificationType? humanClassification;
  final String? message;

  bool get isInsufficient => status == BalanceResultStatus.insufficientData;
}
