import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_meters_core/smart_meters_core.dart';

import '../l10n/admin_strings.dart';
import '../providers/admin_providers.dart';
import '../providers/preferences_providers.dart';
import '../widgets/catalog_widgets.dart';
import 'meter_detail_screen.dart';
import 'meter_form_screen.dart';
import 'sites_tab.dart';

class SiteDetailScreen extends ConsumerWidget {
  const SiteDetailScreen({super.key, required this.siteId});

  final String siteId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AdminStrings(ref.watch(adminLocaleProvider));
    final siteAsync = ref.watch(adminSiteProvider(siteId));
    final metersAsync = ref.watch(siteMetersProvider(siteId));
    final canEdit = ref.watch(canEditSitesProvider);
    final canManageMeters = ref.watch(canManageMetersProvider);

    return Scaffold(
      appBar: AppBar(title: Text(s.isAr ? 'تفاصيل الموقع' : 'Site details')),
      body: siteAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => CatalogErrorView(
          message: friendlySiteError(error),
          onRetry: () => ref.invalidate(adminSiteProvider(siteId)),
        ),
        data: (site) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        site.nameEn,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      if (site.nameAr.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(site.nameAr),
                      ],
                      const SizedBox(height: 12),
                      _DetailRow(label: 'Type', value: site.siteType.label),
                      _DetailRow(label: 'Zone', value: site.displayZoneName),
                      if (site.location != null && site.location!.isNotEmpty)
                        _DetailRow(label: 'Location', value: site.location!),
                      const SizedBox(height: 8),
                      catalogStatusChip(isActive: site.isActive),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      s.meters,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  if (canManageMeters)
                    TextButton.icon(
                      onPressed: () async {
                        await Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => MeterFormScreen(siteId: site.id),
                          ),
                        );
                        ref.invalidate(siteMetersProvider(siteId));
                        ref.invalidate(adminSitesProvider);
                      },
                      icon: const Icon(Icons.add),
                      label: Text(s.addMeter),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              metersAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => Text(friendlyMeterError(error)),
                data: (meters) {
                  if (meters.isEmpty) {
                    return CatalogEmptyState(
                      title: s.isAr ? 'لا توجد عدادات' : 'No meters',
                      message: s.isAr
                          ? 'لا توجد عدادات في هذا الموقع بعد.'
                          : 'This site has no meters yet.',
                      icon: Icons.speed_outlined,
                    );
                  }

                  return Column(
                    children: [
                      for (final meter in meters)
                        Card(
                          child: ListTile(
                            title: Text(meter.nameEn),
                            subtitle: Text(
                              '${meter.meterCode} · ${meter.categoryConfig?.nameEn ?? meter.categoryCode}',
                            ),
                            trailing: catalogStatusChip(
                              isActive: meter.isActive,
                            ),
                            onTap: () async {
                              await Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) =>
                                      MeterDetailScreen(meterId: meter.id),
                                ),
                              );
                              ref.invalidate(siteMetersProvider(siteId));
                            },
                          ),
                        ),
                    ],
                  );
                },
              ),
              if (canEdit) ...[
                const SizedBox(height: 24),
                OutlinedButton.icon(
                  onPressed: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => SiteFormScreen(site: site),
                      ),
                    );
                    ref.invalidate(adminSiteProvider(siteId));
                    ref.invalidate(adminSitesProvider);
                  },
                  icon: const Icon(Icons.edit),
                  label: const Text('Edit site'),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 88,
            child: Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.grey.shade700),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
