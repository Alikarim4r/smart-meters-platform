import '../domain/action_lifecycle.dart';
import '../domain/double_count_rules.dart';
import '../domain/mv_lifecycle.dart';
import '../domain/opportunity_lifecycle.dart';
import '../domain/savings_verification_gates.dart';
import '../models/conservation_baseline.dart';
import '../models/measurement_verification.dart';
import '../models/utility_tariff.dart';
import 'cost_roi_service.dart';
import 'savings_estimation_service.dart';

/// Orchestrates Estimated → verification_pending → Verified Saving.
///
/// ## Rules
///
/// - Potential Excess ≠ Estimated Saving ≠ Verified Saving
/// - No draft → verified
/// - Verified only after gates + human site_admin/super/owner
/// - Technician cannot verify ([ConservationAuthorityPolicy])
/// - Negative outcome → no positive verified saving (store 0)
/// - Zero verified saving allowed when complete
/// - Baseline id binding stays on the historical record
class SavingsVerificationService {
  const SavingsVerificationService({
    this.gates = SavingsVerificationGates.standard,
    this.estimation = const SavingsEstimationService(),
    this.costRoi = const CostRoiService(),
  });

  final SavingsVerificationGates gates;
  final SavingsEstimationService estimation;
  final CostRoiService costRoi;

  GateEvaluationResult evaluateGates({
    required MvStatus currentStatus,
    required double? dataCompleteness,
    required int confidenceScore,
    required int followUpDays,
    required ConservationBaselineStatus? baselineStatus,
    required ActionStatus? actionStatus,
    required OpportunityStatus? opportunityStatus,
    required bool hasPendingCriticalDq,
    required String? verifiedBy,
    required String? actorRole,
  }) {
    return SavingsVerificationGateEvaluator(gates: gates).evaluate(
      currentStatus: currentStatus,
      dataCompleteness: dataCompleteness,
      confidenceScore: confidenceScore,
      followUpDays: followUpDays,
      baselineStatus: baselineStatus,
      actionStatus: actionStatus,
      opportunityStatus: opportunityStatus,
      hasPendingCriticalDq: hasPendingCriticalDq,
      verifiedBy: verifiedBy,
      actorMayVerify: ConservationAuthorityPolicy.canVerifySaving(actorRole),
    );
  }

  /// Apply estimation onto a draft/estimated record (pure; no I/O).
  MeasurementVerification applyEstimation({
    required MeasurementVerification record,
    required double? actualPostValue,
    double? adjustedBaselineValue,
    double? dataCompleteness,
    int? confidenceScore,
    DateTime? estimatedAt,
  }) {
    final result = estimation.estimate(
      baselineValue: record.baselineValue,
      actualPostValue: actualPostValue ?? record.actualPostValue,
      adjustedBaselineValue:
          adjustedBaselineValue ?? record.adjustedBaselineValue,
      prePeriodStart: record.prePeriodStart,
      prePeriodEnd: record.prePeriodEnd,
      postPeriodStart: record.postPeriodStart,
      postPeriodEnd: record.postPeriodEnd,
      unitCode: record.unitCode,
      dataCompleteness: dataCompleteness ?? record.dataCompleteness,
      confidenceScore: confidenceScore ?? record.confidenceScore,
      calculatedAt: estimatedAt,
    );

    if (!result.canEstimate) {
      throw StateError(
        'Cannot estimate: insufficient post-period data '
        '(Estimated Saving requires actual_post_value)',
      );
    }

    if (record.status != MvStatus.draft &&
        record.status != MvStatus.estimated) {
      MvLifecycle.assertCanTransition(record.status, MvStatus.estimated);
    } else if (record.status == MvStatus.draft) {
      MvLifecycle.assertCanTransition(MvStatus.draft, MvStatus.estimated);
    }

    final at = estimatedAt ?? DateTime.now().toUtc();
    final meta = Map<String, dynamic>.from(record.calculationMeta)
      ..addAll(result.toMetaJson());

    return MeasurementVerification(
      id: record.id,
      siteId: record.siteId,
      opportunityId: record.opportunityId,
      actionId: record.actionId,
      baselineId: record.baselineId,
      targetId: record.targetId,
      meterId: record.meterId,
      balanceGroupId: record.balanceGroupId,
      utilityType: record.utilityType,
      verificationMethod: record.verificationMethod,
      calculationVersion: record.calculationVersion,
      supersedesId: record.supersedesId,
      prePeriodStart: record.prePeriodStart,
      prePeriodEnd: record.prePeriodEnd,
      postPeriodStart: record.postPeriodStart,
      postPeriodEnd: record.postPeriodEnd,
      baselineValue: record.baselineValue,
      actualPostValue: result.actualPostValue,
      adjustedBaselineValue:
          adjustedBaselineValue ?? record.adjustedBaselineValue,
      estimatedSavingQuantity: result.estimatedSavingQuantity,
      verifiedSavingQuantity: null,
      // Preserve signed change explicitly (may be negative).
      performanceChangeQuantity: result.performanceChangeQuantity,
      unitCode: record.unitCode,
      dataCompleteness: result.dataCompleteness,
      confidenceScore: result.confidenceScore,
      status: MvStatus.estimated,
      staleReason: record.staleReason,
      needsRecalculation: false,
      tariffId: record.tariffId,
      costAvoided: null,
      costCurrency: null,
      calculationMeta: meta,
      evidenceIds: record.evidenceIds,
      calculatedAt: at,
      estimatedAt: at,
      notes: record.notes,
      createdBy: record.createdBy,
      createdAt: record.createdAt,
      updatedAt: at,
    );
  }

