import '../domain/action_lifecycle.dart';
import '../domain/mv_lifecycle.dart';
import '../domain/opportunity_lifecycle.dart';
import '../models/conservation_baseline.dart';

/// Configurable gates before Verified Saving may be recorded.
///
/// Conservative defaults — mechanical meters + manual readings.
class SavingsVerificationGates {
  const SavingsVerificationGates({
    this.minCompleteness = 0.80,
    this.minConfidence = 70,
    this.minFollowUpDays = 7,
    this.requireApprovedBaseline = true,
    this.requireActionCompleted = true,
    this.requireOpportunityMonitoringOrResolved = true,
    this.forbidPendingCriticalDq = true,
    this.requireHumanVerifier = true,
  });

  /// Minimum post-period data completeness (0–1).
  final double minCompleteness;

  /// Minimum confidence (0–100).
  final int minConfidence;

  /// Minimum inclusive post/follow-up window length in days.
  final int minFollowUpDays;

  /// Baseline must be approved (bound id immutable; status still checked).
  final bool requireApprovedBaseline;

  /// Linked action (when present) must be completed.
  final bool requireActionCompleted;

  /// Opportunity must be monitoring or resolved.
  final bool requireOpportunityMonitoringOrResolved;

  /// Block when unresolved Data Quality findings make savings unverifiable.
  final bool forbidPendingCriticalDq;

  /// Verified Saving requires a human verifier identity.
  final bool requireHumanVerifier;

  static const standard = SavingsVerificationGates();
}

/// Outcome of evaluating savings verification gates.
class GateEvaluationResult {
  const GateEvaluationResult({
    required this.passed,
    required this.reasons,
  });

  final bool passed;
  final List<String> reasons;

  factory GateEvaluationResult.pass() =>
      const GateEvaluationResult(passed: true, reasons: []);

  factory GateEvaluationResult.fail(List<String> reasons) =>
      GateEvaluationResult(passed: false, reasons: reasons);
}

/// Pure gate checks shared by verification service and UI preview.
class SavingsVerificationGateEvaluator {
  const SavingsVerificationGateEvaluator({
    this.gates = SavingsVerificationGates.standard,
  });

  final SavingsVerificationGates gates;

  GateEvaluationResult evaluate({
    required MvStatus currentStatus,
    required double? dataCompleteness,
    required int confidenceScore,
    required int followUpDays,
    required ConservationBaselineStatus? baselineStatus,
    required ActionStatus? actionStatus,
    required OpportunityStatus? opportunityStatus,
    required bool hasPendingCriticalDq,
    required String? verifiedBy,
    required bool actorMayVerify,
  }) {
    final reasons = <String>[];

    if (currentStatus == MvStatus.draft) {
      reasons.add(
        'draft → verified not allowed; estimate + verification_pending first',
      );
    } else if (currentStatus != MvStatus.verificationPending) {
      reasons.add(
        'Verified Saving requires status verification_pending '
        '(current: ${currentStatus.dbValue})',
      );
    }

    final completeness = dataCompleteness ?? 0;
    if (completeness < gates.minCompleteness) {
      reasons.add(
        'Data Completeness ${(completeness * 100).toStringAsFixed(0)}% is below '
        'threshold ${(gates.minCompleteness * 100).toStringAsFixed(0)}%',
      );
    }

    if (confidenceScore < gates.minConfidence) {
      reasons.add(
        'Confidence $confidenceScore is below threshold ${gates.minConfidence}',
      );
    }

    if (followUpDays < gates.minFollowUpDays) {
      reasons.add(
        'Follow-up / post period $followUpDays days is below '
        'minimum ${gates.minFollowUpDays} days',
      );
    }

    if (gates.requireApprovedBaseline) {
      if (baselineStatus == null) {
        reasons.add('Approved baseline required (none bound)');
      } else if (baselineStatus != ConservationBaselineStatus.approved &&
          baselineStatus != ConservationBaselineStatus.superseded) {
        // Bound baseline may later be superseded; historical bind is OK if it
        // was approved when calculated. Draft/archived baselines block verify.
        reasons.add(
          'Baseline status ${baselineStatus.dbValue} is not approved '
          '(requireApprovedBaseline)',
        );
      }
    }

    if (gates.requireActionCompleted && actionStatus != null) {
      if (actionStatus != ActionStatus.completed) {
        reasons.add(
          'Action must be completed before Verified Saving '
          '(status: ${actionStatus.dbValue})',
        );
      }
    }

    if (gates.requireOpportunityMonitoringOrResolved &&
        opportunityStatus != null) {
      if (opportunityStatus != OpportunityStatus.monitoring &&
          opportunityStatus != OpportunityStatus.resolved) {
        reasons.add(
          'Opportunity must be monitoring or resolved '
          '(status: ${opportunityStatus.dbValue})',
        );
      }
    }

    if (gates.forbidPendingCriticalDq && hasPendingCriticalDq) {
      reasons.add('Unresolved blocking Data Quality findings');
    }

    if (gates.requireHumanVerifier) {
      if (verifiedBy == null || verifiedBy.trim().isEmpty) {
        reasons.add('Verified Saving requires human verifiedBy');
      }
      if (!actorMayVerify) {
        reasons.add(
          'Verified Saving requires site_admin / super_admin / platform_owner '
          '(technician cannot verify)',
        );
      }
    }

    if (reasons.isEmpty) return GateEvaluationResult.pass();
    return GateEvaluationResult.fail(reasons);
  }
}
