/// Baseline calculation methods supported in P1D.
enum BaselineCalculationMethod {
  totalPeriod('total_period'),
  averageDaily('average_daily'),
  customFixed('custom_fixed');

  const BaselineCalculationMethod(this.dbValue);
  final String dbValue;

  static BaselineCalculationMethod fromDb(String value) =>
      BaselineCalculationMethod.values.firstWhere(
        (e) => e.dbValue == value,
        orElse: () => BaselineCalculationMethod.totalPeriod,
      );
}

enum ConservationBaselineScopeType {
  site('site'),
  category('category'),
  meter('meter');

  const ConservationBaselineScopeType(this.dbValue);
  final String dbValue;

  static ConservationBaselineScopeType fromDb(String value) =>
      ConservationBaselineScopeType.values.firstWhere(
        (e) => e.dbValue == value,
        orElse: () => ConservationBaselineScopeType.site,
      );
}

enum ConservationBaselineStatus {
  draft('draft'),
  approved('approved'),
  superseded('superseded'),
  archived('archived');

  const ConservationBaselineStatus(this.dbValue);
  final String dbValue;

  static ConservationBaselineStatus fromDb(String value) =>
      ConservationBaselineStatus.values.firstWhere(
        (e) => e.dbValue == value,
        orElse: () => ConservationBaselineStatus.draft,
      );

  bool get isImmutableCore =>
      this == ConservationBaselineStatus.approved ||
      this == ConservationBaselineStatus.superseded ||
      this == ConservationBaselineStatus.archived;
}

/// Quality of meter boundaries used for the reference-period calculation.
enum BaselineBoundaryQuality {
  /// Latest reading strictly before reference_period_start for all meters.
  exactPrePeriod('exact_pre_period'),

  /// At least one meter used first-in-period fallback (not ideal for approval).
  firstInPeriodFallback('first_in_period_fallback'),

  /// Missing valid endpoints.
  insufficient('insufficient'),

  /// custom_fixed — no reading-derived boundary.
  notApplicable('not_applicable');

  const BaselineBoundaryQuality(this.dbValue);
  final String dbValue;

  static BaselineBoundaryQuality? fromDb(String? value) {
    if (value == null || value.isEmpty) return null;
    return BaselineBoundaryQuality.values.firstWhere(
      (e) => e.dbValue == value,
      orElse: () => BaselineBoundaryQuality.insufficient,
    );
  }
}

/// Versioned conservation baseline (reference performance — not a Target).
class ConservationBaseline {
  const ConservationBaseline({
    required this.id,
    required this.siteId,
    required this.scopeType,
    required this.scopeId,
    required this.versionNumber,
    required this.label,
    required this.referencePeriodStart,
    required this.referencePeriodEnd,
    required this.calculationMethod,
    required this.baselineValue,
    required this.unitCode,
    required this.status,
    this.utilityCode,
    this.validFrom,
    this.validTo,
    this.createdBy,
    this.createdAt,
    this.updatedAt,
    this.approvedBy,
    this.approvedAt,
    this.notes,
    this.dataCompleteness,
    this.confidenceScore,
    this.boundaryQuality,
    this.calculationMeta = const {},
  });

  final String id;
  final String siteId;
  final ConservationBaselineScopeType scopeType;
  final String? scopeId;
  final String? utilityCode;
  final int versionNumber;
  final String label;
  final DateTime referencePeriodStart;
  final DateTime referencePeriodEnd;
  final BaselineCalculationMethod calculationMethod;
  final double baselineValue;
  final String unitCode;
  final ConservationBaselineStatus status;
  final DateTime? validFrom;
  final DateTime? validTo;
  final String? createdBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? approvedBy;
  final DateTime? approvedAt;
  final String? notes;
  final double? dataCompleteness;
  final int? confidenceScore;
  final BaselineBoundaryQuality? boundaryQuality;
  final Map<String, dynamic> calculationMeta;

  factory ConservationBaseline.fromJson(Map<String, dynamic> json) {
    final metaRaw = json['calculation_meta'];
    return ConservationBaseline(
      id: json['id'] as String,
      siteId: json['site_id'] as String,
      scopeType: ConservationBaselineScopeType.fromDb(
        json['scope_type'] as String? ?? 'site',
      ),
      scopeId: json['scope_id'] as String?,
      utilityCode: json['utility_code'] as String?,
      versionNumber: json['version_number'] as int? ?? 1,
      label: json['label'] as String? ?? '',
      referencePeriodStart:
          DateTime.parse(json['reference_period_start'] as String),
      referencePeriodEnd: DateTime.parse(json['reference_period_end'] as String),
      calculationMethod: BaselineCalculationMethod.fromDb(
        json['calculation_method'] as String? ?? 'total_period',
      ),
      baselineValue: (json['baseline_value'] as num).toDouble(),
      unitCode: json['unit_code'] as String,
      status: ConservationBaselineStatus.fromDb(
        json['status'] as String? ?? 'draft',
      ),
      validFrom: json['valid_from'] == null
          ? null
          : DateTime.parse(json['valid_from'] as String),
      validTo: json['valid_to'] == null
          ? null
          : DateTime.parse(json['valid_to'] as String),
      createdBy: json['created_by'] as String?,
      createdAt: json['created_at'] == null
          ? null
          : DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] == null
          ? null
          : DateTime.parse(json['updated_at'] as String),
      approvedBy: json['approved_by'] as String?,
      approvedAt: json['approved_at'] == null
          ? null
          : DateTime.parse(json['approved_at'] as String),
      notes: json['notes'] as String?,
      dataCompleteness: json['data_completeness'] == null
          ? null
          : (json['data_completeness'] as num).toDouble(),
      confidenceScore: json['confidence_score'] as int?,
      boundaryQuality:
          BaselineBoundaryQuality.fromDb(json['boundary_quality'] as String?),
      calculationMeta: metaRaw is Map
          ? Map<String, dynamic>.from(metaRaw)
          : const {},
    );
  }
}