  /// Move estimated → verification_pending (pure).
  MeasurementVerification prepareVerificationPending(
    MeasurementVerification record,
  ) {
    MvLifecycle.assertCanTransition(
      record.status,
      MvStatus.verificationPending,
    );
    if (record.estimatedSavingQuantity == null) {
      throw StateError(
        'verification_pending requires Estimated Saving quantity',
      );
    }
    return _copy(
      record,
      status: MvStatus.verificationPending,
      updatedAt: DateTime.now().toUtc(),
    );
  }

  /// Verify after gates. Negative/zero estimated → verified quantity 0
  /// (no positive Verified Saving on negative outcome).
  VerificationOutcome verify({
    required MeasurementVerification record,
    required String verifiedBy,
    required String actorRole,
    required ConservationBaselineStatus? baselineStatus,
    required ActionStatus? actionStatus,
    required OpportunityStatus? opportunityStatus,
    required bool hasPendingCriticalDq,
    UtilityTariff? tariff,
    List<DoubleCountCandidate> existingVerified = const [],
    DoubleCountTopology topology = const DoubleCountTopology(),
    DateTime? verifiedAt,
  }) {
    ConservationAuthorityPolicy.assertCanVerify(actorRole);

    final gate = evaluateGates(
      currentStatus: record.status,
      dataCompleteness: record.dataCompleteness,
      confidenceScore: record.confidenceScore,
      followUpDays: record.postPeriodDays,
      baselineStatus: baselineStatus,
      actionStatus: actionStatus,
      opportunityStatus: opportunityStatus,
      hasPendingCriticalDq: hasPendingCriticalDq,
      verifiedBy: verifiedBy,
      actorRole: actorRole,
    );
    if (!gate.passed) {
      return VerificationOutcome.blocked(gate.reasons);
    }

    final candidate = DoubleCountCandidate(
      id: record.id,
      status: MvStatus.verified,
      postPeriodStart: record.postPeriodStart,
      postPeriodEnd: record.postPeriodEnd,
      meterId: record.meterId,
      balanceGroupId: record.balanceGroupId,
    );
    final overlaps = DoubleCountRules.detectAgainstExisting(
      candidate: candidate,
      existing: existingVerified,
      parentByMeterId: topology.parentByMeterId,
      balanceGroupMembers: topology.balanceGroupMembers,
    );
    if (overlaps.isNotEmpty) {
      return VerificationOutcome.blocked(
        overlaps.map((o) => 'Double-count risk: ${o.reason}').toList(),
      );
    }

    MvLifecycle.assertCanTransition(
      record.status,
      MvStatus.verified,
    );

    final estimated = record.estimatedSavingQuantity;
    if (estimated == null) {
      return VerificationOutcome.blocked(const [
        'Estimated Saving required before Verified Saving',
      ]);
    }

    // Negative outcome: no positive verified saving. Zero allowed.
    final double verifiedQty;
    if (estimated <= 0) {
      verifiedQty = 0;
    } else {
      verifiedQty = estimated;
    }

    final at = verifiedAt ?? DateTime.now().toUtc();
    CostRoiResult? cost;
    if (verifiedQty > 0 && tariff != null) {
      cost = costRoi.compute(
        verifiedSavingQuantity: verifiedQty,
        tariff: tariff,
        postPeriodStart: record.postPeriodStart,
        postPeriodEnd: record.postPeriodEnd,
      );
    } else {
      // Missing tariff or non-positive saving → Cost Avoided N/A (null, not 0).
      cost = costRoi.compute(
        verifiedSavingQuantity: verifiedQty,
        tariff: tariff,
        postPeriodStart: record.postPeriodStart,
        postPeriodEnd: record.postPeriodEnd,
      );
    }

    final meta = Map<String, dynamic>.from(record.calculationMeta)
      ..['verified_saving_label'] = ConservationSavingLabels.verifiedSaving
      ..['verified_from_estimated'] = estimated
      ..['performance_change_quantity'] = estimated
      ..['negative_outcome_clamped'] = estimated <= 0
      ..['status_display'] = estimated < 0
          ? ConservationSavingLabels.noSavingIncreasedConsumption
          : ConservationSavingLabels.verifiedSaving
      ..['cost_roi'] = cost.toJson();

    final verified = _copy(
      record,
      status: MvStatus.verified,
      verifiedSavingQuantity: verifiedQty,
      // Signed change preserved even when verified qty is clamped to 0.
      performanceChangeQuantity: estimated,
      tariffId: tariff?.id ?? record.tariffId,
      costAvoided: cost.costAvoided,
      costCurrency: cost.costCurrency,
      verifiedBy: verifiedBy,
      verifiedAt: at,
      calculationMeta: meta,
      updatedAt: at,
    );

    return VerificationOutcome.verified(verified, cost);
  }

