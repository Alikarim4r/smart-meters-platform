import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/mv_lifecycle.dart';
import '../domain/period_windows.dart';
import '../models/measurement_verification.dart';
import '../services/savings_verification_service.dart';

/// CRUD for `conservation_measurement_verifications`.
///
/// Baseline id on historical rows is never silently retargeted.
class MeasurementVerificationRepository {
  MeasurementVerificationRepository(this._client);

  final SupabaseClient _client;
  static const _table = 'conservation_measurement_verifications';

  Future<MeasurementVerification> createDraft({
    required String siteId,
    required String opportunityId,
    required String baselineId,
    required String utilityType,
    required MvVerificationMethod verificationMethod,
    required DateTime prePeriodStart,
    required DateTime prePeriodEnd,
    required DateTime postPeriodStart,
    required DateTime postPeriodEnd,
    required double baselineValue,
    required String unitCode,
    String? actionId,
    String? targetId,
    String? meterId,
    String? balanceGroupId,
    int calculationVersion = 1,
    String? supersedesId,
    double? actualPostValue,
    double? adjustedBaselineValue,
    double? dataCompleteness,
    int confidenceScore = 0,
    Map<String, dynamic> calculationMeta = const {},
    List<String> evidenceIds = const [],
    String? notes,
    String? createdBy,
  }) async {
    final inserted = await _client
        .from(_table)
        .insert({
          'site_id': siteId,
          'opportunity_id': opportunityId,
          'action_id': ?actionId,
          'baseline_id': baselineId,
          'target_id': ?targetId,
          'meter_id': ?meterId,
          'balance_group_id': ?balanceGroupId,
          'utility_type': utilityType,
          'verification_method': verificationMethod.dbValue,
          'calculation_version': calculationVersion,
          'supersedes_id': ?supersedesId,
          'pre_period_start': _isoDate(prePeriodStart),
          'pre_period_end': _isoDate(prePeriodEnd),
          'post_period_start': _isoDate(postPeriodStart),
          'post_period_end': _isoDate(postPeriodEnd),
          'baseline_value': baselineValue,
          'actual_post_value': ?actualPostValue,
          'adjusted_baseline_value': ?adjustedBaselineValue,
          'unit_code': unitCode,
          'data_completeness': ?dataCompleteness,
          'confidence_score': confidenceScore,
          'status': MvStatus.draft.dbValue,
          'calculation_meta': calculationMeta,
          'evidence_ids': evidenceIds,
          'notes': ?notes,
          'created_by': ?createdBy,
        })
        .select()
        .single();
    return MeasurementVerification.fromJson(
      Map<String, dynamic>.from(inserted),
    );
  }

  Future<MeasurementVerification> get(String id) async {
    final row = await _client.from(_table).select().eq('id', id).single();
    return MeasurementVerification.fromJson(Map<String, dynamic>.from(row));
  }

