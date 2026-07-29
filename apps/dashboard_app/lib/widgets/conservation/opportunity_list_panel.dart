import 'package:flutter/material.dart';
import 'package:smart_meters_core/smart_meters_core.dart';

import '../../theme/dashboard_palette.dart';
import 'opportunity_card.dart';

enum OpportunityListBucket {
  open,
  underInvestigation,
  actionsDue,
  monitoring,
  resolved,
}

extension OpportunityListBucketX on OpportunityListBucket {
  String get label => switch (this) {
        OpportunityListBucket.open => 'Open',
        OpportunityListBucket.underInvestigation => 'Under Investigation',
        OpportunityListBucket.actionsDue => 'Actions Due',
        OpportunityListBucket.monitoring => 'Monitoring',
        OpportunityListBucket.resolved => 'Resolved',
      };

  bool matches(ConservationOpportunity o) => switch (this) {
        OpportunityListBucket.open =>
          o.status == OpportunityStatus.detected ||
              o.status == OpportunityStatus.triaged,
        OpportunityListBucket.underInvestigation =>
          o.status == OpportunityStatus.underInvestigation,
        OpportunityListBucket.actionsDue =>
          o.status == OpportunityStatus.actionRequired,
        OpportunityListBucket.monitoring =>
          o.status == OpportunityStatus.monitoring,
        OpportunityListBucket.resolved =>
          o.status == OpportunityStatus.resolved ||
              o.status == OpportunityStatus.dismissed,
      };
}

/// Filterable opportunity list with status bucket chips.
class OpportunityListPanel extends StatefulWidget {
  const OpportunityListPanel({
    super.key,
    required this.opportunities,
    this.onStartInvestigation,
    this.showStartInvestigation = true,
    this.emptyMessage = 'No opportunities for this filter.',
  });

  final List<ConservationOpportunity> opportunities;
  final void Function(ConservationOpportunity opportunity)? onStartInvestigation;
  final bool showStartInvestigation;
  final String emptyMessage;

  @override
  State<OpportunityListPanel> createState() => _OpportunityListPanelState();
}

class _OpportunityListPanelState extends State<OpportunityListPanel> {
  OpportunityListBucket _bucket = OpportunityListBucket.open;

  @override
  Widget build(BuildContext context) {
    final filtered =
        widget.opportunities.where(_bucket.matches).toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final b in OpportunityListBucket.values) ...[
                FilterChip(
                  label: Text(b.label),
                  selected: _bucket == b,
                  onSelected: (_) => setState(() => _bucket = b),
                  visualDensity: VisualDensity.compact,
                ),
                const SizedBox(width: 6),
              ],
            ],
          ),
        ),
        const SizedBox(height: 8),
        if (filtered.isEmpty)
          Text(
            widget.emptyMessage,
            style: TextStyle(fontSize: 12, color: DashboardPalette.textMuted),
          )
        else
          for (final o in filtered) ...[
            OpportunityCard(
              opportunity: o,
              showStartInvestigation: widget.showStartInvestigation &&
                  _bucket != OpportunityListBucket.resolved,
              onStartInvestigation: widget.onStartInvestigation == null
                  ? null
                  : () => widget.onStartInvestigation!(o),
            ),
            const SizedBox(height: 8),
          ],
      ],
    );
  }
}
