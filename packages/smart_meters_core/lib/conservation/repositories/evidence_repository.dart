import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/conservation_evidence.dart';

export '../models/conservation_evidence.dart'
    show kConservationEvidenceBucket, conservationEvidencePath;

/// Metadata CRUD for `conservation_evidence` (detail views only).
class EvidenceRepository {
  EvidenceRepository(this._client);

  final SupabaseClient _client;
  static const _table = 'conservation_evidence';

  Future<ConservationEvidence> insert(ConservationEvidence evidence) async {
    if (evidence.opportunityId == null &&
        evidence.investigationId == null &&
        evidence.actionId == null) {
      throw StateError(
        'Evidence requires opportunity_id, investigation_id, or action_id',
      );
    }
    final inserted = await _client
        .from(_table)
        .insert(evidence.toInsertJson())
        .select()
        .single();
    return ConservationEvidence.fromJson(Map<String, dynamic>.from(inserted));
  }

  /// List evidence for an opportunity (detail screen).
  Future<List<ConservationEvidence>> listByOpportunity(
    String opportunityId, {
    int limit = 100,
  }) async {
    final rows = await _client
        .from(_table)
        .select()
        .eq('opportunity_id', opportunityId)
        .order('created_at', ascending: false)
        .limit(limit);
    return (rows as List)
        .map(
          (e) => ConservationEvidence.fromJson(
            Map<String, dynamic>.from(e as Map),
          ),
        )
        .toList();
  }

  /// Delete evidence metadata (site_admin / elevated — enforced by RLS).
  Future<void> delete(String id) async {
    await _client.from(_table).delete().eq('id', id);
  }
}
