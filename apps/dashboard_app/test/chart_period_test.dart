import 'package:flutter_test/flutter_test.dart';
import 'package:smart_meters_core/smart_meters_core.dart';

void main() {
  test('ChartPeriod labels are user-facing', () {
    expect(ChartPeriod.weekly.label, 'Weekly');
    expect(ChartPeriod.yearly.label, 'Yearly');
    expect(ChartPeriod.last30Days.label, 'Last 31 Days');
  });

  test('chartPeriodRange last30Days spans 31 inclusive days', () {
    final businessDate = DateTime(2026, 7, 10);
    final range = chartPeriodRange(
      period: ChartPeriod.last30Days,
      businessDate: businessDate,
    );
    expect(range.from, DateTime(2026, 6, 10));
    expect(range.to, businessDate);
    expect(range.to.difference(range.from).inDays, 30);
  });
}
