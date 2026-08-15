/// Peer grouping for optional cross-site benchmarking.
enum ConservationPeerGroup {
  school('school'),
  office('office'),
  administrative('administrative'),
  largeSite('large_site'),
  smallSite('small_site'),
  other('other');

  const ConservationPeerGroup(this.dbValue);
  final String dbValue;

  static ConservationPeerGroup? fromDb(String? value) {
    if (value == null || value.isEmpty) return null;
    for (final e in ConservationPeerGroup.values) {
      if (e.dbValue == value) return e;
    }
    return null;
  }
}

/// Additive site metadata for intensity / benchmarking.
///
/// Missing floor area / occupancy → Normalization Data Missing (never invent).
class SiteConservationProfile {
  const SiteConservationProfile({
    required this.siteId,
    this.floorAreaM2,
    this.occupancyCount,
    this.peerGroup,
    this.profileNotes,
    this.updatedBy,
    this.createdAt,
    this.updatedAt,
  });

  final String siteId;
  final double? floorAreaM2;
  final int? occupancyCount;
  final ConservationPeerGroup? peerGroup;
  final String? profileNotes;
  final String? updatedBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get hasFloorArea => floorAreaM2 != null && floorAreaM2! > 0;
  bool get hasOccupancy => occupancyCount != null && occupancyCount! > 0;

  factory SiteConservationProfile.fromJson(Map<String, dynamic> json) {
    return SiteConservationProfile(
      siteId: json['site_id'] as String,
      floorAreaM2: (json['floor_area_m2'] as num?)?.toDouble(),
      occupancyCount: json['occupancy_count'] as int?,
      peerGroup: ConservationPeerGroup.fromDb(json['peer_group'] as String?),
      profileNotes: json['profile_notes'] as String?,
      updatedBy: json['updated_by'] as String?,
      createdAt: json['created_at'] == null
          ? null
          : DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] == null
          ? null
          : DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toInsertJson() => {
        'site_id': siteId,
        'floor_area_m2': floorAreaM2,
        'occupancy_count': occupancyCount,
        'peer_group': peerGroup?.dbValue,
        'profile_notes': profileNotes,
        'updated_by': ?updatedBy,
      };
}
