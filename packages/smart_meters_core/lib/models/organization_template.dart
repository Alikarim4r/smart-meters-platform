class OrganizationTemplate {
  const OrganizationTemplate({
    required this.id,
    required this.code,
    required this.nameEn,
    required this.nameAr,
    this.description,
    this.sortOrder = 0,
    this.isActive = true,
    this.siteTypes = const [],
  });

  final String id;
  final String code;
  final String nameEn;
  final String nameAr;
  final String? description;
  final int sortOrder;
  final bool isActive;
  final List<TemplateSiteType> siteTypes;

  String label({required bool isAr}) =>
      isAr && nameAr.trim().isNotEmpty ? nameAr : nameEn;

  factory OrganizationTemplate.fromJson(Map<String, dynamic> json) {
    final raw = json['template_site_types'];
    final types = <TemplateSiteType>[];
    if (raw is List) {
      for (final item in raw) {
        if (item is Map) {
          types.add(TemplateSiteType.fromJson(Map<String, dynamic>.from(item)));
        }
      }
      types.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    }
    return OrganizationTemplate(
      id: json['id'] as String,
      code: json['code'] as String,
      nameEn: json['name_en'] as String,
      nameAr: json['name_ar'] as String,
      description: json['description'] as String?,
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
      isActive: json['is_active'] as bool? ?? true,
      siteTypes: types,
    );
  }
}

class TemplateSiteType {
  const TemplateSiteType({
    required this.id,
    required this.templateId,
    required this.nameEn,
    required this.nameAr,
    this.sortOrder = 0,
  });

  final String id;
  final String templateId;
  final String nameEn;
  final String nameAr;
  final int sortOrder;

  factory TemplateSiteType.fromJson(Map<String, dynamic> json) {
    return TemplateSiteType(
      id: json['id'] as String,
      templateId: (json['template_id'] as String?) ?? '',
      nameEn: json['name_en'] as String,
      nameAr: (json['name_ar'] as String?) ?? '',
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
    );
  }
}
