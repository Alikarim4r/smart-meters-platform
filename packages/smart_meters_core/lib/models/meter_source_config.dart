class MeterSourceConfig {
  const MeterSourceConfig({
    required this.id,
    required this.categoryId,
    required this.code,
    required this.nameEn,
    this.nameAr,
    required this.isActive,
    required this.sortOrder,
  });

  final String id;
  final String categoryId;
  final String code;
  final String nameEn;
  final String? nameAr;
  final bool isActive;
  final int sortOrder;

  String get displayName => nameEn;

  factory MeterSourceConfig.fromJson(Map<String, dynamic> json) {
    return MeterSourceConfig(
      id: json['id'] as String,
      categoryId: json['category_id'] as String,
      code: json['code'] as String,
      nameEn: json['name_en'] as String,
      nameAr: json['name_ar'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      sortOrder: json['sort_order'] as int? ?? 0,
    );
  }
}
