enum WeatherDatasetStatus {
  draft('draft'),
  approved('approved'),
  rejected('rejected'),
  archived('archived');

  const WeatherDatasetStatus(this.dbValue);
  final String dbValue;

  static WeatherDatasetStatus fromDb(String v) =>
      WeatherDatasetStatus.values.firstWhere(
        (e) => e.dbValue == v,
        orElse: () => WeatherDatasetStatus.draft,
      );

  bool get isApproved => this == WeatherDatasetStatus.approved;
}

class WeatherDataset {
  const WeatherDataset({
    required this.id,
    required this.organizationId,
    required this.locationLabel,
    required this.source,
    required this.periodStart,
    required this.periodEnd,
    required this.quality,
    required this.status,
    this.siteId,
    this.sourceRef,
    this.importedAt,
    this.approvedBy,
    this.approvedAt,
    this.notes,
  });

  final String id;
  final String organizationId;
  final String? siteId;
  final String locationLabel;
  final String source;
  final String? sourceRef;
  final DateTime periodStart;
  final DateTime periodEnd;
  final String quality;
  final WeatherDatasetStatus status;
  final DateTime? importedAt;
  final String? approvedBy;
  final DateTime? approvedAt;
  final String? notes;

  factory WeatherDataset.fromJson(Map<String, dynamic> json) {
    return WeatherDataset(
      id: json['id'] as String,
      organizationId: json['organization_id'] as String,
      siteId: json['site_id'] as String?,
      locationLabel: json['location_label'] as String,
      source: json['source'] as String,
      sourceRef: json['source_ref'] as String?,
      periodStart: DateTime.parse(json['period_start'] as String),
      periodEnd: DateTime.parse(json['period_end'] as String),
      quality: json['quality'] as String? ?? 'unknown',
      status: WeatherDatasetStatus.fromDb(json['status'] as String? ?? 'draft'),
      importedAt: json['imported_at'] != null
          ? DateTime.parse(json['imported_at'] as String)
          : null,
      approvedBy: json['approved_by'] as String?,
      approvedAt: json['approved_at'] != null
          ? DateTime.parse(json['approved_at'] as String)
          : null,
      notes: json['notes'] as String?,
    );
  }
}

class WeatherObservation {
  const WeatherObservation({
    required this.id,
    required this.datasetId,
    required this.periodStart,
    required this.periodEnd,
    this.hdd,
    this.cdd,
    this.meanTempC,
    this.extra = const {},
  });

  final String id;
  final String datasetId;
  final DateTime periodStart;
  final DateTime periodEnd;
  final double? hdd;
  final double? cdd;
  final double? meanTempC;
  final Map<String, dynamic> extra;

  factory WeatherObservation.fromJson(Map<String, dynamic> json) {
    return WeatherObservation(
      id: json['id'] as String,
      datasetId: json['dataset_id'] as String,
      periodStart: DateTime.parse(json['period_start'] as String),
      periodEnd: DateTime.parse(json['period_end'] as String),
      hdd: (json['hdd'] as num?)?.toDouble(),
      cdd: (json['cdd'] as num?)?.toDouble(),
      meanTempC: (json['mean_temp_c'] as num?)?.toDouble(),
      extra: Map<String, dynamic>.from((json['extra'] as Map?) ?? const {}),
    );
  }
}
