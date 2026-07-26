import 'package:flutter_test/flutter_test.dart';
import 'package:smart_meters_core/smart_meters_core.dart';

import 'package:admin_app/utils/catalog_validation.dart';

void main() {
  test('validateCatalogCode accepts snake_case', () {
    expect(validateCatalogCode('compressed_air'), isNull);
    expect(validateCatalogCode('fuel_test'), isNull);
  });

  test('validateCatalogCode rejects invalid codes', () {
    expect(validateCatalogCode(''), isNotNull);
    expect(validateCatalogCode('Compressed Air'), isNotNull);
    expect(validateCatalogCode('123bad'), isNotNull);
  });

  test('validateUnitFactor requires positive number', () {
    expect(validateUnitFactor('1'), isNull);
    expect(validateUnitFactor('0'), isNotNull);
    expect(validateUnitFactor('-1'), isNotNull);
  });

  test('validateSingleBaseUnit blocks duplicate base', () {
    final units = [
      const MeterUnitConfig(
        id: 'u1',
        categoryId: 'c1',
        code: 'm3',
        nameEn: 'm3',
        unitToBaseFactor: 1,
        isBase: true,
        isActive: true,
        sortOrder: 1,
      ),
    ];
    expect(
      validateSingleBaseUnit(
        isBase: true,
        editingUnitId: null,
        existingUnits: units,
      ),
      isNotNull,
    );
  });

  test('isProtectedSystemCategory covers seeded codes', () {
    const category = MeterCategoryConfig(
      id: '1',
      code: 'water',
      nameEn: 'Water',
      baseUnitCode: 'm3',
      isSystem: true,
      isActive: true,
      sortOrder: 1,
      supportsCopOutput: false,
      supportsElectricInput: false,
      isConsumptionCategory: true,
    );
    expect(isProtectedSystemCategory(category), isTrue);
  });
}
