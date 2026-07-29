import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/conservation_target.dart';

/// CRUD for versioned conservation targets. Never overwrites archived history
/// values — activation archives previous active and inserts a new version.
class ConservationTargetRepository {
  ConservationTargetRepository(this._client);

  final SupabaseClient _client;
  static const _table = 'conservation_targets';

  Future<List<ConservationTarget>> listForSite(
    String siteId, {
    ConservationTargetStatus? status,
  }) async {
    var q = _client.from(_table).select().eq('site_id', siteId);
    if (status != null) q = q.eq('status', status.dbValue);
    final rows = await q.order('period_start', ascending: false).order('version');
    return (rows as List)
        .map((e) => ConservationTarget.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<ConservationTarget?> getActive({
    required String siteId,
    required ConservationTargetScopeType scopeType,
    String? scopeId,
    required ConservationTargetPeriodType periodType,
    required DateTime periodStart,
    required String unitCode,
  }) async {
    var q = _client
        .from(_table)
        .select()
        .eq('site_id', siteId)
        .eq('scope_type', scopeType.dbValue)
        .eq('period_type', periodType.dbValue)
        .eq('period_start', _iso(periodStart))
        .eq('unit_code', unitCode)
        .eq('status', ConservationTargetStatus.active.dbValue);
    q = scopeId == null ? q.isFilter('scope_id', null) : q.eq('scope_id', scopeId);
    final row = await q.maybeSingle();
    if (row == null) return null;
    return ConservationTarget.fromJson(Map<String, dynamic>.from(row));
  }

  /// Insert a draft target (version = next for that key, or 1).
  Future<ConservationTarget> createDraft({
    required String siteId,
    required ConservationTargetScopeType scopeType,
    String? scopeId,
    required ConservationTargetPeriodType periodType,
    required DateTime periodStart,
    required DateTime periodEnd,
    required double targetValue,
    required String unitCode,
    String? createdBy,
  }) async {
    final nextVersion = await _nextVersion(
      siteId: siteId,
      scopeType: scopeType,
      scopeId: scopeId,
      periodType: periodType,
      periodStart: periodStart,
      unitCode: unitCode,
    );
    final inserted = await _client
        .from(_table)
        .insert({
          'site_id': siteId,
          'scope_type': scopeType.dbValue,
          'scope_id': scopeId,
          'period_type': periodType.dbValue,
          'period_start': _iso(periodStart),
          'period_end': _iso(periodEnd),
          'target_value': targetValue,
          'unit_code': unitCode,
          'version': nextVersion,
          'status': ConservationTargetStatus.draft.dbValue,
          'created_by': ?createdBy,
        })
        .select()
        .single();
    return ConservationTarget.fromJson(Map<String, dynamic>.from(inserted));
  }

  /// Update draft fields only (not active/archived target_value history).
  Future<ConservationTarget> updateDraft({
    required String id,
    required double targetValue,
    required DateTime periodEnd,
  }) async {
    final existing = await _client.from(_table).select().eq('id', id).single();
    final status = ConservationTargetStatus.fromDb(existing['status'] as String);
    if (status != ConservationTargetStatus.draft) {
      throw StateError('Only draft targets may be updated in place.');
    }
    final updated = await _client
        .from(_table)
        .update({
          'target_value': targetValue,
          'period_end': _iso(periodEnd),
        })
        .eq('id', id)
        .select()
        .single();
    return ConservationTarget.fromJson(Map<String, dynamic>.from(updated));
  }

  /// Activate a draft: archive any current active for the same key, then set active.
  Future<ConservationTarget> activate(String draftId) async {
    final draftRow = await _client.from(_table).select().eq('id', draftId).single();
    final draft = ConservationTarget.fromJson(Map<String, dynamic>.from(draftRow));
    if (draft.status != ConservationTargetStatus.draft) {
      throw StateError('Only draft targets can be activated.');
    }

    // Archive previous active (preserve history — do not overwrite values).
    var archiveQ = _client
        .from(_table)
        .update({'status': ConservationTargetStatus.archived.dbValue})
        .eq('site_id', draft.siteId)
        .eq('scope_type', draft.scopeType.dbValue)
        .eq('period_type', draft.periodType.dbValue)
        .eq('period_start', _iso(draft.periodStart))
        .eq('unit_code', draft.unitCode)
        .eq('status', ConservationTargetStatus.active.dbValue);
    archiveQ = draft.scopeId == null
        ? archiveQ.isFilter('scope_id', null)
        : archiveQ.eq('scope_id', draft.scopeId!);
    await archiveQ;

    final activated = await _client
        .from(_table)
        .update({'status': ConservationTargetStatus.active.dbValue})
        .eq('id', draftId)
        .select()
        .single();
    return ConservationTarget.fromJson(Map<String, dynamic>.from(activated));
  }

  Future<int> _nextVersion({
    required String siteId,
    required ConservationTargetScopeType scopeType,
    String? scopeId,
    required ConservationTargetPeriodType periodType,
    required DateTime periodStart,
    required String unitCode,
  }) async {
    var q = _client
        .from(_table)
        .select('version')
        .eq('site_id', siteId)
        .eq('scope_type', scopeType.dbValue)
        .eq('period_type', periodType.dbValue)
        .eq('period_start', _iso(periodStart))
        .eq('unit_code', unitCode);
    q = scopeId == null ? q.isFilter('scope_id', null) : q.eq('scope_id', scopeId);
    final rows = await q;
    var maxV = 0;
    for (final row in (rows as List)) {
      final v = (row as Map)['version'] as int? ?? 0;
      if (v > maxV) maxV = v;
    }
    return maxV + 1;
  }

  static String _iso(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
