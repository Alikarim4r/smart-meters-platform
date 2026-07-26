import 'package:flutter/material.dart';

import '../../l10n/app_strings.dart';
import '../../theme/dashboard_palette.dart';
import '../../utils/site_system_navigation.dart';

class UtilitySystemChip extends StatelessWidget {
  const UtilitySystemChip({
    super.key,
    required this.section,
    required this.selected,
    required this.onSelected,
  });

  final SiteDashboardSection section;
  final bool selected;
  final ValueChanged<SiteDashboardSection> onSelected;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    return ChoiceChip(
      avatar: Icon(section.icon, size: 16),
      label: Text(s.sectionLabel(section)),
      selected: selected,
      showCheckmark: false,
      selectedColor: DashboardPalette.goldSoft,
      side: BorderSide(
        color: selected ? DashboardPalette.gold : DashboardPalette.border,
      ),
      labelStyle: TextStyle(
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        color: selected ? DashboardPalette.navy : DashboardPalette.textMuted,
        fontSize: 12,
      ),
      onSelected: (_) => onSelected(section),
    );
  }
}
