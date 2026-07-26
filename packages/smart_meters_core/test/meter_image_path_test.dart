import 'package:flutter_test/flutter_test.dart';
import 'package:smart_meters_core/smart_meters_core.dart';

void main() {
  test(
    'buildMeterImageStoragePath uses org/site/category/date/meter/timestamp',
    () {
      final path = buildMeterImageStoragePath(
        organizationId: 'org-1',
        siteId: 'site-1',
        categoryCode: 'water',
        readingDate: '2026-07-04',
        meterId: 'meter-1',
        capturedAt: DateTime.utc(2026, 7, 4, 11, 32, 0),
      );

      expect(path, 'org-1/site-1/water/2026-07-04/meter-1/20260704_143200.jpg');
    },
  );

  test('formatQatarCaptureTimestamp uses UTC+3', () {
    final label = formatQatarCaptureTimestamp(DateTime.utc(2026, 7, 4, 11, 32));
    expect(label, '2026-07-04 14:32 Asia/Qatar');
  });
}
