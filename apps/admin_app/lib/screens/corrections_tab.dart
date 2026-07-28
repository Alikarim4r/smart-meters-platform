import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_meters_core/smart_meters_core.dart';

import '../providers/admin_providers.dart';
import '../providers/catalog_providers.dart';
import '../providers/correction_providers.dart';
import '../providers/zone_providers.dart';
import 'reading_correction_form_screen.dart';

class CorrectionsTab extends ConsumerWidget {
  const CorrectionsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canCorrect = ref.watch(canCorrectReadingsProvider);
    if (!canCorrect) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Only super admins and site admins can review and correct readings.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final siteId = ref.watch(correctionSiteIdProvider);
    final sitesAsync = ref.watch(adminSitesProvider);
    final zonesAsync = ref.watch(adminZonesProvider);
    final categoriesAsync = ref.watch(catalogCategoriesProvider);
    final readingsAsync = ref.watch(adminCorrectionsProvider);

    return Scaffold(
      primary: false,
      body: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Text(
                'Review submitted readings, correct values, and view audit history.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  SizedBox(
                    width: 220,
                    child: sitesAsync.when(
                      loading: () => const LinearProgressIndicator(),
                      error: (e, _) => Text('Sites: $e'),
                      data: (sites) {
                        return DropdownButtonFormField<String?>(
                          key: ValueKey('site-$siteId-${sites.length}'),
                          initialValue: siteId,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Site',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          items: [
                            const DropdownMenuItem<String?>(
                              value: null,
                              child: Text(
                                'Select site',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            ...sites.map(
                              (site) => DropdownMenuItem(
                                value: site.id,
                                child: Text(
                                  site.nameEn,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ],
                          onChanged: (value) {
                            ref.read(correctionSiteIdProvider.notifier).state =
                                value;
                            // Reset sticky filters that can wipe the list when
                            // switching sites (zone from another site, etc.).
                            ref.read(correctionZoneIdProvider.notifier).state =
                                null;
                            ref
                                    .read(correctionCategoryIdProvider.notifier)
                                    .state =
                                null;
                            ref.invalidate(adminCorrectionsProvider);
                          },
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 180,
                    child: zonesAsync.when(
                      loading: () => const SizedBox.shrink(),
                      error: (_, _) => const SizedBox.shrink(),
                      data: (zones) {
                        final zoneId = ref.watch(correctionZoneIdProvider);
                        final selectedSite = sitesAsync.maybeWhen(
                          data: (sites) => sites
                              .where((s) => s.id == siteId)
                              .firstOrNull,
                          orElse: () => null,
                        );
                        final items = selectedSite == null
                            ? zones
                            : zones
                                .where(
                                  (z) =>
                                      z.organizationId ==
                                      selectedSite.organizationId,
                                )
                                .toList();
                        final effectiveZoneId =
                            zoneId != null && items.any((z) => z.id == zoneId)
                                ? zoneId
                                : null;
                        return DropdownButtonFormField<String?>(
                          key: ValueKey('zone-$siteId-$effectiveZoneId'),
                          initialValue: effectiveZoneId,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Zone',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          items: [
                            const DropdownMenuItem<String?>(
                              value: null,
                              child: Text(
                                'All zones',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            ...items.map(
                              (zone) => DropdownMenuItem(
                                value: zone.id,
                                child: Text(
                                  zone.nameEn,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ],
                          onChanged: (value) {
                            ref.read(correctionZoneIdProvider.notifier).state =
                                value;
                            ref.invalidate(adminCorrectionsProvider);
                          },
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 180,
                    child: categoriesAsync.when(
                      loading: () => const SizedBox.shrink(),
                      error: (_, _) => const SizedBox.shrink(),
                      data: (categories) {
                        final categoryId = ref.watch(
                          correctionCategoryIdProvider,
                        );
                        return DropdownButtonFormField<String?>(
                          initialValue: categoryId,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Category',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          items: [
                            const DropdownMenuItem<String?>(
                              value: null,
                              child: Text(
                                'All categories',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            ...categories.map(
                              (cat) => DropdownMenuItem(
                                value: cat.id,
                                child: Text(
                                  cat.nameEn,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ],
                          onChanged: (value) {
                            ref
                                    .read(correctionCategoryIdProvider.notifier)
                                    .state =
                                value;
                            ref.invalidate(adminCorrectionsProvider);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ...CorrectionDateFilter.values.map(
                    (filter) => FilterChip(
                      label: Text(filter.label),
                      selected:
                          ref.watch(correctionDateFilterProvider) == filter,
                      onSelected: (_) {
                        ref.read(correctionDateFilterProvider.notifier).state =
                            filter;
                        ref.invalidate(adminCorrectionsProvider);
                      },
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: CorrectionListFilter.values.map((filter) {
                  return FilterChip(
                    label: Text(filter.label),
                    selected: ref.watch(correctionListFilterProvider) == filter,
                    onSelected: (_) {
                      ref.read(correctionListFilterProvider.notifier).state =
                          filter;
                      ref.invalidate(adminCorrectionsProvider);
                    },
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: siteId == null
                  ? const Center(
                      child: Text('Select a site to load submitted readings.'),
                    )
                  : readingsAsync.when(
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (error, _) => Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text('Failed to load readings: $error'),
                        ),
                      ),
                      data: (readings) {
                        if (readings.isEmpty) {
                          return const Center(
                            child: Text(
                              'No readings match the current filters.',
                            ),
                          );
                        }
                        return ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                          itemCount: readings.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            return _ReadingCard(
                              row: readings[index],
                              onTap: () async {
                                await Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) => ReadingCorrectionFormScreen(
                                      readingId: readings[index].readingId,
                                    ),
                                  ),
                                );
                                ref.invalidate(adminCorrectionsProvider);
                              },
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

class _ReadingCard extends ConsumerWidget {
  const _ReadingCard({required this.row, required this.onTap});

  final AdminReadingRow row;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final photoAsync = row.hasPhoto
        ? ref.watch(correctionPhotoUrlProvider(row.imageStoragePath!))
        : null;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (row.hasPhoto)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    width: 56,
                    height: 56,
                    child: photoAsync == null
                        ? const ColoredBox(
                            color: Color(0xFFE0E0E0),
                            child: Icon(Icons.image),
                          )
                        : photoAsync.when(
                            loading: () => const Center(
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            ),
                            error: (_, _) => const Icon(Icons.broken_image),
                            data: (url) => Image.network(
                              url,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) =>
                                  const Icon(Icons.broken_image),
                            ),
                          ),
                  ),
                )
              else
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.photo_outlined),
                ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      row.meterName,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    Text(
                      '${row.siteName} · ${row.zoneName}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    Text(
                      '${row.categoryName} · ${formatBusinessDateDisplay(row.readingDate)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${row.rawValue} ${row.unitLabel}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    if (row.enteredByName != null || row.enteredByEmail != null)
                      Text(
                        'Submitted by ${row.enteredByName ?? row.enteredByEmail}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        if (row.isCorrected)
                          const Chip(
                            label: Text('Corrected'),
                            visualDensity: VisualDensity.compact,
                          ),
                        ...row.alertTypes.map(
                          (type) => Chip(
                            label: Text(type.label),
                            visualDensity: VisualDensity.compact,
                            backgroundColor: Theme.of(
                              context,
                            ).colorScheme.errorContainer,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}
