import 'package:supabase_flutter/supabase_flutter.dart';

import '../catalog/catalog_helpers.dart';
import '../domain/business_date.dart';
import '../domain/correction_validation.dart';
import '../models/alert_models.dart';
import '../models/meter_reading.dart';
import '../models/reading_correction_models.dart';

class ReadingCorrectionRepository {
  ReadingCorrectionRepository(this._client);

  final SupabaseClient _client;

  static const _readingSelect = '''
*,
meters(
  name_en,
  meter_code,
  category_id,
  category,
  source,
  unit,
  meter_categories(code, name_en),
  meter_sources(code, name_en),
  meter_units(code, name_en)
),
sites(name_en, zone_id, zones(id, name_en)),
profiles:entered_by(full_name, email)
''';

  Future<List<AdminReadingRow>> getSubmittedReadingsForAdmin({
    required ReadingCorrectionFilters filters,
  }) async {
    var query = _client.from('meter_readings').select(_readingSelect);

    if (filters.siteId != null) {
      query = query.eq('site_id', filters.siteId!);
    }
    if (filters.fromDate != null) {
      query = query.gte('reading_date', formatBusinessDate(filters.fromDate!));
    }
    if (filters.toDate != null) {
      query = query.lte('reading_date', formatBusinessDate(filters.toDate!));
    }

    final rows = await query
        .order('reading_date', ascending: false)
        .order('entered_at', ascending: false)
        .limit(filters.limit);

    final results = <AdminReadingRow>[];
    for (final row in rows as List) {
      final map = Map<String, dynamic>.from(row as Map);
      final adminRow = _mapAdminReadingRow(map);
      if (adminRow == null) continue;

      if (filters.zoneId != null) {
        final siteJson = map['sites'];
        if (siteJson is Map) {
          final zoneId = siteJson['zone_id'] as String?;
          if (zoneId != filters.zoneId) continue;
        }
      }

      if (filters.categoryId != null) {
        final meterJson = map['meters'];
        if (meterJson is! Map ||
            meterJson['category_id'] != filters.categoryId) {
          continue;
        }
      }

      final auditRows = await _client
          .from('reading_audit_logs')
          .select('action')
          .eq('reading_id', adminRow.readingId);
      final isCorrected = (auditRows as List).any(
        (entry) => (entry as Map)['action'] == 'update',
      );

      final previous = await getPreviousReadingValue(
        meterId: adminRow.meterId,
        readingDate: adminRow.readingDate,
      );
      final alertTypes = _detectReadingAlerts(
        rawValue: adminRow.rawValue,
        previousValue: previous,
        hasPhoto: adminRow.hasPhoto,
      );

      final enriched = AdminReadingRow(
        readingId: adminRow.readingId,
        siteId: adminRow.siteId,
        siteName: adminRow.siteName,
        zoneName: adminRow.zoneName,
        meterId: adminRow.meterId,
        meterName: adminRow.meterName,
        meterCode: adminRow.meterCode,
        categoryName: adminRow.categoryName,
        unitLabel: adminRow.unitLabel,
        readingDate: adminRow.readingDate,
        rawValue: adminRow.rawValue,
        normalizedValue: adminRow.normalizedValue,
        note: adminRow.note,
        imageStoragePath: adminRow.imageStoragePath,
        enteredByName: adminRow.enteredByName,
        enteredByEmail: adminRow.enteredByEmail,
        enteredAt: adminRow.enteredAt,
        isCorrected: isCorrected,
        alertTypes: alertTypes,
      );

      if (!_matchesListFilter(enriched, filters.listFilter)) {
        continue;
      }

      results.add(enriched);
    }
    return results;
  }

