import 'package:flutter/material.dart';
import 'package:smart_meters_core/smart_meters_core.dart';

import '../../l10n/app_strings.dart';
import '../../theme/dashboard_theme.dart';
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
    final colors = dashboardColors(context);
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selectedBg = isDark
        ? scheme.primary.withValues(alpha: 0.20)
        : scheme.primary.withValues(alpha: 0.10);
    final selectedBorder = isDark
        ? scheme.primary.withValues(alpha: 0.72)
        : scheme.primary.withValues(alpha: 0.48);

    return Semantics(
      button: true,
      selected: selected,
      label: s.sectionLabel(section),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => onSelected(section),
          borderRadius: BorderRadius.circular(BrandRadius.control),
          child: AnimatedContainer(
            duration: BrandMotion.resolve(context, BrandMotion.quick),
            curve: BrandMotion.curve,
            constraints: const BoxConstraints(
              minHeight: BrandSpace.touchTarget,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: selected ? selectedBg : colors.cardElevated,
              borderRadius: BorderRadius.circular(BrandRadius.control),
              border: Border.all(
                color: selected ? selectedBorder : colors.border,
                width: selected ? 1.35 : 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  section.icon,
                  size: 17,
                  color: selected ? scheme.primary : colors.textMuted,
                ),
                const SizedBox(width: 7),
                Text(
                  s.sectionLabel(section),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontSize: 12,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    color: selected ? colors.textPrimary : colors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
