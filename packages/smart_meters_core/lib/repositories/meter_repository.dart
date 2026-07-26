import '../models/enums.dart';
import '../models/meter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MeterRepository {
  MeterRepository(this._client);

  final SupabaseClient _client;

  static const _adminSelect = '''
*,
meter_categories(*),
meter_sources(*),
meter_units(*),
sites(name_en, name_ar),
parent_meter:parent_meter_id(name_en, meter_code),
destination_tank:destination_tank_id(name_en, name_ar)
''';

  /// Prefer [getMetersForSiteAndCategoryId] with [MeterCategoryConfig].
  @Deprecated('Use getMetersForSiteAndCategoryId with category_id')
  Future<List<Meter>> getMetersForSiteAndCategory(
    String siteId,
    MeterCategory category,
  ) async {
    final rows = await _client
        .from('meters')
        .select()
        .eq('site_id', siteId)
        .eq('category', category.dbValue)
        .eq('is_active', true)
        .eq('meter_kind', 'physical')
        .eq('calculation_type', 'direct_reading')
        .order('sort_order')
        .order('name_en');

    return _mapMeters(rows);
  }

  Future<List<Meter>> getMetersForSiteAndCategoryId(
    String siteId,
    String categoryId,
  ) async {
    final rows = await _client
        .from('meters')
        .select()
        .eq('site_id', siteId)
        .eq('category_id', categoryId)
        .eq('is_active', true)
        .eq('meter_kind', 'physical')
        .eq('calculation_type', 'direct_reading')
        .order('sort_order')
        .order('name_en');

    return _mapMeters(rows);
  }

  /// All meters visible to the current admin user. RLS enforced.
  Future<List<Meter>> getMetersForAdmin({
    String? siteId,
    String? categoryId,
    bool? activeOnly,
    MeterLevel? level,
  }) async {
    var query = _client.from('meters').select(_adminSelect);

    if (siteId != null) {
      query = query.eq('site_id', siteId);
    }
    if (categoryId != null) {
      query = query.eq('category_id', categoryId);
    }
    if (activeOnly == true) {
      query = query.eq('is_active', true);
    } else if (activeOnly == false) {
      query = query.eq('is_active', false);
    }
    if (level != null) {
      query = query.eq('level', level.dbValue);
    }

    final rows = await query.order('sort_order').order('name_en');
    return _mapMeters(rows);
  }

  Future<List<Meter>> getMetersForSite(String siteId) {
    return getMetersForAdmin(siteId: siteId);
  }

  Future<Meter> getMeterById(String meterId) async {
    final row = await _client
        .from('meters')
        .select(_adminSelect)
        .eq('id', meterId)
        .single();
    return Meter.fromJson(Map<String, dynamic>.from(row));
  }

  Future<List<Meter>> getEligibleParentMeters({
    required String siteId,
    required String categoryId,
    required MeterLevel forLevel,
    String? excludeMeterId,
  }) async {
    final parentLevel = forLevel.requiredParentLevel;
    if (parentLevel == null) {
      return const [];
    }

    // Use full admin select — slim rows omit meter_kind/calculation_type and
    // break Meter.fromJson (TypeError → "unexpected error" in the form).
    var query = _client
        .from('meters')
        .select(_adminSelect)
        .eq('site_id', siteId)
        .eq('category_id', categoryId)
        .eq('level', parentLevel.dbValue)
        .eq('is_active', true)
        .order('sort_order')
        .order('name_en');

    final rows = await query;
    final meters = _mapMeters(rows);
    if (excludeMeterId == null) {
      return meters;
    }
    return meters.where((meter) => meter.id != excludeMeterId).toList();
  }

  Future<bool> meterHasReadings(String meterId) async {
    final rows = await _client
        .from('meter_readings')
        .select('id')
        .eq('meter_id', meterId)
        .limit(1);

    return (rows as List).isNotEmpty;
  }

  Future<Meter> createMeter({
    required String siteId,
    required String meterCode,
    required String nameEn,
    required String nameAr,
    required String categoryId,
    required String sourceId,
    required String unitId,
    String? meterTypeId,
    String? measurementTypeId,
    String? globalUnitId,
    MeterLevel level = MeterLevel.main,
    String? parentMeterId,
    bool poursIntoTank = false,
    String? destinationTankId,
    String? location,
    String? locationEn,
    String? locationAr,
    double meterMultiplier = 1,
    int sortOrder = 0,
    bool isActive = true,
    bool includeInDashboard = true,
  }) async {
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
          'meter_type_id': meterTypeId,
          'level': level.dbValue,
          'parent_meter_id': level.requiresParent ? parentMeterId : null,
          'pours_into_tank': poursIntoTank,
          'destination_tank_id': poursIntoTank ? destinationTankId : null,
          'location_en': _trimOrNull(locationEn ?? location),
          'location_ar': _trimOrNull(locationAr),
          'location': _trimOrNull(locationEn ?? location),
          'meter_kind': MeterKind.physical.dbValue,
          'calculation_type': CalculationType.directReading.dbValue,
          'meter_multiplier': meterMultiplier,
          'sort_order': sortOrder,
          'is_active': isActive,
          'include_in_dashboard': includeInDashboard,
        })
        .select(_adminSelect)
        .single();

    final meter = Meter.fromJson(Map<String, dynamic>.from(row));

    if (measurementTypeId != null && globalUnitId != null) {
      await _client.from('meter_registers').insert({
        'meter_id': meter.id,
        'measurement_type_id': measurementTypeId,
        'unit_id': globalUnitId,
        'is_primary': true,
        'name_en': 'Primary',
        'name_ar': 'رئيسي',
      });
    }

    return meter;
  }

  Future<Meter> updateMeter(
    String meterId, {
    String? meterCode,
    String? nameEn,
    String? nameAr,
    String? categoryId,
    String? sourceId,
    String? unitId,
    MeterLevel? level,
    String? parentMeterId,
    bool? poursIntoTank,
    String? destinationTankId,
    String? location,
    String? locationEn,
    String? locationAr,
    bool clearLocation = false,
    double? meterMultiplier,
    int? sortOrder,
    bool? isActive,
    bool? includeInDashboard,
    bool clearParent = false,
    bool clearDestinationTank = false,
  }) async {
    final payload = <String, dynamic>{};
    if (meterCode != null) payload['meter_code'] = meterCode;
    if (nameEn != null) payload['name_en'] = nameEn;
    if (nameAr != null) payload['name_ar'] = nameAr;
    if (categoryId != null) payload['category_id'] = categoryId;
    if (sourceId != null) payload['source_id'] = sourceId;
    if (unitId != null) payload['unit_id'] = unitId;
    if (level != null) payload['level'] = level.dbValue;
    if (clearParent) {
      payload['parent_meter_id'] = null;
    } else if (parentMeterId != null) {
      payload['parent_meter_id'] = parentMeterId;
    }
    if (poursIntoTank != null) payload['pours_into_tank'] = poursIntoTank;
    if (clearDestinationTank || poursIntoTank == false) {
      payload['destination_tank_id'] = null;
    } else if (destinationTankId != null) {
      payload['destination_tank_id'] = destinationTankId;
    }
    if (clearLocation) {
      payload['location'] = null;
      payload['location_en'] = null;
      payload['location_ar'] = null;
    } else {
      if (locationEn != null || location != null) {
        final en = _trimOrNull(locationEn ?? location);
        payload['location_en'] = en;
        payload['location'] = en;
      }
      if (locationAr != null) {
        payload['location_ar'] = _trimOrNull(locationAr);
      }
    }
    if (meterMultiplier != null) payload['meter_multiplier'] = meterMultiplier;
    if (sortOrder != null) payload['sort_order'] = sortOrder;
    if (isActive != null) payload['is_active'] = isActive;
    if (includeInDashboard != null) {
      payload['include_in_dashboard'] = includeInDashboard;
    }

    final row = await _client
        .from('meters')
        .update(payload)
        .eq('id', meterId)
        .select(_adminSelect)
        .single();

    return Meter.fromJson(Map<String, dynamic>.from(row));
  }

  Future<Meter> deactivateMeter(String meterId) {
    return updateMeter(meterId, isActive: false);
  }

  /// Restricted delete (site_admin). Fails if readings/children exist.
  Future<void> deleteMeter(String meterId) async {
    await _client.from('meters').delete().eq('id', meterId);
  }

  /// Super-admin cascade delete via RPC.
  Future<void> forceDeleteMeter(String meterId) async {
    await _client.rpc(
      'admin_force_delete_meter',
      params: {'p_meter_id': meterId},
    );
  }

  /// Legacy helper — queries by enum column. Use catalog + category_id instead.
  @Deprecated('Use MeterCatalogRepository.getCategoriesForSite')
  Future<List<MeterCategory>> getAvailableCategoriesForSite(
    String siteId,
  ) async {
    final rows = await _client
        .from('meters')
        .select('category')
        .eq('site_id', siteId)
        .eq('is_active', true)
        .eq('meter_kind', 'physical')
        .eq('calculation_type', 'direct_reading');

    final categories = <MeterCategory>{};
    for (final row in rows as List) {
      categories.add(MeterCategory.fromDb(row['category'] as String));
    }

    final ordered = MeterCategory.values
        .where(categories.contains)
        .toList(growable: false);
    return ordered;
  }

  List<Meter> _mapMeters(dynamic rows) {
    return (rows as List)
        .map((row) => Meter.fromJson(Map<String, dynamic>.from(row as Map)))
        .toList();
  }
}

String? _trimOrNull(String? value) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) return null;
  return trimmed;
}
