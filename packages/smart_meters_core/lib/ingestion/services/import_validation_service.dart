import 'dart:convert';

import '../domain/reading_source.dart';

enum ImportRowStatus { pending, accepted, rejected, duplicated, reversed }

class ImportColumnMapping {
  const ImportColumnMapping({
    required this.meterCodeColumn,
    required this.readingDateColumn,
    required this.rawValueColumn,
    this.unitColumn,
    this.externalIdColumn,
    this.siteCodeColumn,
    this.noteColumn,
  });

  final String meterCodeColumn;
  final String readingDateColumn;
  final String rawValueColumn;
  final String? unitColumn;
  final String? externalIdColumn;
  final String? siteCodeColumn;
  final String? noteColumn;

  Set<String> get requiredColumns => {
        meterCodeColumn,
        readingDateColumn,
        rawValueColumn,
      };
}

class ImportMeterRef {
  const ImportMeterRef({
    required this.id,
    required this.code,
    required this.siteId,
    required this.unitCode,
    this.organizationId,
  });

  final String id;
  final String code;
  final String siteId;
  final String unitCode;
  final String? organizationId;
}

class ImportPreviewRow {
  const ImportPreviewRow({
    required this.rowNumber,
    required this.raw,
    this.resolvedMeterId,
    this.resolvedSiteId,
    this.readingDate,
    this.rawValue,
    this.unitCode,
    this.externalReadingId,
    required this.status,
    this.errorCode,
    this.errorMessage,
  });

  final int rowNumber;
  final Map<String, String> raw;
  final String? resolvedMeterId;
  final String? resolvedSiteId;
  final DateTime? readingDate;
  final double? rawValue;
  final String? unitCode;
  final String? externalReadingId;
  final ImportRowStatus status;
  final String? errorCode;
  final String? errorMessage;
}

class ImportPreviewResult {
  const ImportPreviewResult({
    required this.headersValid,
    required this.headerErrors,
    required this.rows,
    required this.acceptedCount,
    required this.rejectedCount,
    required this.duplicatedCount,
  });

  final bool headersValid;
  final List<String> headerErrors;
  final List<ImportPreviewRow> rows;
  final int acceptedCount;
  final int rejectedCount;
  final int duplicatedCount;

  bool get canCommitPartial => acceptedCount > 0;
  bool get canCommitAll => rejectedCount == 0 && duplicatedCount == 0 && acceptedCount > 0;
}

/// Pure CSV import validation (preview before write).
class ImportValidationService {
  const ImportValidationService({
    this.partialAcceptance = true,
    this.maxRows = 5000,
  });

  final bool partialAcceptance;
  final int maxRows;

  static final _dateFormats = <RegExp>[
    RegExp(r'^\d{4}-\d{2}-\d{2}$'),
    RegExp(r'^\d{2}/\d{2}/\d{4}$'),
  ];

  List<Map<String, String>> parseCsv(String content) {
    final lines = LineSplitter()
        .convert(content)
        .where((l) => l.trim().isNotEmpty)
        .toList();
    if (lines.isEmpty) return const [];
    final headers = _splitCsvLine(lines.first);
    final rows = <Map<String, String>>[];
    for (var i = 1; i < lines.length; i++) {
      final cols = _splitCsvLine(lines[i]);
      final map = <String, String>{};
      for (var c = 0; c < headers.length; c++) {
        map[headers[c]] = c < cols.length ? cols[c].trim() : '';
      }
      rows.add(map);
    }
    return rows;
  }

