import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_meters_core/smart_meters_core.dart';

import '../l10n/admin_strings.dart';
import '../providers/admin_providers.dart';
import '../providers/policy_providers.dart';
import '../providers/preferences_providers.dart';
import '../widgets/catalog_widgets.dart';
import '../widgets/scoped_report_logo_editor.dart';
import 'meter_detail_screen.dart';
import 'meter_form_screen.dart';
import 'site_cop_groups_screen.dart';
import 'sites_tab.dart';
import 'targets_admin_screen.dart';
import 'baselines_admin_screen.dart';
import 'virtual_meters_admin_screen.dart';
import 'balance_groups_admin_screen.dart';
import 'site_conservation_profile_admin_screen.dart';
import 'opportunities_admin_screen.dart';
import 'actions_admin_screen.dart';
import 'mv_admin_screen.dart';
import 'tariffs_admin_screen.dart';
import 'portfolio_conservation_screen.dart';

final _siteConservationTargetsUiProvider =
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
    flagKey: ConservationFeatureFlags.targets,
    siteId: siteId,
  );
});

final _siteConservationBaselinesUiProvider =
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
    flagKey: ConservationFeatureFlags.baseline,
    siteId: siteId,
  );
});

final _siteConservationVirtualMetersUiProvider =
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
    flagKey: ConservationFeatureFlags.virtualMeters,
    siteId: siteId,
  );
});

final _siteConservationBalanceGroupsUiProvider =
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
  final water = await flags.isEnabled(
    organizationId: site.organizationId,
    flagKey: ConservationFeatureFlags.waterBalance,
    siteId: siteId,
  );
  if (water) return true;
  return flags.isEnabled(
    organizationId: site.organizationId,
    flagKey: ConservationFeatureFlags.energyBalance,
    siteId: siteId,
  );
});

final _siteConservationProfileUiProvider =
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
  final benchmarking = await flags.isEnabled(
    organizationId: site.organizationId,
    flagKey: ConservationFeatureFlags.benchmarking,
    siteId: siteId,
  );
  if (benchmarking) return true;
  return flags.isEnabled(
    organizationId: site.organizationId,
    flagKey: ConservationFeatureFlags.intensity,
    siteId: siteId,
  );
});

final _siteConservationOpportunitiesUiProvider =
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
    flagKey: ConservationFeatureFlags.opportunities,
    siteId: siteId,
  );
});

final _siteConservationActionsUiProvider =
    FutureProvider.autoDispose.family<bool, String>((ref, siteId) async {
  final opportunitiesOn =
      await ref.watch(_siteConservationOpportunitiesUiProvider(siteId).future);
  if (!opportunitiesOn) return false;
  final site = await ref.watch(adminSiteProvider(siteId).future);
  final flags = ConservationFeatureFlagRepository(
    ref.read(supabaseClientProvider),
  );
  return flags.isEnabled(
    organizationId: site.organizationId,
    flagKey: ConservationFeatureFlags.actions,
    siteId: siteId,
  );
});

final _siteConservationMvUiProvider =
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
  final estimation = await flags.isEnabled(
    organizationId: site.organizationId,
    flagKey: ConservationFeatureFlags.savingsEstimation,
    siteId: siteId,
  );
  if (estimation) return true;
  return flags.isEnabled(
    organizationId: site.organizationId,
    flagKey: ConservationFeatureFlags.savingsVerification,
    siteId: siteId,
  );
});

final _siteConservationTariffsUiProvider =
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

