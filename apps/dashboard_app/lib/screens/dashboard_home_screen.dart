import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_meters_core/smart_meters_core.dart';

import '../l10n/app_strings.dart';
import '../navigation/dashboard_partner_navigation.dart';
import '../providers/alert_providers.dart';
import '../providers/dashboard_providers.dart';
import '../reports/report_export_button.dart';
import '../reports/report_models.dart';
import '../utils/dashboard_breakpoints.dart';
import '../utils/dashboard_filters.dart';
import '../widgets/alert_widgets.dart';
import '../widgets/dashboard_widgets.dart';
import '../widgets/premium/premium_section_header.dart';
import '../widgets/premium/premium_stat_card.dart';
import '../widgets/premium/responsive_grid.dart';
import '../widgets/premium/utility_colors.dart';
import 'site_dashboard_screen.dart';

class DashboardHomeScreen extends ConsumerStatefulWidget {
  const DashboardHomeScreen({
    super.key,
    this.embedded = false,
    this.alertsFocus = false,
    this.onSiteSelected,
  });

  final bool embedded;
  final bool alertsFocus;
  final void Function(String siteId)? onSiteSelected;

  @override
  ConsumerState<DashboardHomeScreen> createState() =>
      _DashboardHomeScreenState();
}

class _DashboardHomeScreenState extends ConsumerState<DashboardHomeScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    ref.invalidate(dashboardSitesProvider);
    if (widget.alertsFocus) {
      ref.invalidate(dashboardHomeAlertsProvider);
    }
  }

  void _openSite(DashboardSiteOverview overview) {
    if (widget.onSiteSelected != null) {
      widget.onSiteSelected!(overview.site.id);
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SiteDashboardScreen(
          siteId: overview.site.id,
          initialSite: overview.site,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final profile = ref.watch(authProvider).profile!;
    final sitesAsync = ref.watch(dashboardSitesProvider);
    final zones = ref.watch(dashboardZonesProvider);
    final typeFilter = ref.watch(dashboardSiteTypeFilterProvider);
    final search = ref.watch(dashboardSearchProvider);
    // Only fetch home alerts on the Alerts tab — never on Sites list load.
    final alertsAsync = widget.alertsFocus
        ? ref.watch(dashboardHomeAlertsProvider)
        : const AsyncValue<AlertSummary>.loading();
    final severityFilter = ref.watch(homeAlertSeverityFilterProvider);

    if (_searchController.text != search) {
      _searchController.value = _searchController.value.copyWith(
        text: search,
        selection: TextSelection.collapsed(offset: search.length),
      );
    }

    final padding = DashboardBreakpoints.contentPadding(context);
    final isWide = DashboardBreakpoints.useSidebar(context);

    final listContent = RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        padding: EdgeInsets.fromLTRB(padding, padding, padding, 24),
        children: [
          if (!widget.embedded) ...[
            Text(
              s.welcomeUser(profile.fullName.trim().isEmpty ? profile.email : profile.fullName),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text(
              s.userRole(profile.role),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
          ] else
            PremiumSectionHeader(
              title: widget.alertsFocus ? s.alertsOverview : s.homeDashboardTitle,
              subtitle: widget.alertsFocus
                  ? s.alertsOverviewSubtitle
                  : s.homeDashboardSubtitle,
            ),
          if (widget.embedded && !widget.alertsFocus)
            sitesAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (_, _) => const SizedBox.shrink(),
              data: (sites) => _HomeKpiGrid(sites: sites, isWide: isWide),
            ),
          if (widget.alertsFocus)
            alertsAsync.when(
              loading: () => const DashboardCard(
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, _) => DashboardErrorState(message: '$error'),
              data: (summary) {
                final topCritical = filterAlertsBySeverity(
                  summary.alerts,
                  AlertSeverity.critical,
                ).take(5).toList();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AlertSummaryCard(summary: summary),
                    if (topCritical.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        s.topCriticalAlerts,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 8),
                      for (final alert in topCritical)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: AlertListTile(
                          alert: alert,
                          onTap: () => openSiteFromHomeAlert(ref, alert),
                        ),
                        ),
                    ],
                    const SizedBox(height: 8),
                    DropdownButtonFormField<AlertSeverity?>(
                      initialValue: severityFilter,
                      decoration: InputDecoration(
                        labelText: s.alertSeverityFilter,
                      ),
                      items: [
                        DropdownMenuItem(
                          value: null,
                          child: Text(s.allSeverities),
                        ),
                        DropdownMenuItem(
                          value: AlertSeverity.critical,
                          child: Text(s.criticalOnly),
                        ),
                        DropdownMenuItem(
                          value: AlertSeverity.warning,
                          child: Text(s.warningOnly),
                        ),
                        DropdownMenuItem(
                          value: AlertSeverity.info,
                          child: Text(s.infoOnly),
                        ),
                      ],
                      onChanged: (value) => ref
                          .read(homeAlertSeverityFilterProvider.notifier)
                          .state = value,
                    ),
                    const SizedBox(height: 12),
                    for (final alert in filterAlertsBySeverity(
                      summary.alerts,
                      severityFilter,
                    ))
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: AlertListTile(
                          alert: alert,
                          onTap: () => widget.onSiteSelected != null
                              ? widget.onSiteSelected!(alert.siteId)
                              : openSiteFromHomeAlert(ref, alert),
                        ),
                      ),
                  ],
                );
              },
            ),
          if (!widget.alertsFocus) ...[
            const SizedBox(height: 16),
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: s.searchSitesHint,
              ),
              onChanged: (value) =>
                  ref.read(dashboardSearchProvider.notifier).state = value,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<DashboardSiteTypeFilter>(
              initialValue: typeFilter,
              decoration: InputDecoration(labelText: s.siteType),
              items: [
                for (final filter in DashboardSiteTypeFilter.values)
                  DropdownMenuItem(
                    value: filter,
                    child: Text(s.siteTypeFilter(filter)),
                  ),
              ],
              onChanged: (value) {
                if (value != null) {
                  ref.read(dashboardSiteTypeFilterProvider.notifier).state =
                      value;
                }
              },
            ),
            const SizedBox(height: 16),
            sitesAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(48),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, _) => DashboardErrorState(
                message: '$error',
                onRetry: _refresh,
              ),
              data: (sites) => _SitesHierarchySection(
                sites: sites,
                registeredZones: zones,
                typeFilter: typeFilter,
                search: search,
                onSiteTap: _openSite,
              ),
            ),
          ],
        ],
      ),
    );

    if (widget.embedded) {
      return listContent;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(s.sites),
        actions: [
          ReportExportIconButton(defaultType: ReportType.allSitesSummary),
          IconButton(
            tooltip: s.refresh,
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(child: listContent),
    );
  }
}

