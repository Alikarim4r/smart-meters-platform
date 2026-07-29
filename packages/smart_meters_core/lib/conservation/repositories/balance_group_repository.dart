import 'package:supabase_flutter/supabase_flutter.dart';

enum BalanceGroupStatus {
  draft('draft'),
  active('active'),
  archived('archived');

  const BalanceGroupStatus(this.dbValue);
  final String dbValue;

  static BalanceGroupStatus fromDb(String value) =>
      BalanceGroupStatus.values.firstWhere(
        (e) => e.dbValue == value,
        orElse: () => BalanceGroupStatus.draft,
      );
}

/// conservation_balance_groups row.
class BalanceGroup {
  const BalanceGroup({
    required this.id,
    required this.siteId,
    required this.name,
    required this.utilityCode,
    required this.unitCode,
    required this.mainMeterId,
    required this.status,
    this.virtualMeterId,
    this.notes,
    this.createdBy,
    this.createdAt,
    this.updatedAt,
    this.memberMeterIds = const [],
  });

  final String id;
  final String siteId;
  final String name;
  final String utilityCode;
  final String unitCode;
  final String mainMeterId;
  final String? virtualMeterId;
  final BalanceGroupStatus status;
  final String? notes;
  final String? createdBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final List<String> memberMeterIds;

  factory BalanceGroup.fromJson(
    Map<String, dynamic> json, {
    List<String> memberMeterIds = const [],
  }) {
    return BalanceGroup(
      id: json['id'] as String,
      siteId: json['site_id'] as String,
      name: json['name'] as String,
      utilityCode: json['utility_code'] as String,
      unitCode: json['unit_code'] as String,
      mainMeterId: json['main_meter_id'] as String,
      virtualMeterId: json['virtual_meter_id'] as String?,
      status: BalanceGroupStatus.fromDb(json['status'] as String? ?? 'active'),
      notes: json['notes'] as String?,
      createdBy: json['created_by'] as String?,
      createdAt: json['created_at'] == null
          ? null
          : DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] == null
          ? null
          : DateTime.parse(json['updated_at'] as String),
      memberMeterIds: memberMeterIds,
    );
  }
}

/// CRUD for balance groups + members.
class BalanceGroupRepository {
  BalanceGroupRepository(this._client);

  final SupabaseClient _client;
  static const _groups = 'conservation_balance_groups';
  static const _members = 'conservation_balance_group_members';

