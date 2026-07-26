class MeterUnitConfig {
  const MeterUnitConfig({
    required this.id,
    required this.categoryId,
    required this.code,
    required this.nameEn,
    this.nameAr,
    required this.unitToBaseFactor,
    required this.isBase,
    required this.isActive,
    required this.sortOrder,
  });

  final String id;
  final String categoryId;
  final String code;
  final String nameEn;
  final String? nameAr;
  final double unitToBaseFactor;
  final bool isBase;
  final bool isActive;
  final int sortOrder;

  String get displayName => nameEn;

  factory MeterUnitConfig.fromJson(Map<String, dynamic> json) {
    return MeterUnitConfig(
      id: json['id'] as String,
      categoryId: json['category_id'] as String,
      code: json['code'] as String,
      nameEn: json['name_en'] as String,
      nameAr: json['name_ar'] as String?,
      unitToBaseFactor: (json['unit_to_base_factor'] as num).toDouble(),
      isBase: json['is_base'] as bool? ?? false,
      isActive: json['is_active'] as bool? ?? true,
      sortOrder: json['sort_order'] as int? ?? 0,
    );
  }
}
