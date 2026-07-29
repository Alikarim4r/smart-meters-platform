import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/conservation_providers.dart';
import '../conservation/actual_vs_baseline_card.dart';
import '../conservation/actual_vs_target_card.dart';
import '../conservation/anomaly_card.dart';
import '../conservation/balance_difference_card.dart';
import '../conservation/balance_hierarchy_view.dart';
import '../conservation/benchmark_card.dart';
import '../conservation/period_comparison_cards.dart';

/// Gated Conservation section.
/// Visible when module + any P1/P2 child flag is ON.
class SiteConservationPanel extends ConsumerWidget {
  const SiteConservationPanel({
    super.key,
    required this.siteId,
    required this.useDesktop,
  });

  final String siteId;
  final bool useDesktop;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visibleAsync =
        ref.watch(conservationSectionVisibleProvider(siteId));
    return visibleAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e')),
      data: (visible) {
        if (!visible) return const SizedBox.shrink();

        final periodOn = ref
                .watch(conservationPeriodCompareEnabledProvider(siteId))
                .valueOrNull ??
            false;
        final targetsOn = ref
                .watch(conservationTargetsEnabledProvider(siteId))
                .valueOrNull ??
            false;
        final baselineOn = ref
                .watch(conservationBaselineEnabledProvider(siteId))
                .valueOrNull ??
            false;
        final virtualOn = ref
                .watch(conservationVirtualMetersEnabledProvider(siteId))
                .valueOrNull ??
            false;
        final waterBalanceOn = ref
                .watch(conservationWaterBalanceEnabledProvider(siteId))
                .valueOrNull ??
            false;
        final energyBalanceOn = ref
                .watch(conservationEnergyBalanceEnabledProvider(siteId))
                .valueOrNull ??
            false;
        final benchmarkingOn = ref
                .watch(conservationBenchmarkingEnabledProvider(siteId))
                .valueOrNull ??
            false;
        final intensityOn = ref
                .watch(conservationIntensityEnabledProvider(siteId))
                .valueOrNull ??
            false;
        final anomaliesOn = ref
                .watch(conservationPeriodicAnomaliesEnabledProvider(siteId))
                .valueOrNull ??
            false;
        final copOn = ref
                .watch(conservationCopConservationEnabledProvider(siteId))
                .valueOrNull ??
            false;

        return ListView(
          padding: EdgeInsets.all(useDesktop ? 20 : 12),
          children: [
            const Text(
              'Conservation',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            const Text(
              'Derived metrics only. Gaps are Above/Below Target or Baseline — not Saving.',
              style: TextStyle(fontSize: 12),
            ),
            if (periodOn) ...[
              const SizedBox(height: 16),
              const Text(
                'Period comparisons',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              _PeriodSection(siteId: siteId),
            ],
            if (targetsOn) ...[
              const SizedBox(height: 16),
              const Text(
                'Actual vs Target',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              _TargetsSection(siteId: siteId),
            ],
            if (baselineOn) ...[
              const SizedBox(height: 16),
              const Text(
                'Actual vs Baseline',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              _BaselinesSection(siteId: siteId),
            ],
            if (virtualOn) ...[
              const SizedBox(height: 16),
              const Text(
                'Virtual meters (preview)',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              _VirtualSection(siteId: siteId),
            ],
            if (waterBalanceOn || energyBalanceOn) ...[
              const SizedBox(height: 16),
              Text(
                waterBalanceOn && energyBalanceOn
                    ? 'Water & Energy Balance'
                    : waterBalanceOn
                        ? 'Water Balance'
                        : 'Energy Balance',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              _BalanceSection(
                siteId: siteId,
                waterOn: waterBalanceOn,
                energyOn: energyBalanceOn,
              ),
            ],
            if (benchmarkingOn || intensityOn) ...[
              const SizedBox(height: 16),
              const Text(
                'Benchmark',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              _BenchmarkSection(siteId: siteId),
            ],
            if (anomaliesOn || copOn) ...[
              const SizedBox(height: 16),
              Text(
                anomaliesOn && copOn
                    ? 'Anomalies & COP trend'
                    : anomaliesOn
                        ? 'Anomalies'
                        : 'COP trend',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              if (copOn) ...[
                const SizedBox(height: 4),
                const Text(
                  'COP trend uses existing dashboard COP values — formulas unchanged.',
                  style: TextStyle(fontSize: 11),
                ),
              ],
              const SizedBox(height: 8),
              _AnomaliesSection(siteId: siteId),
            ],
          ],
        );
      },
    );
  }
}

class _PeriodSection extends ConsumerWidget {
  const _PeriodSection({required this.siteId});
  final String siteId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(conservationPeriodComparisonsProvider(siteId));
    return async.when(
      loading: () => const LinearProgressIndicator(),
      error: (e, _) => Text('$e'),
      data: (bundles) {
        if (bundles.isEmpty) {
          return const Text('No utility meters available for period comparison.');
        }
        return Column(
          children: [
            for (final b in bundles) ...[
              PeriodComparisonCard(
                title: 'Previous period',
                utilityLabel: b.utilityLabel,
                result: b.previous,
              ),
              const SizedBox(height: 8),
              PeriodComparisonCard(
                title: 'Compared with same period last year',
                utilityLabel: b.utilityLabel,
                result: b.yoy,
              ),
              const SizedBox(height: 12),
            ],
          ],
        );
      },
    );
  }
}

class _TargetsSection extends ConsumerWidget {
  const _TargetsSection({required this.siteId});
  final String siteId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(conservationActualVsTargetProvider(siteId));
    return async.when(
      loading: () => const LinearProgressIndicator(),
      error: (e, _) => Text('$e'),
      data: (results) {
        if (results.isEmpty) {
          return const Text('No active targets for this site.');
        }
        return Column(
          children: [
            for (final r in results) ...[
              ActualVsTargetCard(result: r),
              const SizedBox(height: 8),
            ],
          ],
        );
      },
    );
  }
}

class _BaselinesSection extends ConsumerWidget {
  const _BaselinesSection({required this.siteId});
  final String siteId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(conservationActualVsBaselineProvider(siteId));
    return async.when(
      loading: () => const LinearProgressIndicator(),
      error: (e, _) => Text('$e'),
      data: (results) {
        if (results.isEmpty) {
          return const Text('No approved baselines for this site.');
        }
        return Column(
          children: [
            for (final r in results) ...[
              ActualVsBaselineCard(result: r),
              const SizedBox(height: 8),
            ],
          ],
        );
      },
    );
  }
}

class _VirtualSection extends ConsumerWidget {
  const _VirtualSection({required this.siteId});
  final String siteId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(conservationVirtualMeterPreviewsProvider(siteId));
    return async.when(
      loading: () => const LinearProgressIndicator(),
      error: (e, _) => Text('$e'),
      data: (results) {
        if (results.isEmpty) {
          return const Text('No virtual meters configured for this site.');
        }
        return Column(
          children: [
            for (final r in results) ...[
              Card(
                child: ListTile(
                  title: Text(r.directionLabel),
                  subtitle: Text(
                    '${r.isInsufficient ? 'Insufficient Data' : (r.value?.toStringAsFixed(1) ?? 'N/A')} '
                    '${r.unitCode}\n'
                    'Confidence ${r.confidenceScore} · '
                    'Completeness ${(r.completeness * 100).toStringAsFixed(0)}%\n'
                    '${r.warnings.isEmpty ? 'Residual/Balance Difference only — not Leak.' : r.warnings.join(' · ')}',
                  ),
                  isThreeLine: true,
                ),
              ),
              const SizedBox(height: 8),
            ],
          ],
        );
      },
    );
  }
}

class _BalanceSection extends ConsumerWidget {
  const _BalanceSection({
    required this.siteId,
    required this.waterOn,
    required this.energyOn,
  });

  final String siteId;
  final bool waterOn;
  final bool energyOn;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(conservationBalanceResultsProvider(siteId));
    return async.when(
      loading: () => const LinearProgressIndicator(),
      error: (e, _) => Text('$e'),
      data: (bundles) {
        final filtered = [
          for (final b in bundles)
            if ((b.group.utilityCode.toLowerCase() == 'water' && waterOn) ||
                (b.group.utilityCode.toLowerCase() == 'electricity' &&
                    energyOn))
              b,
        ];
        if (filtered.isEmpty) {
          return const Text('No active balance groups for this site.');
        }
        return Column(
          children: [
            for (final b in filtered) ...[
              BalanceDifferenceCard(
                groupName: b.group.name,
                result: b.result,
                mainMeterName: b.meterNamesById[b.result.mainMeterId],
                submeterNames: [
                  for (final id in b.result.childMeterIds)
                    b.meterNamesById[id] ?? id,
                ],
              ),
              const SizedBox(height: 8),
              BalanceHierarchyView(
                result: b.result,
                mainMeterName: b.meterNamesById[b.result.mainMeterId],
                submeterNames: [
                  for (final id in b.result.childMeterIds)
                    b.meterNamesById[id] ?? id,
                ],
              ),
              const SizedBox(height: 12),
            ],
          ],
        );
      },
    );
  }
}

class _BenchmarkSection extends ConsumerWidget {
  const _BenchmarkSection({required this.siteId});
  final String siteId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(conservationBenchmarkProvider(siteId));
    return async.when(
      loading: () => const LinearProgressIndicator(),
      error: (e, _) => Text('$e'),
      data: (bundles) {
        if (bundles.isEmpty) {
          return const Text('No water/electricity totals for benchmark.');
        }
        return Column(
          children: [
            for (final b in bundles) ...[
              BenchmarkCard(bundle: b),
              const SizedBox(height: 8),
            ],
          ],
        );
      },
    );
  }
}

class _AnomaliesSection extends ConsumerWidget {
  const _AnomaliesSection({required this.siteId});
  final String siteId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(conservationAnomaliesProvider(siteId));
    return async.when(
      loading: () => const LinearProgressIndicator(),
      error: (e, _) => Text('$e'),
      data: (bundles) {
        if (bundles.isEmpty) {
          return const Text('No anomaly signals for this period.');
        }
        return Column(
          children: [
            for (final b in bundles) ...[
              AnomalyCard(
                title: b.title,
                result: b.result,
                unitCode: b.unitCode,
              ),
              const SizedBox(height: 8),
            ],
          ],
        );
      },
    );
  }
}
