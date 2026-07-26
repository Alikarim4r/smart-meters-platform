import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/site_tank.dart';

class SiteTankRepository {
  SiteTankRepository(this._client);

  final SupabaseClient _client;

  Future<List<SiteTank>> getTanksForSite(String siteId) async {
    final rows = await _client
        .from('site_tanks')
        .select()
        .eq('site_id', siteId)
        .order('name_en');
    return (rows as List)
        .map((row) => SiteTank.fromJson(Map<String, dynamic>.from(row as Map)))
        .toList();
  }

  Future<List<SiteTank>> getActiveTanksForSite(String siteId) async {
    final rows = await _client
        .from('site_tanks')
        .select()
        .eq('site_id', siteId)
        .eq('is_active', true)
        .order('name_en');
    return (rows as List)
        .map((row) => SiteTank.fromJson(Map<String, dynamic>.from(row as Map)))
        .toList();
  }

  Future<SiteTank> createTank({
    required String siteId,
    required String nameEn,
    String? nameAr,
  }) async {
    final row = await _client
        .from('site_tanks')
        .insert({
          'site_id': siteId,
          'name_en': nameEn.trim(),
          'name_ar': (nameAr == null || nameAr.trim().isEmpty)
              ? nameEn.trim()
              : nameAr.trim(),
          'is_active': true,
        })
        .select()
        .single();
    return SiteTank.fromJson(Map<String, dynamic>.from(row));
  }

  Future<void> deleteTank(String tankId) async {
    await _client.from('site_tanks').delete().eq('id', tankId);
  }
}