  Future<List<BalanceGroup>> listForSite(String siteId) async {
    final rows = await _client
        .from(_groups)
        .select()
        .eq('site_id', siteId)
        .order('name');
    final groups = (rows as List)
        .map((e) => BalanceGroup.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    if (groups.isEmpty) return groups;

    final ids = groups.map((g) => g.id).toList();
    final memberRows = await _client
        .from(_members)
        .select('balance_group_id, member_meter_id')
        .inFilter('balance_group_id', ids);
    final byGroup = <String, List<String>>{};
    for (final row in (memberRows as List)) {
      final m = Map<String, dynamic>.from(row as Map);
      byGroup
          .putIfAbsent(m['balance_group_id'] as String, () => [])
          .add(m['member_meter_id'] as String);
    }
    return [
      for (final g in groups)
        BalanceGroup.fromJson(
          {
            'id': g.id,
            'site_id': g.siteId,
            'name': g.name,
            'utility_code': g.utilityCode,
            'unit_code': g.unitCode,
            'main_meter_id': g.mainMeterId,
            'virtual_meter_id': g.virtualMeterId,
            'status': g.status.dbValue,
            'notes': g.notes,
            'created_by': g.createdBy,
            'created_at': g.createdAt?.toIso8601String(),
            'updated_at': g.updatedAt?.toIso8601String(),
          },
          memberMeterIds: byGroup[g.id] ?? const [],
        ),
    ];
  }

  Future<BalanceGroup?> getById(String id) async {
    final row = await _client.from(_groups).select().eq('id', id).maybeSingle();
    if (row == null) return null;
    final members = await listMemberIds(id);
    return BalanceGroup.fromJson(
      Map<String, dynamic>.from(row),
      memberMeterIds: members,
    );
  }

  Future<List<String>> listMemberIds(String balanceGroupId) async {
    final rows = await _client
        .from(_members)
        .select('member_meter_id')
        .eq('balance_group_id', balanceGroupId);
    return [
      for (final row in (rows as List))
        (row as Map)['member_meter_id'] as String,
    ];
  }

  Future<BalanceGroup> create({
    required String siteId,
    required String name,
    required String utilityCode,
    required String unitCode,
    required String mainMeterId,
    required List<String> memberMeterIds,
    String? virtualMeterId,
    BalanceGroupStatus status = BalanceGroupStatus.active,
    String? notes,
    String? createdBy,
  }) async {
    final utility = utilityCode.trim().toLowerCase();
    if (utility != 'water' && utility != 'electricity') {
      throw ArgumentError('utility_code must be water|electricity');
    }
    if (name.trim().isEmpty) {
      throw ArgumentError('name required');
    }
    if (memberMeterIds.contains(mainMeterId)) {
      throw ArgumentError('main meter cannot also be a member');
    }

    final inserted = await _client
        .from(_groups)
        .insert({
          'site_id': siteId,
          'name': name.trim(),
          'utility_code': utility,
          'unit_code': unitCode,
          'main_meter_id': mainMeterId,
          'virtual_meter_id': virtualMeterId,
          'status': status.dbValue,
          'notes': notes,
          'created_by': ?createdBy,
        })
        .select()
        .single();

    final group = BalanceGroup.fromJson(Map<String, dynamic>.from(inserted));
    if (memberMeterIds.isNotEmpty) {
      await _client.from(_members).insert([
        for (final id in memberMeterIds.toSet())
          {
            'balance_group_id': group.id,
            'member_meter_id': id,
          },
      ]);
    }
    return BalanceGroup.fromJson(
      Map<String, dynamic>.from(inserted),
      memberMeterIds: memberMeterIds.toSet().toList(),
    );
  }

  Future<BalanceGroup> update({
    required String id,
    String? name,
    String? unitCode,
    String? mainMeterId,
    String? virtualMeterId,
    BalanceGroupStatus? status,
    String? notes,
    List<String>? memberMeterIds,
  }) async {
    final payload = <String, dynamic>{
      if (name != null) 'name': name.trim(),
      if (unitCode != null) 'unit_code': unitCode,
      if (mainMeterId != null) 'main_meter_id': mainMeterId,
      if (virtualMeterId != null) 'virtual_meter_id': virtualMeterId,
      if (status != null) 'status': status.dbValue,
      if (notes != null) 'notes': notes,
    };
    Map<String, dynamic> row;
    if (payload.isEmpty) {
      row = Map<String, dynamic>.from(
        await _client.from(_groups).select().eq('id', id).single(),
      );
    } else {
      row = Map<String, dynamic>.from(
        await _client
            .from(_groups)
            .update(payload)
            .eq('id', id)
            .select()
            .single(),
      );
    }

    if (memberMeterIds != null) {
      final main = row['main_meter_id'] as String;
      if (memberMeterIds.contains(main)) {
        throw ArgumentError('main meter cannot also be a member');
      }
      await _client.from(_members).delete().eq('balance_group_id', id);
      if (memberMeterIds.isNotEmpty) {
        await _client.from(_members).insert([
          for (final mid in memberMeterIds.toSet())
            {
              'balance_group_id': id,
              'member_meter_id': mid,
            },
        ]);
      }
    }

    final members = memberMeterIds?.toSet().toList() ?? await listMemberIds(id);
    return BalanceGroup.fromJson(row, memberMeterIds: members);
  }

  Future<void> delete(String id) async {
    // Members cascade via FK.
    await _client.from(_groups).delete().eq('id', id);
  }
}
