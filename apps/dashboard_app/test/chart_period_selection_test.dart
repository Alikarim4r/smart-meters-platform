import 'package:dashboard_app/utils/chart_period_selection.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_meters_core/smart_meters_core.dart';

void main() {
  final anchorWednesday = DateTime(2026, 2, 4); // Wednesday

  group('saturdayFridayWeekContaining', () {
    test('week containing Wednesday is previous Saturday through Friday', () {
      final week = saturdayFridayWeekContaining(anchorWednesday);
      expect(week.from, DateTime(2026, 1, 31)); // Saturday
      expect(week.to, DateTime(2026, 2, 6)); // Friday
    });

    test('Saturday anchor starts same day', () {
      final week = saturdayFridayWeekContaining(DateTime(2026, 1, 31));
      expect(week.from, DateTime(2026, 1, 31));
      expect(week.to, DateTime(2026, 2, 6));
    });

    test('Friday anchor ends same day', () {
      final week = saturdayFridayWeekContaining(DateTime(2026, 2, 6));
      expect(week.from, DateTime(2026, 1, 31));
      expect(week.to, DateTime(2026, 2, 6));
    });
  });

  group('resolveUtilityChartPeriodRange', () {
    test('last 31 days uses daily buckets', () {
      const state = UtilityChartPeriodState(
        kind: UtilityChartPeriodKind.last30Days,
      );
      final range = resolveUtilityChartPeriodRange(
        state: state,
        anchorDate: DateTime(2026, 7, 10),
      );
      expect(range.from, DateTime(2026, 6, 10));
      expect(range.to, DateTime(2026, 7, 10));
      expect(range.bucket, ChartBucket.daily);
      expect(range.to.difference(range.from).inDays, 30);
    });

    test('12 months uses monthly buckets', () {
      const state = UtilityChartPeriodState(
        kind: UtilityChartPeriodKind.twelveMonths,
      );
      final range = resolveUtilityChartPeriodRange(
        state: state,
        anchorDate: DateTime(2026, 7, 10),
      );
      expect(range.from, DateTime(2025, 8, 1));
      expect(range.to, DateTime(2026, 7, 10));
      expect(range.bucket, ChartBucket.monthly);
    });

    test('5 years uses yearly buckets', () {
      const state = UtilityChartPeriodState(
        kind: UtilityChartPeriodKind.fiveYears,
      );
      final range = resolveUtilityChartPeriodRange(
        state: state,
        anchorDate: DateTime(2026, 7, 10),
      );
      expect(range.from, DateTime(2022, 1, 1));
      expect(range.to, DateTime(2026, 7, 10));
      expect(range.bucket, ChartBucket.yearly);
    });
  });

  group('UtilityChartPeriodState selectKind', () {
    test('tapping same kind is a no-op when chips already preferred', () {
      const state = UtilityChartPeriodState(
        kind: UtilityChartPeriodKind.twelveMonths,
        preferChipOverCustomRange: true,
      );
      final next = state.selectKind(UtilityChartPeriodKind.twelveMonths);
      expect(identical(next, state) || next == state, isTrue);
      expect(next.kind, UtilityChartPeriodKind.twelveMonths);
      expect(next.label, '12 months');
    });

    test('tapping same kind enables chip preference over custom range', () {
      const state = UtilityChartPeriodState(
        kind: UtilityChartPeriodKind.twelveMonths,
      );
      final next = state.selectKind(UtilityChartPeriodKind.twelveMonths);
      expect(next.kind, UtilityChartPeriodKind.twelveMonths);
      expect(next.preferChipOverCustomRange, isTrue);
    });

    test('tapping different kind switches without toggle', () {
      const state = UtilityChartPeriodState(
        kind: UtilityChartPeriodKind.last30Days,
      );
      final next = state.selectKind(UtilityChartPeriodKind.fiveYears);
      expect(next.kind, UtilityChartPeriodKind.fiveYears);
      expect(next.label, '5 years');
      expect(next.preferChipOverCustomRange, isTrue);
    });
  });
}
