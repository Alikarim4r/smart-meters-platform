import '../catalog/expanded_unit_catalog.dart';

/// Single source of truth for unit-code normalisation and conversion factors.
///
/// Factors come from [ExpandedUnitCatalog] (mirrors `meter_units` /
/// `unit_to_base_factor` in the DB) so client conversions agree with the
/// server-side normalisation of `meter_readings.normalized_value`.
///
/// Rules:
/// - Codes are case/whitespace-insensitive and common display aliases
///   (`kWh thermal`, `ton-hour`, `TRh`, `m³`, `kW·h` …) resolve to catalog codes.
/// - Conversion only happens between units of the same category; thermal and
///   electric kWh never mix.
/// - Apparent energy (kVAh / MVAh) is never converted to real energy (kWh):
///   that requires a power factor we do not have.
/// - Unknown / null units return `null` — callers must treat that as
///   "cannot convert", never as 1:1.
abstract final class UnitConversion {
  /// 1 refrigeration ton-hour in kWh thermal. Matches DB
  /// `unit_to_base_factor` for `ton_hour` / `rt_hour` (migrations 001/017/118).
  static const double tonHourToKwhThermal = 3.51685;

  static const _categories = ['water', 'electricity', 'btu', 'fuel'];

  static const _apparentEnergy = {'kvah', 'mvah'};

  static const _aliases = <String, String>{
    // Thermal kWh (DB BTU category base unit display code is 'kWh thermal').
    'kwh thermal': 'kwh_thermal',
    'kwh-thermal': 'kwh_thermal',
    'kwht': 'kwh_thermal',
    'kwh(t)': 'kwh_thermal',
    'kwh(th)': 'kwh_thermal',
    'kwh th': 'kwh_thermal',
    'kwh_th': 'kwh_thermal',
    'kwhth': 'kwh_thermal',
    'kwh-th': 'kwh_thermal',
    'wh thermal': 'wh_thermal',
    // Refrigeration ton-hours.
    'ton-hour': 'ton_hour',
    'ton hour': 'ton_hour',
    'tonhour': 'ton_hour',
    'ton-hr': 'ton_hour',
    'trh': 'ton_hour',
    'tr·h': 'ton_hour',
    'tr-h': 'ton_hour',
    'rt-hour': 'rt_hour',
    'rt hour': 'rt_hour',
    'rth': 'rt_hour',
    'rt-h': 'rt_hour',
    'rt·h': 'rt_hour',
    // Electric energy.
    'kw·h': 'kwh',
    'kw-h': 'kwh',
    'kw h': 'kwh',
    'kva·h': 'kvah',
    'kva-h': 'kvah',
    'kva h': 'kvah',
    'mva·h': 'mvah',
    // Volume.
    'm³': 'm3',
    'cubic meter': 'm3',
    'cubic metre': 'm3',
    'l': 'liter',
    'litre': 'liter',
    'litres': 'liter',
    'liters': 'liter',
  };

  /// Canonical catalog code for [raw], or `null` when [raw] is null/blank.
  static String? canonicalCode(String? raw) {
    if (raw == null) return null;
    final lower = raw.trim().toLowerCase();
    if (lower.isEmpty) return null;
    return _aliases[lower] ?? lower;
  }

  /// True for apparent-energy units (kVAh, MVAh).
  static bool isApparentEnergy(String? raw) =>
      _apparentEnergy.contains(canonicalCode(raw));

  /// Multiplicative factor converting a value in [from] into [to], or `null`
  /// when the units are unknown, belong to different categories, or would
  /// require mixing apparent and real energy.
  static double? factor(String? from, String? to) {
    final f = canonicalCode(from);
    final t = canonicalCode(to);
    if (f == null || t == null) return null;
    if (f == t) return 1.0;
    if (_apparentEnergy.contains(f) != _apparentEnergy.contains(t)) {
      return null;
    }
    for (final category in _categories) {
      final fromFactor = _baseFactor(category, f);
      final toFactor = _baseFactor(category, t);
      if (fromFactor != null && toFactor != null && toFactor != 0) {
        return fromFactor / toFactor;
      }
    }
    return null;
  }

  /// Convert [value] (cooling / thermal energy) to kWh thermal.
  ///
  /// Accepts BTU-category units plus plain kWh/MWh/Wh, which are thermal by
  /// context on a cooling meter. Returns `null` for unknown, null or
  /// apparent-energy units.
  static double? toKwhThermal(double value, String? unitCode) {
    final code = canonicalCode(unitCode);
    if (code == null || _apparentEnergy.contains(code)) return null;
    final thermal = _baseFactor('btu', code);
    if (thermal != null) return value * thermal;
    if (code == 'kwh' || code == 'mwh' || code == 'wh') {
      return value * _baseFactor('electricity', code)!;
    }
    return null;
  }

  /// Convert [value] (electric energy) to kWh. Returns `null` for unknown,
  /// null, thermal-only or apparent-energy (kVAh/MVAh) units.
  static double? toKwhElectric(double value, String? unitCode) {
    final f = factor(unitCode, 'kwh');
    return f == null ? null : value * f;
  }

  static double? _baseFactor(String category, String code) {
    for (final spec in ExpandedUnitCatalog.forCategoryCode(category)) {
      if (spec.code == code) return spec.unitToBaseFactor;
    }
    return null;
  }
}
