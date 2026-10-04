import 'package:flutter/material.dart';
import 'package:smart_meters_core/smart_meters_core.dart';

import '../l10n/entry_strings.dart';

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
    final scheme = Theme.of(context).colorScheme;
    return BrandLedgerRow(
      title: strings.categoryName(category),
      subtitle: strings.metersOfType,
      onTap: onTap,
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: scheme.primaryContainer.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(BrandRadius.chip),
        ),
        child: Icon(
          MeterCategoryIcons.iconForCode(category.code),
          color: scheme.onPrimaryContainer,
          size: 21,
        ),
      ),
    );
  }
}
