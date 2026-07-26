import 'package:smart_meters_core/smart_meters_core.dart';

import 'chart_period_selection.dart';

/// How the dashboard interprets the selected dates.
enum DashboardDateMode {
  singleDay,
  range,
  month,
}

/// Quick preset for dashboard date filtering.
enum DashboardDatePreset {
  today,
  yesterday,
  pickDay,
  may312026,
  last7Days,
  last30Days,
  currentMonth,
  previousMonth,
  march2026,
  april2026,
  may2026,
  monthPicker,
  customRange,
}

extension DashboardDatePresetLabel on DashboardDatePreset {
  String get label => switch (this) {
        DashboardDatePreset.today => 'Today',
        DashboardDatePreset.yesterday => 'Yesterday',
        DashboardDatePreset.pickDay => 'Pick date',
        DashboardDatePreset.may312026 => 'May 31, 2026',
        DashboardDatePreset.last7Days => 'Last 7 days',
        DashboardDatePreset.last30Days => 'Last 31 days',
        DashboardDatePreset.currentMonth => 'Current month',
        DashboardDatePreset.previousMonth => 'Previous month',
        DashboardDatePreset.march2026 => 'March 2026',
        DashboardDatePreset.april2026 => 'April 2026',
        DashboardDatePreset.may2026 => 'May 2026',
        DashboardDatePreset.monthPicker => 'Month',
        DashboardDatePreset.customRange => 'Custom range',
      };

  bool get isMeterCardPreset => switch (this) {
        DashboardDatePreset.last7Days ||
        DashboardDatePreset.last30Days ||
        DashboardDatePreset.currentMonth ||
        DashboardDatePreset.previousMonth ||
        DashboardDatePreset.march2026 ||
        DashboardDatePreset.april2026 ||
        DashboardDatePreset.may2026 ||
        DashboardDatePreset.monthPicker ||
        DashboardDatePreset.customRange =>
          false,
        _ => true,
      };

  /// Fixed demo months used for showcase data — hide outside debug builds.
  bool get isDemoShowcasePreset => switch (this) {
        DashboardDatePreset.may312026 ||
        DashboardDatePreset.march2026 ||
        DashboardDatePreset.april2026 ||
        DashboardDatePreset.may2026 =>
          true,
        _ => false,
      };
}

/// Unified dashboard date selection shared by cards, charts, and reports.
class DashboardDateSelection {
  const DashboardDateSelection({
    required this.mode,
    required this.preset,
    required this.selectedDay,
    required this.startDate,
    required this.endDate,
    required this.previousReadingDate,
  });

  final DashboardDateMode mode;
  final DashboardDatePreset preset;
  final DateTime selectedDay;
  final DateTime startDate;
  final DateTime endDate;

  /// Previous reading anchor (السابقة) — departure date in the pair picker.
  final DateTime previousReadingDate;

  /// Subsequent reading anchor (اللاحقة) — return date / primary dashboard day.
  DateTime get subsequentReadingDate => selectedBusinessDate;

  /// Anchor day for meter cards — subsequent reading date.
  DateTime get selectedBusinessDate => selectedDay;

  /// Legacy alias used by chart/report providers.
  DateTime get businessDate => selectedBusinessDate;

  bool get isSingleDay => mode == DashboardDateMode.singleDay;

  bool get isRangeMode => mode == DashboardDateMode.range;

  bool get isMonthMode => mode == DashboardDateMode.month;

  /// Week / month / year / custom ranges use inclusive start→end meter queries.
  bool get usesRangeQuery => !isSingleDay;

  DateTime get meterQueryBusinessDate =>
      isSingleDay ? selectedBusinessDate : endDate;

  DateTime? get meterQueryRangeStart =>
      usesRangeQuery ? startDate : null;

  DateTime? get meterQueryPreviousDate =>
      isSingleDay ? previousReadingDate : null;

  String get displayLabel => formatDashboardDateSelectionLabel(this);

  String get summarySubmittedLabel => isSingleDay
      ? 'Submitted on date'
      : isRangeMode
          ? 'Read in range'
          : 'Read in month';

  String get summaryPendingLabel => isSingleDay
      ? 'Pending on date'
      : isRangeMode
          ? 'Not read in range'
          : 'Not read in month';

  String get summaryCompletionLabel => isSingleDay
      ? 'Completion on date'
      : isRangeMode
          ? 'Completion in range'
          : 'Completion in month';

  /// Chart anchor: single day uses that day; range/month use range end.
  DateTime get chartBusinessDate =>
      isSingleDay ? selectedDay : endDate;

