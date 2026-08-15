import 'period_windows.dart';

/// Deterministic opportunity dedupe key.
///
/// Components: site + source_type + entity + period + rule_version.
String buildOpportunityFingerprint({
  required String siteId,
  required String sourceType,
  required String sourceEntityKey,
  required DateTime periodStart,
  required DateTime periodEnd,
  required String ruleVersion,
}) {
  final start = dateOnly(periodStart);
  final end = dateOnly(periodEnd);
  return [
    siteId.trim(),
    sourceType.trim(),
    sourceEntityKey.trim(),
    _iso(start),
    _iso(end),
    ruleVersion.trim(),
  ].join('|');
}

String _iso(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';
