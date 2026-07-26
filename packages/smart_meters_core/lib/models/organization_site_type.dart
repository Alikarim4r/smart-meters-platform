class OrganizationSiteType {
  const OrganizationSiteType({
    required this.id,
    required this.organizationId,
    required this.nameEn,
    required this.nameAr,
    required this.isActive,
    this.sortOrder = 0,
  });

  final String id;
  final String organizationId;
  final String nameEn;
  final String nameAr;
  final bool isActive;
  final int sortOrder;

  String label({required bool isAr}) =>
      isAr && nameAr.trim().isNotEmpty ? nameAr : nameEn;

  factory OrganizationSiteType.fromJson(Map<String, dynamic> json) {
    return OrganizationSiteType(
      id: json['id'] as String,
      organizationId: json['organization_id'] as String,
      nameEn: json['name_en'] as String,
      nameAr: (json['name_ar'] as String?) ?? '',
      isActive: json['is_active'] as bool? ?? true,
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toInsertJson({required String organizationId}) {
    return {
      'organization_id': organizationId,
      'name_en': nameEn,
      'name_ar': nameAr,
      'is_active': isActive,
      'sort_order': sortOrder,
    };
  }
}
