/// Anomaly severity — not a confirmed fault classification.
enum AnomalySeverity {
  info,
  low,
  medium,
  high,
  critical,
}

/// Deterministic consumption / COP anomaly kinds (labels ≠ Fault).
enum AnomalyKind {
  unusualIncrease,
  unusualDecrease,
  repeatedHigh,
  repeatedLow,
  suddenChange,
  aboveTarget,
  farAboveBaseline,
  copDeclining,
}

/// Consumption anomaly / unusual consumption result.
///
/// Status labels: Requires Review / Unusual Consumption — never Confirmed Fault.
class ConsumptionAnomalyResult {
  const ConsumptionAnomalyResult({
    required this.detected,
    required this.kind,
    required this.severity,
    required this.statusLabel,
    required this.reason,
    required this.confidenceScore,
    required this.completeness,
    required this.periodStart,
    required this.periodEnd,
    required this.referenceMethod,
    required this.contributingMeterIds,
    required this.warnings,
    this.currentValue,
    this.referenceValue,
    this.percentageChange,
    this.investigationNotes = const [],
  });

  final bool detected;
  final AnomalyKind? kind;
  final AnomalySeverity severity;
  final String statusLabel;
  final String reason;
  final int confidenceScore;
  final double completeness;
  final DateTime periodStart;
  final DateTime periodEnd;
  final String referenceMethod;
  final List<String> contributingMeterIds;
  final List<String> warnings;
  final double? currentValue;
  final double? referenceValue;
  final double? percentageChange;

  /// Possible investigation directions — never automatic root cause.
  final List<String> investigationNotes;

  static const requiresReview = 'Requires Review';
  static const unusualConsumption = 'Unusual Consumption';
  static const noAnomaly = 'No Anomaly Detected';
  static const insufficientData = 'Insufficient Data';

  /// Forbidden auto label — never use as statusLabel.
  static const forbiddenConfirmedFault = 'Confirmed Fault';
}
