import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_meters_core/smart_meters_core.dart';

import '../l10n/entry_strings.dart';
import '../providers/entry_providers.dart';
import '../providers/preferences_providers.dart';
import '../widgets/entry_state_views.dart';
import '../widgets/site_selector_card.dart';

class SiteSelectionScreen extends ConsumerWidget {
  const SiteSelectionScreen({
    super.key,
    required this.onSiteSelected,
  });

  final ValueChanged<Site> onSiteSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = EntryStrings(ref.watch(entryLocaleProvider));
    final sitesAsync = ref.watch(accessibleSitesProvider);

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          s.selectSite,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          s.selectSiteHint,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.6),
              ),
        ),
        const SizedBox(height: 20),
        sitesAsync.when(
          loading: () => EntryLoadingCard(message: s.loadingSites),
          error: (error, _) => EntryErrorCard(
            message: s.couldNotLoadSites,
            onRetry: () => ref.invalidate(accessibleSitesProvider),
          ),
          data: (sites) {
            if (sites.isEmpty) {
              return EntryEmptyCard(message: s.noSites);
            }

            return Column(
              children: [
                for (final site in sites)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: SiteSelectorCard(
                      site: site,
                      isAr: s.isAr,
                      onTap: () => onSiteSelected(site),
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