  DashboardDateSelection copyWith({
    DashboardDateMode? mode,
    DashboardDatePreset? preset,
    DateTime? selectedDay,
    DateTime? startDate,
    DateTime? endDate,
    DateTime? previousReadingDate,
  }) {
    return DashboardDateSelection(
      mode: mode ?? this.mode,
      preset: preset ?? this.preset,
      selectedDay: selectedDay ?? this.selectedDay,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      previousReadingDate: previousReadingDate ?? this.previousReadingDate,
    );
  }

  static DateTime defaultPreviousFor(DateTime subsequentDay) =>
      normalizeDashboardDate(
        subsequentDay.subtract(const Duration(days: 1)),
      );

  static DashboardDateSelection singleDay({
    required DateTime day,
    DashboardDatePreset preset = DashboardDatePreset.pickDay,
    DateTime? previousDay,
  }) {
    final normalized = normalizeDashboardDate(day);
    final previous = normalizeDashboardDate(previousDay ?? defaultPreviousFor(normalized));
    final orderedPrevious = previous.isAfter(normalized) ? normalized : previous;
    return DashboardDateSelection(
      mode: DashboardDateMode.singleDay,
      preset: preset,
      selectedDay: normalized,
      startDate: normalized,
      endDate: normalized,
      previousReadingDate: orderedPrevious,
    );
  }

  static DashboardDateSelection forPreset({
    required DashboardDatePreset preset,
    required DateTime currentBusinessDate,
    DateTime? pickedDay,
    DateTime? customStart,
    DateTime? customEnd,
    DateTime? pickedMonth,
  }) {
    final anchor = normalizeDashboardDate(currentBusinessDate);

    switch (preset) {
      case DashboardDatePreset.today:
        return singleDay(day: anchor, preset: preset);
      case DashboardDatePreset.yesterday:
        return singleDay(
          day: anchor.subtract(const Duration(days: 1)),
          preset: preset,
        );
      case DashboardDatePreset.pickDay:
        return singleDay(day: pickedDay ?? anchor, preset: preset);
      case DashboardDatePreset.may312026:
        return singleDay(
          day: DateTime(2026, 5, 31),
          preset: preset,
        );
      case DashboardDatePreset.last7Days:
        final start = anchor.subtract(const Duration(days: 6));
        return DashboardDateSelection(
          mode: DashboardDateMode.range,
          preset: preset,
          selectedDay: anchor,
          startDate: start,
          endDate: anchor,
          previousReadingDate: start,
        );
      case DashboardDatePreset.last30Days:
        final start30 = anchor.subtract(const Duration(days: 30));
        return DashboardDateSelection(
          mode: DashboardDateMode.range,
          preset: preset,
          selectedDay: anchor,
          startDate: start30,
          endDate: anchor,
          previousReadingDate: start30,
        );
      case DashboardDatePreset.currentMonth:
        final start = DateTime(anchor.year, anchor.month, 1);
        final end = endOfDashboardMonth(anchor);
        final cappedEnd = end.isAfter(anchor) ? anchor : end;
        return DashboardDateSelection(
          mode: DashboardDateMode.month,
          preset: preset,
          selectedDay: cappedEnd,
          startDate: start,
          endDate: cappedEnd,
          previousReadingDate: start,
        );
      case DashboardDatePreset.previousMonth:
        final prev = DateTime(anchor.year, anchor.month - 1, 1);
        final end = endOfDashboardMonth(prev);
        return DashboardDateSelection(
          mode: DashboardDateMode.month,
          preset: preset,
          selectedDay: end,
          startDate: prev,
          endDate: end,
          previousReadingDate: prev,
        );
      case DashboardDatePreset.march2026:
        return DashboardDateSelection(
          mode: DashboardDateMode.month,
          preset: preset,
          selectedDay: DateTime(2026, 3, 31),
          startDate: DateTime(2026, 3, 1),
          endDate: DateTime(2026, 3, 31),
          previousReadingDate: DateTime(2026, 3, 1),
        );
      case DashboardDatePreset.april2026:
        return DashboardDateSelection(
          mode: DashboardDateMode.month,
          preset: preset,
          selectedDay: DateTime(2026, 4, 30),
          startDate: DateTime(2026, 4, 1),
          endDate: DateTime(2026, 4, 30),
          previousReadingDate: DateTime(2026, 4, 1),
        );
      case DashboardDatePreset.may2026:
        return DashboardDateSelection(
          mode: DashboardDateMode.month,
          preset: preset,
          selectedDay: DateTime(2026, 5, 31),
          startDate: DateTime(2026, 5, 1),
          endDate: DateTime(2026, 5, 31),
          previousReadingDate: DateTime(2026, 5, 1),
        );
      case DashboardDatePreset.monthPicker:
        final month = pickedMonth ?? anchor;
        final start = DateTime(month.year, month.month, 1);
        final rawEnd = endOfDashboardMonth(start);
        // Cap the current month to today so the selection stays valid.
        final end = rawEnd.isAfter(anchor) ? anchor : rawEnd;
        return DashboardDateSelection(
          mode: DashboardDateMode.month,
          preset: preset,
          selectedDay: end,
          startDate: start,
          endDate: end,
          previousReadingDate: start,
        );
      case DashboardDatePreset.customRange:
        final start = normalizeDashboardDate(customStart ?? anchor);
        final end = normalizeDashboardDate(customEnd ?? anchor);
        if (end.isBefore(start)) {
          return DashboardDateSelection(
            mode: DashboardDateMode.range,
            preset: preset,
            selectedDay: start,
            startDate: end,
            endDate: start,
            previousReadingDate: end,
          );
        }
        return DashboardDateSelection(
          mode: DashboardDateMode.range,
          preset: preset,
          selectedDay: end,
          startDate: start,
          endDate: end,
          previousReadingDate: start,
        );
    }
  }

