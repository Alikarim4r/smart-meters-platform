import 'package:flutter/material.dart';

import '../../theme/dashboard_theme.dart';

/// Shimmer-free skeleton placeholder for premium loading states.
class SkeletonBox extends StatelessWidget {
  const SkeletonBox({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 8,
  });

  final double width;
  final double height;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final colors = dashboardColors(context);
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: colors.border.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }
}

class MeterCardSkeleton extends StatelessWidget {
  const MeterCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = dashboardColors(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border.withValues(alpha: 0.6)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SkeletonBox(width: 120, height: 14),
          SizedBox(height: 8),
          SkeletonBox(width: 180, height: 10),
          SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: SkeletonBox(width: double.infinity, height: 48)),
              SizedBox(width: 8),
              Expanded(child: SkeletonBox(width: double.infinity, height: 48)),
              SizedBox(width: 8),
              Expanded(child: SkeletonBox(width: double.infinity, height: 48)),
            ],
          ),
          SizedBox(height: 10),
          SkeletonBox(width: 200, height: 10),
        ],
      ),
    );
  }
}

class MeterCardSkeletonGrid extends StatelessWidget {
  const MeterCardSkeletonGrid({
    super.key,
    this.count = 6,
    this.cardWidth = 340,
  });

  final int count;
  final double cardWidth;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        for (var i = 0; i < count; i++)
          SizedBox(
            width: cardWidth,
            child: const MeterCardSkeleton(),
          ),
      ],
    );
  }
}

class StatCardSkeleton extends StatelessWidget {
  const StatCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = dashboardColors(context);
    return Container(
      height: 108,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.border.withValues(alpha: 0.6)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          SkeletonBox(width: 24, height: 24, borderRadius: 12),
          SkeletonBox(width: 64, height: 22),
          SkeletonBox(width: 90, height: 10),
        ],
      ),
    );
  }
}
