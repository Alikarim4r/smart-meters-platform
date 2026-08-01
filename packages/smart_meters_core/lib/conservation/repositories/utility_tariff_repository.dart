import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/period_windows.dart';
import '../models/utility_tariff.dart';
import '../services/tariff_lookup_service.dart';

/// CRUD / lookup for `utility_tariffs`.
class UtilityTariffRepository {
  UtilityTariffRepository(this._client);

  final SupabaseClient _client;
  static const _table = 'utility_tariffs';
  static const _lookup = TariffLookupService();

  Future<UtilityTariff> create({
    required String organizationId,
    required String utilityType,
    required double rate,
    required String unitCode,
    required DateTime effectiveFrom,
    String currency = 'QAR',
    String? siteId,
    DateTime? effectiveTo,
    String? sourceNotes,
    String? createdBy,
  }) async {
    if (rate <= 0) {
      throw ArgumentError('tariff rate must be > 0 (never invent zero)');
    }
    final inserted = await _client
        .from(_table)
        .insert({
          'organization_id': organizationId,
          if (siteId != null) 'site_id': siteId,
          'utility_type': utilityType,
          'rate': rate,
          'currency': currency,
          'unit_code': unitCode,
          'effective_from': _isoDate(effectiveFrom),
          if (effectiveTo != null) 'effective_to': _isoDate(effectiveTo),
          'status': UtilityTariffStatus.active.dbValue,
          if (sourceNotes != null) 'source_notes': sourceNotes,
          if (createdBy != null) 'created_by': createdBy,
        })
        .select()
        .single();
    return UtilityTariff.fromJson(Map<String, dynamic>.from(inserted));
  }

  Future<UtilityTariff> get(String id) async {
    final row = await _client.from(_table).select().eq('id', id).single();
    return UtilityTariff.fromJson(Map<String, dynamic>.from(row));
  }

  /// Active tariffs for org (+ optional site) usable by [TariffLookupService].
  Future<List<UtilityTariff>> listActiveForLookup({
    required String organizationId,
    String? siteId,
    String? utilityType,
  }) async {
    var q = _client
        .from(_table)
        .select()
        .eq('organization_id', organizationId)
        .eq('status', UtilityTariffStatus.active.dbValue);
    if (utilityType != null) {
      q = q.eq('utility_type', utilityType);
    }
    final rows = await q.order('effective_from', ascending: false);
    final all = (rows as List)
        .map(
          (e) => UtilityTariff.fromJson(Map<String, dynamic>.from(e as Map)),
        )
        .toList();
    // Include org-wide (null site) and matching site-specific.
    return all
        .where((t) => t.siteId == null || (siteId != null && t.siteId == siteId))
        .toList();
  }

  /// Resolve applicable tariff; null → Cost Avoided N/A.
  Future<UtilityTariff?> resolveApplicable({
    required String organizationId,
    required String utilityType,
    required DateTime onDate,
    String? siteId,
    String? unitCode,
  }) async {
    final candidates = await listActiveForLookup(
      organizationId: organizationId,
      siteId: siteId,
      utilityType: utilityType,
    );
    return _lookup.resolve(
      candidates: candidates,
      organizationId: organizationId,
      utilityType: utilityType,
      onDate: onDate,
      siteId: siteId,
      unitCode: unitCode,
    );
  }

  Future<UtilityTariff> supersede({
    required String id,
    required DateTime effectiveTo,
  }) async {
    final updated = await _client
        .from(_table)
        .update({
          'status': UtilityTariffStatus.superseded.dbValue,
          'effective_to': _isoDate(effectiveTo),
        })
        .eq('id', id)
        .select()
        .single();
    return UtilityTariff.fromJson(Map<String, dynamic>.from(updated));
  }

  static String _isoDate(DateTime d) {
    final x = dateOnly(d);
    return '${x.year.toString().padLeft(4, '0')}-'
        '${x.month.toString().padLeft(2, '0')}-'
        '${x.day.toString().padLeft(2, '0')}';
  }
}
