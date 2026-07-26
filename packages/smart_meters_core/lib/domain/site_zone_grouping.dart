import '../models/site.dart';
import '../models/zone.dart';

/// Groups sites by zone for dashboard navigation (zone-first drill-down).
class ZoneSiteGroup {
  const ZoneSiteGroup({
    required this.zoneId,
    required this.zoneName,
    required this.sites,
  });

  final String? zoneId;
  final String zoneName;
  final List<Site> sites;
}

/// Sentinel for admin site list filter: show sites with zone_id null.
const kNoZoneFilterValue = '__no_zone__';

List<ZoneSiteGroup> groupSitesByZone(List<Site> sites) {
  final grouped = <String?, List<Site>>{};
  for (final site in sites) {
    grouped.putIfAbsent(site.zoneId, () => []).add(site);
  }

  final keys = grouped.keys.toList()
    ..sort((a, b) {
      if (a == null) return 1;
      if (b == null) return -1;
      final nameA = grouped[a]!.first.displayZoneName;
      final nameB = grouped[b]!.first.displayZoneName;
      return nameA.compareTo(nameB);
    });

  return [
    for (final key in keys)
      ZoneSiteGroup(
        zoneId: key,
        zoneName: key == null
            ? kNoZoneLabel
            : grouped[key]!.first.displayZoneName,
        sites: List<Site>.from(grouped[key]!)
          ..sort((a, b) => a.nameEn.compareTo(b.nameEn)),
      ),
  ];
}

List<Site> filterSitesByZoneId(List<Site> sites, String? zoneFilterId) {
  if (zoneFilterId == null) {
    return sites;
  }
  if (zoneFilterId == kNoZoneFilterValue) {
    return sites.where((site) => site.zoneId == null).toList();
  }
  return sites.where((site) => site.zoneId == zoneFilterId).toList();
}
