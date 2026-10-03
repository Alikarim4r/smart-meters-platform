import 'package:flutter/material.dart';
import 'package:smart_meters_core/smart_meters_core.dart';

import '../../l10n/conservation_strings.dart';
import '../../theme/dashboard_palette.dart';
import '../../theme/design_system/dashboard_colors.dart';

/// Lightweight Source → Main → Submeters → Balance Difference tree.
/// Does not rebuild Utility Network.
class BalanceHierarchyView extends StatelessWidget {
  const BalanceHierarchyView({
    super.key,
    required this.result,
    this.mainMeterName,
    this.submeterNames = const [],
  });

  final BalanceResult result;
  final String? mainMeterName;
  final List<String> submeterNames;

  @override
  Widget build(BuildContext context) {
    final s = ConservationStrings.of(context);
    final chip = _statusChip(s);
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
            Row(
              children: [
                Text(
                  s.balanceHierarchy,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
                const Spacer(),
                chip,
              ],
            ),
            const SizedBox(height: 10),
            _node(s.source, result.utilityCode.toUpperCase()),
            _indentChild(
              _node(s.mainMeter, mainMeterName ?? result.mainMeterId),
            ),
            _indentChild(
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _node(
                    s.submeters,
                    submeterNames.isEmpty
                        ? s.membersCount(result.childMeterIds.length)
                        : submeterNames.join(', '),
                  ),
                  if (result.missingMeterIds.isNotEmpty)
                    Padding(
                      padding: const EdgeInsetsDirectional.only(
                        start: 12,
                        top: 2,
                      ),
                      child: Text(
                        s.missingCount(result.missingMeterIds.length),
                        style: TextStyle(
                          fontSize: 11,
                          color: DashboardPalette.textMuted,
                        ),
                      ),
                    ),
                ],
              ),
              depth: 2,
            ),
            _indentChild(
              _node(
                s.balanceDifference,
                result.balanceDifference == null
                    ? s.insufficientData
                    : '${result.balanceDifference!.toStringAsFixed(1)} '
                          '${result.unitCode}',
                emphasize: true,
              ),
              depth: 1,
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusChip(ConservationStrings s) {
    late final String label;
    late final Color color;
    if (result.missingMeterIds.isNotEmpty ||
        result.alignmentStatus == ReadingAlignmentStatus.insufficientData) {
      label = s.missingData;
      color = Colors.brown.shade700;
    } else if (result.alignmentStatus == ReadingAlignmentStatus.misaligned) {
      label = s.misaligned;
      color = Colors.orange.shade800;
    } else if (result.confidenceScore < 60) {
      label = s.lowConfidence;
      color = Colors.deepOrange.shade700;
    } else if (result.alignmentStatus == ReadingAlignmentStatus.aligned) {
      label = s.normal;
      color = Colors.teal.shade700;
    } else {
      label = s.partial;
      color = Colors.blueGrey.shade700;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  Widget _node(String title, String value, {bool emphasize = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.circle,
            size: 8,
            color: emphasize
                ? DashboardPalette.navy
                : DashboardPalette.textMuted,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: TextStyle(
                  fontSize: 12,
                  color: DashboardPalette.textMuted,
                ),
                children: [
                  TextSpan(
                    text: '$title: ',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  TextSpan(
                    text: value,
                    style: TextStyle(
                      fontWeight: emphasize ? FontWeight.w800 : FontWeight.w500,
                      color: emphasize
                          ? DashboardPalette.navy
                          : DashboardPalette.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _indentChild(Widget child, {int depth = 1}) {
    return Padding(
      padding: EdgeInsetsDirectional.only(start: 14.0 * depth),
      child: child,
    );
  }
}
