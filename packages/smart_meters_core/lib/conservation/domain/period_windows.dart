/// Inclusive calendar date range (date-only semantics).
class DateTimeRangeInclusive {
  const DateTimeRangeInclusive({required this.start, required this.end});

  final DateTime start;
  final DateTime end;

  int get dayCount => inclusiveDayCount(start, end);
}

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

int inclusiveDayCount(DateTime start, DateTime end) {
  final a = dateOnly(start);
  final b = dateOnly(end);
  if (b.isBefore(a)) return 0;
  return b.difference(a).inDays + 1;
}

int daysInMonth(int year, int month) => DateTime(year, month + 1, 0).day;

/// Shift a calendar date by [years], clamping day-of-month for shorter months
/// (including Feb 29 → Feb 28 in non-leap years).
DateTime shiftCalendarYears(DateTime date, int years) {
  final d = dateOnly(date);
  final targetYear = d.year + years;
  final dim = daysInMonth(targetYear, d.month);
  final day = d.day <= dim ? d.day : dim;
  return DateTime(targetYear, d.month, day);
}

/// Previous period with the **same inclusive day count** ending the day before
/// [currentStart].
///
/// Example: current 1 Jul–29 Jul (29 days) → previous 2 Jun–30 Jun (29 days).
DateTimeRangeInclusive previousPeriodOfEqualLength(
  DateTime currentStart,
  DateTime currentEnd,
) {
  final start = dateOnly(currentStart);
  final end = dateOnly(currentEnd);
  final length = inclusiveDayCount(start, end);
  if (length <= 0) {
    return DateTimeRangeInclusive(start: start, end: end);
  }
  final prevEnd = start.subtract(const Duration(days: 1));
  final prevStart = prevEnd.subtract(Duration(days: length - 1));
  return DateTimeRangeInclusive(start: prevStart, end: prevEnd);
}

/// Same calendar span one year earlier (month/day aware; leap-safe).
///
/// Example: 01–29 Jul 2026 → 01–29 Jul 2025.
DateTimeRangeInclusive samePeriodLastYear(
  DateTime currentStart,
  DateTime currentEnd,
) {
  return DateTimeRangeInclusive(
    start: shiftCalendarYears(currentStart, -1),
    end: shiftCalendarYears(currentEnd, -1),
  );
}
