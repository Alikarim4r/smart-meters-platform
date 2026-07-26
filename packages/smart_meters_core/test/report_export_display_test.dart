import 'package:flutter_test/flutter_test.dart';
import 'package:smart_meters_core/smart_meters_core.dart';

void main() {
  group('joinedCatalogDisplayName', () {
    test('prefers name_en over code', () {
      expect(
        joinedCatalogDisplayName({'name_en': 'Cubic metre', 'code': 'm3'}),
        'Cubic metre',
      );
    });

    test('falls back to code when name_en missing', () {
      expect(joinedCatalogDisplayName({'code': 'kWh'}), 'kWh');
    });

    test('falls back to legacy meter unit label', () {
      expect(
        joinedCatalogDisplayName(
          null,
          legacyFallback: legacyMeterUnitLabel('m3'),
        ),
        'm³',
      );
    });

    test('parses export row labels without display_name', () {
      final meterJson = {
        'category': 'water',
        'source': 'kahramaa',
        'unit': 'm3',
        'meter_categories': {'code': 'water', 'name_en': 'Water'},
        'meter_sources': {'code': 'kahramaa', 'name_en': 'Kahramaa'},
        'meter_units': {'code': 'm3', 'name_en': 'Cubic metre'},
      };

      expect(
        joinedCatalogDisplayName(
          Map<String, dynamic>.from(meterJson['meter_categories'] as Map),
          legacyFallback: legacyMeterCategoryLabel(meterJson['category']),
        ),
        'Water',
      );
      expect(
        joinedCatalogDisplayName(
          Map<String, dynamic>.from(meterJson['meter_units'] as Map),
          legacyFallback: legacyMeterUnitLabel(meterJson['unit']),
        ),
        'Cubic metre',
      );
      expect(
        joinedCatalogDisplayName(
          Map<String, dynamic>.from(meterJson['meter_sources'] as Map),
          legacyFallback: legacyMeterSourceLabel(meterJson['source']),
        ),
        'Kahramaa',
      );
    });

    test('parses correction row labels without display_name', () {
      final meterJson = {
        'name_en': 'Main Water',
        'meter_code': 'W-01',
        'category': 'water',
        'unit': 'm3',
        'meter_categories': {'code': 'water', 'name_en': 'Water'},
        'meter_units': {'code': 'm3', 'name_en': 'Cubic metre'},
      };

      final categoryName = joinedCatalogDisplayName(
        Map<String, dynamic>.from(meterJson['meter_categories'] as Map),
        legacyFallback: legacyMeterCategoryLabel(meterJson['category']),
      );
      final unitLabel = joinedCatalogDisplayName(
        Map<String, dynamic>.from(meterJson['meter_units'] as Map),
        legacyFallback: legacyMeterUnitLabel(meterJson['unit']),
      );

      expect(categoryName, 'Water');
      expect(unitLabel, 'Cubic metre');
    });
  });
}
