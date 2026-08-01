class NormalizationModel {
  const NormalizationModel({
    required this.id,
    required this.organizationId,
    required this.siteId,
    required this.utilityType,
    required this.method,
    required this.trainingPeriodStart,
    required this.trainingPeriodEnd,
    required this.dependentVariable,
    required this.sampleCount,
    required this.confidence,
    required this.modelVersion,
    required this.status,
    required this.qualityGatePassed,
    this.weatherSensitive = false,
    this.weatherVariables = const [],
    this.occupancyVariables = const [],
    this.weatherDatasetId,
    this.goodnessOfFit,
    this.coefficients = const {},
    this.qualityGateFailures = const [],
    this.warnings = const [],
    this.calculatedAt,
    this.createdBy,
    this.approvedBy,
    this.approvedAt,
    this.notes,
  });

  final String id;
  final String organizationId;
  final String siteId;
  final String utilityType;
  final bool weatherSensitive;
  final String method;
  final DateTime trainingPeriodStart;
  final DateTime trainingPeriodEnd;
  final String dependentVariable;
  final List<String> weatherVariables;
  final List<String> occupancyVariables;
  final String? weatherDatasetId;
  final int sampleCount;
  final double? goodnessOfFit;
  final String confidence;
  final int modelVersion;
  final Map<String, dynamic> coefficients;
  final String status;
  final bool qualityGatePassed;
  final List<dynamic> qualityGateFailures;
  final List<dynamic> warnings;
  final DateTime? calculatedAt;
  final String? createdBy;
  final String? approvedBy;
  final DateTime? approvedAt;
  final String? notes;

  factory NormalizationModel.fromJson(Map<String, dynamic> json) {
    return NormalizationModel(
      id: json['id'] as String,
      organizationId: json['organization_id'] as String,
      siteId: json['site_id'] as String,
      utilityType: json['utility_type'] as String,
      weatherSensitive: json['weather_sensitive'] as bool? ?? false,
      method: json['method'] as String,
      trainingPeriodStart:
          DateTime.parse(json['training_period_start'] as String),
      trainingPeriodEnd: DateTime.parse(json['training_period_end'] as String),
      dependentVariable: json['dependent_variable'] as String,
      weatherVariables: List<String>.from(
        (json['weather_variables'] as List?) ?? const [],
      ),
      occupancyVariables: List<String>.from(
        (json['occupancy_variables'] as List?) ?? const [],
      ),
      weatherDatasetId: json['weather_dataset_id'] as String?,
      sampleCount: json['sample_count'] as int? ?? 0,
      goodnessOfFit: (json['goodness_of_fit'] as num?)?.toDouble(),
      confidence: json['confidence'] as String? ?? 'low',
      modelVersion: json['model_version'] as int? ?? 1,
      coefficients: Map<String, dynamic>.from(
        (json['coefficients'] as Map?) ?? const {},
      ),
      status: json['status'] as String? ?? 'draft',
      qualityGatePassed: json['quality_gate_passed'] as bool? ?? false,
      qualityGateFailures:
          List<dynamic>.from((json['quality_gate_failures'] as List?) ?? const []),
      warnings: List<dynamic>.from((json['warnings'] as List?) ?? const []),
      calculatedAt: json['calculated_at'] != null
          ? DateTime.parse(json['calculated_at'] as String)
          : null,
      createdBy: json['created_by'] as String?,
      approvedBy: json['approved_by'] as String?,
      approvedAt: json['approved_at'] != null
          ? DateTime.parse(json['approved_at'] as String)
          : null,
      notes: json['notes'] as String?,
    );
  }
}

class NormalizedResult {
  const NormalizedResult({
    required this.id,
    required this.siteId,
    required this.utilityType,
    required this.periodStart,
    required this.periodEnd,
    required this.actualConsumption,
    required this.unitCode,
    required this.capabilityLevel,
    required this.status,
    required this.reliability,
    this.modelId,
    this.normalizedConsumption,
    this.weatherAdjustedBaseline,
    this.occupancyAdjustedBaseline,
    this.intensityValue,
    this.intensityUnit,
    this.lineage = const {},
    this.warnings = const [],
    this.calculatedAt,
  });

  final String id;
  final String siteId;
  final String? modelId;
  final String utilityType;
  final DateTime periodStart;
  final DateTime periodEnd;

  /// Always preserved — never replaced by normalized value.
  final double actualConsumption;
  final double? normalizedConsumption;
  final double? weatherAdjustedBaseline;
  final double? occupancyAdjustedBaseline;
  final double? intensityValue;
  final String? intensityUnit;
  final String capabilityLevel;
  final String unitCode;
  final String status;
  final String reliability;
  final Map<String, dynamic> lineage;
  final List<dynamic> warnings;
  final DateTime? calculatedAt;

  factory NormalizedResult.fromJson(Map<String, dynamic> json) {
    return NormalizedResult(
      id: json['id'] as String,
      siteId: json['site_id'] as String,
      modelId: json['model_id'] as String?,
      utilityType: json['utility_type'] as String,
      periodStart: DateTime.parse(json['period_start'] as String),
      periodEnd: DateTime.parse(json['period_end'] as String),
      actualConsumption: (json['actual_consumption'] as num).toDouble(),
      normalizedConsumption:
          (json['normalized_consumption'] as num?)?.toDouble(),
      weatherAdjustedBaseline:
          (json['weather_adjusted_baseline'] as num?)?.toDouble(),
      occupancyAdjustedBaseline:
          (json['occupancy_adjusted_baseline'] as num?)?.toDouble(),
      intensityValue: (json['intensity_value'] as num?)?.toDouble(),
      intensityUnit: json['intensity_unit'] as String?,
      capabilityLevel: json['capability_level'] as String? ?? 'A',
      unitCode: json['unit_code'] as String,
      status: json['status'] as String? ?? 'computed',
      reliability: json['reliability'] as String? ?? 'ok',
      lineage: Map<String, dynamic>.from((json['lineage'] as Map?) ?? const {}),
      warnings: List<dynamic>.from((json['warnings'] as List?) ?? const []),
      calculatedAt: json['calculated_at'] != null
          ? DateTime.parse(json['calculated_at'] as String)
          : null,
    );
  }
}
