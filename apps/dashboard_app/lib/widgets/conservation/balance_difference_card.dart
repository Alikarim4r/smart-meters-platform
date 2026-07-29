import 'package:flutter/material.dart';
import 'package:smart_meters_core/smart_meters_core.dart';

import '../../theme/dashboard_palette.dart';
import '../../theme/design_system/dashboard_colors.dart';

/// Visual-priority Balance Difference card.
/// Labels: Balance Difference / Residual only — never Leak.
class BalanceDifferenceCard extends StatelessWidget {
  const BalanceDifferenceCard({
    super.key,
    required this.groupName,
    required this.result,
    this.mainMeterName,
    this.submeterNames = const [],
  });

  final String groupName;
  final BalanceResult result;
  final String? mainMeterName;
  final List<String> submeterNames;

  @override
  Widget build(BuildContext context) {
    final insufficient = result.isInsufficient;
    final needsReview = result.reviewStatus == 'Requires Review';
    return Card(
      elevation: 0,
      color: DashboardColors.card(context),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: needsReview
              ? DashboardPalette.navy.withValues(alpha: 0.55)
              : DashboardPalette.border.withValues(alpha: 0.7),
          width: needsReview ? 1.4 : 1,
        ),
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
                    '${result.utilityCode.toUpperCase()} · $groupName',
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
                    color: needsReview
                        ? DashboardPalette.navy.withValues(alpha: 0.12)
                        : DashboardPalette.border.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    result.reviewStatus,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: DashboardPalette.navy,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              result.directionLabel,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: insufficient
                    ? DashboardPalette.textMuted
                    : DashboardPalette.navy,
              ),
            ),
            const SizedBox(height: 10),
            _kv('Main', _meterLine(mainMeterName, result.mainMeterId,
                result.mainConsumption, result.unitCode)),
            _kv(
              'Submeters',
              submeterNames.isEmpty
                  ? '${result.childMeterIds.length} meters · '
                      '${_fmt(result.childrenConsumption, result.unitCode)}'
                  : '${submeterNames.join(', ')} · '
                      '${_fmt(result.childrenConsumption, result.unitCode)}',
            ),
            _kv(
              'Balance Difference',
              insufficient
                  ? 'Insufficient Data'
                  : _fmt(result.balanceDifference, result.unitCode),
            ),
            _kv(
              '%',
              result.balancePercentage == null
                  ? 'N/A'
                  : '${result.balancePercentage!.toStringAsFixed(1)}%',
            ),
            _kv('Confidence', '${result.confidenceScore}'),
            _kv('Alignment', _alignmentLabel(result.alignmentStatus)),
            const SizedBox(height: 8),
            Text(
              'Status: ${result.reviewStatus}. Never Leak.',
              style: TextStyle(fontSize: 11, color: DashboardPalette.textMuted),
            ),
            if (result.warnings.isNotEmpty)
              Text(
                result.warnings.take(2).join(' · '),
                style: TextStyle(
                  fontSize: 10,
                  color: DashboardPalette.textMuted,
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _meterLine(
    String? name,
    String id,
    double? value,
    String unit,
  ) {
    final label = name ?? id;
    return '$label · ${_fmt(value, unit)}';
  }

  String _alignmentLabel(ReadingAlignmentStatus s) => switch (s) {
        ReadingAlignmentStatus.aligned => 'Aligned',
        ReadingAlignmentStatus.partiallyAligned => 'Partially aligned',
        ReadingAlignmentStatus.misaligned => 'Misaligned',
        ReadingAlignmentStatus.insufficientData => 'Insufficient data',
      };

  Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              k,
              style: TextStyle(fontSize: 12, color: DashboardPalette.textMuted),
            ),
          ),
          Expanded(
            child: Text(
              v,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  String _fmt(double? v, String unit) {
    if (v == null) return 'N/A';
    final s = v == v.roundToDouble()
        ? v.toStringAsFixed(0)
        : v.toStringAsFixed(1);
    return '$s $unit';
  }
}