  Future<ReadingCorrectionDetails> getReadingDetailsForCorrection(
    String readingId,
  ) async {
    final row = await _client
        .from('meter_readings')
        .select(_readingSelect)
        .eq('id', readingId)
        .single();
    final map = Map<String, dynamic>.from(row);
    final reading = _mapAdminReadingRow(map);
    if (reading == null) {
      throw StateError('Reading not found');
    }

    final previousValue = await getPreviousReadingValue(
      meterId: reading.meterId,
      readingDate: reading.readingDate,
    );
    final nextValue = await getNextReadingValue(
      meterId: reading.meterId,
      readingDate: reading.readingDate,
    );
    final auditHistory = await getReadingAuditHistory(readingId);
    final isCorrected = auditHistory.any(
      (e) => e.action == ReadingAuditAction.update,
    );
    final alertTypes = _detectReadingAlerts(
      rawValue: reading.rawValue,
      previousValue: previousValue,
      hasPhoto: reading.hasPhoto,
    );

    return ReadingCorrectionDetails(
      reading: AdminReadingRow(
        readingId: reading.readingId,
        siteId: reading.siteId,
        siteName: reading.siteName,
        zoneName: reading.zoneName,
        meterId: reading.meterId,
        meterName: reading.meterName,
        meterCode: reading.meterCode,
        categoryName: reading.categoryName,
        unitLabel: reading.unitLabel,
        readingDate: reading.readingDate,
        rawValue: reading.rawValue,
        normalizedValue: reading.normalizedValue,
        note: reading.note,
        imageStoragePath: reading.imageStoragePath,
        enteredByName: reading.enteredByName,
        enteredByEmail: reading.enteredByEmail,
        enteredAt: reading.enteredAt,
        isCorrected: isCorrected,
        alertTypes: alertTypes,
      ),
      previousValue: previousValue,
      nextValue: nextValue,
      auditHistory: auditHistory,
      relatedAlerts: alertTypes,
    );
  }

  Future<ReadingCorrection> correctReading({
    required String readingId,
    required double newValue,
    String? newNote,
    required CorrectionReason reason,
    String? internalComment,
    required String correctedByUserId,
    bool lowerThanPreviousConfirmed = false,
    bool greaterThanNextAcknowledged = false,
  }) async {
    final details = await getReadingDetailsForCorrection(readingId);
    final reading = details.reading;

    final validation = validateReadingCorrection(
      currentValue: reading.rawValue,
      newValue: newValue,
      reason: reason,
      newNote: newNote,
      previousValue: details.previousValue,
      nextValue: details.nextValue,
      lowerThanPreviousConfirmed: lowerThanPreviousConfirmed,
      greaterThanNextAcknowledged: greaterThanNextAcknowledged,
    );
    if (!validation.isValid) {
      throw CorrectionValidationException(
        validation.blockingMessage ?? 'Correction validation failed',
      );
    }

    if (!hasMeaningfulCorrectionChange(
      currentValue: reading.rawValue,
      newValue: newValue,
      currentNote: reading.note,
      newNote: newNote,
    )) {
      throw CorrectionValidationException('No changes to save.');
    }

    final formattedNote = formatCorrectionNote(
      reason: reason,
      internalComment: internalComment,
      newNote: newNote,
    );

    final updated = await _client
        .from('meter_readings')
        .update({'raw_value': newValue, 'note': formattedNote})
        .eq('id', readingId)
        .select('id, raw_value, note, updated_at')
        .single();

    final audit = await _client
        .from('reading_audit_logs')
        .select('id')
        .eq('reading_id', readingId)
        .eq('action', 'update')
        .order('changed_at', ascending: false)
        .limit(1)
        .maybeSingle();

    return ReadingCorrection(
      readingId: readingId,
      meterId: reading.meterId,
      siteId: reading.siteId,
      oldValue: reading.rawValue,
      newValue: newValue,
      oldNote: reading.note,
      newNote: formattedNote,
      reason: reason,
      correctedBy: correctedByUserId,
      correctedAt: DateTime.parse(updated['updated_at'] as String),
      auditId: audit == null ? null : audit['id'] as String,
    );
  }

  Future<List<ReadingAuditEntry>> getReadingAuditHistory(
    String readingId,
  ) async {
    final rows = await _client
        .from('reading_audit_logs')
        .select('*, profiles:changed_by(full_name, email)')
        .eq('reading_id', readingId)
        .order('changed_at', ascending: false);

    return (rows as List).map((row) {
      final map = Map<String, dynamic>.from(row as Map);
      final profile = map['profiles'];
      final note = map['note'] as String?;
      return ReadingAuditEntry(
        id: map['id'] as String,
        readingId: map['reading_id'] as String? ?? readingId,
        action: _parseAuditAction(map['action'] as String),
        oldValue: _toDoubleOrNull(map['old_raw_value']),
        newValue: _toDoubleOrNull(map['new_raw_value']),
        oldNote: null,
        newNote: stripCorrectionMarkers(note),
        reason: parseCorrectionReasonFromNote(note),
        changedByName: profile is Map ? profile['full_name'] as String? : null,
        changedByEmail: profile is Map ? profile['email'] as String? : null,
        changedAt: DateTime.parse(map['changed_at'] as String),
      );
    }).toList();
  }

