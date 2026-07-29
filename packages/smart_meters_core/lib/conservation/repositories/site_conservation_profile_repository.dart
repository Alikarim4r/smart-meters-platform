import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/site_conservation_profile.dart';

/// CRUD for [site_conservation_profiles].
class SiteConservationProfileRepository {
  SiteConservationProfileRepository(this._client);

  final SupabaseClient _client;
  static const _table = 'site_conservation_profiles';

  Future<SiteConservationProfile?> get(String siteId) async {
    final row = await _client
        .from(_table)
        .select()
        .eq('site_id', siteId)
        .maybeSingle();
    if (row == null) return null;
    return SiteConservationProfile.fromJson(Map<String, dynamic>.from(row));
  }

  Future<List<SiteConservationProfile>> listByPeerGroup(
    ConservationPeerGroup peerGroup,
  ) async {
    final rows = await _client
        .from(_table)
        .select()
        .eq('peer_group', peerGroup.dbValue);
    return (rows as List)
        .map((e) =>
            SiteConservationProfile.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<SiteConservationProfile> upsert({
    required String siteId,
    double? floorAreaM2,
    int? occupancyCount,
    ConservationPeerGroup? peerGroup,
    String? profileNotes,
    String? updatedBy,
  }) async {
    if (floorAreaM2 != null && floorAreaM2 <= 0) {
      throw ArgumentError('floor_area_m2 must be null or > 0');
    }
    if (occupancyCount != null && occupancyCount < 0) {
      throw ArgumentError('occupancy_count must be null or >= 0');
    }

    final payload = <String, dynamic>{
      'site_id': siteId,
      'floor_area_m2': floorAreaM2,
      'occupancy_count': occupancyCount,
      'peer_group': peerGroup?.dbValue,
      'profile_notes': profileNotes,
      'updated_by': ?updatedBy,
    };

    final row = await _client
        .from(_table)
        .upsert(payload, onConflict: 'site_id')
        .select()
        .single();
    return SiteConservationProfile.fromJson(Map<String, dynamic>.from(row));
  }

  Future<void> delete(String siteId) async {
    await _client.from(_table).delete().eq('site_id', siteId);
  }
}