final _siteConservationPortfolioUiProvider =
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
    flagKey: ConservationFeatureFlags.portfolioOptimization,
    siteId: siteId,
  );
});

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
              if (canManageMeters)
                OutlinedButton.icon(
                  onPressed: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => SiteCopGroupsScreen(siteId: site.id),
                      ),
                    );
                  },
                  icon: const Icon(Icons.speed_outlined),
                  label: Text(s.copEerGroups),
                ),
              // Conservation targets: link only when module + targets flags ON.
              if (canManageMeters &&
                  (ref
                          .watch(_siteConservationTargetsUiProvider(siteId))
                          .valueOrNull ??
                      false)) ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => TargetsAdminScreen(siteId: site.id),
                      ),
                    );
                  },
                  icon: const Icon(Icons.track_changes_outlined),
                  label: Text(s.conservationTargets),
                ),
              ],
              // Conservation baselines: link only when module + baseline flags ON.
              if (canManageMeters &&
                  (ref
                          .watch(_siteConservationBaselinesUiProvider(siteId))
                          .valueOrNull ??
                      false)) ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => BaselinesAdminScreen(siteId: site.id),
                      ),
                    );
                  },
                  icon: const Icon(Icons.insights_outlined),
                  label: Text(s.conservationBaselines),
                ),
              ],
              // Virtual meters: link only when module + virtual_meters flags ON.
              if (canManageMeters &&
                  (ref
                          .watch(
                            _siteConservationVirtualMetersUiProvider(siteId),
                          )
                          .valueOrNull ??
                      false)) ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            VirtualMetersAdminScreen(siteId: site.id),
                      ),
                    );
                  },
                  icon: const Icon(Icons.account_tree_outlined),
                  label: Text(s.virtualMeters),
                ),
              ],
              // Balance groups: module + water_balance OR energy_balance.
              if (canManageMeters &&
                  (ref
                          .watch(
                            _siteConservationBalanceGroupsUiProvider(siteId),
                          )
                          .valueOrNull ??
                      false)) ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            BalanceGroupsAdminScreen(siteId: site.id),
                      ),
                    );
                  },
                  icon: const Icon(Icons.account_balance_outlined),
                  label: Text(s.balanceGroups),
                ),
              ],
              // Site conservation profile: module + benchmarking OR intensity.
              if (canManageMeters &&
                  (ref
                          .watch(_siteConservationProfileUiProvider(siteId))
                          .valueOrNull ??
                      false)) ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => SiteConservationProfileAdminScreen(
                          siteId: site.id,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.apartment_outlined),
                  label: Text(s.siteConservationProfile),
                ),
              ],
              // Opportunities: module + opportunities.
              if (canManageMeters &&
                  (ref
                          .watch(
                            _siteConservationOpportunitiesUiProvider(siteId),
                          )
                          .valueOrNull ??
                      false)) ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            OpportunitiesAdminScreen(siteId: site.id),
                      ),
                    );
                  },
                  icon: const Icon(Icons.lightbulb_outline),
                  label: Text(s.conservationOpportunities),
                ),
              ],
              // Actions: module + opportunities + actions.
              if (canManageMeters &&
                  (ref
                          .watch(_siteConservationActionsUiProvider(siteId))
                          .valueOrNull ??
                      false)) ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => ActionsAdminScreen(siteId: site.id),
                      ),
                    );
                  },
                  icon: const Icon(Icons.task_alt_outlined),
                  label: Text(s.conservationActions),
                ),
              ],
              // M&V: module + savings_estimation OR savings_verification.
              if (canManageMeters &&
                  (ref
                          .watch(_siteConservationMvUiProvider(siteId))
                          .valueOrNull ??
                      false)) ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => MvAdminScreen(siteId: site.id),
                      ),
                    );
                  },
                  icon: const Icon(Icons.verified_outlined),
                  label: Text(s.measurementVerification),
                ),
              ],
              // Tariffs: module + cost_roi.
              if (canManageMeters &&
                  (ref
                          .watch(_siteConservationTariffsUiProvider(siteId))
                          .valueOrNull ??
                      false)) ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => TariffsAdminScreen(siteId: site.id),
                      ),
                    );
                  },
                  icon: const Icon(Icons.payments_outlined),
                  label: Text(s.utilityTariffs),
                ),
              ],
              // Portfolio: module + portfolio_optimization (org-level screen).
              if (canManageMeters &&
                  (ref
                          .watch(_siteConservationPortfolioUiProvider(siteId))
                          .valueOrNull ??
                      false)) ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => PortfolioConservationScreen(
                          organizationId: site.organizationId,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.account_tree_outlined),
                  label: Text(s.conservationPortfolio),
                ),
              ],
              if (ref.watch(canEditReportLogoSecondaryProvider)) ...[
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: ScopedReportLogoEditor(
                      organizationId: site.organizationId,
                      storageKey: 'sites/${site.id}.png',
                      title: s.isAr
                          ? 'شعار الموقع (أعلى اليسار)'
                          : 'Site logo (top-left)',
                      subtitle: s.isAr
                          ? 'يظهر في تقارير هذا الموقع فقط. إن فُرغ يُستخدم شعار المنطقة ثم شعار الجهة.'
                          : 'Shown on this site’s reports. If empty, zone then org logo is used.',
                      storagePath: site.reportLogoPath,
                      canEdit: true,
                      onPathChanged: (path) async {
                        try {
                          await ref
                              .read(siteRepositoryProvider)
                              .updateSiteReportLogo(
                                siteId: site.id,
                                reportLogoPath: path,
                              );
                          ref.invalidate(adminSiteProvider(siteId));
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                path == null
                                    ? (s.isAr ? 'تم مسح الشعار' : 'Logo cleared')
                                    : (s.isAr
                                        ? 'تم حفظ شعار الموقع'
                                        : 'Site logo saved'),
                              ),
                            ),
                          );
                        } catch (error) {
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('$error')),
                          );
                        }
                      },
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 8),
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
