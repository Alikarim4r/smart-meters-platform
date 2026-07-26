import 'package:flutter_test/flutter_test.dart';

import 'package:dashboard_app/utils/chart_period_selection.dart';
import 'package:dashboard_app/utils/dashboard_date_range.dart';

void main() {
  final anchor = DateTime(2026, 7, 4);

  test('single day selection uses subsequent and previous reading dates', () {
    final selection = DashboardDateSelection.singleDay(
      day: DateTime(2026, 5, 31),
      preset: DashboardDatePreset.pickDay,
    );
    expect(selection.mode, DashboardDateMode.singleDay);
    expect(selection.subsequentReadingDate, DateTime(2026, 5, 31));
    expect(selection.previousReadingDate, DateTime(2026, 5, 30));
    expect(selection.displayLabel, contains('Previous'));
    expect(selection.isSingleDay, isTrue);
  });

  test('today defaults to subsequent today and previous yesterday', () {
    final anchor = DateTime(2026, 7, 8);
    final selection = DashboardDateSelection.forPreset(
      preset: DashboardDatePreset.today,
      currentBusinessDate: anchor,
    );
    expect(selection.subsequentReadingDate, anchor);
    expect(selection.previousReadingDate, DateTime(2026, 7, 7));
  });

  test('custom day from calendar preset', () {
    final selection = DashboardDateSelection.forPreset(
      preset: DashboardDatePreset.pickDay,
      currentBusinessDate: anchor,
      pickedDay: DateTime(2026, 3, 15),
    );
    expect(selection.selectedBusinessDate, DateTime(2026, 3, 15));
    expect(selection.isSingleDay, isTrue);
  });

  test('defaults to current business day for all sites', () {
    final selection = defaultDateSelectionForSite('any-site', anchor);
    expect(selection.isSingleDay, isTrue);
    expect(selection.selectedBusinessDate, anchor);
    expect(selection.preset, DashboardDatePreset.today);
  });

  test('range mode uses end date as chart anchor', () {
    final selection = DashboardDateSelection.forPreset(
      preset: DashboardDatePreset.customRange,
      currentBusinessDate: anchor,
      customStart: DateTime(2026, 3, 1),
      customEnd: DateTime(2026, 3, 15),
    );
    expect(selection.isRangeMode, isTrue);
    expect(selection.chartBusinessDate, DateTime(2026, 3, 15));
    expect(selection.selectedBusinessDate, DateTime(2026, 3, 15));
  });

  test('month mode shows month label', () {
    final selection = DashboardDateSelection.forPreset(
      preset: DashboardDatePreset.monthPicker,
      currentBusinessDate: anchor,
      pickedMonth: DateTime(2026, 5, 1),
    );
    expect(selection.isMonthMode, isTrue);
    expect(selection.displayLabel, 'May 2026');
  });

  test('shift single day moves by one day', () {
    final selection = DashboardDateSelection.singleDay(
      day: DateTime(2026, 5, 31),
    );
    final prev = shiftDashboardDateSelection(selection, step: -1);
    final next = shiftDashboardDateSelection(selection, step: 1);
    expect(prev.selectedDay, DateTime(2026, 5, 30));
    expect(next.selectedDay, DateTime(2026, 6, 1));
    expect(prev.isSingleDay, isTrue);
  });

  test('shift month moves by one month', () {
    final selection = DashboardDateSelection.forPreset(
      preset: DashboardDatePreset.monthPicker,
      currentBusinessDate: anchor,
      pickedMonth: DateTime(2026, 5, 1),
    );
    final prev = shiftDashboardDateSelection(selection, step: -1);
    final next = shiftDashboardDateSelection(selection, step: 1);
    expect(prev.startDate, DateTime(2026, 4, 1));
    expect(prev.endDate, DateTime(2026, 4, 30));
    expect(next.startDate, DateTime(2026, 6, 1));
    expect(next.endDate, DateTime(2026, 6, 30));
  });

  test('shift last 7 days moves by one week', () {
    final selection = DashboardDateSelection.forPreset(
      preset: DashboardDatePreset.last7Days,
      currentBusinessDate: DateTime(2026, 7, 10),
    );
    final next = shiftDashboardDateSelection(selection, step: 1);
    expect(next.endDate, DateTime(2026, 7, 17));
    expect(next.startDate, DateTime(2026, 7, 11));
  });

  test('shift calendar week keeps Saturday–Friday bounds', () {
    // 2026-07-04 is Saturday
    final week = saturdayFridayWeekContaining(DateTime(2026, 7, 8));
    final selection = DashboardDateSelection(
      mode: DashboardDateMode.range,
      preset: DashboardDatePreset.customRange,
      selectedDay: week.to,
      startDate: week.from,
      endDate: week.to,
      previousReadingDate: week.from,
    );
    expect(dashboardDateShiftUnit(selection), DashboardDateShiftUnit.week);
    final prev = shiftDashboardDateSelection(selection, step: -1);
    expect(prev.startDate.weekday, DateTime.saturday);
    expect(prev.endDate.difference(prev.startDate).inDays, 6);
    expect(prev.endDate, week.to.subtract(const Duration(days: 7)));
  });

  test('shift year moves by one calendar year', () {
    final selection = DashboardDateSelection(
      mode: DashboardDateMode.range,
      preset: DashboardDatePreset.customRange,
      selectedDay: DateTime(2025, 12, 31),
      startDate: DateTime(2025, 1, 1),
      endDate: DateTime(2025, 12, 31),
      previousReadingDate: DateTime(2025, 1, 1),
    );
    final next = shiftDashboardDateSelection(selection, step: 1);
    expect(next.startDate, DateTime(2026, 1, 1));
    expect(dashboardDateShiftUnit(selection), DashboardDateShiftUnit.year);
  });
}
