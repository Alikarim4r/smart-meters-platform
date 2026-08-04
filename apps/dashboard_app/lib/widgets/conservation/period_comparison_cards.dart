import 'package:flutter/material.dart';
import '../../l10n/conservation_strings.dart';
import 'package:smart_meters_core/smart_meters_core.dart';

import '../../theme/dashboard_palette.dart';
import '../../theme/design_system/dashboard_colors.dart';

/// Presentation-only card for a [PeriodComparisonResult].
class PeriodComparisonCard extends StatelessWidget {
  const PeriodComparisonCard({
    super.key,
    required this.title,
    required this.result,
    required this.utilityLabel,
  });

  final String title;
  final PeriodComparisonResult result;
  final String utilityLabel;

  @override
  Widget build(BuildContext context) {
    final s = ConservationStrings.of(context);
    final insufficient = result.isInsufficient;
    return Card(
      elevation: 0,
      color: DashboardColors.card(context),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: DashboardPalette.border.withValues(alpha: 0.7)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$utilityLabel · $title',
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 14,
              ),
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
            if (insufficient)
              Text(
                s.localizeDomainMessage(result.message),
                style: TextStyle(
                  fontSize: 12,
                  color: DashboardPalette.textMuted,
                ),
              )
            else ...[
              _kv(s.current, _fmt(result.currentValue, result.unitCode, s)),
              _kv(
                s.comparison,
                _fmt(result.comparisonValue, result.unitCode, s),
              ),
              _kv(
                s.absoluteDifference,
                _fmt(result.absoluteDifference, result.unitCode, s),
              ),
              _kv(s.percentageChange, result.percentageDisplay),
            ],
            const SizedBox(height: 8),
            Text(
              s.periodConfidenceDetail(
                confidence: result.confidenceScore,
                current: result.currentPeriodConfidence,
                comparison: result.comparisonPeriodConfidence,
              ),
              style: TextStyle(fontSize: 11, color: DashboardPalette.textMuted),
            ),
            Text(
              s.completenessPair(
                (result.currentCompleteness * 100).toStringAsFixed(0),
                (result.comparisonCompleteness * 100).toStringAsFixed(0),
              ),
              style: TextStyle(fontSize: 11, color: DashboardPalette.textMuted),
            ),
            Text(
              '${_d(result.periodStart)} → ${_d(result.periodEnd)}  vs  '
              '${_d(result.comparisonPeriodStart)} → '
              '${_d(result.comparisonPeriodEnd)}',
              style: TextStyle(fontSize: 10, color: DashboardPalette.textMuted),
            ),
          ],
        ),
      ),
    );
  }

  Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              k,
              style: TextStyle(fontSize: 12, color: DashboardPalette.textMuted),
            ),
          ),
          Text(
            v,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
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

  String _d(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