  @override
  bool operator ==(Object other) =>
      other is DashboardDateSelection &&
      mode == other.mode &&
      preset == other.preset &&
      isSameDashboardDay(selectedDay, other.selectedDay) &&
      isSameDashboardDay(startDate, other.startDate) &&
      isSameDashboardDay(endDate, other.endDate) &&
      isSameDashboardDay(previousReadingDate, other.previousReadingDate);

  @override
  int get hashCode => Object.hash(
        mode,
        preset,
        selectedDay.year,
        selectedDay.month,
        selectedDay.day,
        startDate.year,
        startDate.month,
        startDate.day,
        endDate.year,
        endDate.month,
        endDate.day,
        previousReadingDate.year,
        previousReadingDate.month,
        previousReadingDate.day,
      );
}

DateTime normalizeDashboardDate(DateTime date) =>
    DateTime(date.year, date.month, date.day);

DateTime endOfDashboardMonth(DateTime date) =>
    DateTime(date.year, date.month + 1, 0);

bool isSameDashboardDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// How [shiftDashboardDateSelection] advances the current selection.
enum DashboardDateShiftUnit {
  day,
  week,
  month,
  year,
  customRange,
}

DashboardDateShiftUnit dashboardDateShiftUnit(DashboardDateSelection selection) {
  if (selection.isSingleDay) return DashboardDateShiftUnit.day;
  if (selection.isMonthMode) return DashboardDateShiftUnit.month;

  final start = normalizeDashboardDate(selection.startDate);
  final end = normalizeDashboardDate(selection.endDate);
  final spanDays = end.difference(start).inDays;

  if (selection.preset == DashboardDatePreset.last7Days ||
      (start.weekday == DateTime.saturday && spanDays == 6)) {
    return DashboardDateShiftUnit.week;
  }
  if (selection.preset == DashboardDatePreset.last30Days) {
    return DashboardDateShiftUnit.customRange;
  }
  if (_looksLikeYearSelection(start, end) || spanDays >= 360) {
    return DashboardDateShiftUnit.year;
  }
  if (start.day == 1 &&
      isSameDashboardDay(end, endOfDashboardMonth(start)) &&
      spanDays >= 27 &&
      spanDays <= 30) {
    return DashboardDateShiftUnit.month;
  }
  return DashboardDateShiftUnit.customRange;
}

bool _looksLikeYearSelection(DateTime start, DateTime end) {
  if (start.month != 1 || start.day != 1) return false;
  if (end.year != start.year) return false;
  final today = normalizeDashboardDate(DateTime.now());
  final isFullYear = end.month == 12 && end.day >= 28;
  final isYearToDate = isSameDashboardDay(end, today);
  return isFullYear || isYearToDate;
}

DashboardDateSelection _rangeSelection({
  required DateTime start,
  required DateTime end,
  DashboardDatePreset preset = DashboardDatePreset.customRange,
}) {
  final s = normalizeDashboardDate(start);
  final e = normalizeDashboardDate(end);
  final orderedStart = e.isBefore(s) ? e : s;
  final orderedEnd = e.isBefore(s) ? s : e;
  return DashboardDateSelection(
    mode: DashboardDateMode.range,
    preset: preset,
    selectedDay: orderedEnd,
    startDate: orderedStart,
    endDate: orderedEnd,
    previousReadingDate: orderedStart,
  );
}

