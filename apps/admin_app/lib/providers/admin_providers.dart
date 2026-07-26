import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_meters_core/smart_meters_core.dart';

import '../utils/admin_validation.dart';

final canCreateSitesProvider = Provider<bool>((ref) {
  final profile = ref.watch(authProvider).profile;
  if (profile == null) return false;
  return profile.isPlatformOwner ||
      profile.isSuperAdmin ||
      profile.isSiteAdmin;
});

final canEditSitesProvider = Provider<bool>((ref) {
  final profile = ref.watch(authProvider).profile;
  if (profile == null) {
    return false;
  }
  return profile.isPlatformOwner ||
      profile.isSuperAdmin ||
      profile.isSiteAdmin;
});

final canManageMetersProvider = Provider<bool>((ref) {
  final profile = ref.watch(authProvider).profile;
  if (profile == null) {
    return false;
  }
  return profile.isPlatformOwner ||
      profile.isSuperAdmin ||
      profile.isSiteAdmin;
});

/// Hard-delete for admins who can manage the entity (site_admin with warnings).
final canDeleteEntitiesProvider = Provider<bool>((ref) {
  final profile = ref.watch(authProvider).profile;
  if (profile == null) return false;
  return profile.isPlatformOwner ||
      profile.isSuperAdmin ||
      profile.isSiteAdmin;
});

/// Cascade delete for meters/sites — owner, super_admin and site managers.
final canForceDeleteProvider = Provider<bool>((ref) {
  final profile = ref.watch(authProvider).profile;
  if (profile == null) return false;
  return profile.isPlatformOwner ||
      profile.isSuperAdmin ||
      profile.isSiteAdmin;
});

final adminSitesProvider = FutureProvider.autoDispose<List<Site>>((ref) async {
  return ref.read(siteRepositoryProvider).getSitesForAdmin();
});

final adminOrganizationsProvider =
    FutureProvider.autoDispose<List<Organization>>((ref) async {
      return ref.read(siteRepositoryProvider).getOrganizationsForAdmin();
    });

final adminSiteProvider = FutureProvider.autoDispose.family<Site, String>((
  ref,
  siteId,
) async {
  return ref.read(siteRepositoryProvider).getSiteById(siteId);
});

final selectedAdminSiteIdProvider = StateProvider<String?>((ref) => null);

final adminMetersProvider = FutureProvider.autoDispose<List<Meter>>((
  ref,
) async {
  final siteId = ref.watch(selectedAdminSiteIdProvider);
  if (siteId == null) return const [];

  final categoryId = ref.watch(selectedAdminMeterCategoryIdProvider);
  final levelFilter = ref.watch(adminMeterLevelFilterProvider);
  final activeFilter = ref.watch(adminMeterActiveFilterProvider);

  bool? activeOnly;
  if (activeFilter == AdminActiveFilter.activeOnly) {
    activeOnly = true;
  } else if (activeFilter == AdminActiveFilter.inactiveOnly) {
    activeOnly = false;
  }

  MeterLevel? level;
  if (levelFilter == AdminMeterLevelFilter.mainOnly) {
    level = MeterLevel.main;
  } else if (levelFilter == AdminMeterLevelFilter.subOnly) {
    level = MeterLevel.sub;
  } else if (levelFilter == AdminMeterLevelFilter.subSubOnly) {
    level = MeterLevel.subSub;
  }

  return ref
      .read(meterRepositoryProvider)
      .getMetersForAdmin(
        siteId: siteId,
        categoryId: categoryId,
        activeOnly: activeOnly,
        level: level,
      );
});

final selectedAdminMeterCategoryIdProvider = StateProvider<String?>(
  (ref) => null,
);

final adminMeterActiveFilterProvider = StateProvider<AdminActiveFilter>(
  (ref) => AdminActiveFilter.all,
);

final adminMeterLevelFilterProvider = StateProvider<AdminMeterLevelFilter>(
  (ref) => AdminMeterLevelFilter.all,
);

final meterHasReadingsProvider = FutureProvider.autoDispose
    .family<bool, String>((ref, meterId) async {
      return ref.read(meterRepositoryProvider).meterHasReadings(meterId);
    });

final eligibleParentMetersProvider = FutureProvider.autoDispose
    .family<
      List<Meter>,
      ({
        String siteId,
        String categoryId,
        MeterLevel forLevel,
        String? excludeId,
      })
    >((ref, params) {
      return ref
          .read(meterRepositoryProvider)
          .getEligibleParentMeters(
            siteId: params.siteId,
            categoryId: params.categoryId,
            forLevel: params.forLevel,
            excludeMeterId: params.excludeId,
          );
    });

final adminMeterProvider = FutureProvider.autoDispose.family<Meter, String>((
  ref,
  meterId,
) async {
  return ref.read(meterRepositoryProvider).getMeterById(meterId);
});

final siteMetersProvider = FutureProvider.autoDispose
    .family<List<Meter>, String>((ref, siteId) async {
      return ref.read(meterRepositoryProvider).getMetersForSite(siteId);
    });

final siteTanksProvider = FutureProvider.autoDispose
    .family<List<SiteTank>, String>((ref, siteId) {
      return ref.read(siteTankRepositoryProvider).getActiveTanksForSite(siteId);
    });
