import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/action_lifecycle.dart';
import '../domain/opportunity_signal_rules.dart';
import '../domain/period_windows.dart';
import '../models/conservation_action.dart';

/// CRUD for `conservation_actions`.
class ActionRepository {
  ActionRepository(this._client);

  final SupabaseClient _client;
  static const _table = 'conservation_actions';

  Future<ConservationAction> create({
    required String opportunityId,
    required String siteId,
    required String title,
    required ConservationActionType actionType,
    String description = '',
    String? investigationId,
    String? ownerId,
    OpportunityPriorityLevel priority = OpportunityPriorityLevel.medium,
    DateTime? dueDate,
    String? createdBy,
  }) async {
    final inserted = await _client
        .from(_table)
        .insert({
          'opportunity_id': opportunityId,
          'site_id': siteId,
          'title': title,
          'description': description,
          'action_type': actionType.dbValue,
          if (investigationId != null) 'investigation_id': investigationId,
          if (ownerId != null) 'owner_id': ownerId,
          'priority': priority.dbValue,
          'status': ActionStatus.open.dbValue,
          if (dueDate != null) 'due_date': _isoDate(dueDate),
          if (createdBy != null) 'created_by': createdBy,
        })
        .select()
        .single();
    return ConservationAction.fromJson(Map<String, dynamic>.from(inserted));
  }

  Future<ConservationAction> assign({
    required String id,
    required String ownerId,
  }) async {
    final existing = await _get(id);
    ActionLifecycle.assertCanTransition(existing.status, ActionStatus.assigned);
    final updated = await _client
        .from(_table)
        .update({
          'owner_id': ownerId,
          'status': ActionStatus.assigned.dbValue,
        })
        .eq('id', id)
        .select()
        .single();
    return ConservationAction.fromJson(Map<String, dynamic>.from(updated));
  }

  /// Transition status with Dart-side guard (blocks open → completed).
  Future<ConservationAction> transitionStatus({
    required String id,
    required ActionStatus to,
    String? completionNotes,
  }) async {
    final existing = await _get(id);
    ActionLifecycle.assertCanTransition(existing.status, to);

    final patch = <String, dynamic>{
      'status': to.dbValue,
    };
    if (to == ActionStatus.inProgress && existing.startedAt == null) {
      patch['started_at'] = DateTime.now().toUtc().toIso8601String();
    }
    if (to == ActionStatus.completed) {
      patch['completed_at'] = DateTime.now().toUtc().toIso8601String();
      if (completionNotes != null) patch['completion_notes'] = completionNotes;
    }

    final updated =
        await _client.from(_table).update(patch).eq('id', id).select().single();
    return ConservationAction.fromJson(Map<String, dynamic>.from(updated));
  }

  /// Set real implementation cost. Null cost → ROI/Payback N/A (never invent).
  Future<ConservationAction> updateCost({
    required String id,
    double? implementationCost,
    String? costCurrency,
    String? costSource,
    bool? costApproved,
  }) async {
    if (implementationCost != null && implementationCost < 0) {
      throw ArgumentError('implementation_cost must be >= 0 or null');
    }
    final updated = await _client
        .from(_table)
        .update({
          'implementation_cost': implementationCost,
          if (costCurrency != null) 'cost_currency': costCurrency,
          if (costSource != null) 'cost_source': costSource,
          if (costApproved != null) 'cost_approved': costApproved,
        })
        .eq('id', id)
        .select()
        .single();
    return ConservationAction.fromJson(Map<String, dynamic>.from(updated));
  }

  Future<List<ConservationAction>> listForSite(
    String siteId, {
    List<ActionStatus>? statuses,
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
          (e) => ConservationAction.fromJson(
            Map<String, dynamic>.from(e as Map),
          ),
        )
        .toList();
  }

  Future<List<ConservationAction>> listByOpportunity(
    String opportunityId, {
    int limit = 50,
  }) async {
    final rows = await _client
        .from(_table)
        .select()
        .eq('opportunity_id', opportunityId)
        .order('created_at', ascending: false)
        .limit(limit);
    return (rows as List)
        .map(
          (e) => ConservationAction.fromJson(
            Map<String, dynamic>.from(e as Map),
          ),
        )
        .toList();
  }

  Future<ConservationAction> _get(String id) async {
    final row = await _client.from(_table).select().eq('id', id).single();
    return ConservationAction.fromJson(Map<String, dynamic>.from(row));
  }

  static String _isoDate(DateTime d) {
    final x = dateOnly(d);
    return '${x.year.toString().padLeft(4, '0')}-'
        '${x.month.toString().padLeft(2, '0')}-'
        '${x.day.toString().padLeft(2, '0')}';
  }
}
