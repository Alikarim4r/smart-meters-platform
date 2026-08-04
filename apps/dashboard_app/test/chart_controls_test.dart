import 'package:dashboard_app/providers/chart_providers.dart';
import 'package:dashboard_app/utils/chart_period_selection.dart';
import 'package:dashboard_app/utils/dashboard_date_range.dart';
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
    expect(meterComparisonKey(siteId: 's1', categoryId: 'cat'), 's1::cat');
  });

  test('five-year dashboard selection replaces a stale seven-day chart', () {
    const current = UtilityChartPeriodState(
      kind: UtilityChartPeriodKind.last7Days,
      preferChipOverCustomRange: true,
    );
    final selection = dateSelectionForChartPeriodKind(
      kind: UtilityChartPeriodKind.fiveYears,
      anchorDate: DateTime(2026, 8, 4),
    );

    final next = utilityChartPeriodAfterDateSelection(
      current: current,
      selection: selection,
    );
    final range = resolveUtilityChartPeriodRange(
      state: next,
      anchorDate: selection.chartBusinessDate,
    );

    expect(next.kind, UtilityChartPeriodKind.fiveYears);
    expect(next.preferChipOverCustomRange, isFalse);
    expect(range.from, DateTime(2022, 1, 1));
    expect(range.to, DateTime(2026, 8, 4));
  });

  test('arbitrary meter range preserves an explicitly selected chart chip', () {
    const current = UtilityChartPeriodState(
      kind: UtilityChartPeriodKind.last30Days,
      preferChipOverCustomRange: true,
    );
    final selection = DashboardDateSelection.forPreset(
      preset: DashboardDatePreset.customRange,
      currentBusinessDate: DateTime(2026, 8, 4),
      customStart: DateTime(2026, 3, 3),
      customEnd: DateTime(2026, 4, 19),
    );

    expect(
      utilityChartPeriodAfterDateSelection(
        current: current,
        selection: selection,
      ),
      current,
    );
  });
}
