import '../domain/opportunity_lifecycle.dart';
import '../domain/opportunity_signal_rules.dart';
import '../domain/period_windows.dart';

/// Conservation opportunity row (`conservation_opportunities`).
///
/// Potential issue requiring investigation — **not** a Confirmed Cause and
/// **not** a Verified Saving.
class ConservationOpportunity {
  const ConservationOpportunity({
    required this.id,
    required this.siteId,
    required this.utilityType,
    required this.origin,
    required this.sourceType,
    required this.sourceFingerprint,
    required this.title,
    required this.description,
    required this.detectedPeriodStart,
    required this.detectedPeriodEnd,
    required this.confidenceScore,
    required this.priority,
    required this.status,
    required this.possibleCauses,
    required this.suggestedInvestigations,
    required this.sourceSnapshot,
    required this.ruleVersion,
    required this.detectedAt,
    this.meterId,
    this.balanceGroupId,
    this.unitCode,
    /// Potential excess / quantity at risk — NEVER Saving / Verified Saving.
    this.estimatedWasteQuantity,
    this.createdBy,
    this.createdAt,
    this.updatedAt,
    this.closedAt,
    this.resolutionReason,
    this.dismissedBy,
    this.dismissedAt,
    this.dismissReason,
    this.dismissNotes,
    this.followUpStart,
    this.followUpEnd,
  });

  final String id;
  final String siteId;
  final String? meterId;
  final String? balanceGroupId;
  final String utilityType;
  final OpportunityOrigin origin;
  final OpportunitySourceType sourceType;
  final String sourceFingerprint;
  final String title;
  final String description;
  final DateTime detectedPeriodStart;
  final DateTime detectedPeriodEnd;
  final String? unitCode;

  /// Potential excess / quantity at risk (column name historical).
  /// Never treat as Saving or Verified Saving.
  final double? estimatedWasteQuantity;

  final int confidenceScore;
  final OpportunityPriorityLevel priority;
  final OpportunityStatus status;
  final List<String> possibleCauses;
  final List<String> suggestedInvestigations;
  final Map<String, dynamic> sourceSnapshot;
  final String ruleVersion;
  final String? createdBy;
  final DateTime detectedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? closedAt;
  final String? resolutionReason;
  final String? dismissedBy;
  final DateTime? dismissedAt;
  final OpportunityDismissReason? dismissReason;
  final String? dismissNotes;
  final DateTime? followUpStart;
  final DateTime? followUpEnd;

  /// Display label for [estimatedWasteQuantity] — Potential Excess only.
  static const potentialExcessLabel = 'Potential Excess';

  /// Forbidden product labels (Phase 4 territory).
  static const forbiddenSavingLabels = <String>[
    'Saving',
    'Verified Saving',
    'Estimated Saving',
  ];

