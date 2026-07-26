import 'organization_site_type.dart';

class Organization {
  const Organization({
    required this.id,
    required this.nameEn,
    required this.nameAr,
    required this.isActive,
    this.templateId,
    this.siteCount,
    this.siteTypes = const [],
  });

  final String id;
  final String nameEn;
  final String nameAr;
  final bool isActive;

  /// Template chosen when the organization was created (historical).
  final String? templateId;

  /// Populated when fetched with `sites(count)`.
  final int? siteCount;

  /// Populated when fetched with `organization_site_types(*)`.
  final List<OrganizationSiteType> siteTypes;

  factory Organization.fromJson(Map<String, dynamic> json) {
    final rawTypes = json['organization_site_types'];
    final types = <OrganizationSiteType>[];
    if (rawTypes is List) {
      for (final item in rawTypes) {
        if (item is Map) {
          final map = Map<String, dynamic>.from(item);
          // Embedded rows may omit organization_id; fill from parent.
          map.putIfAbsent('organization_id', () => json['id']);
          types.add(OrganizationSiteType.fromJson(map));
        }
      }
      types.sort((a, b) {
        final byOrder = a.sortOrder.compareTo(b.sortOrder);
        if (byOrder != 0) return byOrder;
        return a.nameEn.compareTo(b.nameEn);
      });
    }

    return Organization(
      id: json['id'] as String,
      nameEn: json['name_en'] as String,
      nameAr: json['name_ar'] as String,
      isActive: json['is_active'] as bool,
      templateId: json['template_id'] as String?,
      siteCount: _parseSiteCount(json['sites']),
      siteTypes: types,
    );
  }

  static int? _parseSiteCount(dynamic sites) {
    if (sites is List && sites.isNotEmpty) {
      final count = sites.first;
      if (count is Map && count['count'] != null) {
        return (count['count'] as num).toInt();
      }
    }
    return null;
  }
}
