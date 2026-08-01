/// Phase 6 — Unified Data Sources / ingestion (additive, feature-flagged).
library;

export 'flags/platform_feature_flag_keys.dart';
export 'flags/platform_feature_flag_repository.dart';
export 'domain/reading_source.dart';
export 'domain/data_frequency.dart';
export 'domain/capability_matrix.dart';
export 'services/file_fingerprint.dart';
export 'services/import_validation_service.dart';
export 'services/api_ingestion_contract.dart';
export 'services/conflict_policy.dart';
export 'services/source_health_service.dart';
export 'services/notification_dedupe.dart';
export 'services/automation_rule_engine.dart';
export 'services/ai_assistant_service.dart';
export 'services/ocr_suggestion_policy.dart';
export 'services/source_adapters.dart';
export 'services/unified_ingestion_pipeline.dart';
export 'repositories/api_ingestion_repository.dart';
export 'repositories/ingestion_repositories.dart';
