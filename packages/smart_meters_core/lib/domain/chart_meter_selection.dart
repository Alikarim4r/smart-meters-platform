import '../models/meter.dart';
import '../models/meter_reading_card_data.dart';

/// Max meters selectable for chart comparison (raised so all mains can fit).
const kMeterComparisonMaxSelection = 12;

/// Canonical water-source bucket for a meter (never mix across buckets in totals).
String meterWaterSourceGroupKey({
  required String sourceCode,
  String sourceName = '',
}) {
  final code = sourceCode.toLowerCase().trim();
  final name = sourceName.toLowerCase().trim();
  if (code == 'kahramaa' ||
      code == 'potable' ||
      name.contains('kahramaa') ||
      name.contains('drinking')) {
    return 'kahramaa';
  }
  if (code == 'tse' || name.contains('tse')) return 'tse';
  if (code == 'ro' ||
      code == 'product' ||
      code == 'ro_product' ||
      name.contains(' ro') ||
      name.startsWith('ro')) {
    return 'ro';
  }
  if (code == 'chilled_water' ||
      name.contains('chilled') ||
      name.contains('flow')) {
    return 'chilled_water';
  }
  if (name.contains('irrigation') || code == 'tanker') return 'irrigation';
  if (name.contains('storm') || name.contains('blowdown')) return 'other';
  if (code == 'other' || code.isEmpty) return 'other';
  return code;
}

String meterWaterSourceGroupKeyForMeter(Meter meter) => meterWaterSourceGroupKey(
      sourceCode: meter.sourceConfig?.code ?? meter.source.dbValue,
      sourceName: meter.sourceDisplayName,
    );

/// Default chart selection: all main meters; if none, all active meters
/// (e.g. electricity sites without a main). Comparison is per-meter series.
Set<String> defaultChartComparisonMeterIds(
  List<MeterReadingCardData> cards, {
  int maxSelection = kMeterComparisonMaxSelection,
}) {
  final active = cards.where((c) => c.isActive).toList();
  if (active.isEmpty) return {};
  final mains = active.where((c) => c.isMain).toList();
  final pool = mains.isNotEmpty ? mains : active;
  return {
    for (final c in pool.take(maxSelection)) c.meterId,
  };
}

/// When summing a category trend, keep only one water-source group so potable
/// and TSE (etc.) are never added together.
List<String>? meterIdsForCompatibleWaterTrend(List<Meter> categoryMeters) {
  if (categoryMeters.isEmpty) return null;
  final isWater = categoryMeters.any((m) {
    final code = m.categoryConfig?.code ?? m.category.dbValue;
    return code == 'water';
  });
  if (!isWater) return null;

  final groups = <String, List<Meter>>{};
  for (final m in categoryMeters) {
    final key = meterWaterSourceGroupKeyForMeter(m);
    groups.putIfAbsent(key, () => []).add(m);
  }
  if (groups.length <= 1) return null;

  // Prefer potable/Kahramaa; else the largest group.
  final preferred = groups['kahramaa'] ??
      groups.values.reduce((a, b) => a.length >= b.length ? a : b);
  return [for (final m in preferred) m.id];
}
