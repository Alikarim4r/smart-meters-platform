import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_meters_core/smart_meters_core.dart';

final canManagePolicySettingsProvider = Provider<bool>((ref) {
  final profile = ref.watch(authProvider).profile;
  if (profile == null) return false;
  return profile.isPlatformOwner || profile.isSuperAdmin;
});

/// Owner-only org logo (report top-right).
final canEditReportLogoPrimaryProvider = Provider<bool>((ref) {
  return ref.watch(authProvider).profile?.isPlatformOwner ?? false;
});

/// Admins may set the site/zone logo (report top-left).
final canEditReportLogoSecondaryProvider = Provider<bool>((ref) {
  final profile = ref.watch(authProvider).profile;
  if (profile == null) return false;
  return profile.isPlatformOwner ||
      profile.isSuperAdmin ||
      profile.isSiteAdmin;
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
