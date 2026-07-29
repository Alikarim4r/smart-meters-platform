import '../models/conservation_baseline.dart';

/// Configurable approval gates for baselines (not buried in UI).
///
/// Conservative P1D defaults — mechanical meters + manual readings.
class BaselineApprovalGates {
  const BaselineApprovalGates({
    this.minCompleteness = 0.80,
    this.minConfidence = 70,
    this.requireExactPrePeriodBoundary = true,
    this.allowCustomFixedWithoutReadings = true,
  });

  /// Minimum data completeness (0–1) to approve reading-derived baselines.
  final double minCompleteness;

  /// Minimum confidence (0–100) to approve.
  final int minConfidence;

  /// When true, first-in-period fallback blocks approval.
  final bool requireExactPrePeriodBoundary;

  /// custom_fixed may be approved without meter endpoints when true.
  final bool allowCustomFixedWithoutReadings;

  static const standard = BaselineApprovalGates();
}

/// Outcome of evaluating whether a draft may be approved.
class BaselineApprovalGateResult {
  const BaselineApprovalGateResult({
    required this.allowed,
    required this.reasons,
  });

  final bool allowed;
  final List<String> reasons;

  factory BaselineApprovalGateResult.ok() =>
      const BaselineApprovalGateResult(allowed: true, reasons: []);

  factory BaselineApprovalGateResult.blocked(List<String> reasons) =>
      BaselineApprovalGateResult(allowed: false, reasons: reasons);
}

/// Pure gate checks shared by approval service and UI preview.
class BaselineApprovalGateEvaluator {
  const BaselineApprovalGateEvaluator({
    this.gates = BaselineApprovalGates.standard,
  });

  final BaselineApprovalGates gates;

  BaselineApprovalGateResult evaluate({
    required ConservationBaselineStatus status,
    required BaselineCalculationMethod method,
    required double? baselineValue,
    required double? completeness,
    required int? confidence,
    required BaselineBoundaryQuality? boundaryQuality,
    required DateTime referenceStart,
    required DateTime referenceEnd,
    required String unitCode,
    required ConservationBaselineScopeType scopeType,
    String? scopeId,
    bool unitMismatch = false,
    bool crossSiteScope = false,
    bool hasCriticalDataQualityFindings = false,
  }) {
    final reasons = <String>[];

    if (status != ConservationBaselineStatus.draft) {
      reasons.add('Only draft baselines can be approved.');
    }
    if (referenceEnd.isBefore(referenceStart)) {
      reasons.add('Invalid reference period (end before start).');
    }
    if (unitCode.trim().isEmpty) {
      reasons.add('Missing unit_code.');
    }
    if (scopeType != ConservationBaselineScopeType.site &&
        (scopeId == null || scopeId.isEmpty)) {
      reasons.add('Missing valid scope_id for ${scopeType.dbValue} scope.');
    }
    if (crossSiteScope) {
      reasons.add('Cross-site scope rejected.');
    }
    if (unitMismatch) {
      reasons.add('Unit mismatch between meters and baseline unit.');
    }
    if (hasCriticalDataQualityFindings) {
      reasons.add('Unresolved critical Data Quality findings.');
    }
    if (baselineValue == null || baselineValue.isNaN || baselineValue < 0) {
      reasons.add('Baseline value is not computable with confidence.');
    }

    final isCustom = method == BaselineCalculationMethod.customFixed;
    if (!isCustom || !gates.allowCustomFixedWithoutReadings) {
      final c = completeness ?? 0;
      if (c < gates.minCompleteness) {
        reasons.add(
          'Data Completeness ${(c * 100).toStringAsFixed(0)}% is below '
          'approval threshold ${(gates.minCompleteness * 100).toStringAsFixed(0)}%.',
        );
      }
      final conf = confidence ?? 0;
      if (conf < gates.minConfidence) {
        reasons.add(
          'Confidence $conf is below approval threshold ${gates.minConfidence}.',
        );
      }
      if (gates.requireExactPrePeriodBoundary) {
        if (boundaryQuality == BaselineBoundaryQuality.insufficient ||
            boundaryQuality == null) {
          reasons.add(
            'Insufficient boundary readings for reference period '
            '(do not invent periodStart-1).',
          );
        } else if (boundaryQuality ==
            BaselineBoundaryQuality.firstInPeriodFallback) {
          reasons.add(
            'first-in-period fallback is not acceptable for formal approval; '
            'require exact/pre-period boundary readings.',
          );
        }
      }
    } else {
      // custom_fixed: still require positive value and period validity.
      if (baselineValue != null && baselineValue <= 0) {
        reasons.add('custom_fixed baseline_value must be > 0.');
      }
    }

    if (reasons.isEmpty) return BaselineApprovalGateResult.ok();
    return BaselineApprovalGateResult.blocked(reasons);
  }
}
