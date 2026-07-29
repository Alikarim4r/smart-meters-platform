import 'package:flutter/material.dart';
import 'package:smart_meters_core/smart_meters_core.dart';

import '../../theme/dashboard_palette.dart';
import '../../theme/design_system/dashboard_colors.dart';

/// Presentation-only Actual vs Target card (never labels gap as Saving).
class ActualVsTargetCard extends StatelessWidget {
  const ActualVsTargetCard({
    super.key,
    required this.result,
  });

  final ActualVsTargetResult result;

  @override
  Widget build(BuildContext context) {
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
              'Actual vs Target · v${result.targetVersion}',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
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
            if (insufficient)
              Text(
                result.message ?? 'Insufficient Data',
                style: TextStyle(
                  fontSize: 12,
                  color: DashboardPalette.textMuted,
                ),
              )
            else ...[
              _kv('Actual', _fmt(result.actualValue, result.unitCode)),
              _kv(
                result.comparisonMode ==
                        ActualVsTargetComparisonMode.periodToDateProrated
                    ? 'Prorated target'
                    : 'Target',
                _fmt(result.effectiveTargetValue, result.unitCode),
              ),
              if (result.comparisonMode ==
                  ActualVsTargetComparisonMode.periodToDateProrated)
                _kv(
                  'Full-period target',
                  _fmt(result.targetValue, result.unitCode),
                ),
              _kv(
                'Difference (Actual − Target)',
                _fmt(result.absoluteDifference, result.unitCode),
              ),
              _kv(
                '% of effective target',
                result.percentageOfTarget == null
                    ? 'N/A'
                    : '${result.percentageOfTarget!.toStringAsFixed(1)}%',
              ),
            ],
            const SizedBox(height: 8),
            Text(
              'Confidence: ${result.confidenceScore} · '
              'Completeness: ${(result.completeness * 100).toStringAsFixed(0)}%',
              style: TextStyle(fontSize: 11, color: DashboardPalette.textMuted),
            ),
            Text(
              'Targets ≠ Baselines. Gap is Above/Below Target — not Saving.',
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

  String _fmt(double? v, String unit) {
    if (v == null) return 'N/A';
    final s = v == v.roundToDouble()
        ? v.toStringAsFixed(0)
        : v.toStringAsFixed(1);
    return '$s $unit';
  }
}
