import 'package:supabase_flutter/supabase_flutter.dart';

import 'feature_flag_keys.dart';

class ConservationFeatureFlagRow {
  const ConservationFeatureFlagRow({
    required this.id,
    required this.organizationId,
    required this.siteId,
    required this.flagKey,
    required this.enabled,
  });

  final String id;
  final String organizationId;
  final String? siteId;
  final String flagKey;
  final bool enabled;

  factory ConservationFeatureFlagRow.fromJson(Map<String, dynamic> json) {
    return ConservationFeatureFlagRow(
      id: json['id'] as String,
      organizationId: json['organization_id'] as String,
      siteId: json['site_id'] as String?,
      flagKey: json['flag_key'] as String,
      enabled: json['enabled'] as bool? ?? false,
    );
  }
}

/// Read/write conservation flags. Defaults to OFF when no row exists.
class ConservationFeatureFlagRepository {
  ConservationFeatureFlagRepository(this._client);

  final SupabaseClient _client;
  static const _table = 'conservation_feature_flags';

  /// Site override wins over org-wide; missing → false.
  Future<bool> isEnabled({
    required String organizationId,
    required String flagKey,
    String? siteId,
  }) async {
    final rows = await _client
        .from(_table)
        .select('site_id, enabled')
        .eq('organization_id', organizationId)
        .eq('flag_key', flagKey);

    final list = (rows as List<dynamic>)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

    if (siteId != null) {
      for (final row in list) {
        if (row['site_id'] == siteId) {
          return row['enabled'] as bool? ?? false;
        }
      }
    }
    for (final row in list) {
      if (row['site_id'] == null) {
        return row['enabled'] as bool? ?? false;
      }
    }
    return false;
  }

  /// Master gate: module flag must be ON for any child flag to matter in UI.
  Future<bool> isModuleEnabled({
    required String organizationId,
    String? siteId,
  }) {
    return isEnabled(
      organizationId: organizationId,
      flagKey: ConservationFeatureFlags.conservationModule,
      siteId: siteId,
    );
  }

  Future<List<ConservationFeatureFlagRow>> listForOrganization(
    String organizationId,
  ) async {
    final rows = await _client
        .from(_table)
        .select()
        .eq('organization_id', organizationId)
        .order('flag_key');
    return (rows as List<dynamic>)
        .map(
          (e) => ConservationFeatureFlagRow.fromJson(
            Map<String, dynamic>.from(e as Map),
          ),
        )
        .toList();
  }

  /// Upsert a flag. Callers must have manage permissions (RLS enforced).
  Future<void> setEnabled({
    required String organizationId,
    required String flagKey,
    required bool enabled,
    String? siteId,
  }) async {
    var query = _client
        .from(_table)
        .select('id')
        .eq('organization_id', organizationId)
        .eq('flag_key', flagKey);
    query = siteId == null ? query.isFilter('site_id', null) : query.eq('site_id', siteId);
    final existing = await query.maybeSingle();

    if (existing != null) {
      await _client
          .from(_table)
          .update({'enabled': enabled})
          .eq('id', existing['id'] as String);
      return;
    }

    await _client.from(_table).insert({
      'organization_id': organizationId,
      'site_id': siteId,
      'flag_key': flagKey,
      'enabled': enabled,
    });
  }
}