/// Move the selection one step backward (`step: -1`) or forward (`step: 1`)
/// using the same unit as the current selection (day / week / month / year / range).
DashboardDateSelection shiftDashboardDateSelection(
  DashboardDateSelection selection, {
  required int step,
}) {
  if (step == 0) return selection;
  final direction = step > 0 ? 1 : -1;
  final unit = dashboardDateShiftUnit(selection);

  switch (unit) {
    case DashboardDateShiftUnit.day:
      final newDay = normalizeDashboardDate(
        selection.selectedDay.add(Duration(days: direction)),
      );
      return DashboardDateSelection.singleDay(
        day: newDay,
        preset: DashboardDatePreset.pickDay,
      );
    case DashboardDateShiftUnit.week:
      final start = normalizeDashboardDate(selection.startDate);
      if (start.weekday == DateTime.saturday &&
          selection.endDate.difference(start).inDays == 6) {
        final newAnchor = normalizeDashboardDate(
          selection.endDate.add(Duration(days: 7 * direction)),
        );
        final week = saturdayFridayWeekContaining(newAnchor);
        return _rangeSelection(start: week.from, end: week.to);
      }
      final newEnd = normalizeDashboardDate(
        selection.endDate.add(Duration(days: 7 * direction)),
      );
      final newStart = normalizeDashboardDate(
        newEnd.subtract(const Duration(days: 6)),
      );
      return _rangeSelection(
        start: newStart,
        end: newEnd,
        preset: DashboardDatePreset.last7Days,
      );
    case DashboardDateShiftUnit.month:
      final base = selection.startDate;
      final monthStart = DateTime(base.year, base.month + direction, 1);
      return DashboardDateSelection.forPreset(
        preset: DashboardDatePreset.monthPicker,
        currentBusinessDate: normalizeDashboardDate(DateTime.now()),
        pickedMonth: monthStart,
      );
    case DashboardDateShiftUnit.year:
      final today = normalizeDashboardDate(DateTime.now());
      final year = selection.startDate.year + direction;
      if (year > today.year) {
        return selection;
      }
      final start = DateTime(year, 1, 1);
      final end = year < today.year
          ? DateTime(year, 12, 31)
          : today;
      return _rangeSelection(start: start, end: end);
    case DashboardDateShiftUnit.customRange:
      final spanDays =
          selection.endDate.difference(selection.startDate).inDays + 1;
      final delta = Duration(days: spanDays * direction);
      return _rangeSelection(
        start: selection.startDate.add(delta),
        end: selection.endDate.add(delta),
        preset: selection.preset == DashboardDatePreset.last30Days
            ? DashboardDatePreset.last30Days
            : DashboardDatePreset.customRange,
      );
  }
}

DashboardDateSelection defaultDateSelectionForSite(
  String siteId,
  DateTime currentBusinessDate,
) {
  // Default is always the current Qatar business day.
  return DashboardDateSelection.singleDay(
    day: currentBusinessDate,
    preset: DashboardDatePreset.today,
  );
}

String formatDashboardDateSelectionLabel(DashboardDateSelection selection) {
  if (selection.isSingleDay) {
    final subsequent = formatBusinessDateDisplay(selection.subsequentReadingDate);
    final previous = formatBusinessDateDisplay(selection.previousReadingDate);
    if (isSameDashboardDay(
      selection.previousReadingDate,
      selection.subsequentReadingDate,
    )) {
      return subsequent;
    }
    return '$subsequent · Previous $previous';
  }
  if (selection.isMonthMode) {
    final d = selection.endDate;
    return '${_monthName(d.month)} ${d.year}';
  }
  return '${formatBusinessDateDisplay(selection.startDate)} – '
      '${formatBusinessDateDisplay(selection.endDate)}';
}

String _monthName(int month) => switch (month) {
      1 => 'January',
      2 => 'February',
      3 => 'March',
      4 => 'April',
      5 => 'May',
      6 => 'June',
      7 => 'July',
      8 => 'August',
      9 => 'September',
      10 => 'October',
      11 => 'November',
      12 => 'December',
      _ => '$month',
    };

String utilityReadingsSubtitle({
  required String utilityLabel,
  required String unitCode,
  required DashboardDateSelection selection,
}) {
  return '$utilityLabel readings for ${formatDashboardDateSelectionLabel(selection)} · $unitCode';
}

String meterReadingsSectionSubtitle({
  required String unitCode,
  required DashboardDateSelection selection,
}) {
  return 'Previous and subsequent readings with consumption in $unitCode for '
      '${formatBusinessDateDisplay(selection.subsequentReadingDate)}.';
}