  ImportPreviewResult validate({
    required List<String> headers,
    required List<Map<String, String>> rows,
    required ImportColumnMapping mapping,
    required Map<String, ImportMeterRef> metersByCode,
    String? expectedSiteId,
    Set<String>? knownExternalIds,
    Set<String>? existingMeterDateKeys,
    ReadingSource source = ReadingSource.csvImport,
  }) {
    final headerErrors = <String>[];
    for (final req in mapping.requiredColumns) {
      if (!headers.contains(req)) {
        headerErrors.add('missing_header:$req');
      }
    }
    if (headerErrors.isNotEmpty) {
      return ImportPreviewResult(
        headersValid: false,
        headerErrors: headerErrors,
        rows: const [],
        acceptedCount: 0,
        rejectedCount: 0,
        duplicatedCount: 0,
      );
    }

    if (rows.length > maxRows) {
      return ImportPreviewResult(
        headersValid: false,
        headerErrors: ['batch_too_large:${rows.length}>$maxRows'],
        rows: const [],
        acceptedCount: 0,
        rejectedCount: 0,
        duplicatedCount: 0,
      );
    }

    final seenInFile = <String>{};
    final out = <ImportPreviewRow>[];
    var accepted = 0;
    var rejected = 0;
    var duplicated = 0;
    final knownExt = knownExternalIds ?? const <String>{};
    final existingKeys = existingMeterDateKeys ?? const <String>{};

    for (var i = 0; i < rows.length; i++) {
      final raw = rows[i];
      final rowNumber = i + 2; // header is row 1
      final meterCode = (raw[mapping.meterCodeColumn] ?? '').trim();
      final dateRaw = (raw[mapping.readingDateColumn] ?? '').trim();
      final valueRaw = (raw[mapping.rawValueColumn] ?? '').trim();
      final unit = mapping.unitColumn == null
          ? null
          : (raw[mapping.unitColumn!] ?? '').trim();
      final extId = mapping.externalIdColumn == null
          ? null
          : (raw[mapping.externalIdColumn!] ?? '').trim();

      if (meterCode.isEmpty || dateRaw.isEmpty || valueRaw.isEmpty) {
        rejected++;
        out.add(ImportPreviewRow(
          rowNumber: rowNumber,
          raw: raw,
          status: ImportRowStatus.rejected,
          errorCode: 'missing_required_fields',
          errorMessage: 'Meter code, date, and value are required',
        ));
        continue;
      }

      final meter = metersByCode[meterCode];
      if (meter == null) {
        rejected++;
        out.add(ImportPreviewRow(
          rowNumber: rowNumber,
          raw: raw,
          status: ImportRowStatus.rejected,
          errorCode: 'unknown_meter',
          errorMessage: 'Unknown meter code: $meterCode',
        ));
        continue;
      }

      if (expectedSiteId != null && meter.siteId != expectedSiteId) {
        rejected++;
        out.add(ImportPreviewRow(
          rowNumber: rowNumber,
          raw: raw,
          resolvedMeterId: meter.id,
          resolvedSiteId: meter.siteId,
          status: ImportRowStatus.rejected,
          errorCode: 'cross_site_rejection',
          errorMessage: 'Meter belongs to another site',
        ));
        continue;
      }

      final readingDate = _parseDate(dateRaw);
      if (readingDate == null) {
        rejected++;
        out.add(ImportPreviewRow(
          rowNumber: rowNumber,
          raw: raw,
          resolvedMeterId: meter.id,
          resolvedSiteId: meter.siteId,
          status: ImportRowStatus.rejected,
          errorCode: 'invalid_date',
          errorMessage: 'Invalid date: $dateRaw',
        ));
        continue;
      }

      final value = double.tryParse(valueRaw);
      if (value == null || value < 0) {
        rejected++;
        out.add(ImportPreviewRow(
          rowNumber: rowNumber,
          raw: raw,
          resolvedMeterId: meter.id,
          resolvedSiteId: meter.siteId,
          readingDate: readingDate,
          status: ImportRowStatus.rejected,
          errorCode: 'invalid_value',
          errorMessage: 'Invalid raw value: $valueRaw',
        ));
        continue;
      }

      if (unit != null &&
          unit.isNotEmpty &&
          meter.unitCode.isNotEmpty &&
          unit != meter.unitCode) {
        rejected++;
        out.add(ImportPreviewRow(
          rowNumber: rowNumber,
          raw: raw,
          resolvedMeterId: meter.id,
          resolvedSiteId: meter.siteId,
          readingDate: readingDate,
          rawValue: value,
          unitCode: unit,
          status: ImportRowStatus.rejected,
          errorCode: 'unit_mismatch',
          errorMessage: 'Expected ${meter.unitCode}, got $unit',
        ));
        continue;
      }

      final dateKey =
          '${meter.id}|${readingDate.toIso8601String().substring(0, 10)}';
      if (seenInFile.contains(dateKey) || existingKeys.contains(dateKey)) {
        duplicated++;
        out.add(ImportPreviewRow(
          rowNumber: rowNumber,
          raw: raw,
          resolvedMeterId: meter.id,
          resolvedSiteId: meter.siteId,
          readingDate: readingDate,
          rawValue: value,
          unitCode: unit?.isEmpty == true ? meter.unitCode : (unit ?? meter.unitCode),
          externalReadingId: extId?.isEmpty == true ? null : extId,
          status: ImportRowStatus.duplicated,
          errorCode: 'duplicate_row',
          errorMessage: 'Duplicate meter+date in file or existing reading',
        ));
        continue;
      }

      if (extId != null && extId.isNotEmpty && knownExt.contains(extId)) {
        duplicated++;
        out.add(ImportPreviewRow(
          rowNumber: rowNumber,
          raw: raw,
          resolvedMeterId: meter.id,
          resolvedSiteId: meter.siteId,
          readingDate: readingDate,
          rawValue: value,
          unitCode: unit?.isEmpty == true ? null : unit,
          externalReadingId: extId,
          status: ImportRowStatus.duplicated,
          errorCode: 'duplicate_external_id',
          errorMessage: 'External reading id already imported',
        ));
        continue;
      }

      seenInFile.add(dateKey);
      accepted++;
      out.add(ImportPreviewRow(
        rowNumber: rowNumber,
        raw: raw,
        resolvedMeterId: meter.id,
        resolvedSiteId: meter.siteId,
        readingDate: readingDate,
        rawValue: value,
        unitCode: (unit == null || unit.isEmpty) ? meter.unitCode : unit,
        externalReadingId: (extId == null || extId.isEmpty) ? null : extId,
        status: ImportRowStatus.accepted,
      ));
    }

    // source reserved for audit labeling by callers
    assert(source == ReadingSource.csvImport ||
        source == ReadingSource.excelImport);

    return ImportPreviewResult(
      headersValid: true,
      headerErrors: const [],
      rows: out,
      acceptedCount: accepted,
      rejectedCount: rejected,
      duplicatedCount: duplicated,
    );
  }

  /// CSV template headers for download.
  static const templateHeaders = [
    'meter_code',
    'reading_date',
    'raw_value',
    'unit',
    'external_reading_id',
    'note',
  ];

  static String templateCsv() => '${templateHeaders.join(',')}\n';

  static List<String> _splitCsvLine(String line) {
    // Simple CSV split (no embedded commas in quotes for v1 template).
    return line.split(',').map((e) => e.trim()).toList();
  }

  static DateTime? _parseDate(String raw) {
    if (_dateFormats[0].hasMatch(raw)) {
      return DateTime.tryParse(raw);
    }
    if (_dateFormats[1].hasMatch(raw)) {
      final p = raw.split('/');
      return DateTime.tryParse('${p[2]}-${p[1]}-${p[0]}');
    }
    return DateTime.tryParse(raw);
  }
}
