import '../domain/action_lifecycle.dart';
import '../domain/opportunity_signal_rules.dart';
import '../domain/period_windows.dart';

/// Action type codes (matches DB check).
enum ConservationActionType {
  inspectMeter('inspect_meter'),
  inspectPipeNetwork('inspect_pipe_network'),
  repairLeak('repair_leak'),
  correctReadingMeterSetup('correct_reading_meter_setup'),
  adjustOperatingSchedule('adjust_operating_schedule'),
  hvacMaintenance('hvac_maintenance'),
  adjustSetpoint('adjust_setpoint'),
  inspectIrrigation('inspect_irrigation'),
  meterCalibration('meter_calibration'),
  investigateCop('investigate_cop'),
  other('other');

  const ConservationActionType(this.dbValue);
  final String dbValue;

  static ConservationActionType fromDb(String value) =>
      ConservationActionType.values.firstWhere(
        (e) => e.dbValue == value,
        orElse: () => ConservationActionType.other,
      );
}

/// Corrective action row (`conservation_actions`) — workflow + optional cost.
class ConservationAction {
  const ConservationAction({
    required this.id,
    required this.opportunityId,
    required this.siteId,
    required this.title,
    required this.description,
    required this.actionType,
    required this.priority,
    required this.status,
    this.investigationId,
    this.ownerId,
    this.dueDate,
    this.startedAt,
    this.completedAt,
    this.completionNotes,
    this.implementationCost,
    this.costCurrency,
    this.costSource,
    this.costApproved = false,
    this.createdBy,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String opportunityId;
  final String? investigationId;
  final String siteId;
  final String title;
  final String description;
  final ConservationActionType actionType;
  final String? ownerId;
  final OpportunityPriorityLevel priority;
  final ActionStatus status;
  final DateTime? dueDate;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final String? completionNotes;

  /// Real implementation cost for ROI/Payback. Null → financial N/A (never invent).
  final double? implementationCost;
  final String? costCurrency;
  final String? costSource;
  final bool costApproved;
  final String? createdBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory ConservationAction.fromJson(Map<String, dynamic> json) {
    return ConservationAction(
      id: json['id'] as String,
      opportunityId: json['opportunity_id'] as String,
      investigationId: json['investigation_id'] as String?,
      siteId: json['site_id'] as String,
      title: json['title'] as String,
      description: json['description'] as String? ?? '',
      actionType: ConservationActionType.fromDb(json['action_type'] as String),
      ownerId: json['owner_id'] as String?,
      priority: OpportunityPriorityLevel.fromDb(
        json['priority'] as String? ?? 'medium',
      ),
      status: ActionStatus.fromDb(json['status'] as String? ?? 'open'),
      dueDate: json['due_date'] == null
          ? null
          : dateOnly(DateTime.parse(json['due_date'] as String)),
      startedAt: _parseDt(json['started_at']),
      completedAt: _parseDt(json['completed_at']),
      completionNotes: json['completion_notes'] as String?,
      implementationCost: (json['implementation_cost'] as num?)?.toDouble(),
      costCurrency: json['cost_currency'] as String?,
      costSource: json['cost_source'] as String?,
      costApproved: json['cost_approved'] as bool? ?? false,
      createdBy: json['created_by'] as String?,
      createdAt: _parseDt(json['created_at']),
      updatedAt: _parseDt(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'opportunity_id': opportunityId,
        'investigation_id': investigationId,
        'site_id': siteId,
        'title': title,
        'description': description,
        'action_type': actionType.dbValue,
        'owner_id': ownerId,
        'priority': priority.dbValue,
        'status': status.dbValue,
        'due_date': dueDate == null ? null : _isoDate(dueDate!),
        'started_at': startedAt?.toUtc().toIso8601String(),
        'completed_at': completedAt?.toUtc().toIso8601String(),
        'completion_notes': completionNotes,
        'implementation_cost': implementationCost,
        'cost_currency': costCurrency,
        'cost_source': costSource,
        'cost_approved': costApproved,
        'created_by': createdBy,
        'created_at': createdAt?.toUtc().toIso8601String(),
        'updated_at': updatedAt?.toUtc().toIso8601String(),
      };

  Map<String, dynamic> toInsertJson() => {
        'opportunity_id': opportunityId,
        if (investigationId != null) 'investigation_id': investigationId,
        'site_id': siteId,
        'title': title,
        'description': description,
        'action_type': actionType.dbValue,
        if (ownerId != null) 'owner_id': ownerId,
        'priority': priority.dbValue,
        'status': status.dbValue,
        if (dueDate != null) 'due_date': _isoDate(dueDate!),
        if (implementationCost != null)
          'implementation_cost': implementationCost,
        if (costCurrency != null) 'cost_currency': costCurrency,
        if (costSource != null) 'cost_source': costSource,
        'cost_approved': costApproved,
        if (createdBy != null) 'created_by': createdBy,
      };

  static DateTime? _parseDt(dynamic v) =>
      v == null ? null : DateTime.parse(v as String);

  static String _isoDate(DateTime d) {
    final x = dateOnly(d);
    return '${x.year.toString().padLeft(4, '0')}-'
        '${x.month.toString().padLeft(2, '0')}-'
        '${x.day.toString().padLeft(2, '0')}';
  }
}
