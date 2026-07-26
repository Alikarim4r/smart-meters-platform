import 'dart:async';

import '../models/organization_site_type.dart';
import '../models/organization_template.dart';
import '../models/zone.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ZoneRepository {
  ZoneRepository(this._client);

  final SupabaseClient _client;
  static const _queryTimeout = Duration(seconds: 15);

  /// Prefer default_site_type FK embed; fall back works if only one FK remains.
  static const _adminSelect =
      '*, sites(count), organization_site_types!zones_default_site_type_id_fkey(*)';

  Future<List<Zone>> getZonesForAdmin({String? organizationId}) async {
    var query = _client.from('zones').select(_adminSelect);
    if (organizationId != null) {
      query = query.eq('organization_id', organizationId);
    }
    final rows =
        await query.order('sort_order').order('name_en').timeout(_queryTimeout);
    return _mapZones(rows);
  }

  Future<List<Zone>> getActiveZonesForOrganization(
    String organizationId,
  ) async {
    final rows = await _client
        .from('zones')
        .select('*, organization_site_types!zones_default_site_type_id_fkey(*)')
        .eq('organization_id', organizationId)
        .eq('is_active', true)
        .order('sort_order')
        .order('name_en');

    return _mapZones(rows);
  }

  Future<Zone> createZone({
    required String organizationId,
    required String code,
    required String nameEn,
    String? nameAr,
    String? description,
    bool isActive = true,
    int sortOrder = 0,
    String? parentZoneId,
    String? defaultSiteTypeId,
  }) async {
    final row = await _client
        .from('zones')
        .insert({
          'organization_id': organizationId,
          'code': code,
          'name_en': nameEn,
          'name_ar': nameAr,
          'description': description,
          'is_active': isActive,
          'sort_order': sortOrder,
          'parent_zone_id': parentZoneId,
          'default_site_type_id': defaultSiteTypeId,
        })
        .select(_adminSelect)
        .single();

    return Zone.fromJson(Map<String, dynamic>.from(row));
  }

  Future<Zone> updateZone(
    String zoneId, {
    String? code,
    String? nameEn,
    String? nameAr,
    String? description,
    bool? isActive,
    int? sortOrder,
    String? parentZoneId,
    bool clearParentZone = false,
    String? defaultSiteTypeId,
    bool clearDefaultSiteType = false,
  }) async {
    final payload = <String, dynamic>{};
    if (code != null) payload['code'] = code;
    if (nameEn != null) payload['name_en'] = nameEn;
    if (nameAr != null) payload['name_ar'] = nameAr;
    if (description != null) payload['description'] = description;
    if (isActive != null) payload['is_active'] = isActive;
    if (sortOrder != null) payload['sort_order'] = sortOrder;
    if (clearParentZone) {
      payload['parent_zone_id'] = null;
    } else if (parentZoneId != null) {
      payload['parent_zone_id'] = parentZoneId;
    }
    if (clearDefaultSiteType) {
      payload['default_site_type_id'] = null;
    } else if (defaultSiteTypeId != null) {
      payload['default_site_type_id'] = defaultSiteTypeId;
    }

    final row = await _client
        .from('zones')
        .update(payload)
        .eq('id', zoneId)
        .select(_adminSelect)
        .single();

    return Zone.fromJson(Map<String, dynamic>.from(row));
  }

  Future<Zone> deactivateZone(String zoneId) {
    return updateZone(zoneId, isActive: false);
  }

  Future<void> deleteZone(String zoneId) async {
    await _client.from('zones').delete().eq('id', zoneId);
  }

  /// Super-admin cascade delete via RPC (nested zones first).
  Future<void> forceDeleteZone(String zoneId) async {
    await _client.rpc('admin_force_delete_zone', params: {'p_zone_id': zoneId});
  }

  Future<List<OrganizationSiteType>> getSiteTypesForOrganization(
    String organizationId,
  ) async {
    final rows = await _client
        .from('organization_site_types')
        .select()
        .eq('organization_id', organizationId)
        .order('sort_order')
        .order('name_en');

    return (rows as List)
        .map(
          (row) => OrganizationSiteType.fromJson(
            Map<String, dynamic>.from(row as Map),
          ),
        )
        .toList();
  }

  Future<OrganizationSiteType> createSiteType({
    required String organizationId,
    required String nameEn,
    required String nameAr,
    bool isActive = true,
    int sortOrder = 0,
  }) async {
    final row = await _client
        .from('organization_site_types')
        .insert({
          'organization_id': organizationId,
          'name_en': nameEn,
          'name_ar': nameAr,
          'is_active': isActive,
          'sort_order': sortOrder,
        })
        .select()
        .single();
    return OrganizationSiteType.fromJson(Map<String, dynamic>.from(row));
  }

  Future<void> deleteSiteType(String siteTypeId) async {
    await _client.from('organization_site_types').delete().eq('id', siteTypeId);
  }

  Future<List<OrganizationTemplate>> getOrganizationTemplates() async {
    final rows = await _client
        .from('organization_templates')
        .select('*, template_site_types(*)')
        .eq('is_active', true)
        .order('sort_order')
        .order('name_en');

    return (rows as List)
        .map(
          (row) => OrganizationTemplate.fromJson(
            Map<String, dynamic>.from(row as Map),
          ),
        )
        .toList();
  }

  List<Zone> _mapZones(dynamic rows) {
    return (rows as List)
        .map((row) => Zone.fromJson(Map<String, dynamic>.from(row as Map)))
        .toList();
  }
}
