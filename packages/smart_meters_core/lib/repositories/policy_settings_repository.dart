import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/policy_settings.dart';

class PolicySettingsRepository {
  PolicySettingsRepository(this._client);

  final SupabaseClient _client;

  Future<PolicySettings> getOrganizationPolicySettings(
    String organizationId,
  ) async {
    try {
      final rows = await _client
          .from('policy_settings')
          .select()
          .eq('organization_id', organizationId)
          .eq('scope', 'organization')
          .eq('is_active', true);
      final match = (rows as List).cast<Map>().where(
        (row) => row['site_id'] == null,
      );
      if (match.isEmpty) {
        return PolicySettings.defaults(organizationId);
      }
      return PolicySettings.fromJson(Map<String, dynamic>.from(match.first));
    } catch (_) {
      return PolicySettings.defaults(organizationId);
    }
  }

  Future<PolicySettings> getEffectivePolicyForSite(String siteId) async {
    try {
      final site = await _client
          .from('sites')
          .select('organization_id')
          .eq('id', siteId)
          .single();
      final organizationId = site['organization_id'] as String;
      return getOrganizationPolicySettings(organizationId);
    } catch (_) {
      return PolicySettings.defaults('');
    }
  }

  Future<PolicySettings> updateOrganizationPolicySettings(
    PolicySettings settings,
  ) async {
    final payload = settings.toUpdateJson()
      ..addAll({
        'organization_id': settings.organizationId,
        'scope': 'organization',
        'site_id': null,
        'is_active': true,
      });

    if (settings.id == null) {
      final inserted = await _client
          .from('policy_settings')
          .insert(payload)
          .select()
          .single();
      return PolicySettings.fromJson(Map<String, dynamic>.from(inserted));
    }

    final updated = await _client
        .from('policy_settings')
        .update(payload)
        .eq('id', settings.id!)
        .select()
        .single();
    return PolicySettings.fromJson(Map<String, dynamic>.from(updated));
  }

  Future<PolicySettings> resetToDefaults(String organizationId) async {
    final existing = await getOrganizationPolicySettings(organizationId);
    final defaults = PolicySettings.defaults(
      organizationId,
    ).copyWith(id: existing.id);
    if (existing.id == null) {
      return updateOrganizationPolicySettings(defaults);
    }
    return updateOrganizationPolicySettings(defaults);
  }
}
