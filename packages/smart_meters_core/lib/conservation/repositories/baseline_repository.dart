import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/conservation_baseline.dart';

/// Permissions for baseline workflow (documented; enforced in service + RLS).
///
/// | Action        | Roles |
/// |---------------|-------|
/// | Create Draft  | site_admin (can_manage_site), super_admin, platform_owner |
/// | Edit Draft    | same |
/// | Approve       | same roles, but explicit approve action (not auto on create) |
/// | Archive       | same |
/// | Viewer/Tech   | SELECT only (RLS) |
abstract final class BaselinePermissions {
  static const createDraftRoles = [
    'site_admin',
    'super_admin',
    'platform_owner',
  ];
  static const editDraftRoles = createDraftRoles;
  static const approveRoles = createDraftRoles;
  static const archiveRoles = createDraftRoles;
}

/// CRUD for versioned baselines. Never overwrites approved history values.
class ConservationBaselineRepository {
  ConservationBaselineRepository(this._client);

  final SupabaseClient _client;
  static const _table = 'conservation_baselines';

  /// Dashboard: current approved only (not full history).
  Future<List<ConservationBaseline>> listApprovedForSite(String siteId) async {
    final rows = await _client
        .from(_table)
        .select()
        .eq('site_id', siteId)
        .eq('status', ConservationBaselineStatus.approved.dbValue)
        .order('unit_code');
    return (rows as List)
        .map((e) =>
            ConservationBaseline.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<ConservationBaseline?> getApproved({
    required String siteId,
    required ConservationBaselineScopeType scopeType,
    String? scopeId,
    required String unitCode,
  }) async {
    var q = _client
        .from(_table)
        .select()
        .eq('site_id', siteId)
        .eq('scope_type', scopeType.dbValue)
        .eq('unit_code', unitCode)
        .eq('status', ConservationBaselineStatus.approved.dbValue);
    q = scopeId == null
        ? q.isFilter('scope_id', null)
        : q.eq('scope_id', scopeId);
    final row = await q.maybeSingle();
    if (row == null) return null;
    return ConservationBaseline.fromJson(Map<String, dynamic>.from(row));
  }

  /// Admin: full history for a site (loaded only on history screens).
  Future<List<ConservationBaseline>> listHistoryForSite(
    String siteId, {
    ConservationBaselineScopeType? scopeType,
    String? scopeId,
    String? unitCode,
  }) async {
    var q = _client.from(_table).select().eq('site_id', siteId);
    if (scopeType != null) q = q.eq('scope_type', scopeType.dbValue);
    if (unitCode != null) q = q.eq('unit_code', unitCode);
    if (scopeId == null && scopeType == ConservationBaselineScopeType.site) {
      q = q.isFilter('scope_id', null);
    } else if (scopeId != null) {
      q = q.eq('scope_id', scopeId);
    }
    final rows = await q
        .order('version_number', ascending: false)
        .order('created_at', ascending: false);
    return (rows as List)
        .map((e) =>
            ConservationBaseline.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<int> nextVersionNumber({
    required String siteId,
    required ConservationBaselineScopeType scopeType,
    String? scopeId,
    required String unitCode,
  }) async {
    final result = await _client.rpc(
      'conservation_baselines_next_version',
      params: {
        'p_site_id': siteId,
        'p_scope_type': scopeType.dbValue,
        'p_scope_id': scopeId,
        'p_unit_code': unitCode,
      },
    );
    if (result is int) return result;
    if (result is num) return result.toInt();
    throw StateError('Unexpected next_version result: $result');
  }

  Future<ConservationBaseline> createDraft({
    required String siteId,
    required ConservationBaselineScopeType scopeType,
    String? scopeId,
    String? utilityCode,
    required String label,
    required DateTime referencePeriodStart,
    required DateTime referencePeriodEnd,
    required BaselineCalculationMethod calculationMethod,
    required double baselineValue,
    required String unitCode,
    String? notes,
    double? dataCompleteness,
    int? confidenceScore,
    BaselineBoundaryQuality? boundaryQuality,
    Map<String, dynamic>? calculationMeta,
    String? createdBy,
  }) async {
    if (scopeType != ConservationBaselineScopeType.site &&
        (scopeId == null || scopeId.isEmpty)) {
      throw ArgumentError('scope_id required for ${scopeType.dbValue}');
    }
    if (scopeType == ConservationBaselineScopeType.site && scopeId != null) {
      throw ArgumentError('site scope must have null scope_id');
    }
    if (referencePeriodEnd.isBefore(referencePeriodStart)) {
      throw ArgumentError('Invalid reference period');
    }

    final version = await nextVersionNumber(
      siteId: siteId,
      scopeType: scopeType,
      scopeId: scopeId,
      unitCode: unitCode,
    );

    final inserted = await _client
        .from(_table)
        .insert({
          'site_id': siteId,
          'scope_type': scopeType.dbValue,
          'scope_id': scopeId,
          'utility_code': utilityCode,
          'version_number': version,
          'label': label,
          'reference_period_start': _iso(referencePeriodStart),
          'reference_period_end': _iso(referencePeriodEnd),
          'calculation_method': calculationMethod.dbValue,
          'baseline_value': baselineValue,
          'unit_code': unitCode,
          'status': ConservationBaselineStatus.draft.dbValue,
          'notes': notes,
          'data_completeness': dataCompleteness,
          'confidence_score': confidenceScore,
          'boundary_quality': boundaryQuality?.dbValue,
          'calculation_meta': calculationMeta ?? {},
          'created_by': ?createdBy,
        })
        .select()
        .single();
    return ConservationBaseline.fromJson(Map<String, dynamic>.from(inserted));
  }

  Future<ConservationBaseline> updateDraft({
    required String id,
    String? label,
    DateTime? referencePeriodStart,
    DateTime? referencePeriodEnd,
    BaselineCalculationMethod? calculationMethod,
    double? baselineValue,
    String? notes,
    double? dataCompleteness,
    int? confidenceScore,
    BaselineBoundaryQuality? boundaryQuality,
    Map<String, dynamic>? calculationMeta,
  }) async {
    final existing = await _client.from(_table).select().eq('id', id).single();
    final status =
        ConservationBaselineStatus.fromDb(existing['status'] as String);
    if (status != ConservationBaselineStatus.draft) {
      throw StateError('Only draft baselines may be updated in place.');
    }
    final payload = <String, dynamic>{
      if (label != null) 'label': label,
      if (referencePeriodStart != null)
        'reference_period_start': _iso(referencePeriodStart),
      if (referencePeriodEnd != null)
        'reference_period_end': _iso(referencePeriodEnd),
      if (calculationMethod != null)
        'calculation_method': calculationMethod.dbValue,
      if (baselineValue != null) 'baseline_value': baselineValue,
      if (notes != null) 'notes': notes,
      if (dataCompleteness != null) 'data_completeness': dataCompleteness,
      if (confidenceScore != null) 'confidence_score': confidenceScore,
      if (boundaryQuality != null) 'boundary_quality': boundaryQuality.dbValue,
      if (calculationMeta != null) 'calculation_meta': calculationMeta,
    };
    final updated = await _client
        .from(_table)
        .update(payload)
        .eq('id', id)
        .select()
        .single();
    return ConservationBaseline.fromJson(Map<String, dynamic>.from(updated));
  }

  Future<void> deleteDraft(String id) async {
    await _client
        .from(_table)
        .delete()
        .eq('id', id)
        .eq('status', ConservationBaselineStatus.draft.dbValue);
  }

  static String _iso(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
