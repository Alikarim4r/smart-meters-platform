import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_meters_core/smart_meters_core.dart';

final canManageZonesProvider = Provider<bool>((ref) {
  return ref.watch(authProvider).profile?.isSuperAdmin ?? false;
});

final adminZonesProvider = FutureProvider.autoDispose<List<Zone>>((ref) async {
  return ref.read(zoneRepositoryProvider).getZonesForAdmin();
});

final organizationZonesProvider = FutureProvider.autoDispose
    .family<List<Zone>, String>((ref, orgId) async {
      return ref
          .read(zoneRepositoryProvider)
          .getActiveZonesForOrganization(orgId);
    });

final organizationSiteTypesProvider = FutureProvider.autoDispose
    .family<List<OrganizationSiteType>, String>((ref, orgId) async {
      return ref
          .read(zoneRepositoryProvider)
          .getSiteTypesForOrganization(orgId);
    });

final selectedSiteZoneFilterProvider = StateProvider<String?>((ref) => null);
