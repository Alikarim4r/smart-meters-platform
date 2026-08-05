import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_meters_core/smart_meters_core.dart';

import '../../l10n/conservation_strings.dart';
import '../../providers/conservation_providers.dart';
import '../conservation/actual_vs_baseline_card.dart';
import '../conservation/actual_vs_target_card.dart';
import '../conservation/advanced_conservation_tabs.dart';
import '../conservation/anomaly_card.dart';
import '../conservation/balance_difference_card.dart';
import '../conservation/balance_hierarchy_view.dart';
import '../conservation/benchmark_card.dart';
import '../conservation/conservation_trends_section.dart';
import '../conservation/mv_summary_strip.dart';
import '../conservation/mv_verification_card.dart';
import '../conservation/opportunity_list_panel.dart';
import '../conservation/period_comparison_cards.dart';

/// Gated Conservation section.
/// Visible when module + any P1–P5 child flag is ON.
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
    final s = ConservationStrings.of(context);
    final visibleAsync =
        ref.watch(conservationSectionVisibleProvider(siteId));
    return visibleAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text(s.friendlyLoadError(e))),
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
        final opportunitiesOn = ref
                .watch(conservationOpportunitiesEnabledProvider(siteId))
                .valueOrNull ??
            false;
        final investigationsOn = ref
                .watch(conservationInvestigationsEnabledProvider(siteId))
                .valueOrNull ??
            false;
        final estimationOn = ref
                .watch(conservationSavingsEstimationEnabledProvider(siteId))
                .valueOrNull ??
            false;
        final verificationOn = ref
                .watch(conservationSavingsVerificationEnabledProvider(siteId))
                .valueOrNull ??
            false;
        final costRoiOn = ref
                .watch(conservationCostRoiEnabledProvider(siteId))
                .valueOrNull ??
            false;
        final mvSectionOn = estimationOn || verificationOn;
        final weatherOn = ref
                .watch(conservationWeatherNormalizationEnabledProvider(siteId))
                .valueOrNull ??
            false;
        final occupancyOn = ref
                .watch(
                  conservationOccupancyNormalizationEnabledProvider(siteId),
                )
                .valueOrNull ??
            false;
        final persistenceOn = ref
                .watch(conservationSavingPersistenceEnabledProvider(siteId))
                .valueOrNull ??
            false;
        final carbonOn = ref
                .watch(conservationCarbonAccountingEnabledProvider(siteId))
                .valueOrNull ??
            false;
        final forecastOn = ref
                .watch(conservationForecastingEnabledProvider(siteId))
                .valueOrNull ??
            false;
        final recoOn = ref
                .watch(
                  conservationRecommendationEngineEnabledProvider(siteId),
                )
                .valueOrNull ??
            false;
        final advancedOn = weatherOn ||
            occupancyOn ||
            persistenceOn ||
            carbonOn ||
            forecastOn ||
            recoOn;
        final trendsOn = periodOn ||
            anomaliesOn ||
            copOn ||
            benchmarkingOn ||
            intensityOn ||
            waterBalanceOn ||
            energyBalanceOn;

        final s = ConservationStrings.of(context);

        final tabs = <_ConservationTab>[];
        if (trendsOn) {
          tabs.add(
            _ConservationTab(
              label: s.tabOverview,
              body: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    s.overviewKpiHint,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).hintColor,
                    ),
                  ),
                ),
                _LazyConservationAccordion(
                  title: s.trendsAndCharts,
                  subtitle: s.trendsAndChartsHint,
                  initiallyExpanded: true,
                  child: ConservationTrendsSection(
                    siteId: siteId,
                    useDesktop: useDesktop,
                  ),
                ),
              ],
            ),
          );
        }
        if (periodOn || targetsOn || baselineOn || virtualOn) {
          tabs.add(
            _ConservationTab(
              label: s.tabComparisons,
              body: [
                if (periodOn)
                  _LazyConservationAccordion(
                    title: s.periodComparisons,
                    initiallyExpanded: true,
                    child: _PeriodSection(siteId: siteId),
                  ),
                if (targetsOn)
                  _LazyConservationAccordion(
                    title: s.actualVsTargetTitle,
                    child: _TargetsSection(siteId: siteId),
                  ),
                if (baselineOn)
                  _LazyConservationAccordion(
                    title: s.actualVsBaselineTitle,
                    child: _BaselinesSection(siteId: siteId),
                  ),
                if (virtualOn)
                  _LazyConservationAccordion(
                    title: s.virtualMetersPreview,
                    child: _VirtualSection(siteId: siteId),
                  ),
              ],
            ),
          );
        }
        if (waterBalanceOn || energyBalanceOn) {
          tabs.add(
            _ConservationTab(
              label: s.tabBalance,
              body: [
                _LazyConservationAccordion(
                  title: waterBalanceOn && energyBalanceOn
                      ? s.waterAndEnergyBalance
                      : waterBalanceOn
                          ? s.waterBalance
                          : s.energyBalance,
                  initiallyExpanded: true,
                  child: _BalanceSection(
                    siteId: siteId,
                    waterOn: waterBalanceOn,
                    energyOn: energyBalanceOn,
                  ),
                ),
              ],
            ),
          );
        }
        if (benchmarkingOn || intensityOn || anomaliesOn || copOn ||
            opportunitiesOn) {
          tabs.add(
            _ConservationTab(
              label: s.tabOpportunities,
              body: [
                if (benchmarkingOn || intensityOn)
                  _LazyConservationAccordion(
                    title: s.benchmarking,
                    child: _BenchmarkSection(siteId: siteId),
                  ),
                if (anomaliesOn || copOn)
                  _LazyConservationAccordion(
                    title: anomaliesOn && copOn
                        ? s.anomaliesAndCop
                        : anomaliesOn
                            ? s.anomalies
                            : s.copTrend,
                    subtitle: copOn ? s.copTrendNote : null,
                    initiallyExpanded: true,
                    child: _AnomaliesSection(siteId: siteId),
                  ),
                if (opportunitiesOn)
                  _LazyConservationAccordion(
                    title: s.opportunities,
                    subtitle: s.manualRefreshOnly,
                    trailing: OutlinedButton.icon(
                      onPressed: () => _refreshOpportunities(context, ref),
                      icon: const Icon(Icons.refresh, size: 18),
                      label: Text(s.refreshOpportunities),
                    ),
                    child: _OpportunitiesSection(
                      siteId: siteId,
                      investigationsOn: investigationsOn,
                    ),
                  ),
              ],
            ),
          );
        }
        if (mvSectionOn) {
          tabs.add(
            _ConservationTab(
              label: s.tabMv,
              body: [
                _LazyConservationAccordion(
                  title: s.measurementVerification,
                  subtitle: s.mvDisclaimer,
                  initiallyExpanded: true,
                  child: _MvSection(
                    siteId: siteId,
                    showCostRoi: costRoiOn,
                  ),
                ),
              ],
            ),
          );
        }
        if (advancedOn) {
          tabs.add(
            _ConservationTab(
              label: s.tabAdvanced,
              body: [
                _LazyConservationAccordion(
                  title: s.advancedOnDemand,
                  subtitle: s.advancedHint,
                  initiallyExpanded: true,
                  child: AdvancedConservationTabs(
                    siteId: siteId,
                    weatherOn: weatherOn,
                    occupancyOn: occupancyOn,
                    persistenceOn: persistenceOn,
                    carbonOn: carbonOn,
                    forecastOn: forecastOn,
                    recommendationsOn: recoOn,
                  ),
                ),
              ],
            ),
          );
        }

        if (tabs.isEmpty) {
          return Padding(
            padding: EdgeInsets.all(useDesktop ? 20 : 12),
            child: Text(s.emptyTabSection),
          );
        }

        return DefaultTabController(
          length: tabs.length,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              useDesktop ? 20 : 12,
              useDesktop ? 16 : 10,
              useDesktop ? 20 : 12,
              0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  s.conservation,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  s.derivedMetricsOnly,
                  style: const TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 8),
                TabBar(
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  tabs: [for (final t in tabs) Tab(text: t.label)],
                ),
                const SizedBox(height: 4),
                Text(
                  s.tapToExpandSection,
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).hintColor,
                  ),
                ),
                const SizedBox(height: 4),
                Expanded(
                  child: TabBarView(
                    children: [
                      for (final t in tabs)
                        ListView(
                          padding: const EdgeInsets.only(bottom: 24),
                          children: t.body,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );

      },
    );
  }

  Future<void> _refreshOpportunities(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final s = ConservationStrings.of(context);
    try {
      final result = await refreshConservationOpportunities(ref, siteId);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            s.opportunitiesRefreshResult(
              created: result.generation.created,
              refreshed: result.generation.refreshed,
              candidates: result.candidateCount,
            ),
          ),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.friendlyLoadError(e))),
      );
    }
  }
}

