/// Canonical reading source types (check-constrained in DB).
enum ReadingSource {
  manual,
  manualPhoto,
  csvImport,
  excelImport,
  api,
  smartMeter,
  bms,
  iot,
  virtual,
  legacy,
  ocrPhoto;

  String get wireValue => switch (this) {
        ReadingSource.manual => 'manual',
        ReadingSource.manualPhoto => 'manual_photo',
        ReadingSource.csvImport => 'csv_import',
        ReadingSource.excelImport => 'excel_import',
        ReadingSource.api => 'api',
        ReadingSource.smartMeter => 'smart_meter',
        ReadingSource.bms => 'bms',
        ReadingSource.iot => 'iot',
        ReadingSource.virtual => 'virtual',
        ReadingSource.legacy => 'legacy',
        ReadingSource.ocrPhoto => 'ocr_photo',
      };

  static ReadingSource? tryParse(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    for (final v in ReadingSource.values) {
      if (v.wireValue == raw) return v;
    }
    return null;
  }

  /// Historical NULL / missing source → legacy (documented policy).
  static ReadingSource resolveLegacySafe(String? raw) =>
      tryParse(raw) ?? ReadingSource.legacy;

  bool get isManualFamily =>
      this == ReadingSource.manual ||
      this == ReadingSource.manualPhoto ||
      this == ReadingSource.legacy ||
      this == ReadingSource.ocrPhoto;

  bool get isAutomated =>
      this == ReadingSource.api ||
      this == ReadingSource.smartMeter ||
      this == ReadingSource.bms ||
      this == ReadingSource.iot;
}