class _HomeKpiGrid extends StatelessWidget {
  const _HomeKpiGrid({required this.sites, required this.isWide});

  final List<DashboardSiteOverview> sites;
  final bool isWide;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final totalMeters = sites.fold<int>(0, (sum, s) => sum + s.meterCount);
    final submitted =
        sites.fold<int>(0, (sum, s) => sum + s.readingsSubmittedToday);
    final eligible =
        sites.fold<int>(0, (sum, s) => sum + s.entryEligibleMeterCount);
    final pending = (eligible - submitted).clamp(0, eligible);
    final completion = eligible == 0
        ? '—'
        : '${((submitted / eligible) * 100).toStringAsFixed(1)}%';

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: ResponsiveGrid(
        minItemWidth: isWide ? 180 : 160,
        childHeight: 150,
        children: [
          PremiumStatCard(
            icon: Icons.apartment_outlined,
            label: strings.sites,
            value: '${sites.length}',
            subtitle: strings.accessible,
            accent: AppColors.navy,
          ),
          PremiumStatCard(
            icon: Icons.speed,
            label: strings.meters,
            value: '$totalMeters',
            subtitle: strings.acrossSites,
            accent: DashboardUtilityColors.water,
          ),
          PremiumStatCard(
            icon: Icons.today,
            label: strings.submittedToday,
            value: '$submitted',
            subtitle: completion,
            accent: DashboardUtilityColors.success,
          ),
          PremiumStatCard(
            icon: Icons.pending_actions,
            label: strings.pendingToday,
            value: '$pending',
            accent: DashboardUtilityColors.warning,
          ),
        ],
      ),
    );
  }
}

