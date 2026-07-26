import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_meters_core/smart_meters_core.dart';

import '../l10n/admin_strings.dart';
import '../providers/admin_providers.dart';
import '../providers/catalog_providers.dart';
import '../providers/preferences_providers.dart';
import '../utils/admin_validation.dart';
import '../utils/catalog_validation.dart';
import '../utils/delete_confirmations.dart';
import '../widgets/catalog_widgets.dart';
import 'meter_detail_screen.dart';
import 'meter_form_screen.dart';

class MetersTab extends ConsumerStatefulWidget {
  const MetersTab({super.key});

  @override
  ConsumerState<MetersTab> createState() => _MetersTabState();
}

class _MetersTabState extends ConsumerState<MetersTab> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _openAddForm(String? siteId) async {
    if (siteId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a site before adding a meter.')),
      );
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => MeterFormScreen(siteId: siteId)),
    );
    ref.invalidate(adminMetersProvider);
    ref.invalidate(adminSitesProvider);
  }

  @override
  Widget build(BuildContext context) {
    final canManage = ref.watch(canManageMetersProvider);
    final canDelete = ref.watch(canDeleteEntitiesProvider);
    final sitesAsync = ref.watch(adminSitesProvider);
    final categoriesAsync = ref.watch(catalogCategoriesProvider);
    final metersAsync = ref.watch(adminMetersProvider);
    final selectedSiteId = ref.watch(selectedAdminSiteIdProvider);
    final selectedCategoryId = ref.watch(selectedAdminMeterCategoryIdProvider);
    final activeFilter = ref.watch(adminMeterActiveFilterProvider);
    final listBottomPadding = catalogListBottomPadding(context);
    final s = AdminStrings(ref.watch(adminLocaleProvider));

    return Scaffold(
      primary: false,
      floatingActionButton: canManage
          ? FloatingActionButton.extended(
              heroTag: 'admin_fab_meters',
              onPressed: () => _openAddForm(selectedSiteId),
              icon: const Icon(Icons.add),
              label: Text(s.addMeter),
            )
          : null,
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: sitesAsync.when(
                loading: () => const LinearProgressIndicator(),
                error: (error, _) => Text(friendlySiteError(error)),
                data: (sites) {
                  if (sites.isEmpty) {
                    if (selectedSiteId != null) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        ref.read(selectedAdminSiteIdProvider.notifier).state =
                            null;
                      });
                    }
                    return const Text('No sites available.');
                  }
                  final selectedStillValid =
                      selectedSiteId != null &&
                      sites.any((site) => site.id == selectedSiteId);
                  final siteId = selectedStillValid
                      ? selectedSiteId
                      : sites.first.id;
                  if (selectedSiteId != siteId) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      ref.read(selectedAdminSiteIdProvider.notifier).state =
                          siteId;
                    });
                  }
                  return DropdownButtonFormField<String>(
                    key: ValueKey('admin-meters-site-$siteId'),
                    initialValue: siteId,
                    isExpanded: true,
                    decoration: catalogFieldDecoration(labelText: s.site),
                    items: [
                      for (final site in sites)
                        DropdownMenuItem(
                          value: site.id,
                          child: Text(
                            site.nameEn,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        ref.read(selectedAdminSiteIdProvider.notifier).state =
                            value;
                      }
                    },
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: categoriesAsync.when(
                loading: () => const SizedBox.shrink(),
                error: (_, _) => const SizedBox.shrink(),
                data: (categories) {
                  final categoryStillValid =
                      selectedCategoryId == null ||
                      categories.any((c) => c.id == selectedCategoryId);
                  final categoryId = categoryStillValid
                      ? selectedCategoryId
                      : null;
                  if (selectedCategoryId != categoryId) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      ref
                              .read(
                                selectedAdminMeterCategoryIdProvider.notifier,
                              )
                              .state =
                          categoryId;
                    });
                  }
                  return DropdownButtonFormField<String?>(
                    key: ValueKey('admin-meters-category-$categoryId'),
                    initialValue: categoryId,
                    isExpanded: true,
                    decoration: catalogFieldDecoration(
                      labelText: s.category,
                      hintText: s.allCategories,
                    ),
                    items: [
                      DropdownMenuItem<String?>(
                        value: null,
                        child: Text(
                          s.allCategories,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      for (final category in categories)
                        DropdownMenuItem(
                          value: category.id,
                          child: Text(
                            category.nameEn,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (value) {
                      ref
                              .read(
                                selectedAdminMeterCategoryIdProvider.notifier,
                              )
                              .state =
                          value;
                    },
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: CatalogToolbar(
                searchController: _searchController,
                activeFilter: _toCatalogFilter(activeFilter),
                onFilterChanged: (value) =>
                    ref.read(adminMeterActiveFilterProvider.notifier).state =
                        _fromCatalogFilter(value),
                hintText: s.searchMeters,
              ),
            ),
            Expanded(
              child: metersAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => CatalogErrorView(
                  message: friendlyMeterError(error),
                  onRetry: () => ref.invalidate(adminMetersProvider),
                ),
                data: (meters) {
                  final filtered = searchMeters(meters, _searchController.text);

                  if (filtered.isEmpty) {
                    return CatalogEmptyState(
                      title: s.isAr ? 'لا توجد عدادات' : 'No meters',
                      message: canManage
                          ? (s.isAr
                              ? 'لا توجد عدادات مطابقة. اضغط إضافة عداد لإنشاء واحد.'
                              : 'No meters match your filters. Tap Add meter to create one.')
                          : (s.isAr
                              ? 'لا توجد عدادات مطابقة للفلاتر.'
                              : 'No meters match your filters.'),
                      icon: Icons.speed_outlined,
                    );
                  }

                  return ListView.separated(
                    padding: EdgeInsets.fromLTRB(16, 12, 16, listBottomPadding),
                    itemCount: filtered.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final meter = filtered[index];
                      return BrandInkCard(
                        onTap: () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) =>
                                  MeterDetailScreen(meterId: meter.id),
                            ),
                          );
                          ref.invalidate(adminMetersProvider);
                        },
                        padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            brandIconWell(
                              context: context,
                              icon: Icons.speed_outlined,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    meter.nameEn,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleSmall
                                        ?.copyWith(
                                          fontWeight: FontWeight.w800,
                                          color: BrandChrome.titleColor(
                                            isDark:
                                                Theme.of(context).brightness ==
                                                Brightness.dark,
                                            scheme: Theme.of(
                                              context,
                                            ).colorScheme,
                                          ),
                                        ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${meter.meterCode} · ${meter.siteNameEn ?? 'Site'}',
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(
                                          color: BrandChrome.mutedColor(
                                            isDark:
                                                Theme.of(context).brightness ==
                                                Brightness.dark,
                                            scheme: Theme.of(
                                              context,
                                            ).colorScheme,
                                          ),
                                        ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${meter.categoryConfig?.nameEn ?? meter.categoryCode} · '
                                    '${meter.sourceConfig?.nameEn ?? meter.sourceDisplayName} · '
                                    '${meter.unitConfig?.nameEn ?? meter.unitDisplayLabel}',
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(
                                          color: BrandChrome.mutedColor(
                                            isDark:
                                                Theme.of(context).brightness ==
                                                Brightness.dark,
                                            scheme: Theme.of(
                                              context,
                                            ).colorScheme,
                                          ),
                                        ),
                                  ),
                                  const SizedBox(height: 10),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      catalogStatusChip(
                                        isActive: meter.isActive,
                                      ),
                                      if (meter.includeInDashboard)
                                        catalogTypeChip(
                                          label: 'Dashboard',
                                          icon: Icons.dashboard_outlined,
                                          color: Colors.brown,
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            if (canManage)
                              PopupMenuButton<String>(
                                onSelected: (action) async {
                                  switch (action) {
                                    case 'edit':
                                      await Navigator.of(context).push(
                                        MaterialPageRoute<void>(
                                          builder: (_) => MeterFormScreen(
                                            siteId: meter.siteId,
                                            meter: meter,
                                          ),
                                        ),
                                      );
                                      ref.invalidate(adminMetersProvider);
                                    case 'toggle':
                                      try {
                                        await ref
                                            .read(meterRepositoryProvider)
                                            .updateMeter(
                                              meter.id,
                                              isActive: !meter.isActive,
                                            );
                                        ref.invalidate(adminMetersProvider);
                                      } catch (error) {
                                        if (!context.mounted) return;
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              friendlyMeterError(error),
                                            ),
                                          ),
                                        );
                                      }
                                    case 'delete':
                                      final confirmed =
                                          await confirmForceDelete(
                                            context: context,
                                            title: s.isAr
                                                ? 'حذف العداد؟'
                                                : 'Delete meter?',
                                            entityName: meter.nameEn,
                                          );
                                      if (confirmed != true) return;
                                      try {
                                        final repo = ref.read(
                                          meterRepositoryProvider,
                                        );
                                        await repo.forceDeleteMeter(meter.id);
                                        ref.invalidate(adminMetersProvider);
                                      } catch (error) {
                                        if (!context.mounted) return;
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              friendlyMeterError(error),
                                            ),
                                          ),
                                        );
                                      }
                                  }
                                },
                                itemBuilder: (context) => [
                                  PopupMenuItem(
                                    value: 'edit',
                                    child: Text(s.edit),
                                  ),
                                  PopupMenuItem(
                                    value: 'toggle',
                                    child: Text(
                                      meter.isActive
                                          ? s.deactivate
                                          : s.activate,
                                    ),
                                  ),
                                  if (canDelete)
                                    PopupMenuItem(
                                      value: 'delete',
                                      child: Text(s.delete),
                                    ),
                                ],
                              ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  ActiveFilter _toCatalogFilter(AdminActiveFilter filter) {
    switch (filter) {
      case AdminActiveFilter.all:
        return ActiveFilter.all;
      case AdminActiveFilter.activeOnly:
        return ActiveFilter.activeOnly;
      case AdminActiveFilter.inactiveOnly:
        return ActiveFilter.inactiveOnly;
    }
  }

  AdminActiveFilter _fromCatalogFilter(ActiveFilter filter) {
    switch (filter) {
      case ActiveFilter.all:
        return AdminActiveFilter.all;
      case ActiveFilter.activeOnly:
        return AdminActiveFilter.activeOnly;
      case ActiveFilter.inactiveOnly:
        return AdminActiveFilter.inactiveOnly;
    }
  }
}
