import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/period_windows.dart';
import '../models/balance_classification.dart';

/// Persist human-reviewed Balance Difference classifications + audit list.
class BalanceClassificationRepository {
  BalanceClassificationRepository(this._client);

  final SupabaseClient _client;
  static const _table = 'conservation_balance_classifications';
  static const _audit = 'conservation_balance_classification_audit';

  /// Refuse auto Confirmed Leak — for UI / service callers before upsert.
  void assertHumanReviewed({
    required BalanceClassificationType classification,
    required bool humanReviewed,
    String? classifiedBy,
  }) {
    final err = BalanceClassificationRules.validateHumanClassification(
      classification: classification,
      humanReviewed: humanReviewed,
      classifiedBy: classifiedBy,
    );
    if (err != null) {
      throw StateError(err);
    }
  }

  Future<BalanceClassificationRecord?> getForPeriod({
    required String balanceGroupId,
    required DateTime periodStart,
    required DateTime periodEnd,
  }) async {
    final row = await _client
        .from(_table)
        .select()
        .eq('balance_group_id', balanceGroupId)
        .eq('period_start', _iso(periodStart))
        .eq('period_end', _iso(periodEnd))
        .maybeSingle();
    if (row == null) return null;
    return BalanceClassificationRecord.fromJson(
      Map<String, dynamic>.from(row),
    );
  }

  Future<List<BalanceClassificationRecord>> listForGroup(
    String balanceGroupId,
  ) async {
    final rows = await _client
        .from(_table)
        .select()
        .eq('balance_group_id', balanceGroupId)
        .order('period_start', ascending: false);
    return (rows as List)
        .map((e) => BalanceClassificationRecord.fromJson(
              Map<String, dynamic>.from(e as Map),
            ))
        .toList();
  }

  Future<List<BalanceClassificationAuditEntry>> listAudit(
    String classificationId,
  ) async {
    final rows = await _client
        .from(_audit)
        .select()
        .eq('classification_id', classificationId)
        .order('changed_at', ascending: false);
    return (rows as List)
        .map((e) => BalanceClassificationAuditEntry.fromJson(
              Map<String, dynamic>.from(e as Map),
            ))
        .toList();
  }

  /// Upsert classification for a group+period.
  ///
  /// Calls [assertHumanReviewed] when classification is confirmed_leak.
  Future<BalanceClassificationRecord> upsert({
    required String siteId,
    required String balanceGroupId,
    required DateTime periodStart,
    required DateTime periodEnd,
    required BalanceClassificationType classification,
    required bool humanReviewed,
    String? notes,
    List<dynamic> evidenceRefs = const [],
    double? balanceDifference,
    String? unitCode,
    String? classifiedBy,
  }) async {
    assertHumanReviewed(
      classification: classification,
      humanReviewed: humanReviewed,
      classifiedBy: classifiedBy,
    );

    final start = dateOnly(periodStart);
    final end = dateOnly(periodEnd);
    final existing = await getForPeriod(
      balanceGroupId: balanceGroupId,
      periodStart: start,
      periodEnd: end,
    );

    if (existing == null) {
      final inserted = await _client
          .from(_table)
          .insert({
            'site_id': siteId,
            'balance_group_id': balanceGroupId,
            'period_start': _iso(start),
            'period_end': _iso(end),
            'classification': classification.dbValue,
            'notes': notes,
            'evidence_refs': evidenceRefs,
            'balance_difference': balanceDifference,
            'unit_code': unitCode,
            'classified_by': ?classifiedBy,
          })
          .select()
          .single();
      return BalanceClassificationRecord.fromJson(
        Map<String, dynamic>.from(inserted),
      );
    }

    final updated = await _client
        .from(_table)
        .update({
          'classification': classification.dbValue,
          'notes': notes,
          'evidence_refs': evidenceRefs,
          'balance_difference': balanceDifference,
          'unit_code': unitCode,
          'classified_by': ?classifiedBy,
        })
        .eq('id', existing.id)
        .select()
        .single();
    return BalanceClassificationRecord.fromJson(
      Map<String, dynamic>.from(updated),
    );
  }

  static String _iso(DateTime d) {
    final x = dateOnly(d);
    return '${x.year.toString().padLeft(4, '0')}-'
        '${x.month.toString().padLeft(2, '0')}-'
        '${x.day.toString().padLeft(2, '0')}';
  }
}
