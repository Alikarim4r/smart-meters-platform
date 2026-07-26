import 'package:flutter_test/flutter_test.dart';
import 'package:smart_meters_core/smart_meters_core.dart';

void main() {
  test('qatarBusinessDate uses UTC+3 calendar day', () {
    final reference = DateTime.utc(2026, 7, 3, 21, 30);
    final businessDate = qatarBusinessDate(reference);
    expect(businessDate.year, 2026);
    expect(businessDate.month, 7);
    expect(businessDate.day, 4);
  });

  test('formatBusinessDate returns ISO date string', () {
    expect(formatBusinessDate(DateTime(2026, 7, 3)), '2026-07-03');
  });
}