class _SitesHierarchySection extends StatefulWidget {
  const _SitesHierarchySection({
    required this.sites,
    required this.registeredZones,
    required this.typeFilter,
    required this.search,
    required this.onSiteTap,
  });

  final List<DashboardSiteOverview> sites;
  final List<Zone> registeredZones;
  final DashboardSiteTypeFilter typeFilter;
  final String search;
  final void Function(DashboardSiteOverview overview) onSiteTap;

  @override
  State<_SitesHierarchySection> createState() => _SitesHierarchySectionState();
}

class _SitesHierarchySectionState extends State<_SitesHierarchySection> {
  final Set<String> _expandedOrgIds = {};
  final Set<String?> _expandedZoneKeys = {};

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    var filtered = filterDashboardSitesByType(widget.sites, widget.typeFilter);
    filtered = searchDashboardSites(filtered, widget.search);

    final orgBuckets = _buildOrgBuckets(
      sites: filtered,
      registeredZones: widget.registeredZones,
    );

    if (orgBuckets.isEmpty) {
      return DashboardEmptyState(
        title: s.noSitesMatchFilters,
        subtitle: s.tryAdjustSearchOrFilters,
      );
    }

    final multiOrg = orgBuckets.length > 1;
    final searching = widget.search.trim().isNotEmpty;

    // Single entity (or search flattening): show direct sites + zones.
    if (!multiOrg) {
      return _OrgBody(
        bucket: orgBuckets.first,
        overviewBySiteId: {
          for (final overview in filtered) overview.site.id: overview,
        },
        expandedZoneKeys: _expandedZoneKeys,
        onZoneExpansionChanged: _setZoneExpanded,
        onSiteTap: widget.onSiteTap,
        showDirectSitesInline: true,
      );
    }

    // Multi-entity: list organizations first.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final bucket in orgBuckets)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _OrgExpansionCard(
              bucket: bucket,
              overviewBySiteId: {
                for (final overview in filtered) overview.site.id: overview,
              },
              expanded: searching || _expandedOrgIds.contains(bucket.orgId),
              onExpansionChanged: (expanded) {
                setState(() {
                  if (expanded) {
                    _expandedOrgIds.add(bucket.orgId);
                  } else {
                    _expandedOrgIds.remove(bucket.orgId);
                  }
                });
              },
              expandedZoneKeys: _expandedZoneKeys,
              onZoneExpansionChanged: _setZoneExpanded,
              onSiteTap: widget.onSiteTap,
            ),
          ),
      ],
    );
  }

  void _setZoneExpanded(String? zoneKey, bool expanded) {
    setState(() {
      if (expanded) {
        _expandedZoneKeys.add(zoneKey);
      } else {
        _expandedZoneKeys.remove(zoneKey);
      }
    });
  }

  List<_OrgBucket> _buildOrgBuckets({
    required List<DashboardSiteOverview> sites,
    required List<Zone> registeredZones,
  }) {
    final byOrg = <String, List<DashboardSiteOverview>>{};
    for (final overview in sites) {
      byOrg.putIfAbsent(overview.site.organizationId, () => []).add(overview);
    }

    final zonesByOrg = <String, List<Zone>>{};
    for (final zone in registeredZones) {
      zonesByOrg.putIfAbsent(zone.organizationId, () => []).add(zone);
    }

    final buckets = <_OrgBucket>[];
    for (final entry in byOrg.entries) {
      final orgId = entry.key;
      final orgSites = entry.value;
      final sample = orgSites.first.site.organization;
      final orgNameEn = sample?.nameEn ?? orgSites.first.site.displayOrganizationName;
      final orgNameAr = sample?.nameAr ?? orgNameEn;

      final direct = orgSites.where((o) => o.site.zoneId == null).toList()
        ..sort((a, b) => a.site.nameEn.compareTo(b.site.nameEn));

      final zoneGroups = _buildZoneGroupsForOrg(
        sites: orgSites.where((o) => o.site.zoneId != null).toList(),
        registeredZones: zonesByOrg[orgId] ?? const [],
      );

      if (direct.isEmpty && zoneGroups.every((g) => g.sites.isEmpty)) {
        // Keep empty orgs out when filtering emptied them.
        if (orgSites.isEmpty) continue;
      }

      buckets.add(
        _OrgBucket(
          orgId: orgId,
          nameEn: orgNameEn,
          nameAr: orgNameAr,
          directSites: direct,
          zoneGroups: zoneGroups,
        ),
      );
    }

    buckets.sort((a, b) => a.nameEn.compareTo(b.nameEn));
    return buckets;
  }

  List<_HomeZoneGroup> _buildZoneGroupsForOrg({
    required List<DashboardSiteOverview> sites,
    required List<Zone> registeredZones,
  }) {
    final sitesByZone = <String?, List<DashboardSiteOverview>>{};
    for (final overview in sites) {
      sitesByZone.putIfAbsent(overview.site.zoneId, () => []).add(overview);
    }

    final groups = <_HomeZoneGroup>[
      for (final zone in registeredZones)
        _HomeZoneGroup(
          zoneKey: zone.id,
          zoneName: zone.nameEn,
          sites: List<DashboardSiteOverview>.from(sitesByZone[zone.id] ?? [])
            ..sort((a, b) => a.site.nameEn.compareTo(b.site.nameEn)),
        ),
    ];

    final knownZoneIds = registeredZones.map((zone) => zone.id).toSet();
    for (final entry in sitesByZone.entries) {
      final zoneId = entry.key;
      if (zoneId == null || knownZoneIds.contains(zoneId)) continue;
      groups.add(
        _HomeZoneGroup(
          zoneKey: zoneId,
          zoneName: entry.value.first.site.displayZoneName,
          sites: List<DashboardSiteOverview>.from(entry.value)
            ..sort((a, b) => a.site.nameEn.compareTo(b.site.nameEn)),
        ),
      );
    }

    // Drop empty zone rows when searching; keep registered empty zones when not.
    groups.sort((a, b) => a.zoneName.compareTo(b.zoneName));
    return groups;
  }
}

