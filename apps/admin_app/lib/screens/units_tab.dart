import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_meters_core/smart_meters_core.dart';

import '../providers/catalog_providers.dart';
import '../utils/catalog_validation.dart';
import '../widgets/catalog_widgets.dart';
import 'unit_form_screen.dart';

class UnitsTab extends ConsumerStatefulWidget {
  const UnitsTab({super.key});

  @override
  ConsumerState<UnitsTab> createState() => _UnitsTabState();
}

class _UnitsTabState extends ConsumerState<UnitsTab> {
  final _searchController = TextEditingController();
  ActiveFilter _filter = ActiveFilter.all;

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

  Future<void> _toggleActive(MeterUnitConfig unit) async {
    try {
      await ref
          .read(meterCatalogRepositoryProvider)
          .updateUnit(unit.id, isActive: !unit.isActive);
      ref.invalidate(catalogUnitsProvider(unit.categoryId));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(friendlyCatalogError(error))));
    }
  }

  Future<void> _deleteUnit(MeterUnitConfig unit) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete unit?'),
        content: Text('Delete "${unit.nameEn}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }

    try {
      await ref.read(meterCatalogRepositoryProvider).deleteUnit(unit.id);
      ref.invalidate(catalogUnitsProvider(unit.categoryId));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(friendlyCatalogError(error))));
    }
  }

  Future<void> _openAddForm(
    String categoryId,
    List<MeterUnitConfig> units,
  ) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            UnitFormScreen(categoryId: categoryId, existingUnits: units),
      ),
    );
    ref.invalidate(catalogUnitsProvider(categoryId));
  }

  @override
  Widget build(BuildContext context) {
    final canManage = ref.watch(canManageCatalogProvider);
    final categoriesAsync = ref.watch(catalogCategoriesProvider);
    final selectedCategoryId = ref.watch(selectedCatalogCategoryIdProvider);
    final listBottomPadding = catalogListBottomPadding(context);

    return categoriesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => CatalogErrorView(
        message: friendlyCatalogError(error),
        onRetry: () => ref.invalidate(catalogCategoriesProvider),
      ),
      data: (categories) {
        if (categories.isEmpty) {
          return const CatalogEmptyState(
            title: 'No categories',
            message: 'Create a category first before adding units.',
            icon: Icons.category_outlined,
          );
        }

        final categoryId = selectedCategoryId ?? categories.first.id;
        if (selectedCategoryId == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ref.read(selectedCatalogCategoryIdProvider.notifier).state =
                categoryId;
          });
        }

        final unitsAsync = ref.watch(catalogUnitsProvider(categoryId));
        final selectedCategory = categories.firstWhere(
          (item) => item.id == categoryId,
          orElse: () => categories.first,
        );

        return Scaffold(
          primary: false,
          floatingActionButton: canManage
              ? FloatingActionButton.extended(
                  heroTag: 'admin_fab_units',
                  onPressed: () {
                    final units =
                        ref.read(catalogUnitsProvider(categoryId)).value ?? [];
                    _openAddForm(categoryId, units);
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Add unit'),
                )
              : null,
          body: SafeArea(
            top: false,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: DropdownMenu<String>(
                    expandedInsets: EdgeInsets.zero,
                    label: const Text('Category'),
                    initialSelection: categoryId,
                    dropdownMenuEntries: [
                      for (final category in categories)
                        DropdownMenuEntry(
                          value: category.id,
                          label: '${category.nameEn} (${category.code})',
                        ),
                    ],
                    onSelected: (value) {
                      if (value != null) {
                        ref
                                .read(
                                  selectedCatalogCategoryIdProvider.notifier,
                                )
                                .state =
                            value;
                      }
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: CatalogToolbar(
                    searchController: _searchController,
                    activeFilter: _filter,
                    onFilterChanged: (value) => setState(() => _filter = value),
                    hintText: 'Search units…',
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Card(
                    color: Colors.amber.shade50,
                    child: const ListTile(
                      leading: Icon(Icons.warning_amber_outlined),
                      title: Text('Unit conversion changes'),
                      subtitle: Text(
                        'Changing unit conversion affects interpretation for '
                        'new meters only. Existing meters with readings are '
                        'protected by the database.',
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: unitsAsync.when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (error, _) => CatalogErrorView(
                      message: friendlyCatalogError(error),
                      onRetry: () =>
                          ref.invalidate(catalogUnitsProvider(categoryId)),
                    ),
                    data: (units) {
                      final filtered = searchUnits(
                        filterByActive(
                          items: units,
                          filter: _filter,
                          isActive: (item) => item.isActive,
                        ),
                        _searchController.text,
                      );

                      if (filtered.isEmpty) {
                        return CatalogEmptyState(
                          title: 'No units',
                          message: canManage
                              ? 'No units for ${selectedCategory.nameEn}. Tap Add unit to create one.'
                              : 'No units for ${selectedCategory.nameEn}.',
                          icon: Icons.straighten_outlined,
                        );
                      }

                      return ListView.separated(
                        padding: EdgeInsets.fromLTRB(
                          16,
                          12,
                          16,
                          listBottomPadding,
                        ),
                        itemCount: filtered.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final unit = filtered[index];
                          return Card(
                            clipBehavior: Clip.antiAlias,
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          unit.nameEn,
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleMedium
                                              ?.copyWith(
                                                fontWeight: FontWeight.w600,
                                              ),
                                        ),
                                        if (unit.nameAr != null) ...[
                                          const SizedBox(height: 2),
                                          Text(
                                            unit.nameAr!,
                                            style: Theme.of(
                                              context,
                                            ).textTheme.bodySmall,
                                          ),
                                        ],
                                        const SizedBox(height: 6),
                                        Text(
                                          'Code: ${unit.code} · Factor: ${unit.unitToBaseFactor}',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.copyWith(
                                                color: Colors.grey.shade700,
                                              ),
                                        ),
                                        const SizedBox(height: 10),
                                        Wrap(
                                          spacing: 8,
                                          runSpacing: 8,
                                          children: [
                                            catalogStatusChip(
                                              isActive: unit.isActive,
                                            ),
                                            if (unit.isBase)
                                              catalogTypeChip(
                                                label: 'Base unit',
                                                icon: Icons.star,
                                                color: Colors.deepPurple,
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
                                                builder: (_) => UnitFormScreen(
                                                  categoryId: categoryId,
                                                  unit: unit,
                                                  existingUnits: units,
                                                ),
                                              ),
                                            );
                                            ref.invalidate(
                                              catalogUnitsProvider(categoryId),
                                            );
                                          case 'toggle':
                                            await _toggleActive(unit);
                                          case 'delete':
                                            await _deleteUnit(unit);
                                        }
                                      },
                                      itemBuilder: (context) => [
                                        const PopupMenuItem(
                                          value: 'edit',
                                          child: Text('Edit'),
                                        ),
                                        PopupMenuItem(
                                          value: 'toggle',
                                          child: Text(
                                            unit.isActive
                                                ? 'Deactivate'
                                                : 'Activate',
                                          ),
                                        ),
                                        const PopupMenuItem(
                                          value: 'delete',
                                          child: Text('Delete'),
                                        ),
                                      ],
                                    )
                                  else
                                    catalogStatusChip(isActive: unit.isActive),
                                ],
                              ),
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
      },
    );
  }
}
