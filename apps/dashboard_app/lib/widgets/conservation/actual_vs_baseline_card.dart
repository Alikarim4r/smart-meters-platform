import 'package:flutter/material.dart';
import 'package:smart_meters_core/smart_meters_core.dart';

import '../../l10n/conservation_strings.dart';
import '../../theme/dashboard_palette.dart';
import '../../theme/design_system/dashboard_colors.dart';

/// Presentation-only Actual vs Baseline card (never labels gap as Saving).
class ActualVsBaselineCard extends StatelessWidget {
  const ActualVsBaselineCard({
    super.key,
    required this.result,
  });

  final ActualVsBaselineResult result;

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
              s.actualVsBaseline(result.baselineVersion),
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
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
              _kv(s.actual, _fmt(result.actualValue, result.unitCode, s)),
              _kv(s.baseline, _fmt(result.baselineValue, result.unitCode, s)),
              _kv(
                s.absoluteVarianceActualMinusBaseline,
                _fmt(result.absoluteVariance, result.unitCode, s),
              ),
              _kv(
                s.percentageVariance,
                result.percentageVariance == null
                    ? s.na
                    : '${result.percentageVariance!.toStringAsFixed(1)}%',
              ),
              _kv(s.method, s.localizeMethod(result.calculationMethod.dbValue)),
            ],
            const SizedBox(height: 8),
            Text(
              '${s.combinedConfidenceDetail(combined: result.confidenceScore, baseline: result.baselineConfidence, actual: result.actualConfidence)} · '
              '${s.completenessPct((result.completeness * 100).toStringAsFixed(0))}',
              style: TextStyle(fontSize: 11, color: DashboardPalette.textMuted),
            ),
            Text(
              s.baselineNotTargetNote,
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

  String _fmt(double? v, String unit, ConservationStrings cs) =>
      cs.formatQuantity(v, unit);
}
