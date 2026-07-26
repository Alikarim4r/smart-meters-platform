class MeterCategoryConfig {
  const MeterCategoryConfig({
    required this.id,
    required this.code,
    required this.nameEn,
    this.nameAr,
    required this.baseUnitCode,
    this.icon,
    this.color,
    required this.isSystem,
    required this.isActive,
    required this.sortOrder,
    required this.supportsCopOutput,
    required this.supportsElectricInput,
    required this.isConsumptionCategory,
  });

  final String id;
  final String code;
  final String nameEn;
  final String? nameAr;
  final String baseUnitCode;
  final String? icon;
  final String? color;
  final bool isSystem;
  final bool isActive;
  final int sortOrder;
  final bool supportsCopOutput;
  final bool supportsElectricInput;
  final bool isConsumptionCategory;

  String get displayName => nameEn;

  factory MeterCategoryConfig.fromJson(Map<String, dynamic> json) {
    return MeterCategoryConfig(
      id: json['id']?.toString() ?? '',
      code: json['code']?.toString() ?? '',
      nameEn: json['name_en']?.toString() ?? '',
      nameAr: json['name_ar']?.toString(),
      baseUnitCode: json['base_unit_code']?.toString() ?? '',
      icon: json['icon']?.toString(),
      color: json['color']?.toString(),
      isSystem: json['is_system'] as bool? ?? false,
      isActive: json['is_active'] as bool? ?? true,
      // PostgREST/JSON may decode integers as num — hard `as int` throws TypeError.
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
      supportsCopOutput: json['supports_cop_output'] as bool? ?? false,
      supportsElectricInput: json['supports_electric_input'] as bool? ?? false,
      isConsumptionCategory: json['is_consumption_category'] as bool? ?? true,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is MeterCategoryConfig && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
