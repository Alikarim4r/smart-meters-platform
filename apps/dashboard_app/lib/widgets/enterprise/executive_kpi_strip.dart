import 'package:flutter/material.dart';
import 'package:smart_meters_core/smart_meters_core.dart';

class ExecutiveKpi {
  const ExecutiveKpi({
    required this.label,
    required this.value,
    required this.icon,
    this.accent,
    this.emphasize = false,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color? accent;
  final bool emphasize;
}

/// Compact analytical tally. Metrics share one ruled surface instead of
/// competing as separate dashboard cards.
class ExecutiveKpiStrip extends StatelessWidget {
  const ExecutiveKpiStrip({super.key, required this.items});

  final List<ExecutiveKpi> items;

  @override
  Widget build(BuildContext context) {
    return BrandMetricLedger(
      items: [
        for (final item in items)
          BrandMetricItem(
            label: item.label,
            value: item.value,
            icon: item.icon,
            accent: item.accent,
            emphasize: item.emphasize,
          ),
      ],
    );
  }
}
