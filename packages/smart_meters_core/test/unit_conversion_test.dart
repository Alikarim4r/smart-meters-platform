import 'package:flutter_test/flutter_test.dart';
import 'package:smart_meters_core/smart_meters_core.dart';

void main() {
  group('UnitConversion.canonicalCode', () {
    test('case / whitespace insensitive with display aliases', () {
      expect(UnitConversion.canonicalCode(' kWh '), 'kwh');
      expect(UnitConversion.canonicalCode('kWh thermal'), 'kwh_thermal');
      expect(UnitConversion.canonicalCode('TRH'), 'ton_hour');
      expect(UnitConversion.canonicalCode('RT-hour'), 'rt_hour');
      expect(UnitConversion.canonicalCode('m³'), 'm3');
      expect(UnitConversion.canonicalCode('kW·h'), 'kwh');
      expect(UnitConversion.canonicalCode(null), isNull);
      expect(UnitConversion.canonicalCode('   '), isNull);
    });
  });

  group('UnitConversion.factor', () {
    test('same-category conversions', () {
      expect(UnitConversion.factor('mwh', 'kwh'), 1000);
      expect(UnitConversion.factor('MWh', 'KWH'), 1000);
      expect(UnitConversion.factor('kwh', 'mwh'), closeTo(0.001, 1e-15));
      expect(UnitConversion.factor('liter', 'm3'), closeTo(0.001, 1e-15));
      expect(UnitConversion.factor('ton_hour', 'kWh thermal'), 3.51685);
      expect(UnitConversion.factor('rt_hour', 'ton_hour'), 1);
    });

    test('kVAh is never silently mapped to kWh', () {
      expect(UnitConversion.factor('kvah', 'kwh'), isNull);
      expect(UnitConversion.factor('kVAh', 'kWh'), isNull);
      expect(UnitConversion.factor('kwh', 'kvah'), isNull);
      expect(UnitConversion.factor('mvah', 'mwh'), isNull);
      // Apparent ↔ apparent is a pure scale change and is allowed.
      expect(UnitConversion.factor('mvah', 'kvah'), 1000);
      expect(UnitConversion.isApparentEnergy('KVAH'), isTrue);
      expect(UnitConversion.isApparentEnergy('kwh'), isFalse);
    });

    test('thermal and electric kWh never mix; cross-category is null', () {
      expect(UnitConversion.factor('kwh_thermal', 'kwh'), isNull);
      expect(UnitConversion.factor('kWh thermal', 'kWh'), isNull);
      expect(UnitConversion.factor('m3', 'kwh'), isNull);
    });

    test('unknown / null units are incompatible, identical codes are 1', () {
      expect(UnitConversion.factor('furlong', 'kwh'), isNull);
      expect(UnitConversion.factor(null, 'kwh'), isNull);
      expect(UnitConversion.factor('kwh', null), isNull);
      expect(UnitConversion.factor('custom', 'CUSTOM'), 1);
    });

    test('ton-hour constant matches the catalog / DB factor', () {
      final spec = ExpandedUnitCatalog.forCategoryCode('btu')
          .firstWhere((s) => s.code == 'ton_hour');
      expect(UnitConversion.tonHourToKwhThermal, spec.unitToBaseFactor);
    });
  });
}
