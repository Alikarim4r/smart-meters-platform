import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_meters_core/smart_meters_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'billing_logic.dart';

/// Server entitlement for one organization, as the server reports it.
class OrgBillingState {
  const OrgBillingState({
    required this.subscription,
    required this.usage,
    required this.provider,
    required this.cancelAtPeriodEnd,
  });

  /// null when the caller cannot see the org's entitlement.
  final OrganizationSubscription? subscription;
  final SubscriptionUsage usage;
  final String? provider;
  final bool cancelAtPeriodEnd;
}

class BillingCatalogResult {
  const BillingCatalogResult({required this.entries, required this.forbidden});
  final List<GooglePlayCatalogEntry> entries;

  /// The server refused billing management for this caller and org.
  final bool forbidden;
}

/// Server side of Google Play billing: the scoped catalog RPC, the verify
/// Edge Function, and entitlement reads. Never writes billing state.
class GooglePlayBillingRepository {
  GooglePlayBillingRepository(this._client)
    : _subscriptions = SubscriptionRepository(_client);

  final SupabaseClient _client;
  final SubscriptionRepository _subscriptions;

  Future<BillingCatalogResult> loadCatalog(String organizationId) async {
    try {
      final raw = await _client.rpc(
        'billing_google_play_catalog',
        params: {'p_organization_id': organizationId},
      );
      final entries = <GooglePlayCatalogEntry>[];
      for (final row in raw as List) {
        final entry = GooglePlayCatalogEntry.tryParse(
          Map<String, dynamic>.from(row as Map),
        );
        if (entry != null) entries.add(entry);
      }
      return BillingCatalogResult(entries: entries, forbidden: false);
    } on PostgrestException catch (e) {
      if (e.code == '42501') {
        return const BillingCatalogResult(entries: [], forbidden: true);
      }
      rethrow;
    }
  }

  Future<OrgBillingState> loadState(String organizationId) async {
    final results = await Future.wait<Object?>([
      _subscriptions.getForOrganization(organizationId),
      _subscriptions.getUsage(organizationId),
      _client
          .from('organization_subscriptions')
          .select('provider, cancel_at_period_end')
          .eq('organization_id', organizationId)
          .maybeSingle(),
    ]);
    final row = results[2] as Map<String, dynamic>?;
    return OrgBillingState(
      subscription: results[0] as OrganizationSubscription?,
      usage: results[1] as SubscriptionUsage,
      provider: row?['provider'] as String?,
      cancelAtPeriodEnd: row?['cancel_at_period_end'] == true,
    );
  }

  /// Sends the purchase token for server verification. Non-2xx responses carry
  /// a fail-closed result with the server's reason.
  Future<BillingVerificationResult> verify({
    required String organizationId,
    required String purchaseToken,
    String? productId,
  }) async {
    try {
      final res = await _client.functions.invoke(
        'google-play-verify',
        body: {
          'organization_id': organizationId,
          'purchase_token': purchaseToken,
          'product_id': ?productId,
        },
      );
      return BillingVerificationResult.fromJson(res.data);
    } on FunctionException catch (e) {
      return BillingVerificationResult.fromJson(e.details);
    }
  }
}

final googlePlayBillingRepositoryProvider =
    Provider<GooglePlayBillingRepository>((ref) {
      return GooglePlayBillingRepository(ref.watch(supabaseClientProvider));
    });
