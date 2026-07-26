import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_meters_core/smart_meters_core.dart';

import '../providers/entry_providers.dart';

final pendingEntryPartnerLinkProvider =
    StateProvider<PartnerLinkIntent?>((ref) => null);

Future<void> applyEntryPartnerLink(
  WidgetRef ref,
  BuildContext context,
  PartnerLinkIntent intent,
) async {
  if (intent.kind != PartnerLinkKind.entrySite &&
      intent.kind != PartnerLinkKind.entryMeter) {
    return;
  }

  final sites = await ref.read(accessibleSitesProvider.future);
  Site? site;
  for (final item in sites) {
    if (item.id == intent.siteId) {
      site = item;
      break;
    }
  }
  if (site == null || !context.mounted) return;

  ref.read(selectedSiteProvider.notifier).state = site;
  ref.read(selectedCategoryProvider.notifier).state = null;

  final categories =
      await ref.read(availableCategoriesProvider(site.id).future);
  MeterCategoryConfig? category;
  if (intent.categoryCode != null && intent.categoryCode!.isNotEmpty) {
    for (final item in categories) {
      if (item.code == intent.categoryCode) {
        category = item;
        break;
      }
    }
  }

  if (intent.kind == PartnerLinkKind.entryMeter && intent.meterId != null) {
    // Resolve category from the meter when not provided.
    if (category == null) {
      for (final item in categories) {
        final statuses = await ref.read(
          metersWithStatusProvider(
            EntryMeterQuery(
              siteId: site.id,
              category: item,
              businessDate: ref.read(businessDateProvider),
              siteLocation: site.location,
            ),
          ).future,
        );
        if (statuses.any((s) => s.meter.id == intent.meterId)) {
          category = item;
          break;
        }
      }
    }
  }

  category ??= categories.isNotEmpty ? categories.first : null;
  if (category == null || !context.mounted) return;

  // Land on the batch cards screen for this type (no single-meter push).
  ref.read(selectedCategoryProvider.notifier).state = category;

  if (intent.readingDate != null) {
    final parsedDate = DateTime.tryParse(intent.readingDate!);
    if (parsedDate != null) {
      ref.read(businessDateProvider.notifier).state = DateTime(
        parsedDate.year,
        parsedDate.month,
        parsedDate.day,
      );
    }
  }
}

Future<void> launchEntryPartnerApp(
  BuildContext context, {
  required Future<bool> Function() action,
  required String appLabel,
}) async {
  final launched = await action();
  if (!context.mounted || launched) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('Could not open $appLabel.')),
  );
}
