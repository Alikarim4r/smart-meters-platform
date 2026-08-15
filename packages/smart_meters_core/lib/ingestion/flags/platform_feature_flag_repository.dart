import 'package:supabase_flutter/supabase_flutter.dart';

import '../flags/platform_feature_flag_keys.dart';

/// Read/write platform flags. Missing row → OFF.
class PlatformFeatureFlagRepository {
  PlatformFeatureFlagRepository(this._client);

  final SupabaseClient _client;
  static const _table = 'platform_feature_flags';

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

  Future<Map<String, bool>> loadAll({
    required String organizationId,
    String? siteId,
  }) async {
    final out = <String, bool>{
      for (final k in PlatformFeatureFlags.all) k: false,
    };
    for (final key in PlatformFeatureFlags.all) {
      out[key] = await isEnabled(
        organizationId: organizationId,
        flagKey: key,
        siteId: siteId,
      );
    }
    return out;
  }
}
