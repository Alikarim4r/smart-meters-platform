import '../domain/opportunity_lifecycle.dart';
import '../models/conservation_opportunity.dart';
import '../models/workflow_audit_entry.dart';
import '../repositories/opportunity_repository.dart';
import '../repositories/workflow_audit_repository.dart';

/// Opportunity status transitions with validation + audit append.
class OpportunityWorkflowService {
  OpportunityWorkflowService({
    required OpportunityRepository opportunityRepository,
    required WorkflowAuditRepository auditRepository,
  })  : _opps = opportunityRepository,
        _audit = auditRepository;

  final OpportunityRepository _opps;
  final WorkflowAuditRepository _audit;

  Future<ConservationOpportunity> triage(
    String opportunityId, {
    String? notes,
  }) =>
      _transition(
        opportunityId,
        to: OpportunityStatus.triaged,
        action: 'triage',
        notes: notes,
      );

  Future<ConservationOpportunity> startInvestigation(
    String opportunityId, {
    String? notes,
  }) =>
      _transition(
        opportunityId,
        to: OpportunityStatus.underInvestigation,
        action: 'start_investigation',
        notes: notes,
      );

  Future<ConservationOpportunity> markActionRequired(
    String opportunityId, {
    String? notes,
  }) =>
      _transition(
        opportunityId,
        to: OpportunityStatus.actionRequired,
        action: 'mark_action_required',
        notes: notes,
      );

  Future<ConservationOpportunity> startMonitoring(
    String opportunityId, {
    String? notes,
    DateTime? followUpStart,
    DateTime? followUpEnd,
  }) =>
      _transition(
        opportunityId,
        to: OpportunityStatus.monitoring,
        action: 'start_monitoring',
        notes: notes,
        patch: {
          if (followUpStart != null) 'follow_up_start': _isoDate(followUpStart),
          if (followUpEnd != null) 'follow_up_end': _isoDate(followUpEnd),
        },
      );

  Future<ConservationOpportunity> resolve(
    String opportunityId, {
    String? resolutionReason,
    String? notes,
  }) =>
      _transition(
        opportunityId,
        to: OpportunityStatus.resolved,
        action: 'resolve',
        notes: notes,
        patch: {
          'closed_at': DateTime.now().toUtc().toIso8601String(),
          if (resolutionReason != null) 'resolution_reason': resolutionReason,
        },
      );

  Future<ConservationOpportunity> dismiss(
    String opportunityId, {
    required OpportunityDismissReason reason,
    String? notes,
    String? dismissedBy,
  }) =>
      _transition(
        opportunityId,
        to: OpportunityStatus.dismissed,
        action: 'dismiss',
        notes: notes,
        patch: {
          'dismiss_reason': reason.dbValue,
          'dismiss_notes': notes,
          'dismissed_by': dismissedBy,
          'dismissed_at': DateTime.now().toUtc().toIso8601String(),
          'closed_at': DateTime.now().toUtc().toIso8601String(),
        },
        metadata: {'dismiss_reason': reason.dbValue},
      );

  /// Reopen from resolved/dismissed → detected (clears dismiss fields).
  Future<ConservationOpportunity> reopen(
    String opportunityId, {
    String? notes,
    OpportunityStatus to = OpportunityStatus.detected,
  }) {
    if (to != OpportunityStatus.detected && to != OpportunityStatus.triaged) {
      throw StateError('reopen target must be detected or triaged');
    }
    return _transition(
      opportunityId,
      to: to,
      action: 'reopen',
      notes: notes,
      patch: {
        'closed_at': null,
        'resolution_reason': null,
        'dismiss_reason': null,
        'dismiss_notes': null,
        'dismissed_by': null,
        'dismissed_at': null,
      },
    );
  }

  Future<ConservationOpportunity> _transition(
    String opportunityId, {
    required OpportunityStatus to,
    required String action,
    String? notes,
    Map<String, dynamic> patch = const {},
    Map<String, dynamic> metadata = const {},
  }) async {
    final current = await _opps.getById(opportunityId);
    if (current == null) {
      throw StateError('Opportunity not found: $opportunityId');
    }
    OpportunityLifecycle.assertCanTransition(current.status, to);

    final updated = await _opps.update(opportunityId, {
      'status': to.dbValue,
      ...patch,
    });

    await _audit.append(
      siteId: updated.siteId,
      entityType: WorkflowAuditEntityType.opportunity,
      entityId: updated.id,
      action: action,
      fromStatus: current.status.dbValue,
      toStatus: to.dbValue,
      notes: notes,
      metadata: metadata,
    );

    return updated;
  }

  static String _isoDate(DateTime d) {
    final x = DateTime(d.year, d.month, d.day);
    return '${x.year.toString().padLeft(4, '0')}-'
        '${x.month.toString().padLeft(2, '0')}-'
        '${x.day.toString().padLeft(2, '0')}';
  }
}
