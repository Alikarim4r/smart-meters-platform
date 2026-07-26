import 'package:flutter/material.dart';
import 'package:smart_meters_core/smart_meters_core.dart';

import '../../theme/dashboard_theme.dart';
import '../../utils/dashboard_date_range.dart';
import '../../utils/meter_reading_filters.dart';
import 'meter_reading_card.dart';

class MeterRelationshipView extends StatelessWidget {
  const MeterRelationshipView({
    super.key,
    required this.groups,
    required this.siteId,
    required this.dateSelection,
    required this.useDesktop,
    required this.onViewReadings,
  });

  final List<MeterRelationshipGroup> groups;
  final String siteId;
  final DashboardDateSelection dateSelection;
  final bool useDesktop;
  final void Function(MeterReadingCardData card) onViewReadings;

  @override
  Widget build(BuildContext context) {
    final colors = dashboardColors(context);
    final maxWidth = useDesktop ? 920.0 : double.infinity;

    return Align(
      alignment: Alignment.topLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final group in groups) ...[
              _RelationshipGroupColumn(
                group: group,
                siteId: siteId,
                dateSelection: dateSelection,
                onViewReadings: onViewReadings,
              ),
              const SizedBox(height: 20),
            ],
            if (groups.isEmpty)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'No meters to display in relationship view.',
                  style: TextStyle(color: colors.textMuted),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _RelationshipGroupColumn extends StatelessWidget {
  const _RelationshipGroupColumn({
    required this.group,
    required this.siteId,
    required this.dateSelection,
    required this.onViewReadings,
  });

  final MeterRelationshipGroup group;
  final String siteId;
  final DashboardDateSelection dateSelection;
  final void Function(MeterReadingCardData card) onViewReadings;

  @override
  Widget build(BuildContext context) {
    final colors = dashboardColors(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MeterReadingCard(
          data: group.parent,
          siteId: siteId,
          dateSelection: dateSelection,
          onViewReadings: () => onViewReadings(group.parent),
        ),
        if (group.hasBranches) ...[
          const SizedBox(height: 4),
          for (var i = 0; i < group.children.length; i++)
            _BranchRow(
              child: group.children[i],
              isLast: i == group.children.length - 1,
              siteId: siteId,
              dateSelection: dateSelection,
              onViewReadings: () => onViewReadings(group.children[i]),
              lineColor: colors.border,
            ),
        ],
      ],
    );
  }
}

class _BranchRow extends StatelessWidget {
  const _BranchRow({
    required this.child,
    required this.isLast,
    required this.siteId,
    required this.dateSelection,
    required this.onViewReadings,
    required this.lineColor,
  });

  final MeterReadingCardData child;
  final bool isLast;
  final String siteId;
  final DashboardDateSelection dateSelection;
  final VoidCallback onViewReadings;
  final Color lineColor;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 28,
            child: CustomPaint(
              painter: _BranchLinePainter(
                color: lineColor,
                isLast: isLast,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: MeterReadingCard(
                data: child,
                siteId: siteId,
                dateSelection: dateSelection,
                onViewReadings: onViewReadings,
                isBranch: true,
                compact: false,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BranchLinePainter extends CustomPainter {
  _BranchLinePainter({required this.color, required this.isLast});

  final Color color;
  final bool isLast;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final midY = 28.0;
    canvas.drawLine(Offset(size.width * 0.5, 0), Offset(size.width * 0.5, midY), paint);
    canvas.drawLine(
      Offset(size.width * 0.5, midY),
      Offset(size.width, midY),
      paint,
    );
    if (!isLast) {
      canvas.drawLine(
        Offset(size.width * 0.5, midY),
        Offset(size.width * 0.5, size.height),
        paint,
      );
    }

    final arrow = Path()
      ..moveTo(size.width - 6, midY - 4)
      ..lineTo(size.width, midY)
      ..lineTo(size.width - 6, midY + 4);
    canvas.drawPath(arrow, paint..style = PaintingStyle.fill);
  }

  @override
  bool shouldRepaint(covariant _BranchLinePainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.isLast != isLast;
}
