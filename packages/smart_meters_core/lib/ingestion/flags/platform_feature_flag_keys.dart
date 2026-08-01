/// Platform / integration feature flags (Phase 6).
/// Missing DB row or enabled=false = OFF. Never auto-enabled.
abstract final class PlatformFeatureFlags {
  static const unifiedIngestion = 'unified_ingestion';
  static const fileImport = 'file_import';
  static const apiIngestion = 'api_ingestion';
  static const smartMeterSources = 'smart_meter_sources';
  static const bmsSources = 'bms_sources';
  static const ingestionJobs = 'ingestion_jobs';
  static const sourceHealth = 'source_health';
  static const notificationCenter = 'notification_center';
  static const automationRules = 'automation_rules';
  static const aiAssistant = 'ai_assistant';
  static const ocrReadiness = 'ocr_readiness';

  static const all = <String>[
    unifiedIngestion,
    fileImport,
    apiIngestion,
    smartMeterSources,
    bmsSources,
    ingestionJobs,
    sourceHealth,
    notificationCenter,
    automationRules,
    aiAssistant,
    ocrReadiness,
  ];
}
