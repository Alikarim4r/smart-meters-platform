import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/cop_group_models.dart';

/// CRUD for site COP/EER meter groups (`cop_groups` + junction tables).
class CopGroupRepository {
  CopGroupRepository(this._client);

  final SupabaseClient _client;

  Future<List<CopGroupDetail>> listForSite(String siteId) async {
    final rows = await _client
        .from('cop_groups')
        .select(
          'id, site_id, name_en, name_ar, description, is_active, '
          'cop_group_btu_meters(meter_id), '
          'cop_group_electricity_meters(meter_id)',
        )
        .eq('site_id', siteId)
        .order('name_en');

    return (rows as List)
        .map((row) => _fromRow(Map<String, dynamic>.from(row as Map)))
        .toList();
  }

  Future<CopGroupDetail> getById(String id) async {
    final row = await _client
        .from('cop_groups')
        .select(
          'id, site_id, name_en, name_ar, description, is_active, '
          'cop_group_btu_meters(meter_id), '
          'cop_group_electricity_meters(meter_id)',
        )
        .eq('id', id)
        .single();
    return _fromRow(Map<String, dynamic>.from(row));
  }

  Future<CopGroupDetail> upsert(CopGroupUpsertInput input) async {
    final payload = <String, dynamic>{
      'site_id': input.siteId,
      'name_en': input.nameEn.trim(),
      'name_ar': input.nameAr.trim(),
      'description': input.description?.trim(),
      'is_active': input.isActive,
    };

    final String groupId;
    if (input.id == null) {
      final inserted = await _client
          .from('cop_groups')
          .insert(payload)
          .select('id')
          .single();
      groupId = inserted['id'] as String;
    } else {
      groupId = input.id!;
      await _client.from('cop_groups').update(payload).eq('id', groupId);
    }

    await _replaceLinks(
      groupId: groupId,
      table: 'cop_group_btu_meters',
      meterIds: input.btuMeterIds,
    );
    await _replaceLinks(
      groupId: groupId,
      table: 'cop_group_electricity_meters',
      meterIds: input.electricityMeterIds,
    );

    return getById(groupId);
  }

  Future<void> delete(String id) async {
    await _client.from('cop_groups').delete().eq('id', id);
  }

  Future<void> _replaceLinks({
    required String groupId,
    required String table,
    required List<String> meterIds,
  }) async {
    await _client.from(table).delete().eq('cop_group_id', groupId);
    final unique = <String>{
      for (final id in meterIds)
        if (id.trim().isNotEmpty) id.trim(),
    };
    if (unique.isEmpty) return;
    await _client.from(table).insert([
      for (final meterId in unique)
        {'cop_group_id': groupId, 'meter_id': meterId, 'weight': 1},
    ]);
  }

  CopGroupDetail _fromRow(Map<String, dynamic> map) {
    return CopGroupDetail(
      id: map['id'] as String,
      siteId: map['site_id'] as String,
      nameEn: map['name_en'] as String? ?? '',
      nameAr: map['name_ar'] as String? ?? '',
      description: map['description'] as String?,
      isActive: map['is_active'] as bool? ?? true,
      btuMeterIds: _meterIds(map['cop_group_btu_meters']),
      electricityMeterIds: _meterIds(map['cop_group_electricity_meters']),
    );
  }

  List<String> _meterIds(Object? raw) {
    if (raw is! List) return const [];
    return [
      for (final item in raw)
        if (item is Map && item['meter_id'] != null)
          item['meter_id'] as String,
    ];
  }
}
