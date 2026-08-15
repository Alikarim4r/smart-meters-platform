import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_meters_core/smart_meters_core.dart';

import '../l10n/admin_strings.dart';
import '../providers/admin_providers.dart';
import '../providers/preferences_providers.dart';
import '../widgets/catalog_widgets.dart';

final _siteTariffsUiEnabledProvider =
    FutureProvider.autoDispose.family<bool, String>((ref, siteId) async {
  final site = await ref.watch(adminSiteProvider(siteId).future);
  final flags = ConservationFeatureFlagRepository(
    ref.read(supabaseClientProvider),
  );
  final module = await flags.isEnabled(
    organizationId: site.organizationId,
    flagKey: ConservationFeatureFlags.conservationModule,
    siteId: siteId,
  );
  if (!module) return false;
  return flags.isEnabled(
    organizationId: site.organizationId,
    flagKey: ConservationFeatureFlags.costRoi,
    siteId: siteId,
  );
});

final _orgTariffsProvider =
    FutureProvider.autoDispose.family<List<UtilityTariff>, String>((
  ref,
  siteId,
) async {
  final site = await ref.watch(adminSiteProvider(siteId).future);
  final client = ref.read(supabaseClientProvider);
  final rows = await client
      .from('utility_tariffs')
      .select()
      .eq('organization_id', site.organizationId)
      .order('effective_from', ascending: false);
  return (rows as List)
      .map(
        (e) => UtilityTariff.fromJson(Map<String, dynamic>.from(e as Map)),
      )
      .where((t) => t.siteId == null || t.siteId == siteId)
      .toList();
});

/// CRUD for utility tariffs (QAR default). Gated by module ∧ cost_roi.
class TariffsAdminScreen extends ConsumerWidget {
  const TariffsAdminScreen({super.key, required this.siteId});