  /// Reject a pending/estimated record (pure).
  MeasurementVerification reject({
    required MeasurementVerification record,
    required String rejectedBy,
    required String actorRole,
    String? rejectionReason,
    DateTime? rejectedAt,
  }) {
    ConservationAuthorityPolicy.assertCanVerify(actorRole);
    MvLifecycle.assertCanTransition(record.status, MvStatus.rejected);
    final at = rejectedAt ?? DateTime.now().toUtc();
    return _copy(
      record,
      status: MvStatus.rejected,
      rejectedBy: rejectedBy,
      rejectedAt: at,
      rejectionReason: rejectionReason,
      updatedAt: at,
    );
  }

  /// Supersede [old] and build a new V+1 draft for recalculation.
  /// Historical versions are preserved (old → superseded; new row created).
  RecalculationVersioning recalculateAsNewVersion({
    required MeasurementVerification old,
    required double? newActualPostValue,
    double? newAdjustedBaselineValue,
    double? dataCompleteness,
    int? confidenceScore,
    String? createdBy,
  }) {
    if (old.status != MvStatus.verified &&
        old.status != MvStatus.estimated &&
        old.status != MvStatus.rejected &&
        old.status != MvStatus.verificationPending) {
      throw StateError(
        'Recalculation requires estimated/verification_pending/verified/rejected '
        '(got ${old.status.dbValue})',
      );
    }

    final now = DateTime.now().toUtc();
    final superseded = _copy(
      old,
      status: MvStatus.superseded,
      needsRecalculation: false,
      staleReason: old.staleReason ?? 'superseded_by_recalculation',
      updatedAt: now,
    );

    // Preserve bound baseline_id — never silently retarget.
    final draft = MeasurementVerification(
      id: '', // repository assigns
      siteId: old.siteId,
      opportunityId: old.opportunityId,
      actionId: old.actionId,
      baselineId: old.baselineId,
      targetId: old.targetId,
      meterId: old.meterId,
      balanceGroupId: old.balanceGroupId,
      utilityType: old.utilityType,
      verificationMethod: old.verificationMethod,
      calculationVersion: old.calculationVersion + 1,
      supersedesId: old.id,
      prePeriodStart: old.prePeriodStart,
      prePeriodEnd: old.prePeriodEnd,
      postPeriodStart: old.postPeriodStart,
      postPeriodEnd: old.postPeriodEnd,
      baselineValue: old.baselineValue,
      actualPostValue: newActualPostValue ?? old.actualPostValue,
      adjustedBaselineValue:
          newAdjustedBaselineValue ?? old.adjustedBaselineValue,
      estimatedSavingQuantity: null,
      verifiedSavingQuantity: null,
      performanceChangeQuantity: null,
      unitCode: old.unitCode,
      dataCompleteness: dataCompleteness ?? old.dataCompleteness,
      confidenceScore: confidenceScore ?? old.confidenceScore,
      status: MvStatus.draft,
      needsRecalculation: false,
      calculationMeta: {
        'recalculated_from': old.id,
        'prior_version': old.calculationVersion,
        'baseline_id_bound': old.baselineId,
      },
      evidenceIds: old.evidenceIds,
      calculatedAt: now,
      notes: old.notes,
      createdBy: createdBy ?? old.createdBy,
      createdAt: now,
      updatedAt: now,
    );

    return RecalculationVersioning(
      superseded: superseded,
      nextDraft: draft,
    );
  }

