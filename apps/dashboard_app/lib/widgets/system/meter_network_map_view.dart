import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_meters_core/smart_meters_core.dart';

import '../../l10n/app_strings.dart';
import '../../theme/design_system/dashboard_design_system.dart';
import '../dashboard_widgets.dart';

Future<UtilityNetworkSnapshot?> _loadNetworkSnapshotForDashboard({
  required UtilityNetworkRepository repo,
  required String siteId,
  required String categoryId,
}) async {
  final network = await repo.resolvePrimaryNetworkForSite(
    siteId: siteId,
    categoryId: categoryId,
  );
  if (network == null) return null;
  // Prefer live draft so Admin canvas edits appear without waiting for publish.
  try {
    return await repo.getDraftSnapshot(network.id);
  } catch (_) {
    try {
      return await repo.getPublishedSnapshot(network.id);
    } on NetworkNotPublishedError {
      return null;
    }
  }
}

/// Latest water network for a site (draft when readable, else published).
///
/// Keeps refreshing while watched so Admin edits stay in sync with Dashboard.
final dashboardPublishedNetworkProvider = FutureProvider.autoDispose
    .family<UtilityNetworkSnapshot?, ({String siteId, String categoryId})>((
      ref,
      key,
    ) async {
      final repo = ref.read(utilityNetworkRepositoryProvider);

      // Continuous sync while the Network map is open.
      final timer = Timer.periodic(const Duration(seconds: 8), (_) {
        ref.invalidateSelf();
      });
      ref.onDispose(timer.cancel);

      return _loadNetworkSnapshotForDashboard(
        repo: repo,
        siteId: key.siteId,
        categoryId: key.categoryId,
      );
    });

/// Read-only published water utility network (v2) for Dashboard.
class MeterNetworkMapView extends ConsumerStatefulWidget {
  const MeterNetworkMapView({
    super.key,
    required this.siteId,
    required this.categoryId,
    required this.cards,
    required this.onViewReadings,
  });

  final String siteId;
  final String categoryId;
  final List<MeterReadingCardData> cards;
  final ValueChanged<MeterReadingCardData> onViewReadings;

  @override
  ConsumerState<MeterNetworkMapView> createState() =>
      _MeterNetworkMapViewState();
}

class _MeterNetworkMapViewState extends ConsumerState<MeterNetworkMapView> {
  final _search = TextEditingController();
  String? _selectedNodeId;
  bool _showUpstream = true;
  bool _showDownstream = true;
  String? _buildingFilter;
  String? _waterTypeFilter;

