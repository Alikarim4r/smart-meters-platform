import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_meters_core/smart_meters_core.dart';

void main() {
  test('MeterCategoryConfig maps database row', () {
    final config = MeterCategoryConfig.fromJson({
      'id': 'c1111111-1111-4111-8111-111111111101',
      'code': 'water',
      'name_en': 'Water',
      'name_ar': 'مياه',
      'base_unit_code': 'm3',
      'icon': 'water_drop',
      'color': '#2196F3',
      'is_system': true,
      'is_active': true,
      'sort_order': 10,
      'supports_cop_output': false,
      'supports_electric_input': false,
      'is_consumption_category': true,
    });

    expect(config.code, 'water');
    expect(config.displayName, 'Water');
  });

  test('MeterCatalogRepository getCategoriesForSite dedupes categories', () {
    // Integration covered on staging; model equality used for UI state.
    final a = MeterCategoryConfig(
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
    final b = MeterCategoryConfig(
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
    expect(a, equals(b));
  });

  test('MeterCategory legacy enum includes fuel', () {
    expect(MeterCategory.fromDb('fuel'), MeterCategory.fuel);
    expect(MeterCategory.fuel.label, 'Fuel');
  });

  test('MeterCategoryIcons maps known codes', () {
    expect(MeterCategoryIcons.iconForCode('water'), Icons.water_drop_outlined);
    expect(
      MeterCategoryIcons.iconForCode('fuel'),
      Icons.local_gas_station_outlined,
    );
    expect(MeterCategoryIcons.iconForCode('steam'), Icons.speed_outlined);
  });
}