/// Chart range that mirrors the dashboard date selection.
///
/// Long spans use monthly/yearly buckets so charts compare months or years.
ChartPeriodRange? chartRangeForDateSelection(DashboardDateSelection selection) {
  if (selection.isSingleDay) return null;
  final from = normalizeDashboardDate(selection.startDate);
  final to = normalizeDashboardDate(selection.endDate);
  final spanDays = to.difference(from).inDays;

  // Multi-year comparison → one bar per year (2024, 2025, 2026, …).
  if (from.month == 1 &&
      from.day == 1 &&
      to.year - from.year >= 1) {
    return ChartPeriodRange(
      period: ChartPeriod.yearly,
      from: from,
      to: to,
      bucket: ChartBucket.yearly,
    );
  }

  // ~12 calendar months → one bar per month.
  if (from.day == 1 && spanDays >= 300 && spanDays <= 400) {
    return ChartPeriodRange(
      period: ChartPeriod.monthly,
      from: from,
      to: to,
      bucket: ChartBucket.monthly,
    );
  }

  final unit = dashboardDateShiftUnit(selection);
  final bucket = switch (unit) {
    DashboardDateShiftUnit.year => ChartBucket.monthly,
    DashboardDateShiftUnit.month => ChartBucket.daily,
    DashboardDateShiftUnit.week => ChartBucket.daily,
    DashboardDateShiftUnit.customRange =>
      spanDays > 90 ? ChartBucket.monthly : ChartBucket.daily,
    DashboardDateShiftUnit.day => ChartBucket.daily,
  };
  final period = switch (unit) {
    DashboardDateShiftUnit.year => ChartPeriod.yearly,
    DashboardDateShiftUnit.month => ChartPeriod.monthly,
    DashboardDateShiftUnit.week => ChartPeriod.weekly,
    _ => spanDays >= 28 ? ChartPeriod.monthly : ChartPeriod.weekly,
  };
  return ChartPeriodRange(
    period: period,
    from: from,
    to: to,
    bucket: bucket,
  );
}

/// Maps a dashboard date selection to a chart period chip, if it matches one.
UtilityChartPeriodState? chartPeriodStateForDateSelection(
  DashboardDateSelection selection,
) {
  if (selection.isSingleDay) return null;

  final start = normalizeDashboardDate(selection.startDate);
  final end = normalizeDashboardDate(selection.endDate);
  final spanDays = end.difference(start).inDays;
  final today = qatarBusinessDate();

  if (selection.preset == DashboardDatePreset.last30Days ||
      (spanDays == 30 && isSameDashboardDay(end, today))) {
    return const UtilityChartPeriodState(
      kind: UtilityChartPeriodKind.last30Days,
    );
  }

  // 12-month comparison window.
  if (start.day == 1 && spanDays >= 300 && spanDays <= 400) {
    return const UtilityChartPeriodState(
      kind: UtilityChartPeriodKind.twelveMonths,
    );
  }

  // Multi-year (≈5 years) comparison window.
  if (start.month == 1 &&
      start.day == 1 &&
      end.year - start.year >= 1) {
    return const UtilityChartPeriodState(
      kind: UtilityChartPeriodKind.fiveYears,
    );
  }

  return null;
}

DateTime _monthsBeforeDay(DateTime day, int monthsBack) {
  var year = day.year;
  var month = day.month - monthsBack;
  while (month <= 0) {
    month += 12;
    year -= 1;
  }
  return DateTime(year, month, 1);
}

/// Builds a dashboard date selection for a chart period preset.
DashboardDateSelection dateSelectionForChartPeriodKind({
  required UtilityChartPeriodKind kind,
  required DateTime anchorDate,
}) {
  final anchor = normalizeDashboardDate(anchorDate);
  switch (kind) {
    case UtilityChartPeriodKind.last30Days:
      return DashboardDateSelection.forPreset(
        preset: DashboardDatePreset.last30Days,
        currentBusinessDate: anchor,
      );
    case UtilityChartPeriodKind.twelveMonths:
      final start = _monthsBeforeDay(anchor, 11);
      return DashboardDateSelection(
        mode: DashboardDateMode.range,
        preset: DashboardDatePreset.customRange,
        selectedDay: anchor,
        startDate: start,
        endDate: anchor,
        previousReadingDate: start,
      );
    case UtilityChartPeriodKind.fiveYears:
      final start = DateTime(anchor.year - 4, 1, 1);
      return DashboardDateSelection(
        mode: DashboardDateMode.range,
        preset: DashboardDatePreset.customRange,
        selectedDay: anchor,
        startDate: start,
        endDate: anchor,
        previousReadingDate: start,
      );
  }
}
