import '../models/utility_tariff.dart';

/// Resolve applicable tariff by org / site / utility / date.
///
/// Preference: site-specific active tariff covering [onDate], else org-wide
/// (site_id null). Never invent rates — returns null when none match.
class TariffLookupService {
  const TariffLookupService();

  /// Pick the best matching tariff from an already-fetched candidate list.
  ///
  /// Callers typically load via [UtilityTariffRepository.listActiveForLookup].
  UtilityTariff? resolve({
    required List<UtilityTariff> candidates,
    required String organizationId,
    required String utilityType,
    required DateTime onDate,
    String? siteId,
    String? unitCode,
  }) {
    final matching = candidates.where((t) {
      if (t.organizationId != organizationId) return false;
      if (t.utilityType != utilityType) return false;
      if (t.status != UtilityTariffStatus.active) return false;
      if (!t.isEffectiveOn(onDate)) return false;
      if (unitCode != null &&
          unitCode.isNotEmpty &&
          t.unitCode != unitCode) {
        return false;
      }
      // Site-specific or org-wide only.
      if (t.siteId != null && siteId != null && t.siteId != siteId) {
        return false;
      }
      if (t.siteId != null && siteId == null) return false;
      return true;
    }).toList();

    if (matching.isEmpty) return null;

    // Prefer site-specific over org-wide.
    final siteSpecific = matching.where((t) => t.siteId != null).toList();
    final pool = siteSpecific.isNotEmpty ? siteSpecific : matching;

    // Prefer latest effective_from among ties.
    pool.sort((a, b) => b.effectiveFrom.compareTo(a.effectiveFrom));
    return pool.first;
  }
}
