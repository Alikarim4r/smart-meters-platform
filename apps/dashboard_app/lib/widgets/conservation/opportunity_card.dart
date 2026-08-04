import 'package:flutter/material.dart';
import 'package:smart_meters_core/smart_meters_core.dart';

import '../../l10n/conservation_strings.dart';
import '../../theme/dashboard_palette.dart';
import '../../theme/design_system/dashboard_colors.dart';

/// Opportunity card — Potential Excess only (never Saving / Verified Saving).
class OpportunityCard extends StatelessWidget {
  const OpportunityCard({
    super.key,
    required this.opportunity,
    this.onStartInvestigation,
    this.showStartInvestigation = true,
  });

  final ConservationOpportunity opportunity;
  final VoidCallback? onStartInvestigation;
  final bool showStartInvestigation;

  @override
  Widget build(BuildContext context) {
    final s = ConservationStrings.of(context);
    final priorityColor = _priorityColor(opportunity.priority);
    final utilityLabel = opportunity.utilityType.isEmpty
        ? s.utility
        : opportunity.utilityType[0].toUpperCase() +
            opportunity.utilityType.substring(1);

    return Card(
      elevation: 0,
      color: DashboardColors.card(context),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: priorityColor.withValues(alpha: 0.45),
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
                    opportunity.title.isNotEmpty
                        ? opportunity.title
                        : s.highUtilityConsumption(utilityLabel),
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
                    color: priorityColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    opportunity.priority.dbValue,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: priorityColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              s.potentialExcess,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: DashboardPalette.navy,
              ),
            ),
            const SizedBox(height: 8),
            _kv(s.status, opportunity.status.dbValue),
            _kv(s.confidence, '${opportunity.confidenceScore}'),
            _kv(s.source, opportunity.sourceType.dbValue),
            if (opportunity.estimatedWasteQuantity != null)
              _kv(
                s.potentialExcess,
                opportunity.unitCode == null
                    ? _fmt(opportunity.estimatedWasteQuantity!)
                    : '${_fmt(opportunity.estimatedWasteQuantity!)} '
                        '${opportunity.unitCode}',
              ),
            const SizedBox(height: 6),
            Text(
              opportunity.description,
              style: TextStyle(fontSize: 12, color: DashboardPalette.textMuted),
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              s.requiresInvestigation,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: DashboardPalette.navy,
              ),
            ),
            if (showStartInvestigation &&
                opportunity.status != OpportunityStatus.underInvestigation &&
                opportunity.status.isOpen) ...[
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: onStartInvestigation,
                  icon: const Icon(Icons.search_outlined, size: 18),
                  label: Text(s.startInvestigation),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _priorityColor(OpportunityPriorityLevel p) => switch (p) {
        OpportunityPriorityLevel.low => Colors.teal.shade700,
        OpportunityPriorityLevel.medium => Colors.orange.shade800,
        OpportunityPriorityLevel.high => Colors.deepOrange.shade800,
        OpportunityPriorityLevel.critical => Colors.red.shade800,
      };

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

  String _fmt(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
}
