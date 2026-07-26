import 'package:flutter/material.dart';

/// Icons for meter category codes from `meter_categories`.
class MeterCategoryIcons {
  static IconData iconForCode(String code) {
    switch (code) {
      case 'water':
        return Icons.water_drop_outlined;
      case 'electricity':
        return Icons.bolt_outlined;
      case 'btu':
        return Icons.ac_unit_outlined;
      case 'fuel':
        return Icons.local_gas_station_outlined;
      default:
        return Icons.speed_outlined;
    }
  }
}
