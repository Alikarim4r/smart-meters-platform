class SiteTank {
  const SiteTank({
    required this.id,
    required this.siteId,
    required this.nameEn,
    this.nameAr,
    required this.isActive,
  });

  final String id;
  final String siteId;
  final String nameEn;
  final String? nameAr;
  final bool isActive;

  String get displayName {
    final ar = nameAr?.trim();
    if (ar != null && ar.isNotEmpty && ar != nameEn) {
      return '$nameEn / $ar';
    }
    return nameEn;
  }

  String label({required bool isAr}) {
    final ar = nameAr?.trim();
    if (isAr && ar != null && ar.isNotEmpty) return ar;
    return nameEn;
  }

  factory SiteTank.fromJson(Map<String, dynamic> json) {
    return SiteTank(
      id: json['id'] as String,
      siteId: json['site_id'] as String,
      nameEn: json['name_en'] as String,
      nameAr: json['name_ar'] as String?,
      isActive: json['is_active'] as bool? ?? true,
    );
  }
}