  Future<double?> getPreviousReadingValue({
    required String meterId,
    required DateTime readingDate,
  }) async {
    final row = await _client
        .from('meter_readings')
        .select('raw_value')
        .eq('meter_id', meterId)
        .lt('reading_date', formatBusinessDate(readingDate))
        .order('reading_date', ascending: false)
        .limit(1)
        .maybeSingle();
    if (row == null) return null;
    return _toDouble(row['raw_value']);
  }

  Future<double?> getNextReadingValue({
    required String meterId,
    required DateTime readingDate,
  }) async {
    final row = await _client
        .from('meter_readings')
        .select('raw_value')
        .eq('meter_id', meterId)
        .gt('reading_date', formatBusinessDate(readingDate))
        .order('reading_date', ascending: true)
        .limit(1)
        .maybeSingle();
    if (row == null) return null;
    return _toDouble(row['raw_value']);
  }

  AdminReadingRow? _mapAdminReadingRow(Map<String, dynamic> map) {
    final reading = MeterReading.fromJson(map);
    final meterJson = map['meters'];
    final siteJson = map['sites'];
    final profileJson = map['profiles'];
    if (meterJson is! Map) return null;

    final categoryJson = meterJson['meter_categories'];
    final unitJson = meterJson['meter_units'];
    final meterMap = Map<String, dynamic>.from(meterJson);
    final zoneName = siteJson is Map
        ? (siteJson['zones'] is Map
              ? siteJson['zones']['name_en'] as String? ?? 'No Zone'
              : 'No Zone')
        : 'No Zone';
    final siteName = siteJson is Map
        ? siteJson['name_en'] as String? ?? 'Site'
        : 'Site';

    return AdminReadingRow(
      readingId: reading.id,
      siteId: reading.siteId,
      siteName: siteName,
      zoneName: zoneName,
      meterId: reading.meterId,
      meterName: meterJson['name_en'] as String? ?? 'Unknown',
      meterCode: meterJson['meter_code'] as String? ?? '',
      categoryName: joinedCatalogDisplayName(
        categoryJson is Map ? Map<String, dynamic>.from(categoryJson) : null,
        legacyFallback: legacyMeterCategoryLabel(meterMap['category']),
      ),
      unitLabel: joinedCatalogDisplayName(
        unitJson is Map ? Map<String, dynamic>.from(unitJson) : null,
        legacyFallback: legacyMeterUnitLabel(meterMap['unit']),
      ),
      readingDate: reading.readingDate,
      rawValue: reading.rawValue,
      normalizedValue: reading.normalizedValue,
      note: reading.note,
      imageStoragePath: reading.imageStoragePath,
      enteredByName: profileJson is Map
          ? profileJson['full_name'] as String?
          : null,
      enteredByEmail: profileJson is Map
          ? profileJson['email'] as String?
          : null,
      enteredAt: reading.enteredAt,
    );
  }

  bool _matchesListFilter(AdminReadingRow row, CorrectionListFilter filter) {
    return switch (filter) {
      CorrectionListFilter.all => true,
      CorrectionListFilter.suspicious =>
        row.alertTypes.contains(AlertType.lowerThanPrevious) ||
            row.alertTypes.contains(AlertType.highConsumption),
      CorrectionListFilter.withAlerts => row.alertTypes.isNotEmpty,
      CorrectionListFilter.corrected => row.isCorrected,
      CorrectionListFilter.withoutPhoto => !row.hasPhoto,
    };
  }

  List<AlertType> _detectReadingAlerts({
    required double rawValue,
    double? previousValue,
    required bool hasPhoto,
  }) {
    final alerts = <AlertType>[];
    if (previousValue != null && rawValue < previousValue) {
      alerts.add(AlertType.lowerThanPrevious);
    }
    if (!hasPhoto) {
      alerts.add(AlertType.missingPhoto);
    }
    return alerts;
  }

  ReadingAuditAction _parseAuditAction(String value) {
    return ReadingAuditAction.values.firstWhere(
      (action) => action.name == value,
      orElse: () => ReadingAuditAction.update,
    );
  }

  static double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.parse(value as String);
  }

  static double? _toDoubleOrNull(dynamic value) {
    if (value == null) return null;
    return _toDouble(value);
  }
}

class CorrectionValidationException implements Exception {
  CorrectionValidationException(this.message);
  final String message;

  @override
  String toString() => message;
}
