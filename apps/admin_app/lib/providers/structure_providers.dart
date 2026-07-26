import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_meters_core/smart_meters_core.dart';

/// Selection in the Structure tree.
sealed class StructureSelection {
  const StructureSelection();
}

class StructureOrgSelection extends StructureSelection {
  const StructureOrgSelection(this.organizationId);
  final String organizationId;
}

class StructureSiteTypesSelection extends StructureSelection {
  const StructureSiteTypesSelection(this.organizationId);
  final String organizationId;
}

class StructureZoneSelection extends StructureSelection {
  const StructureZoneSelection(this.zoneId);
  final String zoneId;
}

class StructureSiteSelection extends StructureSelection {
  const StructureSiteSelection(this.siteId);
  final String siteId;
}

final structureSelectionProvider = StateProvider<StructureSelection?>(
  (ref) => null,
);

final organizationTemplatesProvider =
    FutureProvider.autoDispose<List<OrganizationTemplate>>((ref) async {
      return ref.read(zoneRepositoryProvider).getOrganizationTemplates();
    });

/// Aggregated tree data for the Structure tab.
class StructureTreeData {
  const StructureTreeData({
    required this.organizations,
    required this.zonesByOrg,
    required this.sitesByOrg,
  });

  final List<Organization> organizations;
  final Map<String, List<Zone>> zonesByOrg;
  final Map<String, List<Site>> sitesByOrg;

  List<Zone> rootZones(String orgId) {
    final zones = zonesByOrg[orgId] ?? const [];
    return zones.where((z) => z.parentZoneId == null).toList();
  }

  List<Zone> childZones(String parentId) {
    for (final zones in zonesByOrg.values) {
      final children = zones.where((z) => z.parentZoneId == parentId).toList();
      if (children.isNotEmpty) return children;
    }
    // Still scan all in case empty list vs missing
    return zonesByOrg.values
        .expand((z) => z)
        .where((z) => z.parentZoneId == parentId)
        .toList();
  }

  List<Site> sitesInZone(String zoneId) {
    return sitesByOrg.values
        .expand((s) => s)
        .where((s) => s.zoneId == zoneId)
        .toList();
  }

  List<Site> directSites(String orgId) {
    return (sitesByOrg[orgId] ?? const [])
        .where((s) => s.zoneId == null)
        .toList();
  }
}

final structureTreeProvider = FutureProvider.autoDispose<StructureTreeData>((
  ref,
) async {
  final siteRepo = ref.read(siteRepositoryProvider);
  final zoneRepo = ref.read(zoneRepositoryProvider);

  // Parallel + light site payload so admin home isn't blocked on meters(count).
  final results = await Future.wait([
    siteRepo.getAllOrganizationsForAdmin(),
    zoneRepo.getZonesForAdmin(),
    siteRepo.getSitesForAdmin(includeMeterCounts: false),
  ]);

  final orgs = results[0] as List<Organization>;
  final allZones = results[1] as List<Zone>;
  final allSites = results[2] as List<Site>;

  final zonesByOrg = <String, List<Zone>>{};
  for (final zone in allZones) {
    zonesByOrg.putIfAbsent(zone.organizationId, () => []).add(zone);
  }
  final sitesByOrg = <String, List<Site>>{};
  for (final site in allSites) {
    sitesByOrg.putIfAbsent(site.organizationId, () => []).add(site);
  }

  return StructureTreeData(
    organizations: orgs,
    zonesByOrg: zonesByOrg,
    sitesByOrg: sitesByOrg,
  );
});
