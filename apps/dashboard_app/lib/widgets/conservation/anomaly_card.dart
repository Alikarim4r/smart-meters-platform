import 'package:flutter/material.dart';
import 'package:smart_meters_core/smart_meters_core.dart';

import '../../l10n/conservation_strings.dart';
import '../../theme/dashboard_palette.dart';
import '../../theme/design_system/dashboard_colors.dart';

/// Unusual consumption / COP anomaly card — never Confirmed Fault.
class AnomalyCard extends StatelessWidget {
  const AnomalyCard({
    super.key,
    required this.title,
    required this.result,
    this.unitCode,
  });

  final String title;
  final ConsumptionAnomalyResult result;
  final String? unitCode;

  @override
  Widget build(BuildContext context) {
    final s = ConservationStrings.of(context);
    final severityColor = _severityColor(result.severity);
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
              color: result.detected
                  ? severityColor.withValues(alpha: 0.45)
                  : DashboardPalette.border.withValues(alpha: 0.7),
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
                        s.localizeDomainLabel(title),
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: severityColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        s.localizeDomainLabel(result.statusLabel),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: severityColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  result.detected
                      ? s.unusualConsumption
                      : s.localizeDomainLabel(result.statusLabel),
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: result.detected
                        ? DashboardPalette.navy
                        : DashboardPalette.textMuted,
                  ),
                ),
                const SizedBox(height: 8),
                _kv(s.severity, s.severityLabel(result.severity.name)),
                _kv(
                  s.variance,
                  result.percentageChange == null
                      ? s.na
                      : s.formatPercentageDisplay(
                          '${result.percentageChange!.toStringAsFixed(1)}%',
                        ),
                ),
                _kv(s.confidence, '${result.confidenceScore}'),
                if (result.currentValue != null)
                  _kv(
                    s.current,
                    s.formatQuantity(result.currentValue, unitCode),
                  ),
                const SizedBox(height: 6),
                Text(
                  s.localizeDomainMessage(result.reason),
                  style: TextStyle(
                    fontSize: 12,
                    color: DashboardPalette.textMuted,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  result.detected
                      ? s.requiresReviewNotFault
                      : s.noAutomaticFault,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: DashboardPalette.navy,
                  ),
                ),
                if (result.investigationNotes.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    s.possibleInvestigationNotes,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: DashboardPalette.textMuted,
                    ),
                  ),
                  for (final note in result.investigationNotes.take(3))
                    Text(
                      '· ${s.localizeDomainMessage(note)}',
                      style: TextStyle(
                        fontSize: 10,
                        color: DashboardPalette.textMuted,
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _severityColor(AnomalySeverity severity) => switch (severity) {
    AnomalySeverity.info => Colors.blueGrey.shade700,
    AnomalySeverity.low => Colors.teal.shade700,
    AnomalySeverity.medium => Colors.orange.shade800,
    AnomalySeverity.high => Colors.deepOrange.shade800,
    AnomalySeverity.critical => Colors.red.shade800,
  };

  Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
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
}
