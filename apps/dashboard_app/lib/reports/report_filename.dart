import 'package:smart_meters_core/smart_meters_core.dart';

import 'report_models.dart';

String sanitizeReportFilenamePart(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) {
    return 'report';
  }
  return trimmed
      .replaceAll(RegExp(r'[^\w\s-]'), '')
      .replaceAll(RegExp(r'\s+'), '_')
      .replaceAll(RegExp(r'_+'), '_');
}

String buildReportFilename({
  String? siteName,
  required ReportType type,
  required ReportFormat format,
  required ChartPeriod period,
  required DateTime generatedAt,
}) {
  final sitePart = siteName == null
      ? 'all_sites'
      : sanitizeReportFilenamePart(siteName);
  final datePart =
      '${generatedAt.year.toString().padLeft(4, '0')}-'
      '${generatedAt.month.toString().padLeft(2, '0')}-'
      '${generatedAt.day.toString().padLeft(2, '0')}';
  return '${sitePart}_${reportTypeSlug(type)}_${periodSlug(period)}_$datePart.${format.extension}';
}
