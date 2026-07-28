import 'package:flutter/material.dart';
import 'package:smart_meters_core/smart_meters_core.dart';

import '../l10n/admin_strings.dart';
import '../utils/catalog_validation.dart';

/// Strings resolved from the ambient app locale (set on MaterialApp).
AdminStrings catalogStrings(BuildContext context) =>
    AdminStrings(Localizations.localeOf(context));

/// Bottom inset so scrollable lists clear the FAB and system nav bar.
double catalogListBottomPadding(BuildContext context) {
  final bottomInset = MediaQuery.paddingOf(context).bottom;
  return 88 + bottomInset;
}

InputDecoration catalogFieldDecoration({
  required String labelText,
  String? hintText,
  String? helperText,
}) {
  return InputDecoration(
    labelText: labelText,
    hintText: hintText,
    helperText: helperText,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: BrandChrome.borderLight),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: BrandChrome.accent, width: 1.5),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Colors.red),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Colors.red, width: 2),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
    floatingLabelBehavior: FloatingLabelBehavior.auto,
  );
}

class CatalogFormSection extends StatelessWidget {
  const CatalogFormSection({
    super.key,
    required this.title,
    this.subtitle,
    required this.children,
  });

  final String title;
  final String? subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.brightness == Brightness.dark
                        ? BrandChrome.textDarkMuted
                        : BrandChrome.inkMuted,
                  ),
                ),
              ],
            ],
          ),
        ),
        BrandInkCard(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) const SizedBox(height: 20),
                children[i],
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}

class CatalogSwitchTile extends StatelessWidget {
  const CatalogSwitchTile({
    super.key,
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title),
      subtitle: subtitle != null ? Text(subtitle!) : null,
      value: value,
      onChanged: onChanged,
    );
  }
}

class CatalogToolbar extends StatelessWidget {
  const CatalogToolbar({
    super.key,
    required this.searchController,
    required this.activeFilter,
    required this.onFilterChanged,
    this.hintText = 'Search…',
  });

  final TextEditingController searchController;
  final ActiveFilter activeFilter;
  final ValueChanged<ActiveFilter> onFilterChanged;
  final String hintText;

  @override
  Widget build(BuildContext context) {
    final s = catalogStrings(context);
    return Column(
      children: [
        TextField(
          controller: searchController,
          decoration: catalogFieldDecoration(
            labelText: s.search,
            hintText: hintText,
          ),
          onChanged: (_) {},
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ChoiceChip(
              label: Text(s.all),
              selected: activeFilter == ActiveFilter.all,
              onSelected: (_) => onFilterChanged(ActiveFilter.all),
            ),
            ChoiceChip(
              label: Text(s.active),
              selected: activeFilter == ActiveFilter.activeOnly,
              onSelected: (_) => onFilterChanged(ActiveFilter.activeOnly),
            ),
            ChoiceChip(
              label: Text(s.inactive),
              selected: activeFilter == ActiveFilter.inactiveOnly,
              onSelected: (_) => onFilterChanged(ActiveFilter.inactiveOnly),
            ),
          ],
        ),
      ],
    );
  }
}

class CatalogEmptyState extends StatelessWidget {
  const CatalogEmptyState({
    super.key,
    required this.message,
    this.title,
    this.icon = Icons.inbox_outlined,
  });

  final String message;
  final String? title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            if (title != null)
              Text(
                title!,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            if (title != null) const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.grey.shade700,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CatalogErrorView extends StatelessWidget {
  const CatalogErrorView({
    super.key,
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.red.shade400),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: Text(catalogStrings(context).retry),
            ),
          ],
        ),
      ),
    );
  }
}

Widget catalogStatusChip({required bool isActive}) {
  final color = isActive ? Colors.green : Colors.grey;
  return Builder(
    builder: (context) {
      final s = catalogStrings(context);
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.shade50,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.shade200),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isActive ? Icons.check_circle : Icons.pause_circle_outline,
              size: 14,
              color: color.shade700,
            ),
            const SizedBox(width: 4),
            Text(
              isActive ? s.active : s.inactive,
              style: TextStyle(
                color: color.shade800,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    },
  );
}

Widget catalogTypeChip({
  required String label,
  IconData? icon,
  Color color = const Color(0xFF8B3A4A),
}) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: color.withValues(alpha: 0.28)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
        ],
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    ),
  );
}
