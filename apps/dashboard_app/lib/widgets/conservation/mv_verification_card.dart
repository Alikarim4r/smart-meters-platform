import 'package:flutter/material.dart';
import 'package:smart_meters_core/smart_meters_core.dart';

import '../../l10n/conservation_strings.dart';
import '../../theme/dashboard_palette.dart';
import '../../theme/design_system/dashboard_colors.dart';

/// M&V card — Estimated vs Verified clearly separated.
///
/// Potential Excess is never shown as a Saving label.
class MvVerificationCard extends StatelessWidget {
  const MvVerificationCard({
    super.key,
    required this.record,
    this.baselineVersionLabel,
    this.showCostRoi = true,
  });

  final MeasurementVerification record;
  final String? baselineVersionLabel;
  final bool showCostRoi;

  @override
  Widget build(BuildContext context) {
    final s = ConservationStrings.of(context);
    final statusColor = _statusColor(record.status);
    final estimated = record.estimatedSavingQuantity;
    final verified = record.verifiedSavingQuantity;
    final increased = estimated != null && estimated < 0;
    final shortId = record.baselineId.length > 8
        ? record.baselineId.substring(0, 8)
        : record.baselineId;

    return Card(
      elevation: 0,
      color: DashboardColors.card(context),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: statusColor.withValues(alpha: 0.45)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${record.utilityType} · M&V v${record.calculationVersion}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    record.status.dbValue,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _kv(
              s.estimatedSaving,
              estimated == null
                  ? '—'
                  : increased
                      ? '${s.noSavingIncreased}: '
                          '${_fmt(estimated)} ${record.unitCode}'
                      : '${_fmt(estimated)} ${record.unitCode}',
              emphasize: true,
            ),
            _kv(
              s.verifiedSaving,
              record.status == MvStatus.verified
                  ? (verified == null
                      ? '—'
                      : '${_fmt(verified)} ${record.unitCode}')
                  : '—',
              emphasize: true,
            ),
            if (record.resolvedPerformanceChangeQuantity != null)
              _kv(
                s.performanceChange,
                '${_fmt(record.resolvedPerformanceChangeQuantity!)} '
                '${record.unitCode}'
                '${record.isIncreasedConsumptionOutcome ? ' ${s.increasedNotInVerifiedTotal}' : ''}',
              ),
            if (showCostRoi)
              _kv(
                s.costAvoided,
                record.costAvoided == null
                    ? s.costAvoidedNa
                    : '${_fmt(record.costAvoided!)} '
                        '${record.costCurrency ?? 'QAR'}',
              ),
            _kv(s.confidence, '${record.confidenceScore}'),
            _kv(
              s.baseline,
              baselineVersionLabel ?? s.boundBaseline(shortId),
            ),
            _kv(
              s.postPeriod,
              '${_iso(record.postPeriodStart)} → ${_iso(record.postPeriodEnd)}',
            ),
            if (record.status == MvStatus.verificationPending) ...[
              const SizedBox(height: 6),
              Text(
                s.readyForVerification,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: DashboardPalette.navy,
                ),
              ),
            ],
            if (record.status == MvStatus.verified &&
                record.verifiedBy != null) ...[
              const SizedBox(height: 4),
              _kv(
                s.verifiedBy,
                record.verifiedAt == null
                    ? record.verifiedBy!
                    : '${record.verifiedBy} · ${_iso(record.verifiedAt!)}',
              ),
            ],
            if (record.needsRecalculation) ...[
              const SizedBox(height: 4),
              Text(
                '${s.needsRecalculation}'
                '${record.staleReason == null ? '' : ': ${record.staleReason}'}',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.orange.shade800,
                ),
              ),
            ],
            const SizedBox(height: 6),
            Text(
              s.terminologyChain,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: DashboardPalette.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Color _statusColor(MvStatus status) => switch (status) {
        MvStatus.verified => Colors.green.shade700,
        MvStatus.verificationPending => Colors.blue.shade700,
        MvStatus.estimated => Colors.teal.shade700,
        MvStatus.rejected => Colors.red.shade700,
        MvStatus.superseded || MvStatus.archived => Colors.grey.shade600,
        MvStatus.draft => DashboardPalette.navy,
      };

  static Widget _kv(String k, String v, {bool emphasize = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              k,
              style: TextStyle(
                fontSize: 12,
                fontWeight: emphasize ? FontWeight.w700 : FontWeight.w500,
                color: DashboardPalette.textMuted,
              ),
            ),
          ),
          Expanded(
            child: Text(
              v,
              style: TextStyle(
                fontSize: 12,
                fontWeight: emphasize ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _fmt(double v) {
    if (v == v.roundToDouble()) return v.toStringAsFixed(0);
    return v.toStringAsFixed(2);
  }

  static String _iso(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}
