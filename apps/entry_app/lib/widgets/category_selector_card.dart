import 'package:flutter/material.dart';
import 'package:smart_meters_core/smart_meters_core.dart';

import '../l10n/entry_strings.dart';
import '../theme/entry_chrome.dart';

/// Same visual language as [SiteSelectorCard] — unified Entry selection cards.
class CategorySelectorCard extends StatelessWidget {
  const CategorySelectorCard({
    super.key,
    required this.category,
    required this.onTap,
    required this.strings,
  });

  final MeterCategoryConfig category;
  final VoidCallback onTap;
  final EntryStrings strings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final border = EntryChrome.border(isDark: isDark, scheme: theme.colorScheme);
    final titleColor =
        EntryChrome.titleColor(isDark: isDark, scheme: theme.colorScheme);
    final muted =
        EntryChrome.mutedColor(isDark: isDark, scheme: theme.colorScheme);

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: border, width: 1.2),
            gradient: EntryChrome.cardWash(isDark: isDark),
            boxShadow: [
              BoxShadow(
                color: EntryChrome.accent.withValues(alpha: isDark ? 0.12 : 0.08),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: EntryChrome.iconWellGradient,
                    border: Border.all(
                      color: EntryChrome.accent.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Icon(
                    MeterCategoryIcons.iconForCode(category.code),
                    color: isDark ? EntryChrome.onAccent : EntryChrome.iconGlyph,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        strings.categoryName(category),
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: titleColor,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        strings.metersOfType,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: muted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: muted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
