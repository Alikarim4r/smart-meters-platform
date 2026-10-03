import 'package:flutter/material.dart';

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
          borderRadius: BorderRadius.circular(16),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            constraints: const BoxConstraints(minHeight: 44),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: selected ? selectedBg : colors.cardElevated,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected ? selectedBorder : colors.border,
                width: selected ? 1.35 : 1,
              ),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: scheme.primary.withValues(
                          alpha: isDark ? 0.12 : 0.08,
                        ),
                        blurRadius: 16,
                        offset: const Offset(0, 5),
                      ),
                    ]
                  : null,
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
