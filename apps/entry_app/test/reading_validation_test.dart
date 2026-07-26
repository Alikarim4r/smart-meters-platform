import 'package:entry_app/utils/reading_validation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('validateCumulativeReading', () {
    test('rejects empty input', () {
      expect(
        validateCumulativeReading(''),
        'Please enter the cumulative meter reading.',
      );
    });

    test('rejects non-numeric input', () {
      expect(
        validateCumulativeReading('abc'),
        'Reading must be a valid number.',
      );
    });

    test('rejects reading lower than previous', () {
      expect(
        validateCumulativeReading('90', lastRawValue: 100),
        'This reading is lower than the previous reading.',
      );
    });

    test('accepts valid reading', () {
      expect(validateCumulativeReading('110', lastRawValue: 100), isNull);
    });
  });

  group('shouldWarnHighReading', () {
    test('warns when reading more than double last value', () {
      expect(
        shouldWarnHighReading(newReading: 250, lastRawValue: 100),
        isTrue,
      );
      expect(
        shouldWarnHighReading(newReading: 150, lastRawValue: 100),
        isFalse,
      );
    });

    test('warns when increase exceeds 3x average daily consumption', () {
      expect(
        shouldWarnHighReading(
          newReading: 160,
          lastRawValue: 100,
          averageDailyConsumption: 10,
        ),
        isTrue,
      );
      expect(
        shouldWarnHighReading(
          newReading: 125,
          lastRawValue: 100,
          averageDailyConsumption: 10,
        ),
        isFalse,
      );
    });

    test('does not warn without last reading', () {
      expect(
        shouldWarnHighReading(newReading: 9999),
        isFalse,
      );
    });
  });
}
