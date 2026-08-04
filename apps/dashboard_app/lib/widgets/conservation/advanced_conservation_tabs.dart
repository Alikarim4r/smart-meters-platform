import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_meters_core/smart_meters_core.dart';

import '../../l10n/conservation_strings.dart';
import '../../theme/design_system/dashboard_colors.dart';

/// Phase 5 advanced Conservation drill-down.
/// Simple by default — details load only when a tab is opened (lazy).
class AdvancedConservationTabs extends ConsumerStatefulWidget {
  const AdvancedConservationTabs({
    super.key,
    required this.siteId,
    required this.weatherOn,
    required this.occupancyOn,
    required this.persistenceOn,
    required this.carbonOn,
    required this.forecastOn,
    required this.recommendationsOn,
  });

  final String siteId;
  final bool weatherOn;
  final bool occupancyOn;
  final bool persistenceOn;
  final bool carbonOn;
  final bool forecastOn;
  final bool recommendationsOn;

  @override
  ConsumerState<AdvancedConservationTabs> createState() =>
      _AdvancedConservationTabsState();
}

class _AdvancedConservationTabsState
    extends ConsumerState<AdvancedConservationTabs>
    with SingleTickerProviderStateMixin {
  TabController? _tabs;
  late final List<_TabKind> _kinds;

  @override
  void initState() {
    super.initState();
    _kinds = [
      if (widget.weatherOn || widget.occupancyOn) _TabKind.normalized,
      if (widget.persistenceOn) _TabKind.persistence,
      if (widget.carbonOn) _TabKind.carbon,
      if (widget.forecastOn) _TabKind.forecast,
      if (widget.recommendationsOn) _TabKind.recommendations,
    ];
    if (_kinds.isNotEmpty) {
      _tabs = TabController(length: _kinds.length, vsync: this);
    }
  }

  @override
  void dispose() {
    _tabs?.dispose();
    super.dispose();
  }

  String _label(ConservationStrings s, _TabKind kind) => switch (kind) {
        _TabKind.normalized => s.normalized,
        _TabKind.persistence => s.persistence,
        _TabKind.carbon => s.carbon,
        _TabKind.forecast => s.forecast,
        _TabKind.recommendations => s.recommendations,
      };

  @override
  Widget build(BuildContext context) {
    if (_kinds.isEmpty || _tabs == null) return const SizedBox.shrink();
    final s = ConservationStrings.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          s.advancedOnDemand,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          s.advancedHint,
          style: const TextStyle(fontSize: 11),
        ),
        const SizedBox(height: 8),
        TabBar(
          controller: _tabs,
          isScrollable: true,
          tabs: [for (final k in _kinds) Tab(text: _label(s, k))],
        ),
        SizedBox(
          height: 220,
          child: TabBarView(
            controller: _tabs,
            children: [
              for (final k in _kinds) _tabBody(k, s),
            ],
          ),
        ),
      ],
    );
  }

  Widget _tabBody(_TabKind kind, ConservationStrings s) {
    switch (kind) {
      case _TabKind.normalized:
        return _NormalizedTab(
          siteId: widget.siteId,
          weatherOn: widget.weatherOn,
          occupancyOn: widget.occupancyOn,
        );
      case _TabKind.persistence:
        return _LazyListTab(
          siteId: widget.siteId,
          empty: s.noPersistenceYet,
          loader: (client) async {
            final rows = await SavingPersistenceRepository(client)
                .listForSite(widget.siteId);
            if (rows.isEmpty) {
              return [s.persistenceNeverDeletesVerified];
            }
            return [
              for (final r in rows.take(10))
                '${r.followUpWindow.dbValue}: ${r.status.dbValue} '
                    'sustained=${r.sustainedQuantity?.toStringAsFixed(1) ?? '—'} '
                    '(${r.persistencePct?.toStringAsFixed(0) ?? '—'}%)',
            ];
          },
        );
      case _TabKind.carbon:
        return _LazyListTab(
          siteId: widget.siteId,
          empty: s.carbonNotAvailable,
          loader: (client) async {
            final rows =
                await CarbonResultRepository(client).listForSite(widget.siteId);
            if (rows.isEmpty) {
              return [s.noCarbonResults];
            }
            return [
              for (final r in rows.take(8))
                '${r.quantityBasis.dbValue}: '
                    '${r.carbonAvoided?.toStringAsFixed(2) ?? s.na} '
                    '${r.carbonUnit ?? ''} (${r.status})',
            ];
          },
        );
      case _TabKind.forecast:
        return _LazyListTab(
          siteId: widget.siteId,
          empty: s.noForecasts,
          loader: (client) async {
            final rows =
                await ForecastResultRepository(client).listForSite(widget.siteId);
            if (rows.isEmpty) {
              return [s.insufficientHistoryForecast];
            }
            return [
              for (final r in rows.take(8))
                '${r.forecastHorizon}/${r.method}: '
                    '${r.expectedValue?.toStringAsFixed(1) ?? ForecastLabels.insufficientHistory} '
                    '(${r.confidence})',
            ];
          },
        );
      case _TabKind.recommendations:
        return _LazyListTab(
          siteId: widget.siteId,
          empty: s.noOpenRecommendations,
          loader: (client) async {
            final rows = await RecommendationRepository(client)
                .listOpenForSite(widget.siteId);
            if (rows.isEmpty) return [s.noOpenRecommendations];
            return [
              for (final r in rows.take(10)) '${r.title} — ${r.rationale}',
            ];
          },
        );
    }
  }
}

