import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_meters_core/smart_meters_core.dart';

import '../l10n/entry_strings.dart';
import '../models/meter_entry_status.dart';
import '../providers/entry_providers.dart';
import '../providers/preferences_providers.dart';
import '../widgets/entry_state_views.dart';
import '../widgets/meter_list_card.dart';
import '../widgets/meter_work_progress_summary.dart';

class MeterListScreen extends ConsumerStatefulWidget {
  const MeterListScreen({
    super.key,
    required this.site,
    required this.category,
    required this.businessDate,
    required this.onBack,
    required this.onMeterTap,
  });

  final Site site;
  final MeterCategoryConfig category;
  final DateTime businessDate;
  final VoidCallback onBack;
  final ValueChanged<MeterEntryStatus> onMeterTap;

  @override
  ConsumerState<MeterListScreen> createState() => _MeterListScreenState();
}

class _MeterListScreenState extends ConsumerState<MeterListScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = EntryStrings(ref.watch(entryLocaleProvider));
    final query = EntryMeterQuery(
      siteId: widget.site.id,
      category: widget.category,
      businessDate: widget.businessDate,
      siteLocation: widget.site.location,
    );
    final metersAsync = ref.watch(metersWithStatusProvider(query));
    final search = ref.watch(meterListSearchProvider);
    final filter = ref.watch(meterListFilterProvider);

    if (_searchController.text != search) {
      _searchController.value = _searchController.value.copyWith(
        text: search,
        selection: TextSelection.collapsed(offset: search.length),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      children: [
        Row(
          children: [
            IconButton(onPressed: widget.onBack, icon: const Icon(Icons.arrow_back)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.categoryName(widget.category),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  Text(
                    s.siteName(widget.site),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey.shade700,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _searchController,
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search),
            hintText: s.searchMeters,
            border: const OutlineInputBorder(),
            isDense: true,
          ),
          onChanged: (value) {
            ref.read(meterListSearchProvider.notifier).state = value.trim();
          },
        ),
        const SizedBox(height: 10),
        MeterListFilterChips(
          selected: filter,
          isArabic: s.isAr,
          onSelected: (value) {
            ref.read(meterListFilterProvider.notifier).state = value;
          },
        ),
        const SizedBox(height: 12),
        metersAsync.when(
          loading: () => EntryLoadingCard(message: s.loadingMeters),
          error: (error, _) => EntryErrorCard(
            message: s.couldNotLoadMeters,
            onRetry: () => ref.invalidate(metersWithStatusProvider(query)),
          ),
          data: (meters) {
            if (meters.isEmpty) {
              return EntryEmptyCard(message: s.noMetersOfType);
            }

            final filtered = meters
                .where((status) => matchesMeterFilter(status, filter))
                .where((status) => matchesMeterSearch(status, search))
                .toList();

            final summary = MeterWorkSummary.fromStatuses(meters);

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                MeterWorkProgressSummary(
                  summary: summary,
                  isArabic: s.isAr,
                ),
                const SizedBox(height: 12),
                if (filtered.isEmpty)
                  EntryEmptyCard(
                    message: s.isAr
                        ? 'لا توجد عدادات مطابقة للبحث أو الفلتر.'
                        : 'No meters match your search or filter.',
                  )
                else
                  for (final status in filtered)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: MeterListCard(
                        status: status,
                        isArabic: s.isAr,
                        onTap: () => widget.onMeterTap(status),
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
