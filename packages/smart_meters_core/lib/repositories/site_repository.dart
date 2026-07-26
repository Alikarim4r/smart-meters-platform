import 'dart:async';

import '../models/enums.dart';
import '../models/organization.dart';
import '../models/profile.dart';
import '../models/site.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SiteRepository {
  SiteRepository(this._client);

  final SupabaseClient _client;
  static const _queryTimeout = Duration(seconds: 15);

  // zones has two FKs to organization_site_types — pin default_site_type_id.
  static const _zoneEmbed =
      'zones(*, organization_site_types!zones_default_site_type_id_fkey(*))';
  static const _siteSelect = '*, $_zoneEmbed, organization_site_types(*)';
  /// Fast first-paint select (skips meters(count) embed).
  static const _adminSelectLight =
      '*, $_zoneEmbed, organization_site_types(*)';
  static const _adminSelect =
      '*, meters(count), $_zoneEmbed, organization_site_types(*)';
  static const _orgSelect = '*, sites(count), organization_site_types(*)';

  /// Sites the user can read (dashboard). RLS / scope inheritance is the source of truth.
  Future<List<Site>> getReadableSites(Profile profile) async {
    // Only platform owner bypasses RPC; super_admin must use assigned scopes.
    if (profile.isPlatformOwner) {
      final rows = await _client
          .from('sites')
          .select(_siteSelect)
          .eq('is_active', true)
          .order('name_en')
          .timeout(_queryTimeout);
      return _mapSites(rows);
    }

    final ids =
        await _client.rpc('list_readable_site_ids').timeout(_queryTimeout);
    final idList = _uuidListFromRpc(ids);
    if (idList.isEmpty) return [];

    final rows = await _client
        .from('sites')
        .select(_siteSelect)
        .inFilter('id', idList)
        .order('name_en')
        .timeout(_queryTimeout);
    return _mapSites(rows);
  }

  /// Sites the user can enter readings for (write access).
  Future<List<Site>> getAccessibleSites(Profile profile) async {
    if (profile.isPlatformOwner) {
      final rows = await _client
          .from('sites')
          .select(_siteSelect)
          .eq('is_active', true)
          .order('name_en')
          .timeout(_queryTimeout);
      return _mapSites(rows);
    }

    final ids =
        await _client.rpc('list_writable_site_ids').timeout(_queryTimeout);
    final idList = _uuidListFromRpc(ids);
    if (idList.isEmpty) return [];

    final rows = await _client
        .from('sites')
        .select(_siteSelect)
        .inFilter('id', idList)
        .order('name_en')
        .timeout(_queryTimeout);
    return _mapSites(rows);
  }

  static List<String> _uuidListFromRpc(dynamic ids) {
    if (ids is! List) return const [];
    final out = <String>[];
    for (final e in ids) {
      if (e is String) {
        out.add(e);
      } else if (e is Map && e.values.isNotEmpty) {
        final v = e.values.first;
        if (v is String) out.add(v);
      }
    }
    return out;
  }

  /// All sites visible to the current admin user (includes inactive). RLS enforced.
  Future<List<Site>> getSitesForAdmin({bool includeMeterCounts = true}) async {
    final rows = await _client
        .from('sites')
        .select(includeMeterCounts ? _adminSelect : _adminSelectLight)
        .order('name_en')
        .timeout(_queryTimeout);
    return _mapSites(rows, includeInactive: true);
  }

  Future<Site> getSiteById(String siteId) async {
    final row = await _client
        .from('sites')
        .select(_adminSelect)
        .eq('id', siteId)
        .single()
        .timeout(_queryTimeout);
    return Site.fromJson(Map<String, dynamic>.from(row));
  }

  Future<List<Organization>> getOrganizationsForAdmin() async {
    final rows = await _client
        .from('organizations')
        .select('*, organization_site_types(*)')
        .eq('is_active', true)
        .order('name_en')
        .timeout(_queryTimeout);

    return (rows as List)
        .map(
          (row) => Organization.fromJson(Map<String, dynamic>.from(row as Map)),
        )
        .toList();
  }

  /// All organizations (including inactive) with site counts. RLS enforced.
  Future<List<Organization>> getAllOrganizationsForAdmin() async {
    final rows = await _client
        .from('organizations')
        .select(_orgSelect)
        .order('name_en')
        .timeout(_queryTimeout);

    return (rows as List)
        .map(
          (row) => Organization.fromJson(Map<String, dynamic>.from(row as Map)),
        )
        .toList();
  }

  Future<Organization> createOrganization({
    required String nameEn,
    required String nameAr,
    bool isActive = true,
    String? templateId,
  }) async {
    if (templateId != null) {
      final orgId = await _client.rpc(
        'admin_create_organization_from_template',
        params: {
          'p_name_en': nameEn,
          'p_name_ar': nameAr,
          'p_template_id': templateId,
          'p_is_active': isActive,
        },
      );
      final row = await _client
          .from('organizations')
          .select(_orgSelect)
          .eq('id', orgId as String)
          .single();
      return Organization.fromJson(Map<String, dynamic>.from(row));
    }

    final row = await _client
        .from('organizations')
        .insert({'name_en': nameEn, 'name_ar': nameAr, 'is_active': isActive})
        .select(_orgSelect)
        .single();
    return Organization.fromJson(Map<String, dynamic>.from(row));
  }

  Future<Organization> updateOrganization(
    String organizationId, {
    String? nameEn,
    String? nameAr,
    bool? isActive,
  }) async {
    final payload = <String, dynamic>{};
    if (nameEn != null) payload['name_en'] = nameEn;
    if (nameAr != null) payload['name_ar'] = nameAr;
    if (isActive != null) payload['is_active'] = isActive;

    final row = await _client
        .from('organizations')
        .update(payload)
        .eq('id', organizationId)
        .select(_orgSelect)
        .single();
    return Organization.fromJson(Map<String, dynamic>.from(row));
  }

  /// Hard delete. Fails while sites still reference the organization.
  Future<void> deleteOrganization(String organizationId) async {
    await _client.from('organizations').delete().eq('id', organizationId);
  }

  /// Super-admin cascade delete via RPC (sites, zones, then organization).
  Future<void> forceDeleteOrganization(String organizationId) async {
    await _client.rpc(
      'admin_force_delete_organization',
      params: {'p_organization_id': organizationId},
    );
  }

  Future<Site> createSite({
    required String organizationId,
    required String nameEn,
    required String nameAr,
    required String siteTypeId,
    SiteType siteType = SiteType.other,
    String? location,
    String? zoneId,
    bool isActive = true,
  }) async {
    final row = await _client
        .from('sites')
        .insert({
          'organization_id': organizationId,
          'name_en': nameEn,
          'name_ar': nameAr,
          'site_type': siteType.dbValue,
          'site_type_id': siteTypeId,
          'location': location,
          'zone_id': zoneId,
          'is_active': isActive,
        })
        .select(_adminSelect)
        .single();

    return Site.fromJson(Map<String, dynamic>.from(row));
  }

  Future<Site> updateSite(
    String siteId, {
    String? nameEn,
    String? nameAr,
    String? siteTypeId,
    SiteType? siteType,
    String? location,
    String? zoneId,
    bool clearZone = false,
    bool? isActive,
  }) async {
    final payload = <String, dynamic>{};
    if (nameEn != null) payload['name_en'] = nameEn;
    if (nameAr != null) payload['name_ar'] = nameAr;
    if (siteTypeId != null) payload['site_type_id'] = siteTypeId;
    if (siteType != null) payload['site_type'] = siteType.dbValue;
    if (location != null) payload['location'] = location;
    if (clearZone) {
      payload['zone_id'] = null;
    } else if (zoneId != null) {
      payload['zone_id'] = zoneId;
    }
    if (isActive != null) payload['is_active'] = isActive;

    final row = await _client
        .from('sites')
        .update(payload)
        .eq('id', siteId)
        .select(_adminSelect)
        .single();

    return Site.fromJson(Map<String, dynamic>.from(row));
  }

  Future<Site> deactivateSite(String siteId) {
    return updateSite(siteId, isActive: false);
  }

  /// Hard delete. Fails while meters or other FK-protected rows still reference the site.
  Future<void> deleteSite(String siteId) async {
    await _client.from('sites').delete().eq('id', siteId);
  }

  /// Super-admin cascade delete via RPC.
  Future<void> forceDeleteSite(String siteId) async {
    await _client.rpc('admin_force_delete_site', params: {'p_site_id': siteId});
  }

  List<Site> _mapSites(dynamic rows, {bool includeInactive = false}) {
    return (rows as List)
        .map((row) => Site.fromJson(Map<String, dynamic>.from(row as Map)))
        .where((site) => includeInactive || site.isActive)
        .toList();
  }
}
