import 'package:flutter_test/flutter_test.dart';
import 'package:smart_meters_core/smart_meters_core.dart';

void main() {
  group('classifyCumulativeDelta', () {
    test('first reading → 0', () {
      final d = classifyCumulativeDelta(previous: null, current: 123);
      expect(d.consumption, 0);
      expect(d.transition, ConsumptionTransition.first);
      expect(d.isUnverifiable, isFalse);
    });

    test('increase → difference', () {
      final d = classifyCumulativeDelta(previous: 100, current: 112.5);
      expect(d.consumption, 12.5);
      expect(d.transition, ConsumptionTransition.normal);
    });

    test('near-capacity rollover is counted', () {
      final d = classifyCumulativeDelta(
        previous: 9990,
        current: 10,
        normalizedCapacity: 10000,
      );
      expect(d.consumption, 20);
      expect(d.isRollover, isTrue);
      expect(d.transition.dbValue, 'rollover');
    });

    test('no capacity: a drop is never invented nor clamped to 0', () {
      final d = classifyCumulativeDelta(previous: 9990, current: 10);
      expect(d.consumption, isNull);
      expect(d.transition, ConsumptionTransition.resetOrReplacement);
      expect(d.isUnverifiable, isTrue);
    });

    test('invalid capacities (0, negative, NaN, infinite) are ignored', () {
      for (final cap in [0.0, -10000.0, double.nan, double.infinity]) {
        final d = classifyCumulativeDelta(
          previous: 9990,
          current: 10,
          normalizedCapacity: cap,
        );
        expect(d.consumption, isNull, reason: 'cap=$cap');
        expect(d.isRollover, isFalse, reason: 'cap=$cap');
      }
    });

    test('correction (small drop) on a capacity meter is not a rollover', () {
      final d = classifyCumulativeDelta(
        previous: 9995,
        current: 9950,
        normalizedCapacity: 10000,
      );
      expect(d.consumption, isNull);
      expect(d.transition, ConsumptionTransition.correctionOrImplausibleDrop);
    });

    test('replacement (mid-register → ~0) on a capacity meter is unverifiable',
        () {
      final d = classifyCumulativeDelta(
        previous: 5000,
        current: 3,
        normalizedCapacity: 10000,
      );
      expect(d.consumption, isNull);
      expect(d.transition, ConsumptionTransition.resetOrReplacement);
    });

    test('implausible drop (current not near zero) is unverifiable', () {
      final d = classifyCumulativeDelta(
        previous: 9990,
        current: 4000,
        normalizedCapacity: 10000,
      );
      expect(d.consumption, isNull);
      expect(d.transition, ConsumptionTransition.correctionOrImplausibleDrop);
    });

    test('previous above capacity is not a rollover', () {
      final d = classifyCumulativeDelta(
        previous: 10500,
        current: 5,
        normalizedCapacity: 10000,
      );
      expect(d.isRollover, isFalse);
      expect(d.consumption, isNull);
    });

    test('window edges: prev = cap×0.9 and current = cap×0.1 accepted', () {
      final inside = classifyCumulativeDelta(
        previous: 900,
        current: 100,
        normalizedCapacity: 1000,
      );
      expect(inside.isRollover, isTrue);
      expect(inside.consumption, 200);

      final outside = classifyCumulativeDelta(
        previous: 899,
        current: 50,
        normalizedCapacity: 1000,
      );
      expect(outside.isRollover, isFalse);
      expect(outside.consumption, isNull);
    });

    test('statuses round-trip through the DB value', () {
      for (final t in ConsumptionTransition.values) {
        expect(ConsumptionTransition.fromDb(t.dbValue), t);
      }
      expect(ConsumptionTransition.fromDb('nope'), isNull);
      expect(ConsumptionTransition.fromDb(null), isNull);
    });
  });

  group('normalizedRolloverCapacity (factor × multiplier preserved)', () {
    test('scales raw capacity to the normalized_value scale', () {
      final cap = normalizedRolloverCapacity(
        rawCapacity: 10000,
        unitToBaseFactor: 0.001,
        meterMultiplier: 2,
      );
      expect(cap, closeTo(20, 1e-12));
      // raw 9990 → 19.98, raw 10 → 0.02 (normalized = raw × f × m)
      final d = classifyCumulativeDelta(
        previous: 9990 * 0.001 * 2,
        current: 10 * 0.001 * 2,
        normalizedCapacity: cap,
      );
      expect(d.isRollover, isTrue);
      expect(d.consumption, closeTo(0.04, 1e-9));
    });

    test('precision: large register with fractional factor stays exact enough',
        () {
      final cap = normalizedRolloverCapacity(
        rawCapacity: 99999999.999999,
        unitToBaseFactor: 0.000293071,
        meterMultiplier: 1,
      )!;
      final prev = 99999990.5 * 0.000293071;
      final cur = 1.25 * 0.000293071;
      final d = classifyCumulativeDelta(
        previous: prev,
        current: cur,
        normalizedCapacity: cap,
      );
      expect(d.isRollover, isTrue);
      expect(d.consumption, closeTo((99999999.999999 - 99999990.5 + 1.25) *
          0.000293071, 1e-6));
    });

    test('null / non-positive / non-finite inputs → no capacity', () {
      expect(
        normalizedRolloverCapacity(
          rawCapacity: null,
          unitToBaseFactor: 1,
          meterMultiplier: 1,
        ),
        isNull,
      );
      expect(
        normalizedRolloverCapacity(
          rawCapacity: 0,
          unitToBaseFactor: 1,
          meterMultiplier: 1,
        ),
        isNull,
      );
      expect(
        normalizedRolloverCapacity(
          rawCapacity: 100,
          unitToBaseFactor: 0,
          meterMultiplier: 1,
        ),
        isNull,
      );
      expect(
        normalizedRolloverCapacity(
          rawCapacity: 100,
          unitToBaseFactor: 1,
          meterMultiplier: -1,
        ),
        isNull,
      );
      expect(
        normalizedRolloverCapacity(
          rawCapacity: double.nan,
          unitToBaseFactor: 1,
          meterMultiplier: 1,
        ),
        isNull,
      );
    });
  });

  test('Meter.fromJson parses rollover_capacity (num or string)', () {
    Map<String, dynamic> json(Object? cap) => {
          'id': 'm1',
          'site_id': 's1',
          'meter_code': 'M1',
          'name_en': 'M1',
          'name_ar': 'M1',
          'category': 'water',
          'unit': 'm3',
          'unit_to_base_factor': 1,
          'base_unit': 'm3',
          'meter_multiplier': 1,
          'is_active': true,
          'rollover_capacity': cap,
        };
    expect(Meter.fromJson(json(100000)).rolloverCapacity, 100000);
    expect(Meter.fromJson(json('99999.5')).rolloverCapacity, 99999.5);
    expect(Meter.fromJson(json(null)).rolloverCapacity, isNull);
  });
}
