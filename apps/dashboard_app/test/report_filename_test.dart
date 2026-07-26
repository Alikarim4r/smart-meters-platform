import 'package:flutter_test/flutter_test.dart';
import 'package:smart_meters_core/smart_meters_core.dart';

import 'package:dashboard_app/reports/report_filename.dart';
import 'package:dashboard_app/reports/report_models.dart';

void main() {
  test('sanitizeReportFilenamePart removes unsafe characters', () {
    expect(sanitizeReportFilenamePart('MOEHE HQ!'), 'MOEHE_HQ');
    expect(sanitizeReportFilenamePart('Test/School A'), 'TestSchool_A');
  });

  test('buildReportFilename uses expected pattern', () {
    final name = buildReportFilename(
      siteName: 'MOEHE HQ',
      type: ReportType.consumption,
      format: ReportFormat.excel,
      period: ChartPeriod.weekly,
      generatedAt: DateTime(2026, 7, 4),
    );
    expect(name, 'MOEHE_HQ_consumption_weekly_2026-07-04.xlsx');
  });
}
