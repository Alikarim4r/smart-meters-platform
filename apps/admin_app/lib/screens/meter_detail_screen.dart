import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_meters_core/smart_meters_core.dart';

import '../l10n/admin_strings.dart';
import '../providers/admin_providers.dart';
import '../providers/preferences_providers.dart';
import '../widgets/catalog_widgets.dart';
import 'meter_form_screen.dart';

class MeterDetailScreen extends ConsumerWidget {
  const MeterDetailScreen({super.key, required this.meterId});

  final String meterId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AdminStrings(ref.watch(adminLocaleProvider));
    final meterAsync = ref.watch(adminMeterProvider(meterId));
    final readingsAsync = ref.watch(meterHasReadingsProvider(meterId));
    final canManage = ref.watch(canManageMetersProvider);

    return Scaffold(
      appBar: AppBar(title: Text(s.meterDetails)),
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
                  child: ListTile(
                    leading: const Icon(Icons.lock_outline),
                    title: Text(s.meterHasReadings),
                    subtitle: Text(s.meterHasReadingsHint),
                  ),
                ),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.isAr && meter.nameAr.isNotEmpty
                            ? meter.nameAr
                            : meter.nameEn,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      if (meter.nameAr.isNotEmpty && !s.isAr) ...[
                        const SizedBox(height: 4),
                        Text(meter.nameAr),
                      ],
                      if (meter.nameEn.isNotEmpty && s.isAr) ...[
                        const SizedBox(height: 4),
                        Text(meter.nameEn),
                      ],
                      const SizedBox(height: 12),
                      _DetailRow(label: s.code, value: meter.meterCode),
                      _DetailRow(
                        label: s.site,
                        value: meter.siteNameEn ?? meter.siteId,
                      ),
                      _DetailRow(
                        label: s.category,
                        value:
                            meter.categoryConfig?.nameEn ?? meter.categoryCode,
                      ),
                      _DetailRow(
                        label: s.source,
                        value:
                            meter.sourceConfig?.nameEn ??
                            meter.sourceDisplayName,
                      ),
                      _DetailRow(
                        label: s.unit,
                        value:
                            meter.unitConfig?.nameEn ?? meter.unitDisplayLabel,
                      ),
                      _DetailRow(
                        label: s.isAr ? 'المعامل' : 'Multiplier',
                        value: '${meter.meterMultiplier}',
                      ),
                      _DetailRow(
                        label: s.sortOrder,
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
                              label: s.isAr ? 'العرض' : 'Dashboard',
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
                  label: Text(s.editMeter),
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
