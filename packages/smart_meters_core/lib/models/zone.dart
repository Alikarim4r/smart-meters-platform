import 'organization_site_type.dart';

const kNoZoneLabel = 'No Zone';

class Zone {
  const Zone({
    required this.id,
    required this.organizationId,
    required this.code,
    required this.nameEn,
    this.nameAr,
    this.description,
    required this.isActive,
    required this.sortOrder,
    this.parentZoneId,
    this.defaultSiteTypeId,
    this.defaultSiteType,
    @Deprecated('Use defaultSiteTypeId — zone is not a site kind')
    this.siteTypeId,
    @Deprecated('Use defaultSiteType') this.siteType,
    this.siteCount,
  });

  final String id;
  final String organizationId;
  final String code;
  final String nameEn;
  final String? nameAr;
  final String? description;
  final bool isActive;
  final int sortOrder;

  /// Optional parent for nested zones.
  final String? parentZoneId;

  /// Suggested default site type when creating sites in this zone.
  final String? defaultSiteTypeId;
  final OrganizationSiteType? defaultSiteType;

  /// Legacy column — prefer [defaultSiteTypeId].
  @Deprecated('Use defaultSiteTypeId')
  final String? siteTypeId;

  @Deprecated('Use defaultSiteType')
  final OrganizationSiteType? siteType;

  final int? siteCount;

  factory Zone.fromJson(Map<String, dynamic> json) {
    OrganizationSiteType? type;
    final typeJson = json['organization_site_types'];
    if (typeJson is Map) {
      final map = Map<String, dynamic>.from(typeJson);
      map.putIfAbsent('organization_id', () => json['organization_id']);
      type = OrganizationSiteType.fromJson(map);
    }

    // Prefer default_site_type join when present (alias via FK name).
    OrganizationSiteType? defaultType;
    final defaultJson =
        json['default_site_type'] ??
        json['organization_site_types!zones_default_site_type_id_fkey'];
    if (defaultJson is Map) {
      final map = Map<String, dynamic>.from(defaultJson);
      map.putIfAbsent('organization_id', () => json['organization_id']);
      defaultType = OrganizationSiteType.fromJson(map);
    } else {
      defaultType = type;
    }

    final defaultId =
        json['default_site_type_id'] as String? ??
        defaultType?.id ??
        json['site_type_id'] as String?;

    return Zone(
      id: json['id'] as String,
      organizationId: json['organization_id'] as String,
      code: json['code'] as String,
      nameEn: json['name_en'] as String,
      nameAr: json['name_ar'] as String?,
      description: json['description'] as String?,
      isActive: json['is_active'] as bool,
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
      parentZoneId: json['parent_zone_id'] as String?,
      defaultSiteTypeId: defaultId,
      defaultSiteType: defaultType,
      siteTypeId: json['site_type_id'] as String? ?? defaultId,
      siteType: type ?? defaultType,
      siteCount: _parseSiteCount(json['sites']),
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
