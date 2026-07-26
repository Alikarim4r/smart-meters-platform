import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_strings.dart';
import '../../providers/meter_reading_card_providers.dart';
import '../../providers/shell_providers.dart';
import '../../theme/dashboard_theme.dart';
import '../../theme/design_system/dashboard_design_system.dart';
import '../../utils/meter_reading_filters.dart';
import '../premium/debounced_search_field.dart';

/// Unified filter toolbar — search, filters, and Cards / Network view toggle.
class MeterFilterToolbar extends ConsumerWidget {
  const MeterFilterToolbar({
    super.key,
    required this.filterKey,
    required this.isWater,
  });

  final String filterKey;
  final bool isWater;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppStrings.of(context);
    final search = ref.watch(meterCardSearchProvider(filterKey));
    final status = ref.watch(meterCardStatusFilterProvider(filterKey));
    final sort = ref.watch(meterCardSortProvider(filterKey));
    final ascending = ref.watch(meterCardSortAscendingProvider(filterKey));
    var viewMode = ref.watch(meterCardViewModeProvider(filterKey));
    // Legacy relationship mode removed from UI — fall back to cards.
    if (viewMode == MeterCardViewMode.relationship) {
      viewMode = MeterCardViewMode.cards;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(meterCardViewModeProvider(filterKey).notifier).state =
            MeterCardViewMode.cards;
      });
    }
    final waterChip = ref.watch(waterSourceChipProvider(filterKey));

    final viewModes = SegmentedButton<MeterCardViewMode>(
      segments: [
        ButtonSegment(
          value: MeterCardViewMode.cards,
          icon: const Icon(Icons.grid_view_rounded, size: 16),
          label: Text(s.viewCards),
          tooltip: s.viewCards,
        ),
        if (isWater)
          ButtonSegment(
            value: MeterCardViewMode.network,
            icon: const Icon(Icons.hub_outlined, size: 16),
            label: Text(s.viewNetwork),
            tooltip: s.viewNetwork,
          ),
      ],
      selected: {
        viewMode == MeterCardViewMode.network && !isWater
            ? MeterCardViewMode.cards
            : (viewMode == MeterCardViewMode.relationship
                  ? MeterCardViewMode.cards
                  : viewMode),
      },
      onSelectionChanged: (v) =>
          ref.read(meterCardViewModeProvider(filterKey).notifier).state =
              v.first,
      style: const ButtonStyle(
        visualDensity: VisualDensity.compact,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );

    final filters = Wrap(
      spacing: 6,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _compactDropdown<MeterCardStatusFilter>(
          context: context,
          label: s.filterStatus,
          value: status,
          items: MeterCardStatusFilter.values,
          labelBuilder: s.statusFilter,
          onChanged: (v) =>
              ref.read(meterCardStatusFilterProvider(filterKey).notifier).state =
                  v,
        ),
        if (isWater)
          _compactDropdown<WaterSourceChip>(
            context: context,
            label: s.filterSource,
            value: waterChip,
            items: WaterSourceChip.values,
            labelBuilder: s.waterSourceChip,
            onChanged: (v) =>
                ref.read(waterSourceChipProvider(filterKey).notifier).state = v,
          ),
        _compactDropdown<MeterCardSort>(
          context: context,
          label: s.filterSort,
          value: sort,
          items: MeterCardSort.values,
          labelBuilder: s.sortOption,
          onChanged: (v) =>
              ref.read(meterCardSortProvider(filterKey).notifier).state = v,
        ),
        IconButton(
          tooltip: ascending ? s.ascending : s.descending,
          onPressed: () => ref
              .read(meterCardSortAscendingProvider(filterKey).notifier)
              .state = !ascending,
          icon: Icon(
            ascending
                ? Icons.arrow_upward_rounded
                : Icons.arrow_downward_rounded,
            size: DashboardIcons.sm,
          ),
        ),
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: DebouncedSearchField(
                initialValue: search,
                focusNode: ref.watch(meterSearchFocusNodeProvider),
                hint: s.searchMeters,
                onChanged: (v) =>
                    ref.read(meterCardSearchProvider(filterKey).notifier).state =
                        v,
              ),
            ),
            const SizedBox(width: DashboardSpacing.sm),
            Flexible(
              child: Align(
                alignment: AlignmentDirectional.centerEnd,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerEnd,
                  child: viewModes,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: DashboardSpacing.sm),
        filters,
      ],
    );
  }

  Widget _compactDropdown<T>({
    required BuildContext context,
    required String label,
    required T value,
    required List<T> items,
    required String Function(T) labelBuilder,
    required ValueChanged<T> onChanged,
  }) {
    final colors = dashboardColors(context);
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: colors.inputFill,
        borderRadius: BorderRadius.circular(DashboardRadius.control),
        border: Border.all(color: colors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isDense: true,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colors.textPrimary,
              ),
          items: [
            for (final item in items)
              DropdownMenuItem(
                value: item,
                child: Text('$label: ${labelBuilder(item)}'),
              ),
          ],
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ),
    );
  }
}
