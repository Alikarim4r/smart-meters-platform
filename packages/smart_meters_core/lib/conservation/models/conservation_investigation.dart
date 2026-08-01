import '../domain/investigation_lifecycle.dart';

/// Investigation row (`conservation_investigations`).
///
/// [proposedCause] is technician-friendly (free text). [confirmedCause] is
/// human-approved only by site_admin / super_admin / platform_owner
/// (DB trigger `conservation_inv_confirmed_cause_authority`).
class ConservationInvestigation {
  const ConservationInvestigation({
    required this.id,
    required this.opportunityId,
    required this.siteId,
    required this.investigationStatus,
    this.assignedTo,
    this.assignedBy,
    this.assignedAt,
    this.investigationStartedAt,
    this.investigationCompletedAt,
    this.findingSummary,
    this.possibleCause,
    this.proposedCause,
    this.confirmedCause,
    this.confirmedBy,
    this.confirmedAt,
    this.notes,
    this.createdBy,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String opportunityId;
  final String siteId;
  final String? assignedTo;
  final String? assignedBy;
  final DateTime? assignedAt;
  final InvestigationStatus investigationStatus;
  final DateTime? investigationStartedAt;
  final DateTime? investigationCompletedAt;
  final String? findingSummary;
  final String? possibleCause;

  /// Technician / investigator proposed cause (free text). Distinct from
  /// [confirmedCause].
  final String? proposedCause;

  /// Human-confirmed only (site_admin / super / owner). Requires
  /// [confirmedBy] + [confirmedAt]. Technicians cannot set this.
  final ConfirmedCause? confirmedCause;
  final String? confirmedBy;
  final DateTime? confirmedAt;
  final String? notes;
  final String? createdBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory ConservationInvestigation.fromJson(Map<String, dynamic> json) {
    return ConservationInvestigation(
      id: json['id'] as String,
      opportunityId: json['opportunity_id'] as String,
      siteId: json['site_id'] as String,
      assignedTo: json['assigned_to'] as String?,
      assignedBy: json['assigned_by'] as String?,
      assignedAt: _parseDt(json['assigned_at']),
      investigationStatus: InvestigationStatus.fromDb(
        json['investigation_status'] as String? ?? 'open',
      ),
      investigationStartedAt: _parseDt(json['investigation_started_at']),
      investigationCompletedAt: _parseDt(json['investigation_completed_at']),
      findingSummary: json['finding_summary'] as String?,
      possibleCause: json['possible_cause'] as String?,
      proposedCause: json['proposed_cause'] as String?,
      confirmedCause: json['confirmed_cause'] == null
          ? null
          : ConfirmedCause.fromDb(json['confirmed_cause'] as String),
      confirmedBy: json['confirmed_by'] as String?,
      confirmedAt: _parseDt(json['confirmed_at']),
      notes: json['notes'] as String?,
      createdBy: json['created_by'] as String?,
      createdAt: _parseDt(json['created_at']),
      updatedAt: _parseDt(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'opportunity_id': opportunityId,
        'site_id': siteId,
        'assigned_to': assignedTo,
        'assigned_by': assignedBy,
        'assigned_at': assignedAt?.toUtc().toIso8601String(),
        'investigation_status': investigationStatus.dbValue,
        'investigation_started_at':
            investigationStartedAt?.toUtc().toIso8601String(),
        'investigation_completed_at':
            investigationCompletedAt?.toUtc().toIso8601String(),
        'finding_summary': findingSummary,
        'possible_cause': possibleCause,
        'proposed_cause': proposedCause,
        'confirmed_cause': confirmedCause?.dbValue,
        'confirmed_by': confirmedBy,
        'confirmed_at': confirmedAt?.toUtc().toIso8601String(),
        'notes': notes,
        'created_by': createdBy,
        'created_at': createdAt?.toUtc().toIso8601String(),
        'updated_at': updatedAt?.toUtc().toIso8601String(),
      };

  Map<String, dynamic> toInsertJson() => {
        'opportunity_id': opportunityId,
        'site_id': siteId,
        if (assignedTo != null) 'assigned_to': assignedTo,
        if (assignedBy != null) 'assigned_by': assignedBy,
        if (assignedAt != null)
          'assigned_at': assignedAt!.toUtc().toIso8601String(),
        'investigation_status': investigationStatus.dbValue,
        if (findingSummary != null) 'finding_summary': findingSummary,
        if (possibleCause != null) 'possible_cause': possibleCause,
        if (proposedCause != null) 'proposed_cause': proposedCause,
        if (notes != null) 'notes': notes,
        if (createdBy != null) 'created_by': createdBy,
      };

  /// Validates human-only confirmed cause (actor + timestamp required).
  static String? validateConfirmedCause({
    required ConfirmedCause? cause,
    required String? confirmedBy,
    required DateTime? confirmedAt,
  }) {
    if (cause == null) {
      if (confirmedBy != null || confirmedAt != null) {
        return 'confirmed_by/confirmed_at require confirmed_cause';
      }
      return null;
    }
    if (confirmedBy == null || confirmedBy.trim().isEmpty) {
      return 'confirmed_cause requires confirmedBy (human only)';
    }
    if (confirmedAt == null) {
      return 'confirmed_cause requires confirmedAt (human only)';
    }
    return null;
  }

  static DateTime? _parseDt(dynamic v) =>
      v == null ? null : DateTime.parse(v as String);
}
