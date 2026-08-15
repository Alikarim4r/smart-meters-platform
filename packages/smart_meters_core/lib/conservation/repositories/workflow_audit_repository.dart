import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/workflow_audit_entry.dart';

/// Append-only workflow audit via `conservation_workflow_audit_append` RPC.
class WorkflowAuditRepository {
  WorkflowAuditRepository(this._client);

  final SupabaseClient _client;
  static const _table = 'conservation_workflow_audit';
  static const _rpc = 'conservation_workflow_audit_append';

  Future<String> append({
    required String siteId,
    required WorkflowAuditEntityType entityType,
    required String entityId,
    required String action,
    String? fromStatus,
    String? toStatus,
    String? notes,
    Map<String, dynamic> metadata = const {},
  }) async {
    final id = await _client.rpc(
      _rpc,
      params: {
        'p_site_id': siteId,
        'p_entity_type': entityType.dbValue,
        'p_entity_id': entityId,
        'p_action': action,
        'p_from_status': fromStatus,
        'p_to_status': toStatus,
        'p_notes': notes,
        'p_metadata': metadata,
      },
    );
    return id as String;
  }

  /// Bounded list for an entity (newest first).
  Future<List<WorkflowAuditEntry>> listByEntity({
    required WorkflowAuditEntityType entityType,
    required String entityId,
    int limit = 50,
  }) async {
    final rows = await _client
        .from(_table)
        .select()
        .eq('entity_type', entityType.dbValue)
        .eq('entity_id', entityId)
        .order('created_at', ascending: false)
        .limit(limit);
    return (rows as List)
        .map(
          (e) => WorkflowAuditEntry.fromJson(
            Map<String, dynamic>.from(e as Map),
          ),
        )
        .toList();
  }
}