  static const _unset = Object();

  MeasurementVerification _copy(
    MeasurementVerification r, {
    MvStatus? status,
    Object? verifiedSavingQuantity = _unset,
    Object? performanceChangeQuantity = _unset,
    String? tariffId,
    Object? costAvoided = _unset,
    Object? costCurrency = _unset,
    String? verifiedBy,
    DateTime? verifiedAt,
    String? rejectedBy,
    DateTime? rejectedAt,
    String? rejectionReason,
    bool? needsRecalculation,
    String? staleReason,
    Map<String, dynamic>? calculationMeta,
    DateTime? updatedAt,
  }) {
    return MeasurementVerification(
      id: r.id,
      siteId: r.siteId,
      opportunityId: r.opportunityId,
      actionId: r.actionId,
      baselineId: r.baselineId,
      targetId: r.targetId,
      meterId: r.meterId,
      balanceGroupId: r.balanceGroupId,
      utilityType: r.utilityType,
      verificationMethod: r.verificationMethod,
      calculationVersion: r.calculationVersion,
      supersedesId: r.supersedesId,
      prePeriodStart: r.prePeriodStart,
      prePeriodEnd: r.prePeriodEnd,
      postPeriodStart: r.postPeriodStart,
      postPeriodEnd: r.postPeriodEnd,
      baselineValue: r.baselineValue,
      actualPostValue: r.actualPostValue,
      adjustedBaselineValue: r.adjustedBaselineValue,
      estimatedSavingQuantity: r.estimatedSavingQuantity,
      verifiedSavingQuantity: identical(verifiedSavingQuantity, _unset)
          ? r.verifiedSavingQuantity
          : verifiedSavingQuantity as double?,
      performanceChangeQuantity: identical(performanceChangeQuantity, _unset)
          ? r.performanceChangeQuantity
          : performanceChangeQuantity as double?,
      unitCode: r.unitCode,
      dataCompleteness: r.dataCompleteness,
      confidenceScore: r.confidenceScore,
      status: status ?? r.status,
      staleReason: staleReason ?? r.staleReason,
      needsRecalculation: needsRecalculation ?? r.needsRecalculation,
      tariffId: tariffId ?? r.tariffId,
      costAvoided: identical(costAvoided, _unset)
          ? r.costAvoided
          : costAvoided as double?,
      costCurrency: identical(costCurrency, _unset)
          ? r.costCurrency
          : costCurrency as String?,
      calculationMeta: calculationMeta ?? r.calculationMeta,
      evidenceIds: r.evidenceIds,
      calculatedAt: r.calculatedAt,
      estimatedAt: r.estimatedAt,
      verifiedBy: verifiedBy ?? r.verifiedBy,
      verifiedAt: verifiedAt ?? r.verifiedAt,
      rejectedBy: rejectedBy ?? r.rejectedBy,
      rejectedAt: rejectedAt ?? r.rejectedAt,
      rejectionReason: rejectionReason ?? r.rejectionReason,
      notes: r.notes,
      createdBy: r.createdBy,
      createdAt: r.createdAt,
      updatedAt: updatedAt ?? r.updatedAt,
    );
  }
}

/// Result of [SavingsVerificationService.verify].
class VerificationOutcome {
  const VerificationOutcome._({
    required this.success,
    this.record,
    this.costRoi,
    this.blockReasons = const [],
  });

  final bool success;
  final MeasurementVerification? record;
  final CostRoiResult? costRoi;
  final List<String> blockReasons;

  factory VerificationOutcome.verified(
    MeasurementVerification record,
    CostRoiResult cost,
  ) =>
      VerificationOutcome._(
        success: true,
        record: record,
        costRoi: cost,
      );

  factory VerificationOutcome.blocked(List<String> reasons) =>
      VerificationOutcome._(success: false, blockReasons: reasons);
}

class RecalculationVersioning {
  const RecalculationVersioning({
    required this.superseded,
    required this.nextDraft,
  });

  final MeasurementVerification superseded;
  final MeasurementVerification nextDraft;
}
