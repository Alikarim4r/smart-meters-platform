import 'package:dashboard_app/providers/chart_providers.dart';
import 'package:dashboard_app/utils/chart_period_selection.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('CategoryChartQuery includes period state in equality', () {
    const a = CategoryChartQuery(
      siteId: 'site',
      categoryId: 'cat',
      periodState: UtilityChartPeriodState(
        kind: UtilityChartPeriodKind.last30Days,
      ),
    );
    const b = CategoryChartQuery(
      siteId: 'site',
      categoryId: 'cat',
      periodState: UtilityChartPeriodState(
        kind: UtilityChartPeriodKind.twelveMonths,
      ),
    );
    expect(a == b, isFalse);
    expect(a.hashCode == b.hashCode, isFalse);
  });

  test('MeterComparisonQuery requires at least two meter ids for data', () {
    const query = MeterComparisonQuery(
      siteId: 'site',
      categoryId: 'water',
      meterIds: ['a'],
      periodState: UtilityChartPeriodState(
        kind: UtilityChartPeriodKind.twelveMonths,
      ),
    );
    expect(query.meterIds.length, lessThan(2));
  });

  test('utility chart period keys are stable', () {
    expect(
      utilityChartPeriodKey(siteId: 's1', categoryCode: 'water'),
      's1::water',
    );
    expect(
      meterComparisonKey(siteId: 's1', categoryId: 'cat'),
      's1::cat',
    );
  });
}
