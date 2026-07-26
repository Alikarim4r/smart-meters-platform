import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_meters_core/smart_meters_core.dart';

import '../l10n/entry_strings.dart';
import '../providers/entry_providers.dart';
import '../providers/preferences_providers.dart';
import '../widgets/category_selector_card.dart';
import '../widgets/entry_state_views.dart';

class CategorySelectionScreen extends ConsumerWidget {
  const CategorySelectionScreen({
    super.key,
    required this.site,
    required this.onBack,
    required this.onCategorySelected,
  });

  final Site site;
  final VoidCallback onBack;
  final ValueChanged<MeterCategoryConfig> onCategorySelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = EntryStrings(ref.watch(entryLocaleProvider));
    final categoriesAsync = ref.watch(availableCategoriesProvider(site.id));
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      children: [
        Text(
          s.selectMeterType,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          s.selectMeterTypeHint,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: 16),
        categoriesAsync.when(
          loading: () => EntryLoadingCard(message: s.loadingTypes),
          error: (error, _) => EntryErrorCard(
            message: s.couldNotLoadTypes,
            onRetry: () =>
                ref.invalidate(availableCategoriesProvider(site.id)),
          ),
          data: (categories) {
            if (categories.isEmpty) {
              return EntryEmptyCard(message: s.noMetersAtSite);
            }

            return Column(
              children: [
                for (final category in categories)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: CategorySelectorCard(
                      category: category,
                      strings: s,
                      onTap: () => onCategorySelected(category),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}
