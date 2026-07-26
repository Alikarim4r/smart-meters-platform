import 'package:flutter/material.dart';

import '../../theme/dashboard_palette.dart';
import '../../utils/site_system_navigation.dart';

class UtilityLegend extends StatelessWidget {
  const UtilityLegend({
    super.key,
    this.utilities = UtilitySystemKey.values,
    this.compact = false,
  });

  final List<UtilitySystemKey> utilities;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: compact ? 22 : 26,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: utilities.length,
        separatorBuilder: (_, _) => const SizedBox(width: 14),
        itemBuilder: (context, index) {
          final utility = utilities[index];
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: _colorFor(utility),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                utility.label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      fontSize: compact ? 10 : 11,
                      color: DashboardPalette.textMuted,
                    ),
              ),
            ],
          );
        },
      ),
    );
  }

  Color _colorFor(UtilitySystemKey utility) => switch (utility) {
        UtilitySystemKey.water => DashboardPalette.water,
        UtilitySystemKey.electricity => DashboardPalette.electricity,
        UtilitySystemKey.btu => DashboardPalette.btu,
        UtilitySystemKey.fuel => DashboardPalette.fuel,
      };
}
