import 'package:flutter/material.dart';
import 'package:smart_meters_core/smart_meters_core.dart';

import '../../l10n/app_strings.dart';
import '../../theme/dashboard_theme.dart';
import '../../utils/dashboard_date_range.dart';
import 'dashboard_date_selector.dart';

/// Business date control — single calendar picker + quick shortcuts.
class DashboardDateQuickBar extends StatelessWidget {
  const DashboardDateQuickBar({
    super.key,
    required this.selection,
    required this.onChanged,
    this.siteId,
    this.compact = false,
  });

  final DashboardDateSelection selection;
  final ValueChanged<DashboardDateSelection> onChanged;
  final String? siteId;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final useCompact = compact || constraints.maxWidth < 520;
        return _buildBar(context, useCompact: useCompact);
      },
    );
  }

  Widget _buildBar(BuildContext context, {required bool useCompact}) {
    final s = AppStrings.of(context);
    final today = qatarBusinessDate();
    final presets = <({String label, DashboardDateSelection value})>[
      (
        label: s.today,
        value: DashboardDateSelection.forPreset(
          preset: DashboardDatePreset.today,
          currentBusinessDate: today,
        ),
      ),
    ];

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        DashboardDateSelector(
          selection: selection,
          onChanged: onChanged,
          siteId: siteId,
          compact: useCompact,
          width: useCompact ? 220 : 268,
        ),
        if (!useCompact) ...[
          const SizedBox(width: 8),
          for (final preset in presets)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: _QuickChip(
                label: preset.label,
                selected: isSameDashboardDay(
                  selection.subsequentReadingDate,
                  preset.value.subsequentReadingDate,
                ),
                onTap: () => onChanged(preset.value),
              ),
            ),
        ],
      ],
    );
  }
}

class _QuickChip extends StatelessWidget {
  const _QuickChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = dashboardColors(context);
    return Material(
      color: selected
          ? colors.navy.withValues(alpha: 0.1)
          : colors.cardElevated,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color:
                  selected ? colors.navy.withValues(alpha: 0.3) : colors.border,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: selected ? colors.textPrimary : colors.textMuted,
            ),
          ),
        ),
      ),
    );
  }
}
