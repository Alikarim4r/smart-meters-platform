class MeterTypeConfig {
  const MeterTypeConfig({
    required this.id,
    required this.code,
    required this.nameEn,
    required this.nameAr,
    this.isActive = true,
    this.sortOrder = 0,
    this.legacyCategoryId,
  });

  final String id;
  final String code;
  final String nameEn;
  final String nameAr;
  final bool isActive;
  final int sortOrder;
  final String? legacyCategoryId;

  String label({required bool isAr}) =>
      isAr && nameAr.trim().isNotEmpty ? nameAr : nameEn;

  factory MeterTypeConfig.fromJson(Map<String, dynamic> json) {
    return MeterTypeConfig(
      id: json['id'] as String,
      code: json['code'] as String,
      nameEn: json['name_en'] as String,
      nameAr: (json['name_ar'] as String?) ?? '',
      isActive: json['is_active'] as bool? ?? true,
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
      legacyCategoryId: json['legacy_category_id'] as String?,
    );
  }
}

class MeasurementTypeConfig {
  const MeasurementTypeConfig({
    required this.id,
    required this.code,
    required this.nameEn,
    required this.nameAr,
    required this.dimension,
    this.isActive = true,
    this.sortOrder = 0,
  });

  final String id;
  final String code;
  final String nameEn;
  final String nameAr;
  final String dimension;
  final bool isActive;
  final int sortOrder;

  String label({required bool isAr}) =>
      isAr && nameAr.trim().isNotEmpty ? nameAr : nameEn;

  factory MeasurementTypeConfig.fromJson(Map<String, dynamic> json) {
    return MeasurementTypeConfig(
      id: json['id'] as String,
      code: json['code'] as String,
      nameEn: json['name_en'] as String,
      nameAr: (json['name_ar'] as String?) ?? '',
      dimension: json['dimension'] as String,
      isActive: json['is_active'] as bool? ?? true,
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
    );
  }
}

class GlobalUnitConfig {
  const GlobalUnitConfig({
    required this.id,
    required this.code,
    required this.nameEn,
    required this.nameAr,
    required this.dimension,
    this.unitToBaseFactor = 1,
    this.isActive = true,
  });

  final String id;
  final String code;
  final String nameEn;
  final String nameAr;
  final String dimension;
  final double unitToBaseFactor;
  final bool isActive;

  String label({required bool isAr}) =>
      isAr && nameAr.trim().isNotEmpty ? nameAr : nameEn;

  factory GlobalUnitConfig.fromJson(Map<String, dynamic> json) {
    return GlobalUnitConfig(
      id: json['id'] as String,
      code: json['code'] as String,
      nameEn: json['name_en'] as String,
      nameAr: (json['name_ar'] as String?) ?? '',
      dimension: json['dimension'] as String,
      unitToBaseFactor: (json['unit_to_base_factor'] as num?)?.toDouble() ?? 1,
      isActive: json['is_active'] as bool? ?? true,
    );
  }
}
