import 'package:flutter/material.dart';
import 'package:smart_meters_core/smart_meters_core.dart';

/// Entry alias for shared [BrandTheme].
abstract final class EntryTheme {
  static ThemeData light() => BrandTheme.light();
  static ThemeData dark() => BrandTheme.dark();
}
