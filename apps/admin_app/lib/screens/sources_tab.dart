import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_meters_core/smart_meters_core.dart';

import '../providers/catalog_providers.dart';
import '../utils/catalog_validation.dart';
import '../widgets/catalog_widgets.dart';
import 'source_form_screen.dart';

class SourcesTab extends ConsumerStatefulWidget {
  const SourcesTab({super.key});

  @override
  ConsumerState<SourcesTab> createState() => _SourcesTabState();
}

class _SourcesTabState extends ConsumerState<SourcesTab> {
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

  Future<void> _toggleActive(MeterSourceConfig source) async {
    try {
      await ref
          .read(meterCatalogRepositoryProvider)
          .updateSource(source.id, isActive: !source.isActive);
      ref.invalidate(catalogSourcesProvider(source.categoryId));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(friendlyCatalogError(error))));
    }
  }

  Future<void> _deleteSource(MeterSourceConfig source) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete source?'),
        content: Text('Delete "${source.nameEn}"?'),
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
      await ref.read(meterCatalogRepositoryProvider).deleteSource(source.id);
      ref.invalidate(catalogSourcesProvider(source.categoryId));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(friendlyCatalogError(error))));
    }
  }

  Future<void> _openAddForm(String categoryId) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SourceFormScreen(categoryId: categoryId),
      ),
    );
    ref.invalidate(catalogSourcesProvider(categoryId));
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
            message: 'Create a category first before adding sources.',
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

        final sourcesAsync = ref.watch(catalogSourcesProvider(categoryId));
        final selectedCategory = categories.firstWhere(
          (item) => item.id == categoryId,
          orElse: () => categories.first,
        );

        return Scaffold(
          primary: false,
          floatingActionButton: canManage
              ? FloatingActionButton.extended(
                  heroTag: 'admin_fab_sources',
                  onPressed: () => _openAddForm(categoryId),
                  icon: const Icon(Icons.add),
                  label: const Text('Add source'),
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
                    hintText: 'Search sources…',
                  ),
                ),
                Expanded(
                  child: sourcesAsync.when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (error, _) => CatalogErrorView(
                      message: friendlyCatalogError(error),
                      onRetry: () =>
                          ref.invalidate(catalogSourcesProvider(categoryId)),
                    ),
                    data: (sources) {
                      final filtered = searchSources(
                        filterByActive(
                          items: sources,
                          filter: _filter,
                          isActive: (item) => item.isActive,
                        ),
                        _searchController.text,
                      );

                      if (filtered.isEmpty) {
                        return CatalogEmptyState(
                          title: 'No sources',
                          message: canManage
                              ? 'No sources for ${selectedCategory.nameEn}. Tap Add source to create one.'
                              : 'No sources for ${selectedCategory.nameEn}.',
                          icon: Icons.source_outlined,
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
                          final source = filtered[index];
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
                                          source.nameEn,
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleMedium
                                              ?.copyWith(
                                                fontWeight: FontWeight.w600,
                                              ),
                                        ),
                                        if (source.nameAr != null) ...[
                                          const SizedBox(height: 2),
                                          Text(
                                            source.nameAr!,
                                            style: Theme.of(
                                              context,
                                            ).textTheme.bodySmall,
                                          ),
                                        ],
                                        const SizedBox(height: 6),
                                        Text(
                                          'Code: ${source.code}',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.copyWith(
                                                color: Colors.grey.shade700,
                                              ),
                                        ),
                                        const SizedBox(height: 10),
                                        catalogStatusChip(
                                          isActive: source.isActive,
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
                                                    SourceFormScreen(
                                                      categoryId: categoryId,
                                                      source: source,
                                                    ),
                                              ),
                                            );
                                            ref.invalidate(
                                              catalogSourcesProvider(
                                                categoryId,
                                              ),
                                            );
                                          case 'toggle':
                                            await _toggleActive(source);
                                          case 'delete':
                                            await _deleteSource(source);
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
                                            source.isActive
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
                                    catalogStatusChip(
                                      isActive: source.isActive,
                                    ),
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
