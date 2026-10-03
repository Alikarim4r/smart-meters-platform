import 'package:dashboard_app/widgets/chart_widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('soft chart ceiling clips extreme visual outliers safely', () {
    final values = <double>[160, 170, 180, 175, 190, 4207.73];
    final maxY = chartSoftMaxY(values);

    expect(maxY, lessThan(values.last));
    expect(chartHasClippedOutlier(values, maxY), isTrue);
    expect(chartDisplayY(values.last, maxY), lessThanOrEqualTo(maxY));
    expect(chartDisplayY(180, maxY), 180);
    expect(chartDisplayY(-4, maxY), 0);
  });

  test('normal series is not reported as visually clipped', () {
    final values = <double>[1, 2, 3, 4, 5];
    final maxY = chartSoftMaxY(values);

    expect(chartHasClippedOutlier(values, maxY), isFalse);
    expect(chartDisplayY(5, maxY), 5);
  });
}