class _OrgBucket {
  const _OrgBucket({
    required this.orgId,
    required this.nameEn,
    required this.nameAr,
    required this.directSites,
    required this.zoneGroups,
  });

  final String orgId;
  final String nameEn;
  final String nameAr;
  final List<DashboardSiteOverview> directSites;
  final List<_HomeZoneGroup> zoneGroups;

  int get siteCount =>
      directSites.length +
      zoneGroups.fold<int>(0, (sum, g) => sum + g.sites.length);

  int get zoneCount => zoneGroups.where((g) => g.sites.isNotEmpty).length;
}

class _OrgExpansionCard extends StatelessWidget {
  const _OrgExpansionCard({
    required this.bucket,
    required this.overviewBySiteId,
    required this.expanded,
    required this.onExpansionChanged,
    required this.expandedZoneKeys,
    required this.onZoneExpansionChanged,
    required this.onSiteTap,
  });

  final _OrgBucket bucket;
  final Map<String, DashboardSiteOverview> overviewBySiteId;
  final bool expanded;
  final ValueChanged<bool> onExpansionChanged;
  final Set<String?> expandedZoneKeys;
  final void Function(String? zoneKey, bool expanded) onZoneExpansionChanged;
  final void Function(DashboardSiteOverview overview) onSiteTap;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final colors = Theme.of(context).colorScheme;
    final title = s.localizedName(en: bucket.nameEn, ar: bucket.nameAr);

    return DashboardCard(
      padding: EdgeInsets.fromLTRB(12, 8, 12, expanded ? 12 : 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => onExpansionChanged(!expanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: colors.primary.withValues(alpha: 0.1),
                    child: Icon(
                      Icons.business_outlined,
                      color: colors.primary,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        Text(
                          '${s.sitesCount(bucket.siteCount)} · ${s.zonesCount(bucket.zoneCount)}',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: colors.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: colors.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
          if (expanded) ...[
            const Divider(height: 1),
            const SizedBox(height: 8),
            _OrgBody(
              bucket: bucket,
              overviewBySiteId: overviewBySiteId,
              expandedZoneKeys: expandedZoneKeys,
              onZoneExpansionChanged: onZoneExpansionChanged,
              onSiteTap: onSiteTap,
              showDirectSitesInline: true,
            ),
          ],
        ],
      ),
    );
  }
}

class _OrgBody extends StatelessWidget {
  const _OrgBody({
    required this.bucket,
    required this.overviewBySiteId,
    required this.expandedZoneKeys,
    required this.onZoneExpansionChanged,
    required this.onSiteTap,
    required this.showDirectSitesInline,
  });

