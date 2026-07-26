import 'package:flutter/material.dart';

import '../../l10n/app_strings.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_meters_core/smart_meters_core.dart';

import '../../providers/chart_providers.dart';
import '../../providers/dashboard_providers.dart';
import '../../utils/dashboard_breakpoints.dart';
import '../../utils/site_system_navigation.dart';
import '../chart_widgets.dart';
import '../dashboard_widgets.dart';
import '../premium/premium_section_header.dart';
import '../premium/premium_stat_card.dart';
import '../premium/responsive_grid.dart';

/// Operational site summary — counts and completion only; no mixed-unit charts.
class SiteOverviewPanel extends ConsumerWidget {
  const SiteOverviewPanel({
    super.key,
    required this.siteId,
    required this.summary,
    required this.useDesktop,
    required this.onOpenAlerts,
    required this.onOpenSystem,
  });

  final String siteId;
  final SiteDashboardSummary summary;
  final bool useDesktop;
  final VoidCallback onOpenAlerts;
  final ValueChanged<SiteDashboardSection> onOpenSystem;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppStrings.of(context);
    final padding = DashboardBreakpoints.contentPadding(context);
    final categoriesAsync = ref.watch(siteCategoriesSummaryProvider(siteId));
    final completionAsync = ref.watch(siteTodayCompletionProvider(siteId));

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(siteCategoriesSummaryProvider(siteId));
        ref.invalidate(siteTodayCompletionProvider(siteId));
      },
      child: ListView(
        padding: EdgeInsets.all(padding),
        children: [
          PremiumSectionHeader(
            title: s.isAr ? 'نظرة تشغيلية عامة' : 'Operational overview',
            subtitle: s.isAr
                ? 'الأعداد ونسب الإنجاز حسب نظام المرفق — اتجاهات الاستهلاك في شاشة كل نظام.'
                : 'Counts and completion by utility system — consumption trends are on each system screen.',
          ),
          categoriesAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => DashboardErrorState(message: '$e'),
            data: (categories) {
              final systemCards = <Widget>[
                for (final system in UtilitySystemKey.values)
                  _SystemStatusCard(
                    system: system,
                    summary: categorySummaryForUtility(categories, system),
                    onTap: () => onOpenSystem(
                      switch (system) {
                        UtilitySystemKey.water =>
                          SiteDashboardSection.water,
                        UtilitySystemKey.electricity =>
                          SiteDashboardSection.electricity,
                        UtilitySystemKey.btu =>
                          SiteDashboardSection.btuCooling,
                        UtilitySystemKey.fuel => SiteDashboardSection.fuel,
                      },
                    ),
                  ),
              ];

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ResponsiveGrid(
                    minItemWidth: useDesktop ? 200 : 160,
                    childHeight: 150,
                    children: systemCards,
                  ),
                  const SizedBox(height: 16),
                  if (useDesktop)
                    ResponsiveSplitRow(
                      left: DashboardChartCard(
                        title: s.isAr ? 'إنجاز اليوم (كل الأنظمة)' : 'Today completion (all systems)',
                        subtitle: 'Comparable percentage across meters',
                        height: 280,
                        child: completionAsync.when(
                          loading: () => const ChartLoadingPlaceholder(),
                          error: (e, _) => ChartErrorPlaceholder(message: '$e'),
                          data: (progress) => CompletionDonutChart(
                            submitted: progress.submitted,
                            pending: progress.pending,
                            total: progress.total,
                          ),
                        ),
                      ),
                      right: DashboardCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              s.isAr ? 'القراءات المعلّقة حسب النظام' : 'Pending readings by system',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 12),
                            for (final system in UtilitySystemKey.values) ...[
                              _PendingRow(
                                label: s.utilityLabel(system),
                                pending: categorySummaryForUtility(
                                      categories,
                                      system,
                                    )?.pendingToday ??
                                    0,
                                total: categorySummaryForUtility(
                                      categories,
                                      system,
                                    )?.meterCount ??
                                    0,
                                color: system.accent,
                              ),
                              const SizedBox(height: 8),
                            ],
                          ],
                        ),
                      ),
                    )
                  else ...[
                    DashboardChartCard(
                      title: s.isAr ? 'إنجاز اليوم (كل الأنظمة)' : 'Today completion (all systems)',
                      height: 220,
                      child: completionAsync.when(
                        loading: () => const ChartLoadingPlaceholder(),
                        error: (e, _) => ChartErrorPlaceholder(message: '$e'),
                        data: (progress) => CompletionDonutChart(
                          submitted: progress.submitted,
                          pending: progress.pending,
                          total: progress.total,
                        ),
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _SystemStatusCard extends StatelessWidget {
  const _SystemStatusCard({
    required this.system,
    required this.summary,
    required this.onTap,
  });

  final UtilitySystemKey system;
  final SiteCategorySummary? summary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final meters = summary?.meterCount ?? 0;
    final submitted = summary?.readingsSubmittedToday ?? 0;
    final pending = summary?.pendingToday ?? 0;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: PremiumStatCard(
        icon: switch (system) {
          UtilitySystemKey.water => Icons.water_drop_outlined,
          UtilitySystemKey.electricity => Icons.bolt_outlined,
          UtilitySystemKey.btu => Icons.ac_unit_outlined,
          UtilitySystemKey.fuel => Icons.local_gas_station_outlined,
        },
        label: s.isAr
            ? 'عدادات ${s.utilityLabel(system)}'
            : '${system.label} meters',
        value: '$meters',
        subtitle: s.isAr
            ? '$submitted مُسجَّل · $pending معلّق'
            : '$submitted submitted · $pending pending',
        accent: system.accent,
      ),
    );
  }
}

class _PendingRow extends StatelessWidget {
  const _PendingRow({
    required this.label,
    required this.pending,
    required this.total,
    required this.color,
  });

  final String label;
  final int pending;
  final int total;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final pct = total == 0 ? 0.0 : pending / total;
    return Row(
      children: [
        SizedBox(
          width: 88,
          child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: pct.clamp(0, 1),
              minHeight: 8,
              backgroundColor: color.withValues(alpha: 0.12),
              color: color,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text('$pending/$total', style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