  final String siteId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AdminStrings(ref.watch(adminLocaleProvider));
    final enabledAsync = ref.watch(_siteTariffsUiEnabledProvider(siteId));
    final canManage = ref.watch(canManageMetersProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(s.isAr ? 'تعرفة المرافق' : 'Utility tariffs'),
      ),
      floatingActionButton: enabledAsync.maybeWhen(
        data: (on) => on && canManage
            ? FloatingActionButton.extended(
                onPressed: () => _createTariff(context, ref),
                icon: const Icon(Icons.add),
                label: Text(s.isAr ? 'تعرفة' : 'Add tariff'),
              )
            : null,
        orElse: () => null,
      ),
      body: enabledAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => CatalogErrorView(
          message: e.toString(),
          onRetry: () => ref.invalidate(_siteTariffsUiEnabledProvider(siteId)),
        ),
        data: (enabled) {
          if (!enabled) {
            return CatalogEmptyState(
              title: s.isAr ? 'التعرفة غير مفعّلة' : 'Tariffs disabled',
              message: s.isAr
                  ? 'فعّل conservation_module و cost_roi.'
                  : 'Enable conservation_module and cost_roi.',
              icon: Icons.flag_outlined,
            );
          }
          final listAsync = ref.watch(_orgTariffsProvider(siteId));
          return listAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => CatalogErrorView(
              message: e.toString(),
              onRetry: () => ref.invalidate(_orgTariffsProvider(siteId)),
            ),
            data: (rows) {
              if (rows.isEmpty) {
                return CatalogEmptyState(
                  title: s.isAr ? 'لا تعرفات' : 'No tariffs',
                  message: s.isAr
                      ? 'أضف تعرفة فعّالة (افتراضي QAR). بدون تعرفة يكون Cost Avoided = N/A.'
                      : 'Add an effective tariff (QAR default). Missing tariff → Cost Avoided N/A.',
                  icon: Icons.payments_outlined,
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: rows.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final t = rows[index];
                  return Card(
                    child: ListTile(
                      title: Text(
                        '${t.utilityType} · ${t.rate} ${t.currency}/${t.unitCode}',
                      ),
                      subtitle: Text(
                        'Status: ${t.status.dbValue}\n'
                        'Effective: ${_iso(t.effectiveFrom)}'
                        '${t.effectiveTo == null ? '' : ' → ${_iso(t.effectiveTo!)}'}\n'
                        'Scope: ${t.siteId == null ? 'organization-wide' : 'site-specific'}'
                        '${t.sourceNotes == null ? '' : '\n${t.sourceNotes}'}',
                      ),
                      isThreeLine: true,
                      trailing: canManage &&
                              t.status == UtilityTariffStatus.active
                          ? IconButton(
                              tooltip: 'Supersede',
                              icon: const Icon(Icons.archive_outlined),
                              onPressed: () => _supersede(context, ref, t),
                            )
                          : null,
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _createTariff(BuildContext context, WidgetRef ref) async {
    final site = await ref.read(adminSiteProvider(siteId).future);
    if (!context.mounted) return;
    final utilityCtrl = TextEditingController(text: 'water');
    final rateCtrl = TextEditingController();
    final unitCtrl = TextEditingController(text: 'm3');
    final fromCtrl = TextEditingController(
      text: _iso(DateTime.now()),
    );
    final toCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    var siteSpecific = true;
    var currency = 'QAR';

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setState) {
            return AlertDialog(
              title: const Text('Add utility tariff'),
              content: SingleChildScrollView(
                child: SizedBox(
                  width: 400,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: utilityCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Utility type (water/electricity/…)',
                        ),
                      ),
                      TextField(
                        controller: rateCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Rate (must be > 0)',
                        ),
                        keyboardType: TextInputType.number,
                      ),
                      TextField(
                        controller: unitCtrl,
                        decoration:
                            const InputDecoration(labelText: 'Unit code'),
                      ),
                      DropdownButtonFormField<String>(
                        initialValue: currency,
                        decoration:
                            const InputDecoration(labelText: 'Currency'),
                        items: const [
                          DropdownMenuItem(value: 'QAR', child: Text('QAR')),
                          DropdownMenuItem(value: 'USD', child: Text('USD')),
                          DropdownMenuItem(value: 'EUR', child: Text('EUR')),
                        ],
                        onChanged: (v) {
                          if (v != null) setState(() => currency = v);
                        },
                      ),
                      TextField(
                        controller: fromCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Effective from (YYYY-MM-DD)',
                        ),
                      ),
                      TextField(
                        controller: toCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Effective to (optional)',
                        ),
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Site-specific'),
                        subtitle: const Text(
                          'Off = organization-wide tariff',
                        ),
                        value: siteSpecific,
                        onChanged: (v) => setState(() => siteSpecific = v),
                      ),
                      TextField(
                        controller: notesCtrl,
                        decoration:
                            const InputDecoration(labelText: 'Source notes'),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Create'),
                ),
              ],
            );
          },
        );
      },
    );

    if (ok != true || !context.mounted) return;
    try {
      final client = ref.read(supabaseClientProvider);
      await UtilityTariffRepository(client).create(
        organizationId: site.organizationId,
        utilityType: utilityCtrl.text.trim(),
        rate: double.parse(rateCtrl.text.trim()),
        unitCode: unitCtrl.text.trim(),
        effectiveFrom: DateTime.parse(fromCtrl.text.trim()),
        currency: currency,
        siteId: siteSpecific ? siteId : null,
        effectiveTo: toCtrl.text.trim().isEmpty
            ? null
            : DateTime.parse(toCtrl.text.trim()),
        sourceNotes:
            notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
        createdBy: client.auth.currentUser?.id,
      );
      ref.invalidate(_orgTariffsProvider(siteId));
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tariff created')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _supersede(
    BuildContext context,
    WidgetRef ref,
    UtilityTariff tariff,
  ) async {
    final toCtrl = TextEditingController(text: _iso(DateTime.now()));
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supersede tariff'),
        content: TextField(
          controller: toCtrl,
          decoration: const InputDecoration(
            labelText: 'Effective to (YYYY-MM-DD)',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Supersede'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    try {
      await UtilityTariffRepository(ref.read(supabaseClientProvider))
          .supersede(
        id: tariff.id,
        effectiveTo: DateTime.parse(toCtrl.text.trim()),
      );
      ref.invalidate(_orgTariffsProvider(siteId));
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tariff superseded')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  static String _iso(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}
