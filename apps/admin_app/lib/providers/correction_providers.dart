import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_meters_core/smart_meters_core.dart';

final canCorrectReadingsProvider = Provider<bool>((ref) {
  final profile = ref.watch(authProvider).profile;
  if (profile == null) return false;
  return profile.isPlatformOwner ||
      profile.isSuperAdmin ||
      profile.isSiteAdmin;
});

final correctionSiteIdProvider = StateProvider<String?>((ref) => null);
final correctionZoneIdProvider = StateProvider<String?>((ref) => null);
final correctionCategoryIdProvider = StateProvider<String?>((ref) => null);
final correctionDateFilterProvider = StateProvider<CorrectionDateFilter>(
  (ref) => CorrectionDateFilter.last30Days,
);
final correctionListFilterProvider = StateProvider<CorrectionListFilter>(
  (ref) => CorrectionListFilter.all,
);

ReadingCorrectionFilters buildCorrectionFilters({required Ref ref}) {
  final siteId = ref.watch(correctionSiteIdProvider);
  final zoneId = ref.watch(correctionZoneIdProvider);
  final categoryId = ref.watch(correctionCategoryIdProvider);
  final dateFilter = ref.watch(correctionDateFilterProvider);
  final listFilter = ref.watch(correctionListFilterProvider);
  final businessDate = qatarBusinessDate();

  DateTime? fromDate;
  DateTime? toDate = businessDate;
  switch (dateFilter) {
    case CorrectionDateFilter.today:
      fromDate = businessDate;
    case CorrectionDateFilter.last7Days:
      fromDate = businessDate.subtract(const Duration(days: 6));
    case CorrectionDateFilter.last30Days:
      fromDate = businessDate.subtract(const Duration(days: 29));
    case CorrectionDateFilter.all:
      fromDate = null;
      toDate = null;
  }

  return ReadingCorrectionFilters(
    siteId: siteId,
    zoneId: zoneId,
    categoryId: categoryId,
    fromDate: fromDate,
    toDate: toDate,
    listFilter: listFilter,
    limit: dateFilter == CorrectionDateFilter.all ? 500 : 200,
  );
}

final adminCorrectionsProvider =
    FutureProvider.autoDispose<List<AdminReadingRow>>((ref) async {
      final filters = buildCorrectionFilters(ref: ref);
      if (filters.siteId == null) return [];
      return ref
          .read(readingCorrectionRepositoryProvider)
          .getSubmittedReadingsForAdmin(filters: filters);
    });

final readingCorrectionDetailsProvider = FutureProvider.autoDispose
    .family<ReadingCorrectionDetails, String>((ref, readingId) async {
      return ref
          .read(readingCorrectionRepositoryProvider)
          .getReadingDetailsForCorrection(readingId);
    });

final readingAuditHistoryProvider = FutureProvider.autoDispose
    .family<List<ReadingAuditEntry>, String>((ref, readingId) async {
      return ref
          .read(readingCorrectionRepositoryProvider)
          .getReadingAuditHistory(readingId);
    });

final correctionPhotoUrlProvider = FutureProvider.autoDispose
    .family<String, String>((ref, storagePath) async {
      return ref
          .read(meterImageStorageRepositoryProvider)
          .createSignedUrl(storagePath);
    });