  factory ConservationOpportunity.fromJson(Map<String, dynamic> json) {
    return ConservationOpportunity(
      id: json['id'] as String,
      siteId: json['site_id'] as String,
      meterId: json['meter_id'] as String?,
      balanceGroupId: json['balance_group_id'] as String?,
      utilityType: json['utility_type'] as String,
      origin: OpportunityOrigin.fromDb(
        json['origin'] as String? ?? 'automatic',
      ),
      sourceType: OpportunitySourceType.fromDb(json['source_type'] as String),
      sourceFingerprint: json['source_fingerprint'] as String,
      title: json['title'] as String,
      description: json['description'] as String? ?? '',
      detectedPeriodStart: DateTime.parse(json['detected_period_start'] as String),
      detectedPeriodEnd: DateTime.parse(json['detected_period_end'] as String),
      unitCode: json['unit_code'] as String?,
      estimatedWasteQuantity:
          (json['estimated_waste_quantity'] as num?)?.toDouble(),
      confidenceScore: json['confidence_score'] as int? ?? 0,
      priority: OpportunityPriorityLevel.fromDb(
        json['priority'] as String? ?? 'medium',
      ),
      status: OpportunityStatus.fromDb(json['status'] as String? ?? 'detected'),
      possibleCauses: _stringList(json['possible_causes']),
      suggestedInvestigations: _stringList(json['suggested_investigations']),
      sourceSnapshot: Map<String, dynamic>.from(
        (json['source_snapshot'] as Map?) ?? const {},
      ),
      ruleVersion:
          json['rule_version'] as String? ?? OpportunitySignalRules.defaultRuleVersion,
      createdBy: json['created_by'] as String?,
      detectedAt: json['detected_at'] == null
          ? DateTime.now().toUtc()
          : DateTime.parse(json['detected_at'] as String),
      createdAt: _parseDt(json['created_at']),
      updatedAt: _parseDt(json['updated_at']),
      closedAt: _parseDt(json['closed_at']),
      resolutionReason: json['resolution_reason'] as String?,
      dismissedBy: json['dismissed_by'] as String?,
      dismissedAt: _parseDt(json['dismissed_at']),
      dismissReason: json['dismiss_reason'] == null
          ? null
          : OpportunityDismissReason.fromDb(json['dismiss_reason'] as String),
      dismissNotes: json['dismiss_notes'] as String?,
      followUpStart: _parseDate(json['follow_up_start']),
      followUpEnd: _parseDate(json['follow_up_end']),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'site_id': siteId,
        'meter_id': meterId,
        'balance_group_id': balanceGroupId,
        'utility_type': utilityType,
        'origin': origin.dbValue,
        'source_type': sourceType.dbValue,
        'source_fingerprint': sourceFingerprint,
        'title': title,
        'description': description,
        'detected_period_start': _isoDate(detectedPeriodStart),
        'detected_period_end': _isoDate(detectedPeriodEnd),
        'unit_code': unitCode,
        'estimated_waste_quantity': estimatedWasteQuantity,
        'confidence_score': confidenceScore,
        'priority': priority.dbValue,
        'status': status.dbValue,
        'possible_causes': possibleCauses,
        'suggested_investigations': suggestedInvestigations,
        'source_snapshot': sourceSnapshot,
        'rule_version': ruleVersion,
        'created_by': createdBy,
        'detected_at': detectedAt.toUtc().toIso8601String(),
        'created_at': createdAt?.toUtc().toIso8601String(),
        'updated_at': updatedAt?.toUtc().toIso8601String(),
        'closed_at': closedAt?.toUtc().toIso8601String(),
        'resolution_reason': resolutionReason,
        'dismissed_by': dismissedBy,
        'dismissed_at': dismissedAt?.toUtc().toIso8601String(),
        'dismiss_reason': dismissReason?.dbValue,
        'dismiss_notes': dismissNotes,
        'follow_up_start':
            followUpStart == null ? null : _isoDate(followUpStart!),
        'follow_up_end': followUpEnd == null ? null : _isoDate(followUpEnd!),
      };

  /// Payload for insert (omit id / timestamps managed by DB).
  Map<String, dynamic> toInsertJson() => {
        'site_id': siteId,
        if (meterId != null) 'meter_id': meterId,
        if (balanceGroupId != null) 'balance_group_id': balanceGroupId,
        'utility_type': utilityType,
        'origin': origin.dbValue,
        'source_type': sourceType.dbValue,
        'source_fingerprint': sourceFingerprint,
        'title': title,
        'description': description,
        'detected_period_start': _isoDate(detectedPeriodStart),
        'detected_period_end': _isoDate(detectedPeriodEnd),
        if (unitCode != null) 'unit_code': unitCode,
        if (estimatedWasteQuantity != null)
          'estimated_waste_quantity': estimatedWasteQuantity,
        'confidence_score': confidenceScore,
        'priority': priority.dbValue,
        'status': status.dbValue,
        'possible_causes': possibleCauses,
        'suggested_investigations': suggestedInvestigations,
        'source_snapshot': sourceSnapshot,
        'rule_version': ruleVersion,
        if (createdBy != null) 'created_by': createdBy,
      };

  static List<String> _stringList(dynamic v) {
    if (v is! List) return const [];
    return v.map((e) => e.toString()).toList();
  }

  static DateTime? _parseDt(dynamic v) =>
      v == null ? null : DateTime.parse(v as String);

  static DateTime? _parseDate(dynamic v) =>
      v == null ? null : dateOnly(DateTime.parse(v as String));

  static String _isoDate(DateTime d) {
    final x = dateOnly(d);
    return '${x.year.toString().padLeft(4, '0')}-'
        '${x.month.toString().padLeft(2, '0')}-'
        '${x.day.toString().padLeft(2, '0')}';
  }
}
