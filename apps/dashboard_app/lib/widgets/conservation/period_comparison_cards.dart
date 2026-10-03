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
    final pctText = s.formatPercentageDisplay(result.percentageDisplay);
    final pctWarn = s.isUnrealisticPercentage(result.percentageDisplay);
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Card(
          elevation: 0,
          color: DashboardColors.card(context),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: DashboardPalette.border.withValues(alpha: 0.7),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${s.localizeUtilityName(utilityLabel)} · $title',
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
                  _kv(
                    s.current,
                    s.formatQuantity(result.currentValue, result.unitCode),
                  ),
                  _kv(
                    s.comparison,
                    s.formatQuantity(result.comparisonValue, result.unitCode),
                  ),
                  _kv(
                    s.absoluteDifference,
                    s.formatQuantity(
                      result.absoluteDifference,
                      result.unitCode,
                    ),
                  ),
                  _kv(s.percentageChange, pctText),
                  if (pctWarn) ...[
                    const SizedBox(height: 4),
                    Text(
                      s.percentageChangeUnrealistic,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.orange.shade800,
                      ),
                    ),
                  ],
                ],
                const SizedBox(height: 8),
                Text(
                  s.periodConfidenceDetail(
                    confidence: result.confidenceScore,
                    current: result.currentPeriodConfidence,
                    comparison: result.comparisonPeriodConfidence,
                  ),
                  style: TextStyle(
                    fontSize: 11,
                    color: DashboardPalette.textMuted,
                  ),
                ),
                Text(
                  s.completenessPair(
                    (result.currentCompleteness * 100).toStringAsFixed(0),
                    (result.comparisonCompleteness * 100).toStringAsFixed(0),
                  ),
                  style: TextStyle(
                    fontSize: 11,
                    color: DashboardPalette.textMuted,
                  ),
                ),
                const SizedBox(height: 6),
                _kv(
                  s.currentPeriodLabel,
                  '${_d(result.periodStart)} → ${_d(result.periodEnd)}',
                ),
                _kv(
                  s.comparisonPeriodLabel,
                  '${_d(result.comparisonPeriodStart)} → '
                  '${_d(result.comparisonPeriodEnd)}',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 5,
            child: Text(
              k,
              style: TextStyle(fontSize: 12, color: DashboardPalette.textMuted),
            ),
          ),
          Expanded(
            flex: 6,
            child: Text(
              v,
              textAlign: TextAlign.end,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  String _d(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
