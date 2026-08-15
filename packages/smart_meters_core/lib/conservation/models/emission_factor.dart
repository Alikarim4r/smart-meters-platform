class EmissionFactor {
  const EmissionFactor({
    required this.id,
    required this.organizationId,
    required this.utilityOrFuelType,
    required this.geography,
    required this.factor,
    required this.unitCode,
    required this.co2eUnit,
    required this.source,
    required this.effectiveFrom,
    required this.status,
    this.effectiveTo,
    this.notes,
    this.approvedBy,
    this.approvedAt,
  });

  final String id;
  final String organizationId;
  final String utilityOrFuelType;
  final String geography;
  final double factor;
  final String unitCode;
  final String co2eUnit;
  final String source;
  final DateTime effectiveFrom;
  final DateTime? effectiveTo;
  final String status;
  final String? notes;
  final String? approvedBy;
  final DateTime? approvedAt;

  bool get isActive => status == 'active';

  bool isEffectiveOn(DateTime day) {
    final d = DateTime(day.year, day.month, day.day);
    final from = DateTime(
      effectiveFrom.year,
      effectiveFrom.month,
      effectiveFrom.day,
    );
    if (d.isBefore(from)) return false;
    if (effectiveTo == null) return true;
    final to = DateTime(
      effectiveTo!.year,
      effectiveTo!.month,
      effectiveTo!.day,
    );
    return !d.isAfter(to);
  }

  factory EmissionFactor.fromJson(Map<String, dynamic> json) {
    return EmissionFactor(
      id: json['id'] as String,
      organizationId: json['organization_id'] as String,
      utilityOrFuelType: json['utility_or_fuel_type'] as String,
      geography: json['geography'] as String? ?? 'QA',
      factor: (json['factor'] as num).toDouble(),
      unitCode: json['unit_code'] as String,
      co2eUnit: json['co2e_unit'] as String? ?? 'kgCO2e',
      source: json['source'] as String,
      effectiveFrom: DateTime.parse(json['effective_from'] as String),
      effectiveTo: json['effective_to'] != null
          ? DateTime.parse(json['effective_to'] as String)
          : null,
      status: json['status'] as String? ?? 'draft',
      notes: json['notes'] as String?,
      approvedBy: json['approved_by'] as String?,
      approvedAt: json['approved_at'] != null
          ? DateTime.parse(json['approved_at'] as String)
          : null,
    );
  }
}

enum CarbonQuantityBasis {
  verifiedSaving('verified_saving'),
  estimatedSaving('estimated_saving');

  const CarbonQuantityBasis(this.dbValue);
  final String dbValue;
}

class CarbonResult {
  const CarbonResult({
    required this.id,
    required this.siteId,
    required this.quantityBasis,
    required this.status,
    this.measurementVerificationId,
    this.savingQuantity,
    this.emissionFactorId,
    this.factorValueSnapshot,
    this.factorSourceSnapshot,
    this.factorEffectiveFromSnapshot,
    this.carbonAvoided,
    this.carbonUnit,
    this.lineage = const {},
    this.warnings = const [],
    this.calculatedAt,
  });

  final String id;
  final String siteId;
  final String? measurementVerificationId;
  final CarbonQuantityBasis quantityBasis;
  final double? savingQuantity;
  final String? emissionFactorId;
  final double? factorValueSnapshot;
  final String? factorSourceSnapshot;
  final DateTime? factorEffectiveFromSnapshot;
  final double? carbonAvoided;
  final String? carbonUnit;
  final String status;
  final Map<String, dynamic> lineage;
  final List<dynamic> warnings;
  final DateTime? calculatedAt;

  bool get isNotAvailable =>
      status == 'not_available' ||
      status == 'missing_factor' ||
      status == 'expired_factor';

  factory CarbonResult.fromJson(Map<String, dynamic> json) {
    return CarbonResult(
      id: json['id'] as String,
      siteId: json['site_id'] as String,
      measurementVerificationId: json['measurement_verification_id'] as String?,
      quantityBasis: (json['quantity_basis'] as String?) == 'estimated_saving'
          ? CarbonQuantityBasis.estimatedSaving
          : CarbonQuantityBasis.verifiedSaving,
      savingQuantity: (json['saving_quantity'] as num?)?.toDouble(),
      emissionFactorId: json['emission_factor_id'] as String?,
      factorValueSnapshot: (json['factor_value_snapshot'] as num?)?.toDouble(),
      factorSourceSnapshot: json['factor_source_snapshot'] as String?,
      factorEffectiveFromSnapshot: json['factor_effective_from_snapshot'] != null
          ? DateTime.parse(json['factor_effective_from_snapshot'] as String)
          : null,
      carbonAvoided: (json['carbon_avoided'] as num?)?.toDouble(),
      carbonUnit: json['carbon_unit'] as String?,
      status: json['status'] as String? ?? 'not_available',
      lineage: Map<String, dynamic>.from((json['lineage'] as Map?) ?? const {}),
      warnings: List<dynamic>.from((json['warnings'] as List?) ?? const []),
      calculatedAt: json['calculated_at'] != null
          ? DateTime.parse(json['calculated_at'] as String)
          : null,
    );
  }
}
