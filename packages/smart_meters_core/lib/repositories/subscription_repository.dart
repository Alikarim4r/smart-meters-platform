import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/subscription.dart';
import '../models/subscription_plan.dart';

class SubscriptionRepository {
  SubscriptionRepository(this._client);
  final SupabaseClient _client;
  Future<List<SubscriptionPlanCatalogItem>> listPlans() async {
    final rows = await _client
        .from('subscription_plan_catalog')
        .select()
        .eq('is_public', true)
        .order('display_order');
    return (rows as List)
        .map(
          (e) => SubscriptionPlanCatalogItem.fromJson(
            Map<String, dynamic>.from(e as Map),
          ),
        )
        .toList();
  }

  Future<OrganizationSubscription?> getForOrganization(
    String organizationId,
  ) async {
    final raw = await _client.rpc(
      'subscription_access_state',
      params: {'p_organization_id': organizationId},
    );
    final rows = raw as List;
    if (rows.isEmpty) return null;
    return OrganizationSubscription.fromRpc(
      organizationId,
      Map<String, dynamic>.from(rows.first as Map),
    );
  }

  Future<SubscriptionUsage> getUsage(String organizationId) async {
    final raw = await _client.rpc(
      'subscription_usage',
      params: {'p_organization_id': organizationId},
    );
    final rows = raw as List;
    if (rows.isEmpty) {
      return const SubscriptionUsage(
        activeUsers: 0,
        activeSites: 0,
        activeMeters: 0,
      );
    }
    final j = Map<String, dynamic>.from(rows.first as Map);
    return SubscriptionUsage(
      activeUsers: (j['active_users'] as num?)?.toInt() ?? 0,
      activeSites: (j['active_sites'] as num?)?.toInt() ?? 0,
      activeMeters: (j['active_meters'] as num?)?.toInt() ?? 0,
    );
  }

  Future<bool> hasFeature(String organizationId, String feature) async =>
      await _client.rpc(
        'subscription_has_feature',
        params: {'p_organization_id': organizationId, 'p_feature': feature},
      ) ==
      true;
}
