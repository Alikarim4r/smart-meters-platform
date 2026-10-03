import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_meters_core/smart_meters_core.dart';

import '../providers/catalog_providers.dart';
import '../utils/catalog_validation.dart';
import '../widgets/catalog_widgets.dart';
import 'category_form_screen.dart';
import '../l10n/admin_strings.dart';

class CategoriesTab extends ConsumerStatefulWidget {
  const CategoriesTab({super.key});

  @override
  ConsumerState<CategoriesTab> createState() => _CategoriesTabState();
}

class _CategoriesTabState extends ConsumerState<CategoriesTab> {
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

  Future<void> _openAddForm() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const CategoryFormScreen()));
    ref.invalidate(catalogCategoriesProvider);
  }

  Future<void> _toggleActive(MeterCategoryConfig category) async {
    if (!ref.read(canManageCatalogProvider)) {
      return;
    }
    try {
      await ref
          .read(meterCatalogRepositoryProvider)
          .updateCategory(category.id, isActive: !category.isActive);
      ref.invalidate(catalogCategoriesProvider);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(friendlyCatalogError(error))));
    }
  }

  Future<void> _deleteCategory(MeterCategoryConfig category) async {
    if (isProtectedSystemCategory(category)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            adminText(
              context,
              'System categories cannot be deleted.',
              'لا يمكن حذف فئات النظام.',
            ),
          ),
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(adminText(context, 'Delete category?', 'حذف الفئة؟')),
        content: Text('Delete "${category.nameEn}"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(adminText(context, 'Cancel', 'إلغاء')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(adminText(context, 'Delete', 'حذف')),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }

    try {
      await ref
          .read(meterCatalogRepositoryProvider)
          .deleteCategory(category.id);
      ref.invalidate(catalogCategoriesProvider);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(friendlyCatalogError(error))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final canManage = ref.watch(canManageCatalogProvider);
    final categoriesAsync = ref.watch(catalogCategoriesProvider);
    final listBottomPadding = catalogListBottomPadding(context);

    return Scaffold(
      primary: false,
      floatingActionButton: canManage
          ? FloatingActionButton.extended(
              heroTag: 'admin_fab_categories',
              onPressed: _openAddForm,
              icon: const Icon(Icons.add),
              label: Text(adminText(context, 'Add category', 'إضافة فئة')),
            )
          : null,
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: CatalogToolbar(
                searchController: _searchController,
                activeFilter: _filter,
                onFilterChanged: (value) => setState(() => _filter = value),
                hintText: adminText(
                  context,
                  'Search categories…',
                  'بحث في الفئات…',
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: categoriesAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => CatalogErrorView(
                  message: friendlyCatalogError(error),
                  onRetry: () => ref.invalidate(catalogCategoriesProvider),
                ),
                data: (categories) {
                  final filtered = searchCategories(
                    filterByActive(
                      items: categories,
                      filter: _filter,
                      isActive: (item) => item.isActive,
                    ),
                    _searchController.text,
                  );

                  if (filtered.isEmpty) {
                    return CatalogEmptyState(
                      title: adminText(
                        context,
                        'No categories',
                        'لا توجد فئات',
                      ),
                      message: canManage
                          ? 'No categories match your filters. Tap Add category to create one.'
                          : 'No categories match your filters.',
                      icon: Icons.category_outlined,
                    );
                  }

                  return ListView.separated(
                    padding: EdgeInsets.fromLTRB(16, 8, 16, listBottomPadding),
                    itemCount: filtered.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final category = filtered[index];
                      final protected = isProtectedSystemCategory(category);
                      return Card(
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: canManage
                              ? () async {
                                  await Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (_) => CategoryFormScreen(
                                        category: category,
                                      ),
                                    ),
                                  );
                                  ref.invalidate(catalogCategoriesProvider);
                                }
                              : null,
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
                                        category.nameEn,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.w600,
                                            ),
                                      ),
                                      if (category.nameAr != null) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          category.nameAr!,
                                          style: Theme.of(
                                            context,
                                          ).textTheme.bodySmall,
                                        ),
                                      ],
                                      const SizedBox(height: 6),
                                      Text(
                                        'Code: ${category.code} · Base: ${category.baseUnitCode}',
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
                                            isActive: category.isActive,
                                          ),
                                          catalogTypeChip(
                                            label:
                                                protected || category.isSystem
                                                ? 'System'
                                                : 'Custom',
                                            icon: protected || category.isSystem
                                                ? Icons.lock_outline
                                                : Icons.tune,
                                            color:
                                                protected || category.isSystem
                                                ? Colors.indigo
                                                : Colors.teal,
                                          ),
                                          if (category.supportsCopOutput)
                                            catalogTypeChip(
                                              label: 'COP output',
                                              icon: Icons.speed,
                                              color: Colors.orange,
                                            ),
                                          if (category.supportsElectricInput)
                                            catalogTypeChip(
                                              label: 'COP input',
                                              icon: Icons.bolt,
                                              color: Colors.amber,
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
                                              builder: (_) =>
                                                  CategoryFormScreen(
                                                    category: category,
                                                  ),
                                            ),
                                          );
                                          ref.invalidate(
                                            catalogCategoriesProvider,
                                          );
                                        case 'toggle':
                                          await _toggleActive(category);
                                        case 'delete':
                                          await _deleteCategory(category);
                                      }
                                    },
                                    itemBuilder: (context) => [
                                      PopupMenuItem(
                                        value: 'edit',
                                        child: Text(
                                          adminText(context, 'Edit', 'تعديل'),
                                        ),
                                      ),
                                      PopupMenuItem(
                                        value: 'toggle',
                                        child: Text(
                                          category.isActive
                                              ? 'Deactivate'
                                              : 'Activate',
                                        ),
                                      ),
                                      if (!protected)
                                        PopupMenuItem(
                                          value: 'delete',
                                          child: Text(
                                            adminText(context, 'Delete', 'حذف'),
                                          ),
                                        ),
                                    ],
                                  ),
                              ],
                            ),
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
  }
}
