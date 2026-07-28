class ReportFileSaveException implements Exception {
  ReportFileSaveException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ReportOpenResult {
  const ReportOpenResult({
    required this.success,
    this.message,
  });

  final bool success;
  final String? message;
}

String reportSafeFilename(String filename) {
  final trimmed = filename.trim();
  if (trimmed.isEmpty) {
    return 'report.pdf';
  }
  return trimmed.replaceAll(RegExp(r'[\\/]+'), '_');
}
