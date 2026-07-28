import 'dart:typed_data';

import 'package:share_plus/share_plus.dart';

import 'report_export_log.dart';
import 'report_file_types.dart';
import 'report_models.dart';

class ReportFileService {
  Future<String> saveReportBytes({
    required List<int> bytes,
    required String filename,
  }) async {
    reportExportLog(
      'I',
      'web save/download start ($filename, ${bytes.length} bytes)',
    );
    if (bytes.isEmpty) {
      throw ReportFileSaveException('Report file is empty');
    }

    final safeName = reportSafeFilename(filename);
    final mime = safeName.toLowerCase().endsWith('.xlsx')
        ? 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
        : 'application/pdf';

    await Share.shareXFiles(
      [
        XFile.fromData(
          Uint8List.fromList(bytes),
          mimeType: mime,
          name: safeName,
        ),
      ],
      text: safeName,
      fileNameOverrides: [safeName],
    );
    reportExportLog('I', 'web share/download ok ($safeName)');
    return 'download://$safeName';
  }

  Future<ReportOpenResult> openReport(GeneratedReportFile file) async {
    reportExportLog('J', 'web open skipped (browser download/share used)');
    return const ReportOpenResult(
      success: true,
      message: 'Use the browser download / share sheet',
    );
  }

  Future<void> shareReport(GeneratedReportFile file) async {
    reportExportLog('K', 'web share note (${file.filename})');
    // Bytes are not retained after the first save on web.
    throw ReportFileSaveException(
      'On web, use Export again to download/share the report.',
    );
  }
}
