import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_meters_core/smart_meters_core.dart';

import '../providers/admin_providers.dart';
import '../widgets/catalog_widgets.dart';
import 'meter_form_screen.dart';

class MeterDetailScreen extends ConsumerWidget {
  const MeterDetailScreen({super.key, required this.meterId});

  final String meterId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final meterAsync = ref.watch(adminMeterProvider(meterId));
    final readingsAsync = ref.watch(meterHasReadingsProvider(meterId));
    final canManage = ref.watch(canManageMetersProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Meter details')),
      body: meterAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => CatalogErrorView(
          message: friendlyMeterError(error),
          onRetry: () => ref.invalidate(adminMeterProvider(meterId)),
        ),
        data: (meter) {
          final hasReadings = readingsAsync.value ?? false;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (hasReadings)
                Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  color: Colors.amber.shade50,
                  child: const ListTile(
                    leading: Icon(Icons.lock_outline),
                    title: Text('Meter has readings'),
                    subtitle: Text(
                      'This meter has readings. Category and unit cannot be changed.',
                    ),
                  ),
                ),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        meter.nameEn,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      if (meter.nameAr.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(meter.nameAr),
                      ],
                      const SizedBox(height: 12),
                      _DetailRow(label: 'Code', value: meter.meterCode),
                      _DetailRow(
                        label: 'Site',
                        value: meter.siteNameEn ?? meter.siteId,
                      ),
                      _DetailRow(
                        label: 'Category',
                        value:
                            meter.categoryConfig?.nameEn ?? meter.categoryCode,
                      ),
                      _DetailRow(
                        label: 'Source',
                        value:
                            meter.sourceConfig?.nameEn ??
                            meter.sourceDisplayName,
                      ),
                      _DetailRow(
                        label: 'Unit',
                        value:
                            meter.unitConfig?.nameEn ?? meter.unitDisplayLabel,
                      ),
                      _DetailRow(
                        label: 'Multiplier',
                        value: '${meter.meterMultiplier}',
                      ),
                      _DetailRow(
                        label: 'Sort order',
                        value: '${meter.sortOrder}',
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          catalogStatusChip(isActive: meter.isActive),
                          if (meter.includeInDashboard)
                            catalogTypeChip(
                              label: 'Dashboard',
                              icon: Icons.dashboard_outlined,
                              color: Colors.teal,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              if (canManage) ...[
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            MeterFormScreen(siteId: meter.siteId, meter: meter),
                      ),
                    );
                    ref.invalidate(adminMeterProvider(meterId));
                    ref.invalidate(adminMetersProvider);
                  },
                  icon: const Icon(Icons.edit),
                  label: const Text('Edit meter'),
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
            width: 96,
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
