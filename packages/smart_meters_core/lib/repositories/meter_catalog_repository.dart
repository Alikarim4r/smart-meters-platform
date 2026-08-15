import '../catalog/expanded_unit_catalog.dart';
import '../models/meter_category_config.dart';
import '../models/meter_source_config.dart';
import '../models/meter_type_config.dart';
import '../models/meter_unit_config.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MeterCatalogRepository {
  MeterCatalogRepository(this._client);

  final SupabaseClient _client;

  Future<List<MeterCategoryConfig>> getCategories({
    bool activeOnly = false,
  }) async {
    var query = _client.from('meter_categories').select();
    if (activeOnly) {
      query = query.eq('is_active', true);
    }
    final rows = await query.order('sort_order').order('name_en');

    return (rows as List)
        .map(
          (row) => MeterCategoryConfig.fromJson(
            Map<String, dynamic>.from(row as Map),
          ),
        )
        .toList();
  }

  Future<List<MeterCategoryConfig>> getActiveCategories() {
    return getCategories(activeOnly: true);
  }

  Future<MeterCategoryConfig> createCategory({
    required String code,
    required String nameEn,
    String? nameAr,
    required String baseUnitCode,
    String? icon,
    String? color,
    bool isSystem = false,
    bool isActive = true,
    int sortOrder = 0,
    bool supportsCopOutput = false,
    bool supportsElectricInput = false,
    bool isConsumptionCategory = true,
  }) async {
    final row = await _client
        .from('meter_categories')
        .insert({
          'code': code,
          'name_en': nameEn,
          'name_ar': nameAr,
          'base_unit_code': baseUnitCode,
          'icon': icon,
          'color': color,
          'is_system': isSystem,
          'is_active': isActive,
          'sort_order': sortOrder,
          'supports_cop_output': supportsCopOutput,
          'supports_electric_input': supportsElectricInput,
          'is_consumption_category': isConsumptionCategory,
        })
        .select()
        .single();

    return MeterCategoryConfig.fromJson(Map<String, dynamic>.from(row));
  }

  Future<MeterCategoryConfig> updateCategory(
    String id, {
    String? code,
    String? nameEn,
    String? nameAr,
    String? baseUnitCode,
    String? icon,
    String? color,
    bool? isActive,
    int? sortOrder,
    bool? supportsCopOutput,
    bool? supportsElectricInput,
    bool? isConsumptionCategory,
  }) async {
    final payload = <String, dynamic>{};
    if (code != null) payload['code'] = code;
    if (nameEn != null) payload['name_en'] = nameEn;
    if (nameAr != null) payload['name_ar'] = nameAr;
    if (baseUnitCode != null) payload['base_unit_code'] = baseUnitCode;
    if (icon != null) payload['icon'] = icon;
    if (color != null) payload['color'] = color;
    if (isActive != null) payload['is_active'] = isActive;
    if (sortOrder != null) payload['sort_order'] = sortOrder;
    if (supportsCopOutput != null) {
      payload['supports_cop_output'] = supportsCopOutput;
    }
    if (supportsElectricInput != null) {
      payload['supports_electric_input'] = supportsElectricInput;
    }
    if (isConsumptionCategory != null) {
      payload['is_consumption_category'] = isConsumptionCategory;
    }

    final row = await _client
        .from('meter_categories')
        .update(payload)
        .eq('id', id)
        .select()
        .single();

    return MeterCategoryConfig.fromJson(Map<String, dynamic>.from(row));
  }

  Future<void> deleteCategory(String id) async {
    await _client.from('meter_categories').delete().eq('id', id);
  }

  Future<List<MeterUnitConfig>> getUnitsForCategory(
    String categoryId, {
    bool activeOnly = false,
  }) async {
    List<MeterUnitConfig> parseRows(dynamic rows) {
      final out = <MeterUnitConfig>[];
      for (final row in (rows as List)) {
        try {
          final map = Map<String, dynamic>.from(row as Map);
          map.remove('meter_categories');
          out.add(MeterUnitConfig.fromJson(map));
        } catch (_) {}
      }
      return out;
    }

    Future<List<MeterUnitConfig>> fetchForIds(List<String> ids) async {
      if (ids.isEmpty) return const [];
      var query = _client.from('meter_units').select().inFilter('category_id', ids);
      if (activeOnly) {
        query = query.eq('is_active', true);
      }
      return parseRows(
        await query.order('sort_order').order('name_en').limit(200),
      );
    }

    var units = await fetchForIds([categoryId]);

    // Staging sometimes has expanded rows under a sibling category id with the
    // same code. Prefer the fullest active catalog for that code.
    if (units.length < 10) {
      try {
        final catRows = await _client
            .from('meter_categories')
            .select('code')
            .eq('id', categoryId)
            .limit(1);
        if ((catRows as List).isNotEmpty) {
          final code = (catRows.first as Map)['code']?.toString();
          if (code != null && code.isNotEmpty) {
            final sameCode = await _client
                .from('meter_categories')
                .select('id')
                .eq('code', code);
            final ids = (sameCode as List)
                .map((r) => (r as Map)['id']?.toString())
                .whereType<String>()
                .toList();
            final byCode = await fetchForIds(ids);
            if (byCode.length > units.length) {
              units = byCode;
            }
          }
        }
      } catch (_) {
        // Keep category_id-only result.
      }
    }

    if (activeOnly) {
      units = units.where((u) => u.isActive).toList();
    }
    return units;
  }

  /// Inserts missing standard units (≥12) for a known category code.
  /// Requires super-admin insert rights. Returns how many rows were created.
  Future<int> ensureExpandedUnitsForCategory({
    required String categoryId,
    required String categoryCode,
  }) async {
    final specs = ExpandedUnitCatalog.forCategoryCode(categoryCode);
    if (specs.isEmpty) return 0;

    final existing = await getUnitsForCategory(categoryId);
    final byCode = {
      for (final u in existing) u.code.toLowerCase(): u,
    };

    var created = 0;
    for (final spec in specs) {
      final key = spec.code.toLowerCase();
      final current = byCode[key];
      if (current != null) {
        // Re-activate / refresh labels if still present but inactive/stale.
        if (!current.isActive ||
            current.nameEn != spec.nameEn ||
            current.sortOrder != spec.sortOrder) {
          try {
            await updateUnit(
              current.id,
              nameEn: spec.nameEn,
              nameAr: spec.nameAr,
              unitToBaseFactor: spec.unitToBaseFactor,
              isBase: spec.isBase,
              isActive: true,
              sortOrder: spec.sortOrder,
            );
          } catch (_) {}
        }
        continue;
      }
      try {
        await createUnit(
          categoryId: categoryId,
          code: spec.code,
          nameEn: spec.nameEn,
          nameAr: spec.nameAr,
          unitToBaseFactor: spec.unitToBaseFactor,
          isBase: spec.isBase,
          isActive: true,
          sortOrder: spec.sortOrder,
        );
        created++;
      } catch (_) {
        // RLS / unique race — continue remaining units.
      }
    }
    return created;
  }

  Future<MeterUnitConfig> createUnit({
    required String categoryId,
    required String code,
    required String nameEn,
    String? nameAr,
    required double unitToBaseFactor,
    bool isBase = false,
    bool isActive = true,
    int sortOrder = 0,
  }) async {
    final row = await _client
        .from('meter_units')
        .insert({
          'category_id': categoryId,
          'code': code,
          'name_en': nameEn,
          'name_ar': nameAr,
          'unit_to_base_factor': unitToBaseFactor,
          'is_base': isBase,
          'is_active': isActive,
          'sort_order': sortOrder,
        })
        .select()
        .single();

    return MeterUnitConfig.fromJson(Map<String, dynamic>.from(row));
  }

  Future<MeterUnitConfig> updateUnit(
    String id, {
    String? code,
    String? nameEn,
    String? nameAr,
    double? unitToBaseFactor,
    bool? isBase,
    bool? isActive,
    int? sortOrder,
  }) async {
    final payload = <String, dynamic>{};
    if (code != null) payload['code'] = code;
    if (nameEn != null) payload['name_en'] = nameEn;
    if (nameAr != null) payload['name_ar'] = nameAr;
    if (unitToBaseFactor != null) {
      payload['unit_to_base_factor'] = unitToBaseFactor;
    }
    if (isBase != null) payload['is_base'] = isBase;
    if (isActive != null) payload['is_active'] = isActive;
    if (sortOrder != null) payload['sort_order'] = sortOrder;

    final row = await _client
        .from('meter_units')
        .update(payload)
        .eq('id', id)
        .select()
        .single();

    return MeterUnitConfig.fromJson(Map<String, dynamic>.from(row));
  }

  Future<void> deleteUnit(String id) async {
    await _client.from('meter_units').delete().eq('id', id);
  }

  Future<List<MeterSourceConfig>> getSourcesForCategory(
    String categoryId, {
    bool activeOnly = false,
  }) async {
    var query = _client
        .from('meter_sources')
        .select()
        .eq('category_id', categoryId);
    if (activeOnly) {
      query = query.eq('is_active', true);
    }
    final rows = await query.order('sort_order').order('name_en');

    return (rows as List)
        .map(
          (row) =>
              MeterSourceConfig.fromJson(Map<String, dynamic>.from(row as Map)),
        )
        .toList();
  }

  Future<MeterSourceConfig> createSource({
    required String categoryId,
    required String code,
    required String nameEn,
    String? nameAr,
    bool isActive = true,
    int sortOrder = 0,
  }) async {
    final row = await _client
        .from('meter_sources')
        .insert({
          'category_id': categoryId,
          'code': code,
          'name_en': nameEn,
          'name_ar': nameAr,
          'is_active': isActive,
          'sort_order': sortOrder,
        })
        .select()
        .single();

    return MeterSourceConfig.fromJson(Map<String, dynamic>.from(row));
  }

  Future<MeterSourceConfig> updateSource(
    String id, {
    String? code,
    String? nameEn,
    String? nameAr,
    bool? isActive,
    int? sortOrder,
  }) async {
    final payload = <String, dynamic>{};
    if (code != null) payload['code'] = code;
    if (nameEn != null) payload['name_en'] = nameEn;
    if (nameAr != null) payload['name_ar'] = nameAr;
    if (isActive != null) payload['is_active'] = isActive;
    if (sortOrder != null) payload['sort_order'] = sortOrder;

    final row = await _client
        .from('meter_sources')
        .update(payload)
        .eq('id', id)
        .select()
        .single();

    return MeterSourceConfig.fromJson(Map<String, dynamic>.from(row));
  }

  Future<void> deleteSource(String id) async {
    await _client.from('meter_sources').delete().eq('id', id);
  }

  /// Active categories that have at least one active entry-eligible meter at [siteId].
  Future<List<MeterCategoryConfig>> getCategoriesForSite(String siteId) async {
    final rows = await _client
        .from('meters')
        .select('category_id, meter_categories(*)')
        .eq('site_id', siteId)
        .eq('is_active', true)
        .eq('meter_kind', 'physical')
        .eq('calculation_type', 'direct_reading');

    final byId = <String, MeterCategoryConfig>{};
    for (final row in rows as List) {
      final categoryJson = row['meter_categories'];
      if (categoryJson == null) {
        continue;
      }
      final config = MeterCategoryConfig.fromJson(
        Map<String, dynamic>.from(categoryJson as Map),
      );
      if (config.isActive) {
        byId[config.id] = config;
      }
    }

    final categories = byId.values.toList()
      ..sort((a, b) {
        final order = a.sortOrder.compareTo(b.sortOrder);
        if (order != 0) {
          return order;
        }
        return a.nameEn.compareTo(b.nameEn);
      });
    return categories;
  }

  // ---- Phase 2: meter type → measurement → unit -----------------------------

  Future<List<MeterTypeConfig>> getMeterTypes({bool activeOnly = true}) async {
    var query = _client.from('meter_types').select();
    if (activeOnly) query = query.eq('is_active', true);
    final rows = await query.order('sort_order').order('name_en');
    return (rows as List)
        .map(
          (row) =>
              MeterTypeConfig.fromJson(Map<String, dynamic>.from(row as Map)),
        )
        .toList();
  }

  Future<List<MeasurementTypeConfig>> getMeasurementsForMeterType(
    String meterTypeId,
  ) async {
    final rows = await _client
        .from('meter_type_measurements')
        .select('is_primary, sort_order, measurement_types(*)')
        .eq('meter_type_id', meterTypeId)
        .order('sort_order');

    final out = <MeasurementTypeConfig>[];
    for (final row in rows as List) {
      final mt = row['measurement_types'];
      if (mt is Map) {
        out.add(MeasurementTypeConfig.fromJson(Map<String, dynamic>.from(mt)));
      }
    }
    return out;
  }

  Future<List<GlobalUnitConfig>> getUnitsForMeasurement(
    String measurementTypeId,
  ) async {
    final rows = await _client
        .from('measurement_units')
        .select('is_default, sort_order, units(*)')
        .eq('measurement_type_id', measurementTypeId)
        .order('sort_order');

    final out = <GlobalUnitConfig>[];
    for (final row in rows as List) {
      final u = row['units'];
      if (u is Map) {
        out.add(GlobalUnitConfig.fromJson(Map<String, dynamic>.from(u)));
      }
    }
    return out;
  }

  Future<String?> resolveMeterTypeIdForCategory(String categoryId) async {
    final rows = await _client
        .from('meter_types')
        .select('id')
        .eq('legacy_category_id', categoryId)
        .limit(1);
    if ((rows as List).isEmpty) return null;
    return (rows.first as Map)['id'] as String?;
  }

  /// Maps a global units.code onto meter_units.id for the given category.
  Future<String?> resolveLegacyUnitId({
    required String categoryId,
    required String globalUnitCode,
  }) async {
    final candidates = _unitCodeCandidates(globalUnitCode);
    for (final code in candidates) {
      final rows = await _client
          .from('meter_units')
          .select('id')
          .eq('category_id', categoryId)
          .ilike('code', code)
          .limit(1);
      if ((rows as List).isNotEmpty) {
        return (rows.first as Map)['id'] as String?;
      }
    }

    // Fallback: any unit in category with same base preference
    final fallback = await _client
        .from('meter_units')
        .select('id')
        .eq('category_id', categoryId)
        .eq('is_active', true)
        .order('sort_order')
        .limit(1);
    if ((fallback as List).isEmpty) return null;
    return (fallback.first as Map)['id'] as String?;
  }

  /// Looks up a Phase-2 global unit id for register creation (optional).
  Future<String?> findGlobalUnitIdByCode(String code) async {
    final candidates = _unitCodeCandidates(code);
    for (final candidate in candidates) {
      final rows = await _client
          .from('units')
          .select('id')
          .ilike('code', candidate)
          .limit(1);
      if ((rows as List).isNotEmpty) {
        return (rows.first as Map)['id'] as String?;
      }
    }
    return null;
  }

  /// Global unit codes → legacy meter_units codes (Phase-2 ↔ catalog).
  static List<String> _unitCodeCandidates(String globalUnitCode) {
    final raw = globalUnitCode.trim();
    final lower = raw.toLowerCase();
    const aliases = <String, List<String>>{
      'l': ['liter', 'L', 'l'],
      'litre': ['liter'],
      'liter': ['liter', 'L'],
      'gal_us': ['gallon', 'gal_us'],
      'us_gal': ['gallon'],
      'gallon': ['gallon', 'gal_us'],
      'ml': ['ml', 'mL'],
      'mL': ['ml', 'mL'],
      'dm³': ['dm3'],
      'm³': ['m3'],
      'ft³': ['ft3'],
      'yd³': ['yd3'],
      'cm³': ['cm3'],
      'kwh': ['kwh', 'kWh', 'kwh_thermal'],
      'kWh': ['kwh', 'kWh', 'kwh_thermal'],
      'mwh': ['mwh', 'MWh'],
      'MWh': ['mwh', 'MWh'],
      'gwh': ['gwh', 'GWh'],
      'GWh': ['gwh', 'GWh'],
      'wh': ['wh', 'Wh', 'wh_thermal'],
      'Wh': ['wh', 'Wh', 'wh_thermal'],
      'kwh_thermal': ['kwh_thermal', 'kwh', 'kWh'],
      'wh_thermal': ['wh_thermal', 'wh', 'Wh'],
      'gj': ['gj', 'GJ'],
      'GJ': ['gj', 'GJ'],
      'mj': ['mj', 'MJ'],
      'MJ': ['mj', 'MJ'],
      'kj': ['kj', 'kJ'],
      'kJ': ['kj', 'kJ'],
      'j': ['j', 'J'],
      'J': ['j', 'J'],
      'btu': ['btu', 'BTU'],
      'BTU': ['btu', 'BTU'],
      'kbtu': ['kbtu', 'kBTU'],
      'kBTU': ['kbtu', 'kBTU'],
      'mmbtu': ['mmbtu', 'MMBtu'],
      'MMBtu': ['mmbtu', 'MMBtu'],
    };

    final out = <String>{raw, lower};
    final mapped = aliases[raw] ?? aliases[lower];
    if (mapped != null) out.addAll(mapped);
    return out.toList();
  }
}
