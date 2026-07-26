import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_meters_core/smart_meters_core.dart';

import '../models/meter_entry_status.dart';
import '../providers/entry_providers.dart';
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
                    widget.category.displayName,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  Text(
                    widget.site.nameEn,
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
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search),
            hintText: 'Search name, code, or location',
            border: OutlineInputBorder(),
            isDense: true,
          ),
          onChanged: (value) {
            ref.read(meterListSearchProvider.notifier).state = value.trim();
          },
        ),
        const SizedBox(height: 10),
        MeterListFilterChips(
          selected: filter,
          onSelected: (value) {
            ref.read(meterListFilterProvider.notifier).state = value;
          },
        ),
        const SizedBox(height: 12),
        metersAsync.when(
          loading: () => const EntryLoadingCard(message: 'Loading meters…'),
          error: (error, _) => EntryErrorCard(
            message: 'Could not load meters.',
            onRetry: () => ref.invalidate(metersWithStatusProvider(query)),
          ),
          data: (meters) {
            if (meters.isEmpty) {
              return const EntryEmptyCard(
                message: 'No active physical meters in this category.',
              );
            }

            final filtered = meters
                .where((status) => matchesMeterFilter(status, filter))
                .where((status) => matchesMeterSearch(status, search))
                .toList();

            final summary = MeterWorkSummary.fromStatuses(meters);

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                MeterWorkProgressSummary(summary: summary),
                const SizedBox(height: 12),
                if (filtered.isEmpty)
                  const EntryEmptyCard(
                    message: 'No meters match your search or filter.',
                  )
                else
                  for (final status in filtered)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: MeterListCard(
                        status: status,
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
