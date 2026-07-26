import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_meters_core/smart_meters_core.dart';

final canManagePolicySettingsProvider = Provider<bool>((ref) {
  return ref.watch(authProvider).profile?.isSuperAdmin ?? false;
});

final selectedPolicyOrganizationIdProvider = StateProvider<String?>(
  (ref) => null,
);

final organizationPolicyProvider = FutureProvider.autoDispose
    .family<PolicySettings, String>((ref, orgId) async {
      return ref
          .read(policySettingsRepositoryProvider)
          .getOrganizationPolicySettings(orgId);
    });

final effectiveSitePolicyProvider = FutureProvider.autoDispose
    .family<PolicySettings, String>((ref, siteId) async {
      return ref
          .read(policySettingsRepositoryProvider)
          .getEffectivePolicyForSite(siteId);
    });
