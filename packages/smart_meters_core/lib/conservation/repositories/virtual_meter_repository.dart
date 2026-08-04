import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/enums.dart';
import '../../models/meter.dart';
import '../../repositories/meter_repository.dart';
import '../domain/virtual_meter_validation.dart';

/// Members + create/update for virtual meters (does not alter physical create path).
class VirtualMeterRepository {
  VirtualMeterRepository(this._client);

  final SupabaseClient _client;
  static const _members = 'conservation_virtual_meter_members';

  MeterRepository get _meters => MeterRepository(_client);

  Future<List<String>> listMemberIds(String virtualMeterId) async {
    final rows = await _client
        .from(_members)
        .select('member_meter_id')
        .eq('virtual_meter_id', virtualMeterId);
    return [
      for (final row in (rows as List))
        (row as Map)['member_meter_id'] as String,
    ];
  }

  Future<Map<String, List<String>>> listMemberIdsForSite(String siteId) async {
    final virtuals = await _client
        .from('meters')
        .select('id')
        .eq('site_id', siteId)
        .eq('meter_kind', MeterKind.virtual.dbValue);
    final ids = [
      for (final row in (virtuals as List)) (row as Map)['id'] as String,
    ];
    if (ids.isEmpty) return {};
    final rows = await _client
        .from(_members)
        .select('virtual_meter_id, member_meter_id')
        .inFilter('virtual_meter_id', ids);
    final map = <String, List<String>>{};
    for (final row in (rows as List)) {
      final m = Map<String, dynamic>.from(row as Map);
      map
          .putIfAbsent(m['virtual_meter_id'] as String, () => [])
          .add(m['member_meter_id'] as String);
    }
    return map;
  }

