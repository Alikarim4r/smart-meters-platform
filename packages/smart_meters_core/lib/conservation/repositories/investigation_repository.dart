import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/investigation_lifecycle.dart';
import '../models/conservation_investigation.dart';

/// CRUD for `conservation_investigations`.
///
/// Assignee approved + site access validation belongs at the app layer;
/// this repository persists after callers validate.
class InvestigationRepository {
  InvestigationRepository(this._client);

  final SupabaseClient _client;
  static const _table = 'conservation_investigations';

  Future<ConservationInvestigation> create({
    required String opportunityId,
    required String siteId,
    String? createdBy,
    String? notes,
  }) async {
    final inserted = await _client
        .from(_table)
        .insert({
          'opportunity_id': opportunityId,
          'site_id': siteId,
          'investigation_status': InvestigationStatus.open.dbValue,
          if (createdBy != null) 'created_by': createdBy,
          if (notes != null) 'notes': notes,
        })
        .select()
        .single();
    return ConservationInvestigation.fromJson(
      Map<String, dynamic>.from(inserted),
    );
  }

  /// Assign investigation. Caller must validate assignee approved + site access.
  Future<ConservationInvestigation> assign({
    required String id,
    required String assignedTo,
    required String assignedBy,
  }) async {
    final existing = await _get(id);
    InvestigationLifecycle.assertCanTransition(
      existing.investigationStatus,
      InvestigationStatus.assigned,
    );
    final updated = await _client
        .from(_table)
        .update({
          'assigned_to': assignedTo,
          'assigned_by': assignedBy,
          'assigned_at': DateTime.now().toUtc().toIso8601String(),
          'investigation_status': InvestigationStatus.assigned.dbValue,
        })
        .eq('id', id)
        .select()
        .single();
    return ConservationInvestigation.fromJson(
      Map<String, dynamic>.from(updated),
    );
  }

  Future<ConservationInvestigation> updateFindings({
    required String id,
    String? findingSummary,
    String? possibleCause,
    String? proposedCause,
    String? notes,
    bool markInProgress = true,
  }) async {
    final existing = await _get(id);
    final patch = <String, dynamic>{
      if (findingSummary != null) 'finding_summary': findingSummary,
      if (possibleCause != null) 'possible_cause': possibleCause,
      if (proposedCause != null) 'proposed_cause': proposedCause,
      if (notes != null) 'notes': notes,
    };
    if (markInProgress &&
        existing.investigationStatus != InvestigationStatus.completed &&
        existing.investigationStatus != InvestigationStatus.cancelled) {
      if (existing.investigationStatus != InvestigationStatus.inProgress) {
        InvestigationLifecycle.assertCanTransition(
          existing.investigationStatus,
          InvestigationStatus.inProgress,
        );
        patch['investigation_status'] = InvestigationStatus.inProgress.dbValue;
        if (existing.investigationStartedAt == null) {
          patch['investigation_started_at'] =
              DateTime.now().toUtc().toIso8601String();
        }
      }
    }
    final updated =
        await _client.from(_table).update(patch).eq('id', id).select().single();
    return ConservationInvestigation.fromJson(
      Map<String, dynamic>.from(updated),
    );
  }

  /// Technician-friendly proposed cause (does not set confirmed_cause).
  Future<ConservationInvestigation> setProposedCause({
    required String id,
    required String proposedCause,
  }) async {
    final updated = await _client
        .from(_table)
        .update({'proposed_cause': proposedCause})
        .eq('id', id)
        .select()
        .single();
    return ConservationInvestigation.fromJson(
      Map<String, dynamic>.from(updated),
    );
  }

  /// Human-only confirmed cause — site_admin / super_admin / platform_owner.
  ///
  /// Technicians must use [setProposedCause]. Authority is also enforced by
  /// DB trigger `conservation_inv_confirmed_cause_authority`.
  Future<ConservationInvestigation> confirmCause({
    required String id,
    required ConfirmedCause cause,
    required String confirmedBy,
    DateTime? confirmedAt,
  }) async {
    final at = confirmedAt ?? DateTime.now().toUtc();
    final err = ConservationInvestigation.validateConfirmedCause(
      cause: cause,
      confirmedBy: confirmedBy,
      confirmedAt: at,
    );
    if (err != null) throw StateError(err);

    final updated = await _client
        .from(_table)
        .update({
          'confirmed_cause': cause.dbValue,
          'confirmed_by': confirmedBy,
          'confirmed_at': at.toUtc().toIso8601String(),
        })
        .eq('id', id)
        .select()
        .single();
    return ConservationInvestigation.fromJson(
      Map<String, dynamic>.from(updated),
    );
  }

  Future<ConservationInvestigation> complete(String id) async {
    final existing = await _get(id);
    InvestigationLifecycle.assertCanTransition(
      existing.investigationStatus,
      InvestigationStatus.completed,
    );
    final updated = await _client
        .from(_table)
        .update({
          'investigation_status': InvestigationStatus.completed.dbValue,
          'investigation_completed_at':
              DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', id)
        .select()
        .single();
    return ConservationInvestigation.fromJson(
      Map<String, dynamic>.from(updated),
    );
  }

  Future<List<ConservationInvestigation>> listByOpportunity(
    String opportunityId, {
    int limit = 20,
  }) async {
    final rows = await _client
        .from(_table)
        .select()
        .eq('opportunity_id', opportunityId)
        .order('created_at', ascending: false)
        .limit(limit);
    return (rows as List)
        .map(
          (e) => ConservationInvestigation.fromJson(
            Map<String, dynamic>.from(e as Map),
          ),
        )
        .toList();
  }

  Future<ConservationInvestigation> _get(String id) async {
    final row =
        await _client.from(_table).select().eq('id', id).single();
    return ConservationInvestigation.fromJson(Map<String, dynamic>.from(row));
  }
}
