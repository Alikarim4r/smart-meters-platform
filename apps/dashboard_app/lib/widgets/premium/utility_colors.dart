import 'package:flutter/material.dart';
import 'package:smart_meters_core/smart_meters_core.dart';

abstract final class DashboardUtilityColors {
  static const water = Color(0xFF2563EB);
  static const electricity = Color(0xFFD97706);
  static const btu = Color(0xFF7C3AED);
  static const fuel = Color(0xFFEA580C);
  static const success = Color(0xFF16A34A);
  static const warning = Color(0xFFF59E0B);
  static const critical = Color(0xFFDC2626);
  static const info = Color(0xFF0EA5E9);

  static Color forCategoryCode(String? code) {
    return switch (code) {
      'water' => water,
      'electricity' => electricity,
      'btu' => btu,
      'fuel' => fuel,
      _ => AppColors.navyMuted,
    };
  }

  static Color forLegacyCategory(MeterCategory? category) {
    if (category == null) return AppColors.navyMuted;
    return switch (category) {
      MeterCategory.water => water,
      MeterCategory.electricity => electricity,
      MeterCategory.btu => btu,
      MeterCategory.fuel => fuel,
    };
  }
}
