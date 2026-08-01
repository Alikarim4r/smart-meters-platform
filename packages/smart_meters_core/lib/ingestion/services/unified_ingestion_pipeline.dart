import '../domain/reading_source.dart';

/// Unified ingestion stages (additive). Manual entry path is not rewritten.
enum IngestionStage {
  adapt,
  validate,
  normalize,
  deduplicate,
  authorize,
  ingest,
  audit,
}

class IngestionCandidate {
  const IngestionCandidate({
    required this.siteId,
    required this.meterId,
    required this.readingDate,
    required this.rawValue,
    required this.source,
    this.sourceSystem,
    this.externalReadingId,
    this.unitCode,
    this.sourceTimestamp,
    this.sourceQuality,
    this.metadata = const {},
  });

  final String siteId;
  final String meterId;
  final DateTime readingDate;
  final double rawValue;
  final ReadingSource source;
  final String? sourceSystem;
  final String? externalReadingId;
  final String? unitCode;
  final DateTime? sourceTimestamp;
  final String? sourceQuality;
  final Map<String, dynamic> metadata;
}

class IngestionStageResult {
  const IngestionStageResult({
    required this.stage,
    required this.ok,
    this.message,
  });

  final IngestionStage stage;
  final bool ok;
  final String? message;
}

class UnifiedIngestionPipeline {
  const UnifiedIngestionPipeline();

  /// Documents stage order. Actual writes go through repositories/RPC.
  List<IngestionStage> get stages => IngestionStage.values;

  List<IngestionStageResult> dryRunValidate(IngestionCandidate c) {
    final out = <IngestionStageResult>[];
    out.add(IngestionStageResult(
      stage: IngestionStage.adapt,
      ok: true,
      message: 'source=${c.source.wireValue}',
    ));
    final valid = c.rawValue >= 0 && c.meterId.isNotEmpty && c.siteId.isNotEmpty;
    out.add(IngestionStageResult(
      stage: IngestionStage.validate,
      ok: valid,
      message: valid ? null : 'invalid_candidate',
    ));
    out.add(const IngestionStageResult(
      stage: IngestionStage.normalize,
      ok: true,
      message: 'DB trigger compute_normalized_reading applies on insert',
    ));
    out.add(const IngestionStageResult(
      stage: IngestionStage.deduplicate,
      ok: true,
      message: 'external_id + meter/date uniqueness',
    ));
    out.add(const IngestionStageResult(
      stage: IngestionStage.authorize,
      ok: true,
      message: 'RLS + can_manage_site enforced at write boundary',
    ));
    out.add(const IngestionStageResult(
      stage: IngestionStage.ingest,
      ok: true,
      message: 'deferred_to_repository',
    ));
    out.add(const IngestionStageResult(
      stage: IngestionStage.audit,
      ok: true,
      message: 'platform_integration_audit',
    ));
    return out;
  }
}
