import 'package:flutter/material.dart';

import '../../utils/dashboard_breakpoints.dart';

/// Fixed-height responsive grid for KPI cards and site tiles.
class ResponsiveGrid extends StatelessWidget {
  const ResponsiveGrid({
    super.key,
    required this.children,
    this.minItemWidth = 200,
    this.childHeight = 150,
    this.spacing = 12,
  });

  final List<Widget> children;
  final double minItemWidth;
  final double childHeight;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        if (maxWidth <= 0 || children.isEmpty) {
          return const SizedBox.shrink();
        }

        var columns =
            (maxWidth + spacing) ~/ (minItemWidth + spacing);
        columns = columns.clamp(1, children.length);

        final itemWidth =
            (maxWidth - spacing * (columns - 1)) / columns;
        final aspectRatio = itemWidth / childHeight;

        return GridView.count(
          crossAxisCount: columns,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: spacing,
          crossAxisSpacing: spacing,
          childAspectRatio: aspectRatio,
          children: children,
        );
      },
    );
  }
}

/// Two-column desktop row that stacks on narrow widths.
class ResponsiveSplitRow extends StatelessWidget {
  const ResponsiveSplitRow({
    super.key,
    required this.left,
    required this.right,
    this.leftFlex = 1,
    this.rightFlex = 2,
    this.spacing = 16,
    this.stackBelow = DashboardBreakpoints.sidebar,
  });

  final Widget left;
  final Widget right;
  final int leftFlex;
  final int rightFlex;
  final double spacing;
  final double stackBelow;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        if (width < stackBelow) {
          return Column(
            children: [
              left,
              SizedBox(height: spacing),
              right,
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: leftFlex, child: left),
            SizedBox(width: spacing),
            Expanded(flex: rightFlex, child: right),
          ],
        );
      },
    );
  }
}
