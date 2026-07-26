import 'package:smart_meters_core/smart_meters_core.dart';

/// Running total of daily/period consumption points.
List<TimeSeriesPoint> cumulativeChartPoints(List<TimeSeriesPoint> points) {
  var running = 0.0;
  return [
    for (final point in points)
      TimeSeriesPoint(
        date: point.date,
        value: running += point.value,
        label: point.label,
      ),
  ];
}

const _weekdayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

/// Average consumption by weekday (Mon–Sun) from daily points.
List<TimeSeriesPoint> weekdayAveragePoints(
  List<TimeSeriesPoint> points, {
  List<String>? labels,
}) {
  final weekdayLabels = labels ?? _weekdayLabels;
  final sums = List<double>.filled(7, 0);
  final counts = List<int>.filled(7, 0);
  for (final point in points) {
    final index = point.date.weekday - 1; // Mon=0 … Sun=6
    sums[index] += point.value;
    counts[index] += 1;
  }
  return [
    for (var i = 0; i < 7; i++)
      TimeSeriesPoint(
        date: DateTime(2000, 1, 3 + i), // Monday-based placeholder dates
        value: counts[i] == 0 ? 0 : sums[i] / counts[i],
        label: weekdayLabels[i],
      ),
  ];
}