  final _OrgBucket bucket;
  final Map<String, DashboardSiteOverview> overviewBySiteId;
  final Set<String?> expandedZoneKeys;
  final void Function(String? zoneKey, bool expanded) onZoneExpansionChanged;
  final void Function(DashboardSiteOverview overview) onSiteTap;
  final bool showDirectSitesInline;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final visibleZones = bucket.zoneGroups
        .where((g) => g.sites.isNotEmpty)
        .toList();

    if (bucket.directSites.isEmpty && visibleZones.isEmpty) {
      return DashboardEmptyState(
        title: s.noSitesMatchFilters,
        subtitle: s.tryAdjustSearchOrFilters,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showDirectSitesInline && bucket.directSites.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              s.directSites,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ),
          for (final overview in bucket.directSites)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: DashboardSiteListTile(
                overview: overviewBySiteId[overview.site.id] ?? overview,
                onTap: () => onSiteTap(
                  overviewBySiteId[overview.site.id] ?? overview,
                ),
              ),
            ),
          if (visibleZones.isNotEmpty) const SizedBox(height: 4),
        ],
        for (final group in visibleZones)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _ZoneExpansionCard(
              group: group,
              overviewBySiteId: overviewBySiteId,
              expanded: expandedZoneKeys.contains(group.zoneKey),
              onExpansionChanged: (expanded) =>
                  onZoneExpansionChanged(group.zoneKey, expanded),
              onSiteTap: onSiteTap,
            ),
          ),
      ],
    );
  }
}

class _HomeZoneGroup {
  const _HomeZoneGroup({
    required this.zoneKey,
    required this.zoneName,
    required this.sites,
  });

  final String? zoneKey;
  final String zoneName;
  final List<DashboardSiteOverview> sites;
}

class _ZoneExpansionCard extends StatelessWidget {
  const _ZoneExpansionCard({
    required this.group,
    required this.overviewBySiteId,
    required this.expanded,
    required this.onExpansionChanged,
    required this.onSiteTap,
  });

  final _HomeZoneGroup group;
  final Map<String, DashboardSiteOverview> overviewBySiteId;
  final bool expanded;
  final ValueChanged<bool> onExpansionChanged;
  final void Function(DashboardSiteOverview overview) onSiteTap;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final colors = Theme.of(context).colorScheme;
    return DashboardCard(
      padding: EdgeInsets.fromLTRB(12, 8, 12, expanded ? 12 : 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => onExpansionChanged(!expanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: colors.primary.withValues(alpha: 0.1),
                    child: Icon(Icons.map_outlined, color: colors.primary, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s.zoneDisplayName(group.zoneName),
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        Text(
                          s.sitesCount(group.sites.length),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: colors.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: colors.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
          if (expanded) ...[
            const Divider(height: 1),
            const SizedBox(height: 8),
            if (group.sites.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  s.noAccessibleSitesInZone,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                ),
              )
            else
              for (final overview in group.sites)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: DashboardSiteListTile(
                    overview: overviewBySiteId[overview.site.id] ?? overview,
                    onTap: () => onSiteTap(
                      overviewBySiteId[overview.site.id] ?? overview,
                    ),
                  ),
                ),
          ],
        ],
      ),
    );
  }
}

String userRoleLabel(UserRole role) {
  return switch (role) {
    UserRole.superAdmin => 'Super Admin',
    UserRole.siteAdmin => 'Site Admin',
    UserRole.technician => 'Technician',
    UserRole.technicianRequest => 'Technician Request',
    UserRole.viewer => 'Viewer',
  };
}
