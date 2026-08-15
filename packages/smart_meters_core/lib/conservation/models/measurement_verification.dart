import '../domain/mv_lifecycle.dart';
import '../domain/period_windows.dart';

/// Measurement & Verification row (`conservation_measurement_verifications`).
///
/// Terminology (do not conflate):
/// - Opportunity **Potential Excess** ≠ this record
/// - [estimatedSavingQuantity] = Estimated Saving only
/// - [verifiedSavingQuantity] = Verified Saving only (after gates + human)
///
/// [baselineId] is bound at calculation time and must not be silently
/// retargeted to a newer baseline version.
class MeasurementVerification {
  const MeasurementVerification({
    required this.id,
    required this.siteId,
    required this.opportunityId,
    required this.baselineId,
    required this.utilityType,
    required this.verificationMethod,
    required this.calculationVersion,
    required this.prePeriodStart,
    required this.prePeriodEnd,
    required this.postPeriodStart,
    required this.postPeriodEnd,
    required this.baselineValue,
    required this.unitCode,
    required this.confidenceScore,
    required this.status,
    this.actionId,
    this.targetId,
    this.meterId,
    this.balanceGroupId,
    this.supersedesId,
    this.actualPostValue,
    this.adjustedBaselineValue,
    this.estimatedSavingQuantity,
    this.verifiedSavingQuantity,
    this.performanceChangeQuantity,
    this.dataCompleteness,
    this.staleReason,
    this.needsRecalculation = false,
    this.tariffId,
    this.costAvoided,
    this.costCurrency,
    this.calculationMeta = const {},
    this.evidenceIds = const [],
    this.calculatedAt,
    this.estimatedAt,
    this.verifiedBy,
    this.verifiedAt,
    this.rejectedBy,
    this.rejectedAt,
    this.rejectionReason,
    this.notes,
    this.createdBy,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String siteId;
  final String opportunityId;
  final String? actionId;

  /// Bound baseline id — immutable for historical records.
  final String baselineId;
  final String? targetId;
  final String? meterId;
  final String? balanceGroupId;
  final String utilityType;
  final MvVerificationMethod verificationMethod;
  final int calculationVersion;
  final String? supersedesId;
  final DateTime prePeriodStart;
  final DateTime prePeriodEnd;
  final DateTime postPeriodStart;
  final DateTime postPeriodEnd;
  final double baselineValue;
  final double? actualPostValue;
  final double? adjustedBaselineValue;

  /// Estimated Saving (signed). Positive = reduced consumption; negative =
  /// increased consumption ("No Saving / Increased Consumption" in UI).
  /// Never call this Potential Excess or Verified Saving.
  final double? estimatedSavingQuantity;

  /// Official Verified Saving after gates + human approval. May be 0.
  /// Negative outcomes must not produce a positive verified saving.
  final double? verifiedSavingQuantity;

  /// Signed performance change (reference − post). May be negative when
  /// consumption increased. Preserved for reporting even when
  /// [verifiedSavingQuantity] is clamped to 0. Never summed into Verified
  /// Savings totals when negative.
  final double? performanceChangeQuantity;
  final String unitCode;
  final double? dataCompleteness;
  final int confidenceScore;
  final MvStatus status;
  final String? staleReason;
  final bool needsRecalculation;
  final String? tariffId;

  /// Cost avoided from verified saving × tariff. Null = N/A (never invent 0).
  final double? costAvoided;
  final String? costCurrency;
  final Map<String, dynamic> calculationMeta;
  final List<String> evidenceIds;
  final DateTime? calculatedAt;
  final DateTime? estimatedAt;
  final String? verifiedBy;
  final DateTime? verifiedAt;
  final String? rejectedBy;
  final DateTime? rejectedAt;
  final String? rejectionReason;
  final String? notes;
  final String? createdBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// Inclusive post-period day count.
  int get postPeriodDays =>
      inclusiveDayCount(postPeriodStart, postPeriodEnd);

  /// Prefer explicit column; fall back to estimated (signed) or meta.
  double? get resolvedPerformanceChangeQuantity =>
      performanceChangeQuantity ??
      estimatedSavingQuantity ??
      (calculationMeta['performance_change_quantity'] as num?)?.toDouble() ??
      (calculationMeta['verified_from_estimated'] as num?)?.toDouble();

  bool get isIncreasedConsumptionOutcome =>
      (resolvedPerformanceChangeQuantity ?? 0) < 0;

  factory MeasurementVerification.fromJson(Map<String, dynamic> json) {
    return MeasurementVerification(
      id: json['id'] as String,
      siteId: json['site_id'] as String,
      opportunityId: json['opportunity_id'] as String,
      actionId: json['action_id'] as String?,
      baselineId: json['baseline_id'] as String,
      targetId: json['target_id'] as String?,
      meterId: json['meter_id'] as String?,
      balanceGroupId: json['balance_group_id'] as String?,
      utilityType: json['utility_type'] as String,
      verificationMethod: MvVerificationMethod.fromDb(
        json['verification_method'] as String? ?? 'baseline_comparison',
      ),
      calculationVersion: json['calculation_version'] as int? ?? 1,
      supersedesId: json['supersedes_id'] as String?,
      prePeriodStart: dateOnly(DateTime.parse(json['pre_period_start'] as String)),
      prePeriodEnd: dateOnly(DateTime.parse(json['pre_period_end'] as String)),
      postPeriodStart:
          dateOnly(DateTime.parse(json['post_period_start'] as String)),
      postPeriodEnd: dateOnly(DateTime.parse(json['post_period_end'] as String)),
      baselineValue: (json['baseline_value'] as num).toDouble(),
      actualPostValue: (json['actual_post_value'] as num?)?.toDouble(),
      adjustedBaselineValue:
          (json['adjusted_baseline_value'] as num?)?.toDouble(),
      estimatedSavingQuantity:
          (json['estimated_saving_quantity'] as num?)?.toDouble(),
      verifiedSavingQuantity:
          (json['verified_saving_quantity'] as num?)?.toDouble(),
      performanceChangeQuantity:
          (json['performance_change_quantity'] as num?)?.toDouble(),
      unitCode: json['unit_code'] as String,
      dataCompleteness: (json['data_completeness'] as num?)?.toDouble(),
      confidenceScore: json['confidence_score'] as int? ?? 0,
      status: MvStatus.fromDb(json['status'] as String? ?? 'draft'),
      staleReason: json['stale_reason'] as String?,
      needsRecalculation: json['needs_recalculation'] as bool? ?? false,
      tariffId: json['tariff_id'] as String?,
      costAvoided: (json['cost_avoided'] as num?)?.toDouble(),
      costCurrency: json['cost_currency'] as String?,
      calculationMeta: Map<String, dynamic>.from(
        (json['calculation_meta'] as Map?) ?? const {},
      ),
      evidenceIds: _parseStringList(json['evidence_ids']),
      calculatedAt: _parseDt(json['calculated_at']),
      estimatedAt: _parseDt(json['estimated_at']),
      verifiedBy: json['verified_by'] as String?,
      verifiedAt: _parseDt(json['verified_at']),
      rejectedBy: json['rejected_by'] as String?,
      rejectedAt: _parseDt(json['rejected_at']),
      rejectionReason: json['rejection_reason'] as String?,
      notes: json['notes'] as String?,
      createdBy: json['created_by'] as String?,
      createdAt: _parseDt(json['created_at']),
      updatedAt: _parseDt(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'site_id': siteId,
        'opportunity_id': opportunityId,
        'action_id': actionId,
        'baseline_id': baselineId,
        'target_id': targetId,
        'meter_id': meterId,
        'balance_group_id': balanceGroupId,
        'utility_type': utilityType,
        'verification_method': verificationMethod.dbValue,
        'calculation_version': calculationVersion,
        'supersedes_id': supersedesId,
        'pre_period_start': _isoDate(prePeriodStart),
        'pre_period_end': _isoDate(prePeriodEnd),
        'post_period_start': _isoDate(postPeriodStart),
        'post_period_end': _isoDate(postPeriodEnd),
        'baseline_value': baselineValue,
        'actual_post_value': actualPostValue,
        'adjusted_baseline_value': adjustedBaselineValue,
        'estimated_saving_quantity': estimatedSavingQuantity,
        'verified_saving_quantity': verifiedSavingQuantity,
        'performance_change_quantity': performanceChangeQuantity,
        'unit_code': unitCode,
        'data_completeness': dataCompleteness,
        'confidence_score': confidenceScore,
        'status': status.dbValue,
        'stale_reason': staleReason,
        'needs_recalculation': needsRecalculation,
        'tariff_id': tariffId,
        'cost_avoided': costAvoided,
        'cost_currency': costCurrency,
        'calculation_meta': calculationMeta,
        'evidence_ids': evidenceIds,
        'calculated_at': calculatedAt?.toUtc().toIso8601String(),
        'estimated_at': estimatedAt?.toUtc().toIso8601String(),
        'verified_by': verifiedBy,
        'verified_at': verifiedAt?.toUtc().toIso8601String(),
        'rejected_by': rejectedBy,
        'rejected_at': rejectedAt?.toUtc().toIso8601String(),
        'rejection_reason': rejectionReason,
        'notes': notes,
        'created_by': createdBy,
        'created_at': createdAt?.toUtc().toIso8601String(),
        'updated_at': updatedAt?.toUtc().toIso8601String(),
      };

  Map<String, dynamic> toInsertJson() => {
        'site_id': siteId,
        'opportunity_id': opportunityId,
        if (actionId != null) 'action_id': actionId,
        'baseline_id': baselineId,
        if (targetId != null) 'target_id': targetId,
        if (meterId != null) 'meter_id': meterId,
        if (balanceGroupId != null) 'balance_group_id': balanceGroupId,
        'utility_type': utilityType,
        'verification_method': verificationMethod.dbValue,
        'calculation_version': calculationVersion,
        if (supersedesId != null) 'supersedes_id': supersedesId,
        'pre_period_start': _isoDate(prePeriodStart),
        'pre_period_end': _isoDate(prePeriodEnd),
        'post_period_start': _isoDate(postPeriodStart),
        'post_period_end': _isoDate(postPeriodEnd),
        'baseline_value': baselineValue,
        if (actualPostValue != null) 'actual_post_value': actualPostValue,
        if (adjustedBaselineValue != null)
          'adjusted_baseline_value': adjustedBaselineValue,
        if (estimatedSavingQuantity != null)
          'estimated_saving_quantity': estimatedSavingQuantity,
        'unit_code': unitCode,
        if (dataCompleteness != null) 'data_completeness': dataCompleteness,
        'confidence_score': confidenceScore,
        'status': status.dbValue,
        if (staleReason != null) 'stale_reason': staleReason,
        'needs_recalculation': needsRecalculation,
        if (tariffId != null) 'tariff_id': tariffId,
        if (costAvoided != null) 'cost_avoided': costAvoided,
        if (costCurrency != null) 'cost_currency': costCurrency,
        'calculation_meta': calculationMeta,
        'evidence_ids': evidenceIds,
        if (estimatedAt != null)
          'estimated_at': estimatedAt!.toUtc().toIso8601String(),
        if (notes != null) 'notes': notes,
        if (createdBy != null) 'created_by': createdBy,
      };

  static List<String> _parseStringList(dynamic v) {
    if (v == null) return const [];
    if (v is List) {
      return v.map((e) => e.toString()).toList();
    }
    return const [];
  }

  static DateTime? _parseDt(dynamic v) =>
      v == null ? null : DateTime.parse(v as String);

  static String _isoDate(DateTime d) {
    final x = dateOnly(d);
    return '${x.year.toString().padLeft(4, '0')}-'
        '${x.month.toString().padLeft(2, '0')}-'
        '${x.day.toString().padLeft(2, '0')}';
  }
}

/// Display labels — keep Estimated / Verified distinct from Potential Excess.
abstract final class ConservationSavingLabels {
  static const estimatedSaving = 'Estimated Saving';
  static const verifiedSaving = 'Verified Saving';
  static const potentialExcess = 'Potential Excess';
  static const noSavingIncreasedConsumption = 'No Saving / Increased Consumption';
  static const costAvoidedNa = 'N/A';

  /// Potential Excess must never be presented as a Saving label.
  static const forbiddenAsSaving = [
    'Potential Excess',
    'potential excess',
  ];
}