/// Collapsed by default — mounts [child] (and its providers) only when opened.
class _LazyConservationAccordion extends StatefulWidget {
  const _LazyConservationAccordion({
    required this.title,
    required this.child,
    this.subtitle,
    this.trailing,
    this.initiallyExpanded = false,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Widget child;
  final bool initiallyExpanded;

  @override
  State<_LazyConservationAccordion> createState() =>
      _LazyConservationAccordionState();
}

class _LazyConservationAccordionState extends State<_LazyConservationAccordion> {
  late bool _expanded = widget.initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final border = Theme.of(context).dividerColor.withValues(alpha: 0.55);
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Material(
        color: Theme.of(context).cardColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: border),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InkWell(
              onTap: () => setState(() => _expanded = !_expanded),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      _expanded ? Icons.expand_less : Icons.expand_more,
                      size: 24,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.title,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (widget.subtitle != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              widget.subtitle!,
                              style: TextStyle(
                                fontSize: 11,
                                color: Theme.of(context).hintColor,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (widget.trailing != null && _expanded) ...[
                      const SizedBox(width: 8),
                      widget.trailing!,
                    ],
                  ],
                ),
              ),
            ),
            // Lazy mount: providers inside [child] only run when expanded.
            if (_expanded)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: widget.child,
              ),
          ],
        ),
      ),
    );
  }
}