  Future<List<MeasurementVerification>> listForSite(
    String siteId, {
    List<MvStatus>? statuses,
    int limit = 50,
    int offset = 0,
  }) async {
    var q = _client.from(_table).select().eq('site_id', siteId);
    if (statuses != null && statuses.isNotEmpty) {
      q = q.inFilter('status', statuses.map((s) => s.dbValue).toList());
    }
    final rows = await q
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);
    return (rows as List)
        .map(
          (e) => MeasurementVerification.fromJson(
            Map<String, dynamic>.from(e as Map),
          ),
        )
        .toList();
  }

  Future<List<MeasurementVerification>> listByOpportunity(
    String opportunityId, {
    int limit = 50,
  }) async {
    final rows = await _client
        .from(_table)
        .select()
        .eq('opportunity_id', opportunityId)
        .order('calculation_version', ascending: false)
        .limit(limit);
    return (rows as List)
        .map(
          (e) => MeasurementVerification.fromJson(
            Map<String, dynamic>.from(e as Map),
          ),
        )
        .toList();
  }

  /// Verified rows that may overlap a candidate (double-count checks).
  Future<List<MeasurementVerification>> listVerifiedOverlappingScope({
    required String siteId,
    String? meterId,
    String? balanceGroupId,
  }) async {
    var q = _client
        .from(_table)
        .select()
        .eq('site_id', siteId)
        .eq('status', MvStatus.verified.dbValue);
    if (meterId != null) {
      q = q.eq('meter_id', meterId);
    } else if (balanceGroupId != null) {
      q = q.eq('balance_group_id', balanceGroupId);
    }
    final rows = await q.order('post_period_start');
    return (rows as List)
        .map(
          (e) => MeasurementVerification.fromJson(
            Map<String, dynamic>.from(e as Map),
          ),
        )
        .toList();
  }

  Future<MeasurementVerification> updateRow(
    MeasurementVerification record,
  ) async {
    final updated = await _client
        .from(_table)
        .update({
          'actual_post_value': record.actualPostValue,
          'adjusted_baseline_value': record.adjustedBaselineValue,
          'estimated_saving_quantity': record.estimatedSavingQuantity,
          'verified_saving_quantity': record.verifiedSavingQuantity,
          'performance_change_quantity': record.performanceChangeQuantity,
          'data_completeness': record.dataCompleteness,
          'confidence_score': record.confidenceScore,
          'status': record.status.dbValue,
          'stale_reason': record.staleReason,
          'needs_recalculation': record.needsRecalculation,
          'tariff_id': record.tariffId,
          'cost_avoided': record.costAvoided,
          'cost_currency': record.costCurrency,
          'calculation_meta': record.calculationMeta,
          'evidence_ids': record.evidenceIds,
          'estimated_at': record.estimatedAt?.toUtc().toIso8601String(),
          'verified_by': record.verifiedBy,
          'verified_at': record.verifiedAt?.toUtc().toIso8601String(),
          'rejected_by': record.rejectedBy,
          'rejected_at': record.rejectedAt?.toUtc().toIso8601String(),
          'rejection_reason': record.rejectionReason,
          'notes': record.notes,
          // baseline_id intentionally omitted — immutable bind.
        })
        .eq('id', record.id)
        .select()
        .single();
    return MeasurementVerification.fromJson(Map<String, dynamic>.from(updated));
  }

  /// Persist supersede + insert next draft from [RecalculationVersioning].
  Future<MeasurementVerification> persistRecalculation(
    RecalculationVersioning versioning, {
    String? createdBy,
  }) async {
    await updateRow(versioning.superseded);
    final next = versioning.nextDraft;
    return createDraft(
      siteId: next.siteId,
      opportunityId: next.opportunityId,
      baselineId: next.baselineId,
      utilityType: next.utilityType,
      verificationMethod: next.verificationMethod,
      prePeriodStart: next.prePeriodStart,
      prePeriodEnd: next.prePeriodEnd,
      postPeriodStart: next.postPeriodStart,
      postPeriodEnd: next.postPeriodEnd,
      baselineValue: next.baselineValue,
      unitCode: next.unitCode,
      actionId: next.actionId,
      targetId: next.targetId,
      meterId: next.meterId,
      balanceGroupId: next.balanceGroupId,
      calculationVersion: next.calculationVersion,
      supersedesId: next.supersedesId ?? versioning.superseded.id,
      actualPostValue: next.actualPostValue,
      adjustedBaselineValue: next.adjustedBaselineValue,
      dataCompleteness: next.dataCompleteness,
      confidenceScore: next.confidenceScore,
      calculationMeta: next.calculationMeta,
      evidenceIds: next.evidenceIds,
      notes: next.notes,
      createdBy: createdBy ?? next.createdBy,
    );
  }

  static String _isoDate(DateTime d) {
    final x = dateOnly(d);
    return '${x.year.toString().padLeft(4, '0')}-'
        '${x.month.toString().padLeft(2, '0')}-'
        '${x.day.toString().padLeft(2, '0')}';
  }
}
