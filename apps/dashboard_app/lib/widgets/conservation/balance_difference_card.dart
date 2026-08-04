import 'package:flutter/material.dart';
import 'package:smart_meters_core/smart_meters_core.dart';

import '../../l10n/conservation_strings.dart';
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
    final s = ConservationStrings.of(context);
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
                    '${s.localizeUtilityCode(result.utilityCode)} · $groupName',
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
                    s.localizeReviewStatus(result.reviewStatus),
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
              s.localizeDomainLabel(result.directionLabel),
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: insufficient
                    ? DashboardPalette.textMuted
                    : DashboardPalette.navy,
              ),
            ),
            const SizedBox(height: 10),
            _kv(
              s.mainMeter,
              _meterLine(
                mainMeterName,
                result.mainMeterId,
                result.mainConsumption,
                result.unitCode,
                s,
              ),
            ),
            _kv(
              s.submeters,
              submeterNames.isEmpty
                  ? '${s.metersCount(result.childMeterIds.length)} · '
                      '${_fmt(result.childrenConsumption, result.unitCode, s)}'
                  : '${submeterNames.join(', ')} · '
                      '${_fmt(result.childrenConsumption, result.unitCode, s)}',
            ),
            _kv(
              s.balanceDifference,
              insufficient
                  ? s.insufficientData
                  : _fmt(result.balanceDifference, result.unitCode, s),
            ),
            _kv(
              '%',
              result.balancePercentage == null
                  ? s.na
                  : '${result.balancePercentage!.toStringAsFixed(1)}%',
            ),
            _kv(s.confidence, '${result.confidenceScore}'),
            _kv(s.alignment, _alignmentLabel(result.alignmentStatus, s)),
            const SizedBox(height: 8),
            Text(
              s.balanceStatus(s.localizeReviewStatus(result.reviewStatus)),
              style: TextStyle(fontSize: 11, color: DashboardPalette.textMuted),
            ),
            if (result.warnings.isNotEmpty)
              Text(
                result.warnings
                    .take(2)
                    .map(s.localizeDomainMessage)
                    .join(' · '),
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
    ConservationStrings s,
  ) {
    final label = name ?? id;
    return '$label · ${_fmt(value, unit, s)}';
  }

  String _alignmentLabel(ReadingAlignmentStatus status, ConservationStrings s) =>
      switch (status) {
        ReadingAlignmentStatus.aligned => s.aligned,
        ReadingAlignmentStatus.partiallyAligned => s.partiallyAligned,
        ReadingAlignmentStatus.misaligned => s.misaligned,
        ReadingAlignmentStatus.insufficientData => s.insufficientData,
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

  String _fmt(double? v, String unit, ConservationStrings cs) {
    if (v == null) return cs.na;
    final n = v == v.roundToDouble()
        ? v.toStringAsFixed(0)
        : v.toStringAsFixed(1);
    final u = cs.localizeUnit(unit);
    return u.isEmpty ? n : '$n $u';
  }
}
