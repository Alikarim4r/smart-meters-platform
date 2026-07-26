import 'enums.dart';
import 'meter_category_config.dart';
import 'meter_source_config.dart';
import 'meter_unit_config.dart';

class Meter {
  const Meter({
    required this.id,
    required this.siteId,
    required this.meterCode,
    required this.nameEn,
    required this.nameAr,
    required this.categoryId,
    required this.sourceId,
    required this.unitId,
    required this.category,
    required this.source,
    required this.unit,
    required this.level,
    this.parentMeterId,
    this.destinationTankId,
    this.poursIntoTank = false,
    this.destinationTankNameEn,
    this.location,
    this.locationEn,
    this.locationAr,
    required this.unitToBaseFactor,
    required this.baseUnit,
    required this.meterMultiplier,
    required this.meterKind,
    required this.calculationType,
    required this.isActive,
    required this.includeInDashboard,
    required this.sortOrder,
    this.categoryConfig,
    this.sourceConfig,
    this.unitConfig,
    this.siteNameEn,
    this.parentMeterNameEn,
    this.parentMeterCode,
  });

  final String id;
  final String siteId;
  final String meterCode;
  final String nameEn;
  final String nameAr;
  final String categoryId;
  final String sourceId;
  final String unitId;
  final MeterCategory category;
  final MeterSource source;
  final MeterUnit unit;
  final MeterLevel level;
  final String? parentMeterId;
  final String? destinationTankId;
  final bool poursIntoTank;
  final String? destinationTankNameEn;

  /// Legacy single place field (prefer [locationEn] / [locationAr]).
  final String? location;

  /// Physical place within the site — English.
  final String? locationEn;

  /// Physical place within the site — Arabic.
  final String? locationAr;
  final double unitToBaseFactor;
  final String baseUnit;
  final double meterMultiplier;
  final MeterKind meterKind;
  final CalculationType calculationType;
  final bool isActive;
  final bool includeInDashboard;
  final int sortOrder;
  final MeterCategoryConfig? categoryConfig;
  final MeterSourceConfig? sourceConfig;
  final MeterUnitConfig? unitConfig;
  final String? siteNameEn;
  final String? parentMeterNameEn;
  final String? parentMeterCode;

  String get unitDisplayLabel => unitConfig?.displayName ?? unit.label;

  String get categoryCode => categoryConfig?.code ?? category.dbValue;

  String get sourceDisplayName => sourceConfig?.nameEn ?? source.dbValue;

  String get parentDisplayLabel {
    if (parentMeterNameEn == null) {
      return parentMeterCode ?? '';
    }
    if (parentMeterCode == null || parentMeterCode!.isEmpty) {
      return parentMeterNameEn!;
    }
    return '$parentMeterNameEn ($parentMeterCode)';
  }

  String get tankDisplayLabel => destinationTankNameEn ?? '';

  /// Place of the meter inside the site (not city/address), locale-aware.
  String? placeLabel({required bool isAr}) {
    final en = (locationEn ?? location)?.trim();
    final ar = locationAr?.trim();
    if (isAr) {
      if (ar != null && ar.isNotEmpty) return ar;
      if (en != null && en.isNotEmpty) return en;
      return null;
    }
    if (en != null && en.isNotEmpty) return en;
    if (ar != null && ar.isNotEmpty) return ar;
    return null;
  }

  factory Meter.fromJson(Map<String, dynamic> json) {
    final categoryConfigJson = json['meter_categories'];
    final sourceConfigJson = json['meter_sources'];
    final unitConfigJson = json['meter_units'];
    final siteJson = json['sites'];
    final parentJson = json['parent_meter'];
    final tankJson = json['destination_tank'];

    final categoryConfig = categoryConfigJson == null
        ? null
        : MeterCategoryConfig.fromJson(
            Map<String, dynamic>.from(categoryConfigJson as Map),
          );
    final sourceConfig = sourceConfigJson == null
        ? null
        : MeterSourceConfig.fromJson(
            Map<String, dynamic>.from(sourceConfigJson as Map),
          );
    final unitConfig = unitConfigJson == null
        ? null
        : MeterUnitConfig.fromJson(
            Map<String, dynamic>.from(unitConfigJson as Map),
          );

    final categoryValue =
        categoryConfig?.code ?? json['category'] as String? ?? 'water';
    final unitValue = unitConfig?.code ?? json['unit'] as String? ?? 'm3';
    final sourceValue =
        sourceConfig?.code ?? json['source'] as String? ?? 'other';

    String? siteNameEn;
    if (siteJson is Map) {
      siteNameEn = siteJson['name_en'] as String?;
    }

    String? parentMeterNameEn;
    String? parentMeterCode;
    if (parentJson is Map) {
      parentMeterNameEn = parentJson['name_en'] as String?;
      parentMeterCode = parentJson['meter_code'] as String?;
    }

    String? destinationTankNameEn;
    if (tankJson is Map) {
      destinationTankNameEn = tankJson['name_en'] as String?;
    }

    return Meter(
      id: json['id'] as String,
      siteId: json['site_id'] as String,
      meterCode: json['meter_code'] as String,
      nameEn: json['name_en'] as String,
      nameAr: json['name_ar'] as String,
      categoryId: json['category_id'] as String? ?? categoryConfig?.id ?? '',
      sourceId: json['source_id'] as String? ?? sourceConfig?.id ?? '',
      unitId: json['unit_id'] as String? ?? unitConfig?.id ?? '',
      category: MeterCategory.fromDb(categoryValue),
      source: MeterSource.fromDb(sourceValue),
      unit: MeterUnit.fromDb(unitValue),
      level: MeterLevel.fromDb(json['level'] as String? ?? 'main'),
      parentMeterId: json['parent_meter_id'] as String?,
      destinationTankId: json['destination_tank_id'] as String?,
      poursIntoTank: json['pours_into_tank'] as bool? ?? false,
      destinationTankNameEn: destinationTankNameEn,
      location: _nullableTrim(json['location'] as String?),
      locationEn:
          _nullableTrim(json['location_en'] as String?) ??
          _nullableTrim(json['location'] as String?),
      locationAr: _nullableTrim(json['location_ar'] as String?),
      unitToBaseFactor:
          (json['unit_to_base_factor'] as num?)?.toDouble() ??
          unitConfig?.unitToBaseFactor ??
          1,
      baseUnit:
          json['base_unit'] as String? ?? categoryConfig?.baseUnitCode ?? '',
      meterMultiplier: (json['meter_multiplier'] as num?)?.toDouble() ?? 1,
      meterKind: MeterKind.fromDb(json['meter_kind'] as String? ?? 'physical'),
      calculationType: CalculationType.fromDb(
        json['calculation_type'] as String? ?? 'direct_reading',
      ),
      isActive: json['is_active'] as bool,
      includeInDashboard: json['include_in_dashboard'] as bool? ?? true,
      sortOrder: json['sort_order'] as int? ?? 0,
      categoryConfig: categoryConfig,
      sourceConfig: sourceConfig,
      unitConfig: unitConfig,
      siteNameEn: siteNameEn,
      parentMeterNameEn: parentMeterNameEn,
      parentMeterCode: parentMeterCode,
    );
  }

  bool get isEntryEligible =>
      isActive &&
      meterKind == MeterKind.physical &&
      calculationType == CalculationType.directReading;
}

String? _nullableTrim(String? value) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) return null;
  return trimmed;
}
