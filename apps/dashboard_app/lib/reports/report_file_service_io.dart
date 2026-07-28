import 'dart:io';

import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'report_export_log.dart';
import 'report_file_types.dart';
import 'report_models.dart';

class ReportFileService {
  Future<String> saveReportBytes({
    required List<int> bytes,
    required String filename,
  }) async {
    reportExportLog('I', 'save start ($filename, ${bytes.length} bytes)');
    if (bytes.isEmpty) {
      throw ReportFileSaveException('Report file is empty');
    }

    final directory = await getApplicationDocumentsDirectory();
    if (directory.path.trim().isEmpty) {
      throw ReportFileSaveException('Application documents path is unavailable');
    }

    final reportsDir = Directory('${directory.path}/reports');
    if (!await reportsDir.exists()) {
      await reportsDir.create(recursive: true);
    }

    final safeName = reportSafeFilename(filename);
    final file = File('${reportsDir.path}/$safeName');
    await file.writeAsBytes(bytes, flush: true);

    if (!file.existsSync()) {
      throw ReportFileSaveException('Report file was not created');
    }
    final size = await file.length();
    if (size <= 0) {
      throw ReportFileSaveException('Report file is empty on disk');
    }

    reportExportLog('I', 'save ok (${file.path}, $size bytes)');
    return file.path;
  }

  Future<ReportOpenResult> openReport(GeneratedReportFile file) async {
    reportExportLog('J', 'open start (${file.path})');
    final localFile = File(file.path);
    if (!localFile.existsSync() || localFile.lengthSync() <= 0) {
      const message = 'Report file is missing on device';
      reportExportLog('J', 'open failed: $message');
      return const ReportOpenResult(success: false, message: message);
    }

    final result = await OpenFilex.open(file.path);
    final success = result.type == ResultType.done;
    reportExportLog(
      'J',
      success ? 'open ok' : 'open failed (${result.message})',
    );
    return ReportOpenResult(
      success: success,
      message: result.message,
    );
  }

  Future<void> shareReport(GeneratedReportFile file) async {
    reportExportLog('K', 'share start (${file.path})');
    final localFile = File(file.path);
    if (!localFile.existsSync() || localFile.lengthSync() <= 0) {
      throw ReportFileSaveException('Report file is missing on device');
    }
    await Share.shareXFiles(
      [XFile(file.path, name: file.filename)],
      text: file.filename,
    );
    reportExportLog('K', 'share ok');
  }
}