  Future<List<Meter>> listVirtualMetersForSite(String siteId) async {
    final rows = await _client
        .from('meters')
        .select(MeterRepository.adminSelectPublic)
        .eq('site_id', siteId)
        .eq('meter_kind', MeterKind.virtual.dbValue)
        .order('sort_order')
        .order('name_en');
    return (rows as List)
        .map((e) => Meter.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  /// Create virtual meter + members. Physical meters are not mutated.
  Future<Meter> createVirtualMeter({
    required String siteId,
    required String meterCode,
    required String nameEn,
    required String nameAr,
    required String categoryId,
    required String sourceId,
    required String unitId,
    required CalculationType calculationType,
    required List<String> memberMeterIds,
    String? parentMeterId,
    double meterMultiplier = 1,
    int sortOrder = 0,
    bool includeInDashboard = true,
  }) async {
    if (calculationType != CalculationType.sumChildren &&
        calculationType != CalculationType.parentMinusChildren) {
      throw ArgumentError('Unsupported calculation_type');
    }
    if (calculationType == CalculationType.parentMinusChildren &&
        parentMeterId == null) {
      throw ArgumentError('parent_minus_children requires parentMeterId');
    }

    final siteMeters = await _meters.getMetersForSite(siteId);
    final byId = <String, Meter>{for (final m in siteMeters) m.id: m};
    final members = <Meter>[
      for (final id in memberMeterIds)
        if (byId[id] != null) byId[id]!,
    ];
    if (members.length != memberMeterIds.toSet().length) {
      throw StateError('One or more member meters not found on site.');
    }

    final sample = members.first;
    final unitCode = sample.baseUnit.isNotEmpty
        ? sample.baseUnit
        : sample.unitDisplayLabel;

    final validation = const VirtualMeterValidation().validateConfig(
      meterKind: MeterKind.virtual,
      calculationType: calculationType,
      siteId: siteId,
      categoryId: categoryId,
      unitCode: unitCode,
      parentMeterId: parentMeterId,
      memberMeters: members,
      metersById: byId,
      memberIdsByVirtualId: await listMemberIdsForSite(siteId),
    );
    if (!validation.ok) {
      throw StateError(
        'Virtual meter validation failed:\n- ${validation.issues.map((i) => i.message).join('\n- ')}',
      );
    }

    // sum_children → level main (no parent). parent_minus → level sub under parent.
    final level = calculationType == CalculationType.parentMinusChildren
        ? MeterLevel.sub
        : MeterLevel.main;

    final row = await _client
        .from('meters')
        .insert({
          'site_id': siteId,
          'meter_code': meterCode,
          'name_en': nameEn,
          'name_ar': nameAr,
          'category_id': categoryId,
          'source_id': sourceId,
          'unit_id': unitId,
          'level': level.dbValue,
          'parent_meter_id':
              calculationType == CalculationType.parentMinusChildren
                  ? parentMeterId
                  : null,
          'meter_kind': MeterKind.virtual.dbValue,
          'calculation_type': calculationType.dbValue,
          'meter_multiplier': meterMultiplier,
          'sort_order': sortOrder,
          'is_active': true,
          'include_in_dashboard': includeInDashboard,
        })
        .select(MeterRepository.adminSelectPublic)
        .single();

    final virtual = Meter.fromJson(Map<String, dynamic>.from(row));

    if (memberMeterIds.isNotEmpty) {
      await _client.from(_members).insert([
        for (final id in memberMeterIds.toSet())
          {
            'virtual_meter_id': virtual.id,
            'member_meter_id': id,
          },
      ]);
    }

    return virtual;
  }

  Future<void> replaceMembers({
    required String virtualMeterId,
    required List<String> memberMeterIds,
  }) async {
    final virtual = await _meters.getMeterById(virtualMeterId);
    if (virtual.meterKind != MeterKind.virtual) {
      throw StateError('Not a virtual meter');
    }
    final siteMeters = await _meters.getMetersForSite(virtual.siteId);
    final byId = <String, Meter>{for (final m in siteMeters) m.id: m};
    final members = <Meter>[
      for (final id in memberMeterIds)
        if (byId[id] != null) byId[id]!,
    ];
    final unitCode = virtual.baseUnit.isNotEmpty
        ? virtual.baseUnit
        : virtual.unitDisplayLabel;
    final memberMap = await listMemberIdsForSite(virtual.siteId);
    final validation = const VirtualMeterValidation().validateConfig(
      meterKind: MeterKind.virtual,
      calculationType: virtual.calculationType,
      siteId: virtual.siteId,
      categoryId: virtual.categoryId,
      unitCode: unitCode,
      parentMeterId: virtual.parentMeterId,
      memberMeters: members,
      metersById: byId,
      virtualMeterId: virtualMeterId,
      memberIdsByVirtualId: memberMap,
    );
    if (!validation.ok) {
      throw StateError(
        'Virtual meter validation failed:\n- ${validation.issues.map((i) => i.message).join('\n- ')}',
      );
    }

    await _client.from(_members).delete().eq('virtual_meter_id', virtualMeterId);
    if (memberMeterIds.isNotEmpty) {
      await _client.from(_members).insert([
        for (final id in memberMeterIds.toSet())
          {
            'virtual_meter_id': virtualMeterId,
            'member_meter_id': id,
          },
      ]);
    }
  }

  /// Delete virtual definition only. Refuses if another virtual lists it as member.
  Future<void> deleteVirtualMeter(String virtualMeterId) async {
    final virtual = await _meters.getMeterById(virtualMeterId);
    if (virtual.meterKind != MeterKind.virtual) {
      throw StateError('Refusing to delete non-virtual meter via this API.');
    }
    final deps = await _client
        .from(_members)
        .select('virtual_meter_id')
        .eq('member_meter_id', virtualMeterId)
        .limit(1);
    if ((deps as List).isNotEmpty) {
      throw StateError(
        'Virtual meter is a member of another virtual meter; remove dependency first.',
      );
    }
    // Members cascade via FK on virtual delete.
    await _client.from('meters').delete().eq('id', virtualMeterId);
  }
}
