import 'package:dashboard_app/reports/report_text_sanitize.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('report text sanitize', () {
    test('replaces em dash and superscript for PDF', () {
      expect(sanitizePdfText('MOEHE — HQ'), 'MOEHE - HQ');
      expect(sanitizePdfText('12 m³'), '12 m3');
      expect(sanitizePdfText(null), '-');
      expect(sanitizePdfText(''), '-');
    });

    test('sanitizes excel cells', () {
      expect(sanitizeExcelCell(12.5), '12.5');
      expect(sanitizeExcelCell(null), '');
      expect(sanitizeExcelCell('note'), 'note');
    });
  });
}
