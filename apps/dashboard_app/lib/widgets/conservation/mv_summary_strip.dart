import 'package:flutter/material.dart';
import 'package:smart_meters_core/smart_meters_core.dart';

import '../../providers/conservation_providers.dart';
import '../../theme/dashboard_palette.dart';
import '../../theme/design_system/dashboard_colors.dart';

/// Compact M&V portfolio strip.
///
/// Verified Saving / Cost Avoided use verified rows only.
class MvSummaryStrip extends StatelessWidget {
  const MvSummaryStrip({
    super.key,
    required this.totals,
    this.showCostRoi = true,
    this.unitHint,
  });

  final ConservationMvPortfolioTotals totals;
  final bool showCostRoi;
  final String? unitHint;

  @override
  Widget build(BuildContext context) {
    final unit = unitHint == null || unitHint!.isEmpty ? '' : ' $unitHint';
    return Card(
      elevation: 0,
      color: DashboardColors.card(context),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: DashboardPalette.border.withValues(alpha: 0.7),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Wrap(
          spacing: 10,
          runSpacing: 8,
          children: [
            _chip(
              ConservationSavingLabels.estimatedSaving,
              '${_fmt(totals.estimatedSavingTotal)}$unit',
            ),
            _chip(
              ConservationSavingLabels.verifiedSaving,
              '${_fmt(totals.verifiedSavingTotal)}$unit',
            ),
            if (showCostRoi)
              _chip(
                'Cost Avoided',
                totals.costAvoidedTotal == null
                    ? ConservationSavingLabels.costAvoidedNa
                    : '${_fmt(totals.costAvoidedTotal!)} QAR',
              ),
            _chip(
              'Verification Pending',
              '${totals.verificationPendingCount}',
            ),
          ],
        ),
      ),
    );
  }

  static Widget _chip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: DashboardPalette.navy.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: DashboardPalette.textMuted,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
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
}
