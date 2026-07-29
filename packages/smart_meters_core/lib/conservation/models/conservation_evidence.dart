/// Evidence kind (matches DB check).
enum ConservationEvidenceKind {
  photo('photo'),
  note('note'),
  meterReadingReference('meter_reading_reference'),
  balanceResultReference('balance_result_reference'),
  anomalyReference('anomaly_reference'),
  documentLink('document_link');

  const ConservationEvidenceKind(this.dbValue);
  final String dbValue;

  static ConservationEvidenceKind fromDb(String value) =>
      ConservationEvidenceKind.values.firstWhere(
        (e) => e.dbValue == value,
        orElse: () => ConservationEvidenceKind.note,
      );
}

/// before | after | general — Phase 4 M&V may use before/after later.
enum ConservationEvidencePhase {
  before('before'),
  after('after'),
  general('general');

  const ConservationEvidencePhase(this.dbValue);
  final String dbValue;

  static ConservationEvidencePhase fromDb(String value) =>
      ConservationEvidencePhase.values.firstWhere(
        (e) => e.dbValue == value,
        orElse: () => ConservationEvidencePhase.general,
      );
}

const kConservationEvidenceBucket = 'conservation-evidence';

/// Storage path: `{orgId}/{siteId}/opportunities/{opportunityId}/{fileName}`.
String conservationEvidencePath({
  required String orgId,
  required String siteId,
  required String opportunityId,
  required String fileName,
}) {
  final safe = fileName.trim().replaceAll(RegExp(r'[/\\]+'), '_');
  return '$orgId/$siteId/opportunities/$opportunityId/$safe';
}

/// Evidence metadata row (`conservation_evidence`).
class ConservationEvidence {
  const ConservationEvidence({
    required this.id,
    required this.siteId,
    required this.evidenceKind,
    required this.evidencePhase,
    required this.title,
    required this.referenceJson,
    required this.createdAt,
    this.opportunityId,
    this.investigationId,
    this.actionId,
    this.notes,
    this.storageBucket,
    this.storagePath,
    this.externalUrl,
    this.meterReadingId,
    this.uploadedBy,
  });

  final String id;
  final String siteId;
  final String? opportunityId;
  final String? investigationId;
  final String? actionId;
  final ConservationEvidenceKind evidenceKind;
  final ConservationEvidencePhase evidencePhase;
  final String title;
  final String? notes;
  final String? storageBucket;
  final String? storagePath;
  final String? externalUrl;
  final String? meterReadingId;
  final Map<String, dynamic> referenceJson;
  final String? uploadedBy;
  final DateTime createdAt;

  factory ConservationEvidence.fromJson(Map<String, dynamic> json) {
    return ConservationEvidence(
      id: json['id'] as String,
      siteId: json['site_id'] as String,
      opportunityId: json['opportunity_id'] as String?,
      investigationId: json['investigation_id'] as String?,
      actionId: json['action_id'] as String?,
      evidenceKind:
          ConservationEvidenceKind.fromDb(json['evidence_kind'] as String),
      evidencePhase: ConservationEvidencePhase.fromDb(
        json['evidence_phase'] as String? ?? 'general',
      ),
      title: json['title'] as String? ?? '',
      notes: json['notes'] as String?,
      storageBucket: json['storage_bucket'] as String?,
      storagePath: json['storage_path'] as String?,
      externalUrl: json['external_url'] as String?,
      meterReadingId: json['meter_reading_id'] as String?,
      referenceJson: Map<String, dynamic>.from(
        (json['reference_json'] as Map?) ?? const {},
      ),
      uploadedBy: json['uploaded_by'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'site_id': siteId,
        'opportunity_id': opportunityId,
        'investigation_id': investigationId,
        'action_id': actionId,
        'evidence_kind': evidenceKind.dbValue,
        'evidence_phase': evidencePhase.dbValue,
        'title': title,
        'notes': notes,
        'storage_bucket': storageBucket,
        'storage_path': storagePath,
        'external_url': externalUrl,
        'meter_reading_id': meterReadingId,
        'reference_json': referenceJson,
        'uploaded_by': uploadedBy,
        'created_at': createdAt.toUtc().toIso8601String(),
      };

  Map<String, dynamic> toInsertJson() => {
        'site_id': siteId,
        if (opportunityId != null) 'opportunity_id': opportunityId,
        if (investigationId != null) 'investigation_id': investigationId,
        if (actionId != null) 'action_id': actionId,
        'evidence_kind': evidenceKind.dbValue,
        'evidence_phase': evidencePhase.dbValue,
        'title': title,
        if (notes != null) 'notes': notes,
        if (storageBucket != null) 'storage_bucket': storageBucket,
        if (storagePath != null) 'storage_path': storagePath,
        if (externalUrl != null) 'external_url': externalUrl,
        if (meterReadingId != null) 'meter_reading_id': meterReadingId,
        'reference_json': referenceJson,
        if (uploadedBy != null) 'uploaded_by': uploadedBy,
      };
}
