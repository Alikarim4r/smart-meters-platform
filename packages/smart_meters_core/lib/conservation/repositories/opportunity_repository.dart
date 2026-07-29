import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/opportunity_lifecycle.dart';
import '../domain/opportunity_signal_rules.dart';
import '../models/conservation_opportunity.dart';

/// Persistence surface used by [OpportunityGenerationService] (testable).
abstract class OpportunityGenerationStore {
  Future<ConservationOpportunity?> findOpenByFingerprint({
    required String siteId,
    required String sourceFingerprint,
  });

  Future<ConservationOpportunity> insert(ConservationOpportunity opp);

  Future<ConservationOpportunity> refreshOpenSignal({
    required String id,
    required int confidenceScore,
    required OpportunityPriorityLevel priority,
    required Map<String, dynamic> sourceSnapshot,
    double? estimatedWasteQuantity,
    List<String>? possibleCauses,
    List<String>? suggestedInvestigations,
    String? title,
    String? description,
  });
}

/// CRUD + fingerprint lookup for `conservation_opportunities`.
class OpportunityRepository implements OpportunityGenerationStore {
  OpportunityRepository(this._client);

  final SupabaseClient _client;
  static const _table = 'conservation_opportunities';

  Future<List<ConservationOpportunity>> listForSite(
    String siteId, {
    List<OpportunityStatus>? statuses,
    int limit = 50,
    int offset = 0,
  }) async {
    var q = _client.from(_table).select().eq('site_id', siteId);
    if (statuses != null && statuses.isNotEmpty) {
      q = q.inFilter('status', statuses.map((s) => s.dbValue).toList());
    }
    final rows = await q
        .order('detected_at', ascending: false)
        .range(offset, offset + limit - 1);
    return (rows as List)
        .map(
          (e) => ConservationOpportunity.fromJson(
            Map<String, dynamic>.from(e as Map),
          ),
        )
        .toList();
  }

  Future<ConservationOpportunity?> getById(String id) async {
    final row =
        await _client.from(_table).select().eq('id', id).maybeSingle();
    if (row == null) return null;
    return ConservationOpportunity.fromJson(Map<String, dynamic>.from(row));
  }

  /// Open (non-resolved / non-dismissed) opportunity with fingerprint.
  @override
  Future<ConservationOpportunity?> findOpenByFingerprint({
    required String siteId,
    required String sourceFingerprint,
  }) async {
    final openStatuses = OpportunityStatus.values
        .where((s) => s.isOpen)
        .map((s) => s.dbValue)
        .toList();
    final rows = await _client
        .from(_table)
        .select()
        .eq('site_id', siteId)
        .eq('source_fingerprint', sourceFingerprint)
        .inFilter('status', openStatuses)
        .limit(1);
    final list = rows as List;
    if (list.isEmpty) return null;
    return ConservationOpportunity.fromJson(
      Map<String, dynamic>.from(list.first as Map),
    );
  }

  @override
  Future<ConservationOpportunity> insert(ConservationOpportunity opp) async {
    final inserted = await _client
        .from(_table)
        .insert(opp.toInsertJson())
        .select()
        .single();
    return ConservationOpportunity.fromJson(
      Map<String, dynamic>.from(inserted),
    );
  }

  Future<ConservationOpportunity> update(
    String id,
    Map<String, dynamic> patch,
  ) async {
    final updated =
        await _client.from(_table).update(patch).eq('id', id).select().single();
    return ConservationOpportunity.fromJson(Map<String, dynamic>.from(updated));
  }

  /// Refresh detection fields on an open opportunity (dedupe path).
  @override
  Future<ConservationOpportunity> refreshOpenSignal({
    required String id,
    required int confidenceScore,
    required OpportunityPriorityLevel priority,
    required Map<String, dynamic> sourceSnapshot,
    double? estimatedWasteQuantity,
    List<String>? possibleCauses,
    List<String>? suggestedInvestigations,
    String? title,
    String? description,
  }) async {
    final existing = await getById(id);
    if (existing == null) {
      throw StateError('Opportunity not found: $id');
    }
    if (existing.status.isClosed) {
      throw StateError('Cannot refresh closed opportunity $id');
    }
    return update(id, {
      'confidence_score': confidenceScore,
      'priority': priority.dbValue,
      'source_snapshot': sourceSnapshot,
      if (estimatedWasteQuantity != null)
        'estimated_waste_quantity': estimatedWasteQuantity,
      if (possibleCauses != null) 'possible_causes': possibleCauses,
      if (suggestedInvestigations != null)
        'suggested_investigations': suggestedInvestigations,
      if (title != null) 'title': title,
      if (description != null) 'description': description,
    });
  }
}
