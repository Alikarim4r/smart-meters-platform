import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_meters_core/smart_meters_core.dart';

final canManageCatalogProvider = Provider<bool>((ref) {
  return ref.watch(authProvider).profile?.isSuperAdmin ?? false;
});

final catalogCategoriesProvider =
    FutureProvider.autoDispose<List<MeterCategoryConfig>>((ref) {
      return ref.read(meterCatalogRepositoryProvider).getCategories();
    });

final catalogUnitsProvider = FutureProvider.autoDispose
    .family<List<MeterUnitConfig>, String>((ref, categoryId) {
      return ref
          .read(meterCatalogRepositoryProvider)
          .getUnitsForCategory(categoryId);
    });

final catalogSourcesProvider = FutureProvider.autoDispose
    .family<List<MeterSourceConfig>, String>((ref, categoryId) {
      return ref
          .read(meterCatalogRepositoryProvider)
          .getSourcesForCategory(categoryId);
    });

final selectedCatalogCategoryIdProvider = StateProvider<String?>((ref) => null);
