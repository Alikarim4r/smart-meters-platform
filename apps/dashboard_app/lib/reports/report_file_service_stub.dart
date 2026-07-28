import 'report_file_types.dart';
import 'report_models.dart';

class ReportFileService {
  Future<String> saveReportBytes({
    required List<int> bytes,
    required String filename,
  }) {
    throw UnsupportedError('Report save is not supported on this platform');
  }

  Future<ReportOpenResult> openReport(GeneratedReportFile file) async {
    return const ReportOpenResult(
      success: false,
      message: 'Open is not supported on this platform',
    );
  }

  Future<void> shareReport(GeneratedReportFile file) {
    throw UnsupportedError('Share is not supported on this platform');
  }
}
