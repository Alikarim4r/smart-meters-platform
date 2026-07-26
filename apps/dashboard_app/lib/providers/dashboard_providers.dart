import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_meters_core/smart_meters_core.dart';

import '../utils/dashboard_filters.dart';
import '../utils/site_system_navigation.dart';

final businessDateProvider = Provider<DateTime>((ref) => qatarBusinessDate());

final dashboardSitesProvider =
    FutureProvider.autoDispose<List<DashboardSiteOverview>>((ref) async {
  final businessDate = ref.watch(businessDateProvider);
  return ref.read(dashboardRepositoryProvider).getSitesOverview(
        businessDate: businessDate,
      );
});

final dashboardZonesProvider = Provider<List<Zone>>((ref) {
  final sites = ref.watch(dashboardSitesProvider).valueOrNull ?? [];
  final zones = <String, Zone>{};
  for (final item in sites) {
    final zone = item.site.zone;
    if (zone != null) {
      zones[zone.id] = zone;
    }
  }
  final list = zones.values.toList()
    ..sort((a, b) => a.nameEn.compareTo(b.nameEn));
  return list;
});

final dashboardZoneFilterProvider = StateProvider<String?>((ref) => null);

final dashboardSiteTypeFilterProvider =
    StateProvider<DashboardSiteTypeFilter>((ref) => DashboardSiteTypeFilter.all);

final dashboardSearchProvider = StateProvider<String>((ref) => '');

final siteDashboardSummaryProvider =
    FutureProvider.autoDispose.family<SiteDashboardSummary, String>(
  (ref, siteId) async {
    return ref.read(dashboardRepositoryProvider).getSiteDashboardSummary(
          siteId: siteId,
          businessDate: ref.watch(businessDateProvider),
        );
  },
);

final siteCategoriesSummaryProvider =
    FutureProvider.autoDispose.family<List<SiteCategorySummary>, String>(
  (ref, siteId) async {
    return ref.read(dashboardRepositoryProvider).getSiteCategoriesSummary(
          siteId: siteId,
          businessDate: ref.watch(businessDateProvider),
        );
  },
);

final siteMetersDashboardProvider =
    FutureProvider.autoDispose.family<List<DashboardMeterRow>, String>(
  (ref, siteId) async {
    return ref
        .read(dashboardRepositoryProvider)
        .getSiteMetersWithLatestReadings(
          siteId: siteId,
          businessDate: ref.watch(businessDateProvider),
        );
  },
);

final siteCopGroupsProvider =
    FutureProvider.autoDispose.family<List<DashboardCopGroupSummary>, String>(
  (ref, siteId) async {
    return ref.read(dashboardRepositoryProvider).getCopGroupsForSite(siteId);
  },
);

class SiteReadingsQuery {
  const SiteReadingsQuery({
    required this.siteId,
    required this.dateFilter,
    this.categoryId,
    this.meterId,
    this.photoFilter = DashboardPhotoFilter.all,
    this.limit = 100,
  });

  final String siteId;
  final DashboardReadingDateFilter dateFilter;
  final String? categoryId;
  final String? meterId;
  final DashboardPhotoFilter photoFilter;
  final int limit;

  @override
  bool operator ==(Object other) {
    return other is SiteReadingsQuery &&
        other.siteId == siteId &&
        other.dateFilter == dateFilter &&
        other.categoryId == categoryId &&
        other.meterId == meterId &&
        other.photoFilter == photoFilter &&
        other.limit == limit;
  }

  @override
  int get hashCode =>
      Object.hash(siteId, dateFilter, categoryId, meterId, photoFilter, limit);
}

final siteReadingsProvider =
    FutureProvider.autoDispose.family<List<DashboardReadingRow>, SiteReadingsQuery>(
  (ref, query) async {
    final businessDate = ref.watch(businessDateProvider);
    final range = readingDateRangeForFilter(
      filter: query.dateFilter,
      businessDate: businessDate,
    );
    bool? hasPhoto;
    if (query.photoFilter == DashboardPhotoFilter.withPhoto) {
      hasPhoto = true;
    } else if (query.photoFilter == DashboardPhotoFilter.withoutPhoto) {
      hasPhoto = false;
    }

    return ref.read(dashboardRepositoryProvider).getRecentSiteReadings(
          siteId: query.siteId,
          filters: DashboardReadingFilters(
            fromDate: range.from,
            toDate: range.to,
            categoryId: query.categoryId,
            meterId: query.meterId,
            hasPhoto: hasPhoto,
            limit: query.limit,
          ),
        );
  },
);

final meterReadingPhotoUrlProvider =
    FutureProvider.autoDispose.family<String?, String>((ref, storagePath) async {
  if (storagePath.isEmpty) {
    return null;
  }
  return ref.read(meterImageStorageRepositoryProvider).createSignedUrl(storagePath);
});

final siteMeterSearchProvider = StateProvider<String>((ref) => '');

final siteMeterCategoryFilterProvider = StateProvider<String?>((ref) => null);

final siteMeterLevelFilterProvider = StateProvider<MeterLevel?>((ref) => null);

final siteMeterActiveFilterProvider = StateProvider<bool?>((ref) => null);

final siteReadingsDateFilterProvider =
    StateProvider<DashboardReadingDateFilter>((ref) => DashboardReadingDateFilter.last7Days);

final siteReadingsLimitProvider = StateProvider<int>((ref) => 100);

final siteReadingsCategoryFilterProvider = StateProvider<String?>((ref) => null);

final siteReadingsPhotoFilterProvider =
    StateProvider<DashboardPhotoFilter>((ref) => DashboardPhotoFilter.all);

final siteDashboardTabProvider = StateProvider<int>((ref) => 0);

final siteDashboardSectionProvider =
    StateProvider<SiteDashboardSection>((ref) => SiteDashboardSection.overview);
