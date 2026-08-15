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
      id: json['id']?.toString() ?? '',
      categoryId: json['category_id']?.toString() ?? '',
      code: json['code']?.toString() ?? '',
      nameEn: json['name_en']?.toString() ?? '',
      nameAr: json['name_ar']?.toString(),
      unitToBaseFactor: _toDouble(json['unit_to_base_factor']),
      isBase: json['is_base'] as bool? ?? false,
      isActive: json['is_active'] as bool? ?? true,
      // PostgREST may decode ints as num.
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
    );
  }

  static double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 1;
    return 1;
  }
}
