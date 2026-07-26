import 'enums.dart';
import 'organization.dart';
import 'organization_site_type.dart';
import 'zone.dart';

class Site {
  const Site({
    required this.id,
    required this.organizationId,
    required this.nameEn,
    required this.nameAr,
    required this.siteType,
    this.siteTypeId,
    this.orgSiteType,
    this.organization,
    this.location,
    this.zoneId,
    this.zone,
    required this.isActive,
    this.meterCount,
  });

  final String id;
  final String organizationId;
  final String nameEn;
  final String nameAr;

  /// Legacy enum (kept for dashboard filters / older rows).
  final SiteType siteType;

  /// Preferred custom type from the parent organization.
  final String? siteTypeId;
  final OrganizationSiteType? orgSiteType;
  final Organization? organization;
  final String? location;
  final String? zoneId;
  final Zone? zone;
  final bool isActive;
  final int? meterCount;

  String get displayZoneName => zone?.nameEn ?? kNoZoneLabel;

  String get displayOrganizationName => organization?.nameEn ?? organizationId;

  String typeLabel({required bool isAr}) {
    if (orgSiteType != null) return orgSiteType!.label(isAr: isAr);
    return isAr ? siteType.labelAr : siteType.label;
  }

  factory Site.fromJson(Map<String, dynamic> json) {
    final zoneJson = json['zones'];
    Zone? zone;
    if (zoneJson is Map<String, dynamic>) {
      zone = Zone.fromJson(zoneJson);
    } else if (zoneJson is Map) {
      zone = Zone.fromJson(Map<String, dynamic>.from(zoneJson));
    }

    OrganizationSiteType? orgType;
    final typeJson = json['organization_site_types'];
    if (typeJson is Map) {
      final map = Map<String, dynamic>.from(typeJson);
      map.putIfAbsent('organization_id', () => json['organization_id']);
      orgType = OrganizationSiteType.fromJson(map);
    }

    Organization? organization;
    final orgJson = json['organizations'];
    if (orgJson is Map<String, dynamic>) {
      organization = Organization.fromJson(orgJson);
    } else if (orgJson is Map) {
      organization = Organization.fromJson(Map<String, dynamic>.from(orgJson));
    }

    return Site(
      id: json['id'] as String,
      organizationId: json['organization_id'] as String,
      nameEn: json['name_en'] as String,
      nameAr: json['name_ar'] as String,
      siteType: SiteType.fromDb(json['site_type'] as String),
      siteTypeId: json['site_type_id'] as String? ?? orgType?.id,
      orgSiteType: orgType,
      organization: organization,
      location: json['location'] as String?,
      zoneId: json['zone_id'] as String? ?? zone?.id,
      zone: zone,
      isActive: json['is_active'] as bool,
      meterCount: _parseMeterCount(json['meters']),
    );
  }

  static int? _parseMeterCount(dynamic meters) {
    if (meters is List && meters.isNotEmpty) {
      final count = meters.first;
      if (count is Map && count['count'] != null) {
        return (count['count'] as num).toInt();
      }
    }
    return null;
  }

  Map<String, dynamic> toInsertJson() {
    return {
      'organization_id': organizationId,
      'name_en': nameEn,
      'name_ar': nameAr,
      'site_type': siteType.dbValue,
      'site_type_id': siteTypeId,
      'location': location,
      'zone_id': zoneId,
      'is_active': isActive,
    };
  }

  Map<String, dynamic> toUpdateJson() {
    return {
      'name_en': nameEn,
      'name_ar': nameAr,
      'site_type': siteType.dbValue,
      'site_type_id': siteTypeId,
      'location': location,
      'zone_id': zoneId,
      'is_active': isActive,
    };
  }
}