  @override
  void initState() {
    super.initState();
    // Always pull the latest published revision when opening Network.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.invalidate(
        dashboardPublishedNetworkProvider((
          siteId: widget.siteId,
          categoryId: widget.categoryId,
        )),
      );
    });
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  UtilityRevisionNode? _nodeById(UtilityNetworkSnapshot snap, String? id) {
    if (id == null) return null;
    return snap.nodes.where((n) => n.id == id).firstOrNull;
  }

  List<String> _upstreamIds(UtilityNetworkSnapshot snap, String nodeId) {
    return [
      for (final c in snap.connections)
        if (c.toNodeId == nodeId) c.fromNodeId,
    ];
  }

  List<String> _downstreamIds(UtilityNetworkSnapshot snap, String nodeId) {
    return [
      for (final c in snap.connections)
        if (c.fromNodeId == nodeId) c.toNodeId,
    ];
  }

  String _label(UtilityRevisionNode? node, bool isAr) {
    final asset = node?.asset;
    if (asset == null) return '—';
    final name = isAr ? asset.nameAr : asset.nameEn;
    return '${asset.code} · $name';
  }

  String? _defaultViewId(UtilityNetworkSnapshot snapshot) {
    final def = snapshot.views.where((v) => v.isDefault).firstOrNull;
    if (def != null) return def.id;
    if (snapshot.views.isNotEmpty) return snapshot.views.first.id;
    if (snapshot.placements.isNotEmpty) return snapshot.placements.first.viewId;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final providerKey = (
      siteId: widget.siteId,
      categoryId: widget.categoryId,
    );
    final snapAsync = ref.watch(dashboardPublishedNetworkProvider(providerKey));
    final byMeterId = {for (final c in widget.cards) c.meterId: c};
    final screenH = MediaQuery.sizeOf(context).height;
    final canvasH = (screenH * 0.58).clamp(420.0, 720.0);

    return snapAsync.when(
      loading: () => SizedBox(
        height: canvasH,
        child: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => DashboardErrorState(
        title: s.couldNotLoadNetworkMap,
        message: s.pleaseRefreshNetworkMap,
        onRetry: () =>
            ref.invalidate(dashboardPublishedNetworkProvider(providerKey)),
      ),
      data: (snapshot) {
        if (snapshot == null || snapshot.nodes.isEmpty) {
          return DashboardEmptyState(
            title: s.networkMapEmpty,
            subtitle: s.networkMapEmptyHint,
          );
        }

        final viewId = _defaultViewId(snapshot);
        if (viewId == null) {
          return DashboardEmptyState(
            title: s.networkMapEmpty,
            subtitle: s.networkMapEmptyHint,
          );
        }

        final selected = _nodeById(snapshot, _selectedNodeId);
        final selectedMeterId = selected?.asset?.refMeterId;
        final selectedCard = selectedMeterId == null
            ? null
            : byMeterId[selectedMeterId];

        final buildings = <String>{
          for (final n in snapshot.nodes)
            if (n.asset?.facilityAreaId != null) n.asset!.facilityAreaId!,
        }.toList()..sort();

        final query = _search.text.trim().toLowerCase();
        final filteredNodeIds = <String>{
          for (final n in snapshot.nodes)
            if (n.asset != null)
              if (query.isEmpty ||
                  n.asset!.code.toLowerCase().contains(query) ||
                  n.asset!.nameAr.toLowerCase().contains(query) ||
                  n.asset!.nameEn.toLowerCase().contains(query))
                if (_buildingFilter == null ||
                    n.asset!.facilityAreaId == _buildingFilter)
                  n.id,
        };

        final meterCount = snapshot.nodes
            .where((n) => n.asset?.assetType.dbValue == 'meter')
            .length;
        final tankCount = snapshot.nodes
            .where((n) => n.asset?.assetType.dbValue == 'tank')
            .length;
        final sourceCount = snapshot.nodes
            .where((n) => n.asset?.assetType.dbValue == 'external_source')
            .length;

        final publishedAt = snapshot.revision.publishedAt;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: _KpiChip(
                    label: s.networkSources,
                    value: '$sourceCount',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _KpiChip(
                    label: s.networkMetersKpi,
                    value: '$meterCount',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _KpiChip(
                    label: s.networkTanksKpi,
                    value: '$tankCount',
                  ),
                ),
              ],
            ),
            if (publishedAt != null) ...[
              const SizedBox(height: 6),
              Text(
                isAr
                    ? 'آخر نشر من الأدمن: ${publishedAt.toLocal().toString().split('.').first} · بعد تعديل الشبكة في الأدمن اضغط اعتماد/نشر لتحديث العرض هنا'
                    : 'Last published from Admin: ${publishedAt.toLocal().toString().split('.').first} · After editing in Admin, Approve/Publish to update this view',
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ],
            const SizedBox(height: DashboardSpacing.sm),
            // Filters moved above the full-width canvas (no side panel).
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 220,
                  child: TextField(
                    controller: _search,
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: s.networkSearchHint,
                      prefixIcon: const Icon(Icons.search, size: 18),
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                SizedBox(
                  width: 160,
                  child: DropdownButtonFormField<String?>(
                    initialValue: _waterTypeFilter,
                    isDense: true,
                    decoration: InputDecoration(
                      isDense: true,
                      labelText: s.networkWaterTypeFilter,
                      border: const OutlineInputBorder(),
                    ),
                    items: [
                      DropdownMenuItem(value: null, child: Text(s.all)),
                      for (final w in [
                        'potable',
                        'tse',
                        'rainwater',
                        'reject',
                      ])
                        DropdownMenuItem(value: w, child: Text(w)),
                    ],
                    onChanged: (v) => setState(() => _waterTypeFilter = v),
                  ),
                ),
                if (buildings.isNotEmpty)
                  SizedBox(
                    width: 160,
                    child: DropdownButtonFormField<String?>(
                      initialValue: _buildingFilter,
                      isDense: true,
                      decoration: InputDecoration(
                        isDense: true,
                        labelText: s.networkBuildingFilter,
                        border: const OutlineInputBorder(),
                      ),
                      items: [
                        DropdownMenuItem(value: null, child: Text(s.all)),
                        for (final b in buildings)
                          DropdownMenuItem(value: b, child: Text(b)),
                      ],
                      onChanged: (v) => setState(() => _buildingFilter = v),
                    ),
                  ),
                FilterChip(
                  label: Text(s.networkShowUpstream),
                  selected: _showUpstream,
                  onSelected: (v) => setState(() => _showUpstream = v),
                ),
                FilterChip(
                  label: Text(s.networkShowDownstream),
                  selected: _showDownstream,
                  onSelected: (v) => setState(() => _showDownstream = v),
                ),
                IconButton(
                  tooltip: s.refresh,
                  onPressed: () => ref.invalidate(
                    dashboardPublishedNetworkProvider(providerKey),
                  ),
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            const SizedBox(height: DashboardSpacing.sm),
            SizedBox(
              width: double.infinity,
              height: canvasH,
              child: UtilityNetworkCanvas(
                snapshot: snapshot,
                viewId: viewId,
                isArabic: isAr,
                selectedNodeId: _selectedNodeId,
                editMode: false,
                showPorts: false,
                showFitControl: true,
                onNodeTap: (n) {
                  if (filteredNodeIds.isNotEmpty &&
                      !filteredNodeIds.contains(n.id)) {
                    return;
                  }
                  if (_waterTypeFilter != null) {
                    final related = snapshot.connections.any(
                      (c) =>
                          (c.fromNodeId == n.id || c.toNodeId == n.id) &&
                          c.waterType == _waterTypeFilter,
                    );
                    if (!related &&
                        n.asset?.serviceType?.dbValue != _waterTypeFilter) {
                      return;
                    }
                  }
                  setState(() => _selectedNodeId = n.id);
                },
              ),
            ),
            if (selected != null) ...[
              const SizedBox(height: DashboardSpacing.sm),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        s.networkSelectedDetails,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(_label(selected, isAr)),
                      if (selectedCard != null) ...[
                        Text(
                          '${s.networkCurrentReading}: '
                          '${selectedCard.latestValue?.toStringAsFixed(2) ?? '—'} '
                          '${selectedCard.unitLabel}',
                        ),
                        Text(
                          '${s.networkLastReading}: '
                          '${selectedCard.latestDate?.toIso8601String().split('T').first ?? '—'}',
                        ),
                      ],
                      if (_showUpstream) ...[
                        const SizedBox(height: 8),
                        Text(s.networkUpstreamPath),
                        for (final id in _upstreamIds(snapshot, selected.id))
                          Text(
                            '· ${_label(_nodeById(snapshot, id), isAr)}',
                          ),
                      ],
                      if (_showDownstream) ...[
                        Text(s.networkDownstreamPath),
                        for (final id in _downstreamIds(snapshot, selected.id))
                          Text(
                            '· ${_label(_nodeById(snapshot, id), isAr)}',
                          ),
                      ],
                      if (selectedCard != null) ...[
                        const SizedBox(height: 12),
                        Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: FilledButton(
                            onPressed: () =>
                                widget.onViewReadings(selectedCard),
                            child: Text(s.viewReadingHistory),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _KpiChip extends StatelessWidget {
  const _KpiChip({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.labelMedium),
            Text(value, style: Theme.of(context).textTheme.headlineSmall),
          ],
        ),
      ),
    );
  }
}
