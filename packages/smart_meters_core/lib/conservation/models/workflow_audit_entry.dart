/// Workflow audit entity types (matches DB check).
enum WorkflowAuditEntityType {
  opportunity('opportunity'),
  investigation('investigation'),
  action('action'),
  evidence('evidence');

  const WorkflowAuditEntityType(this.dbValue);
  final String dbValue;

  static WorkflowAuditEntityType fromDb(String value) =>
      WorkflowAuditEntityType.values.firstWhere(
        (e) => e.dbValue == value,
        orElse: () => WorkflowAuditEntityType.opportunity,
      );
}

/// Append-only workflow audit row (`conservation_workflow_audit`).
class WorkflowAuditEntry {
  const WorkflowAuditEntry({
    required this.id,
    required this.siteId,
    required this.entityType,
    required this.entityId,
    required this.action,
    required this.metadata,
    required this.createdAt,
    this.actorId,
    this.fromStatus,
    this.toStatus,
    this.notes,
  });

  final String id;
  final String siteId;
  final WorkflowAuditEntityType entityType;
  final String entityId;
  final String? actorId;
  final String action;
  final String? fromStatus;
  final String? toStatus;
  final String? notes;
  final Map<String, dynamic> metadata;
  final DateTime createdAt;

  factory WorkflowAuditEntry.fromJson(Map<String, dynamic> json) {
    return WorkflowAuditEntry(
      id: json['id'] as String,
      siteId: json['site_id'] as String,
      entityType:
          WorkflowAuditEntityType.fromDb(json['entity_type'] as String),
      entityId: json['entity_id'] as String,
      actorId: json['actor_id'] as String?,
      action: json['action'] as String,
      fromStatus: json['from_status'] as String?,
      toStatus: json['to_status'] as String?,
      notes: json['notes'] as String?,
      metadata: Map<String, dynamic>.from(
        (json['metadata'] as Map?) ?? const {},
      ),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'site_id': siteId,
        'entity_type': entityType.dbValue,
        'entity_id': entityId,
        'actor_id': actorId,
        'action': action,
        'from_status': fromStatus,
        'to_status': toStatus,
        'notes': notes,
        'metadata': metadata,
        'created_at': createdAt.toUtc().toIso8601String(),
      };
}