enum _TabKind { normalized, persistence, carbon, forecast, recommendations }

class _NormalizedTab extends ConsumerWidget {
  const _NormalizedTab({
    required this.siteId,
    required this.weatherOn,
    required this.occupancyOn,
  });

  final String siteId;
  final bool weatherOn;
  final bool occupancyOn;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ConservationStrings.of(context);
    return FutureBuilder<List<NormalizedResult>>(
      future: NormalizationModelRepository(ref.read(supabaseClientProvider))
          .listResultsForSite(siteId, limit: 12),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final rows = snap.data ?? const <NormalizedResult>[];
        if (rows.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              weatherOn || occupancyOn
                  ? s.noNormalizedYet
                  : s.normalizationFlagsOff,
              style: const TextStyle(fontSize: 12),
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(8),
          itemCount: rows.length,
          itemBuilder: (_, i) {
            final r = rows[i];
            return Card(
              elevation: 0,
              color: DashboardColors.card(context),
              child: ListTile(
                dense: true,
                title: Text(
                  s.actualConsumptionLine(
                    _fmt(r.actualConsumption),
                    r.unitCode,
                  ),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  r.normalizedConsumption == null
                      ? s.normalizedStatus(r.status)
                      : s.normalizedValueLine(
                          _fmt(r.normalizedConsumption!),
                          r.unitCode,
                          r.reliability,
                        ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  String _fmt(double v) => v.toStringAsFixed(v.abs() >= 100 ? 0 : 2);
}

class _LazyListTab extends ConsumerWidget {
  const _LazyListTab({
    required this.siteId,
    required this.empty,
    required this.loader,
  });

  final String siteId;
  final String empty;
  final Future<List<String>> Function(dynamic client) loader;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final client = ref.read(supabaseClientProvider);
    return FutureBuilder<List<String>>(
      future: loader(client),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final lines = snap.data ?? const <String>[];
        if (lines.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(12),
            child: Text(empty, style: const TextStyle(fontSize: 12)),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(8),
          itemCount: lines.length,
          itemBuilder: (_, i) => ListTile(
            dense: true,
            title: Text(lines[i], style: const TextStyle(fontSize: 12)),
          ),
        );
      },
    );
  }
}