class _ConservationTab {
  const _ConservationTab({required this.label, required this.body});
  final String label;
  final List<Widget> body;
}

class _PeriodSection extends ConsumerWidget {
  const _PeriodSection({required this.siteId});
  final String siteId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ConservationStrings.of(context);
    final async = ref.watch(conservationPeriodComparisonsProvider(siteId));
    return async.when(
      loading: () => const LinearProgressIndicator(),
      error: (e, _) => Text(s.friendlyLoadError(e)),
      data: (bundles) {
        if (bundles.isEmpty) {
          return Text(s.noUtilityMetersPeriod);
        }
        return Column(
          children: [
            for (final b in bundles) ...[
              PeriodComparisonCard(
                title: s.previousPeriod,
                utilityLabel: b.utilityLabel,
                result: b.previous,
              ),
              const SizedBox(height: 8),
              PeriodComparisonCard(
                title: s.comparedWithSamePeriodLastYear,
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
    final s = ConservationStrings.of(context);
    final async = ref.watch(conservationActualVsTargetProvider(siteId));
    return async.when(
      loading: () => const LinearProgressIndicator(),
      error: (e, _) => Text(s.friendlyLoadError(e)),
      data: (results) {
        if (results.isEmpty) {
          return Text(s.noActiveTargets);
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
    final s = ConservationStrings.of(context);
    final async = ref.watch(conservationActualVsBaselineProvider(siteId));
    return async.when(
      loading: () => const LinearProgressIndicator(),
      error: (e, _) => Text(s.friendlyLoadError(e)),
      data: (results) {
        if (results.isEmpty) {
          return Text(s.noApprovedBaselines);
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
    final s = ConservationStrings.of(context);
    final async = ref.watch(conservationVirtualMeterPreviewsProvider(siteId));
    return async.when(
      loading: () => const LinearProgressIndicator(),
      error: (e, _) => Text(s.friendlyLoadError(e)),
      data: (results) {
        if (results.isEmpty) {
          return Text(s.noVirtualMeters);
        }
        return Column(
          children: [
            for (final r in results) ...[
              Card(
                child: ListTile(
                  title: Text(s.localizeDomainLabel(r.directionLabel)),
                  subtitle: Text(
                    '${r.isInsufficient ? s.insufficientData : s.formatQuantity(r.value, r.unitCode)}\n'
                    '${s.confidenceCompleteness(confidence: r.confidenceScore, completenessPct: (r.completeness * 100).toStringAsFixed(0))}\n'
                    '${r.warnings.isEmpty ? s.residualNotLeak : r.warnings.map(s.localizeDomainMessage).join(' · ')}',
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
    final s = ConservationStrings.of(context);
    final async = ref.watch(conservationBalanceResultsProvider(siteId));
    return async.when(
      loading: () => const LinearProgressIndicator(),
      error: (e, _) => Text(s.friendlyLoadError(e)),
      data: (bundles) {
        final filtered = [
          for (final b in bundles)
            if ((b.group.utilityCode.toLowerCase() == 'water' && waterOn) ||
                (b.group.utilityCode.toLowerCase() == 'electricity' &&
                    energyOn))
              b,
        ];
        if (filtered.isEmpty) {
          return Text(s.noActiveBalanceGroups);
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
    final s = ConservationStrings.of(context);
    final async = ref.watch(conservationBenchmarkProvider(siteId));
    return async.when(
      loading: () => const LinearProgressIndicator(),
      error: (e, _) => Text(s.friendlyLoadError(e)),
      data: (bundles) {
        if (bundles.isEmpty) {
          return Text(s.noBenchmarkTotals);
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
    final s = ConservationStrings.of(context);
    final async = ref.watch(conservationAnomaliesProvider(siteId));
    return async.when(
      loading: () => const LinearProgressIndicator(),
      error: (e, _) => Text(s.friendlyLoadError(e)),
      data: (bundles) {
        if (bundles.isEmpty) {
          return Text(s.noAnomalySignals);
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

class _OpportunitiesSection extends ConsumerWidget {
  const _OpportunitiesSection({
    required this.siteId,
    required this.investigationsOn,
  });

  final String siteId;
  final bool investigationsOn;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ConservationStrings.of(context);
    final async = ref.watch(conservationOpportunitiesProvider(siteId));
    return async.when(
      loading: () => const LinearProgressIndicator(),
      error: (e, _) => Text(s.friendlyLoadError(e)),
      data: (opportunities) {
        if (opportunities.isEmpty) {
          return Text(s.noOpportunitiesYet);
        }
        return OpportunityListPanel(
          opportunities: opportunities,
          emptyMessage: s.noOpportunitiesFilter,
          showStartInvestigation: investigationsOn,
          onStartInvestigation: investigationsOn
              ? (o) => _startInvestigation(context, ref, o)
              : null,
        );
      },
    );
  }

  Future<void> _startInvestigation(
    BuildContext context,
    WidgetRef ref,
    ConservationOpportunity opportunity,
  ) async {
    final s = ConservationStrings.of(context);
    try {
      final client = ref.read(supabaseClientProvider);
      final userId = client.auth.currentUser?.id;
      final workflow = OpportunityWorkflowService(
        opportunityRepository: OpportunityRepository(client),
        auditRepository: WorkflowAuditRepository(client),
      );
      await workflow.startInvestigation(opportunity.id);
      await InvestigationRepository(client).create(
        opportunityId: opportunity.id,
        siteId: opportunity.siteId,
        createdBy: userId,
      );
      ref.invalidate(conservationOpportunitiesProvider(siteId));
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.investigationStarted)),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.friendlyLoadError(e))),
      );
    }
  }
}

class _MvSection extends ConsumerWidget {
  const _MvSection({
    required this.siteId,
    required this.showCostRoi,
  });

  final String siteId;
  final bool showCostRoi;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ConservationStrings.of(context);
    final async = ref.watch(conservationMvListProvider(siteId));
    return async.when(
      loading: () => const LinearProgressIndicator(),
      error: (e, _) => Text(s.friendlyLoadError(e)),
      data: (rows) {
        if (rows.isEmpty) {
          return Text(s.noMvRecordsYet);
        }
        final totals = computeMvPortfolioTotals(rows);
        return Column(
          children: [
            MvSummaryStrip(
              totals: totals,
              showCostRoi: showCostRoi,
            ),
            const SizedBox(height: 10),
            for (final row in rows) ...[
              MvVerificationCard(
                record: row,
                showCostRoi: showCostRoi,
              ),
              const SizedBox(height: 8),
            ],
          ],
        );
      },
    );
  }
}
