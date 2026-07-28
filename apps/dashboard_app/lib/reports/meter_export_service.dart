import 'package:excel/excel.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:smart_meters_core/smart_meters_core.dart';

import '../utils/dashboard_date_range.dart';

class MeterExportService {
  MeterExportService(this._repository);

  final DashboardRepository _repository;

  /// Builds an Excel file and opens the system share sheet.
  Future<String> exportMeterReadings({
    required String siteId,
    required MeterReadingCardData meter,
    required DashboardDateSelection dateSelection,
  }) async {
    final fromDate = dateSelection.usesRangeQuery
        ? dateSelection.startDate
        // Single-day view often has no row yet — export a year of history.
        : DateTime(
            dateSelection.endDate.year - 1,
            dateSelection.endDate.month,
            dateSelection.endDate.day,
          );

    final rows = await _repository.getRecentSiteReadings(
      siteId: siteId,
      filters: DashboardReadingFilters(
        fromDate: fromDate,
        toDate: dateSelection.endDate,
        meterId: meter.meterId,
        limit: 500,
      ),
    );

    if (rows.isEmpty) {
      throw const MeterExportEmptyException();
    }

    final excel = Excel.createExcel();
    final sheet = excel['Readings'];
    excel.delete('Sheet1');

    final headers = [
      'Meter code',
      'Meter name',
      'Utility',
      'Unit',
      'Date',
      'Reading',
      'Consumption',
      'Note',
      'Photo',
    ];
    for (var c = 0; c < headers.length; c++) {
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 0))
          .value = TextCellValue(headers[c]);
    }

    for (var i = 0; i < rows.length; i++) {
      final row = rows[i];
      final reading = row.reading;
      double? consumption;
      if (i + 1 < rows.length) {
        consumption = reading.rawValue - rows[i + 1].reading.rawValue;
      }

      final values = [
        meter.meterCode,
        meter.meterName,
        meter.categoryName,
        row.unitLabel,
        formatBusinessDate(reading.readingDate),
        reading.rawValue.toString(),
        consumption?.toString() ?? '',
        reading.note ?? '',
        reading.hasPhoto ? 'Yes' : 'No',
      ];

      for (var c = 0; c < values.length; c++) {
        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: i + 1))
            .value = TextCellValue(values[c]);
      }
    }

    final bytes = excel.encode();
    if (bytes == null || bytes.isEmpty) {
      throw StateError('Excel generation failed');
    }

    final filename =
        'meter_${meter.meterCode}_${formatBusinessDate(dateSelection.endDate)}.xlsx'
            .replaceAll(RegExp(r'[^\w\-.]+'), '_');

    if (kIsWeb) {
      await Share.shareXFiles(
        [
          XFile.fromData(
            Uint8List.fromList(bytes),
            mimeType:
                'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
            name: filename,
          ),
        ],
        text: filename,
        fileNameOverrides: [filename],
      );
      return 'download://$filename';
    }

    // Avoid importing dart:io so this library compiles for web.
    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/$filename';
    final xfile = XFile.fromData(
      Uint8List.fromList(bytes),
      mimeType:
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      name: filename,
      path: path,
    );
    await xfile.saveTo(path);
    await Share.shareXFiles([XFile(path, name: filename)], text: filename);
    return path;
  }
}

class MeterExportEmptyException implements Exception {
  const MeterExportEmptyException();
}
