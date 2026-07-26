import 'package:flutter_test/flutter_test.dart';

void main() {
  group('alert repository meter reading sort', () {
    test('copying empty default list before sort does not throw', () {
      final meterReadings = List<int>.from(const []);
      expect(
        () => meterReadings.sort((a, b) => b.compareTo(a)),
        returnsNormally,
      );
    });

    test('sorting const default list directly throws', () {
      final meterReadings = const <int>[];
      expect(
        () => meterReadings.sort((a, b) => b.compareTo(a)),
        throwsUnsupportedError,
      );
    });
  });
}
