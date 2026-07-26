import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_meters_core/smart_meters_core.dart';

import '../../l10n/app_strings.dart';
import '../../providers/chart_providers.dart';
import '../../providers/meter_reading_card_providers.dart';
import '../../providers/shell_providers.dart';
import '../../theme/design_system/dashboard_design_system.dart';
import '../../utils/dashboard_date_range.dart';
import '../../utils/meter_reading_filters.dart';
import '../../utils/site_system_navigation.dart';
import '../dashboard_widgets.dart';
import '../premium/skeleton_loaders.dart';
import 'meter_reading_card.dart';
import 'meter_reading_history_dialog.dart';
import 'meter_network_map_view.dart';

double meterCardLayoutWidth({
  required double maxWidth,
  required bool useDesktop,
}) {
  if (!useDesktop || maxWidth < 520) return maxWidth;
  if (maxWidth >= 1400) return DashboardLayout.meterCardWidth + 8;
  if (maxWidth >= 1100) return DashboardLayout.meterCardWidth;
  if (maxWidth >= 860) return 320;
  return maxWidth;
}

/// Meter grid as scroll slivers — filters live in [MeterFilterToolbar].
class MeterReadingsSliverSection extends ConsumerWidget {
  const MeterReadingsSliverSection({
    super.key,
    required this.siteId,
    required this.system,
    required this.useDesktop,
    required this.dateSelection,
    this.categoryId,
  });

  final String siteId;
  final UtilitySystemKey system;
  final bool useDesktop;
  final DashboardDateSelection dateSelection;
  final String? categoryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppStrings.of(context);
    final filterKey = meterCardFilterKey(siteId, system.categoryCode);
    final search = ref.watch(meterCardSearchProvider(filterKey));
    final statusFilter = ref.watch(meterCardStatusFilterProvider(filterKey));
    final sort = ref.watch(meterCardSortProvider(filterKey));
    final sortAscending = ref.watch(meterCardSortAscendingProvider(filterKey));
    final viewMode = ref.watch(meterCardViewModeProvider(filterKey));
    final waterChip = ref.watch(waterSourceChipProvider(filterKey));
    final isWater = system == UtilitySystemKey.water;

    final query = MeterReadingCardsQuery(
      siteId: siteId,
      utilityKey: system.categoryCode,
      businessDate: dateSelection.meterQueryBusinessDate,
      previousBusinessDate:
          dateSelection.meterQueryPreviousDate,
      rangeStart: dateSelection.meterQueryRangeStart,
      search: search,
      statusFilter: statusFilter,
      sort: sort,
      sortAscending: sortAscending,
    );
    final cardsAsync = ref.watch(meterReadingCardsProvider(query));

    void openHistory(MeterReadingCardData card) => showMeterReadingHistoryDialog(
          context: context,
          ref: ref,
          siteId: siteId,
          meter: card,
          dateSelection: dateSelection,
        );

    return cardsAsync.when(
      skipLoadingOnReload: true,
      skipLoadingOnRefresh: true,
      loading: () => SliverToBoxAdapter(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth.isFinite && constraints.maxWidth > 0
                ? constraints.maxWidth
                : MediaQuery.sizeOf(context).width -
                    DashboardLayout.pagePadding(useDesktop) * 2;
            return MeterCardSkeletonGrid(
              cardWidth: meterCardLayoutWidth(
                maxWidth: width,
                useDesktop: useDesktop,
              ),
            );
          },
        ),
      ),
      error: (e, _) => SliverToBoxAdapter(
        child: DashboardErrorState(
          title: s.couldNotLoadMeterCards,
          message: s.pleaseRefreshMeterCards,
          onRetry: () => ref.invalidate(meterReadingCardsProvider(query)),
        ),
      ),
      data: (rawCards) {
        var cards = isWater
            ? filterCardsByWaterSourceChip(cards: rawCards, chip: waterChip)
            : rawCards;

        if (viewMode == MeterCardViewMode.network &&
            isWater &&
            categoryId != null) {
          return SliverToBoxAdapter(
            child: MeterNetworkMapView(
              siteId: siteId,
              categoryId: categoryId!,
              cards: cards.isEmpty ? rawCards : cards,
              onViewReadings: openHistory,
            ),
          );
        }

        if (cards.isEmpty) {
          return SliverToBoxAdapter(
            child: DashboardEmptyState(
              title: s.noMetersMatchFilters(system),
              subtitle: s.tryDifferentFilters,
            ),
          );
        }

        // On phones, show a flat card list — collapsible source groups hide
        // meters and feel broken on small screens.
        final grouped = useDesktop
            ? _resolveGroups(
                cards: cards,
                isWater: isWater,
                waterChip: waterChip,
                strings: s,
              )
            : null;

        if (grouped == null) {
          return SliverLayoutBuilder(
            builder: (context, constraints) {
              return _buildCardsSliver(
                context: context,
                ref: ref,
                cards: cards,
                maxWidth: constraints.crossAxisExtent,
                useDesktop: useDesktop,
                siteId: siteId,
                dateSelection: dateSelection,
                onViewReadings: openHistory,
                categoryId: categoryId,
                searchHighlight: search.trim().isEmpty ? null : search.trim(),
              );
            },
          );
        }

        final prefix = '$siteId::${system.categoryCode}';
        return SliverMainAxisGroup(
          slivers: [
            for (final entry in grouped.groups.entries) ...[
              _GroupHeaderSliver(
                groupKey: '$prefix::${entry.key}',
                title: grouped.labelForKey(entry.key),
                icon: grouped.iconForKey(entry.key),
                count: entry.value.length,
              ),
              _GroupCardsSliver(
                groupKey: '$prefix::${entry.key}',
                cards: entry.value,
                useDesktop: useDesktop,
                siteId: siteId,
                dateSelection: dateSelection,
                onViewReadings: openHistory,
                categoryId: categoryId,
                searchHighlight: search.trim().isEmpty ? null : search.trim(),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: DashboardSpacing.md)),
            ],
          ],
        );
      },
    );
  }

  _GroupedData? _resolveGroups({
    required List<MeterReadingCardData> cards,
    required bool isWater,
    required WaterSourceChip waterChip,
    required AppStrings strings,
  }) {
    if (isWater && waterChip == WaterSourceChip.all) {
      return _GroupedData(
        groups: groupCardsBySource(cards, waterUtility: true),
        labelForKey: strings.waterSourceGroup,
        iconForKey: (k) => sourceGroupIcon(k, waterUtility: true),
      );
    }
    if (!isWater && shouldGroupCardsBySource(cards)) {
      return _GroupedData(
        groups: groupCardsBySource(cards),
        labelForKey: (k) => strings.catalogLabel(sourceGroupLabel(k)),
        iconForKey: sourceGroupIcon,
      );
    }
    return null;
  }
}

class _GroupedData {
  _GroupedData({
    required this.groups,
    required this.labelForKey,
    required this.iconForKey,
  });

  final Map<String, List<MeterReadingCardData>> groups;
  final String Function(String) labelForKey;
  final IconData Function(String) iconForKey;
}

class _GroupHeaderSliver extends ConsumerWidget {
  const _GroupHeaderSliver({
    required this.groupKey,
    required this.title,
    required this.icon,
    required this.count,
  });

  final String groupKey;
  final String title;
  final IconData icon;
  final int count;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expanded = ref.watch(sourceGroupExpandedProvider(groupKey));
    return SliverToBoxAdapter(
      child: Material(
        color: DashboardColors.background(context),
        child: InkWell(
          onTap: () => ref
              .read(sourceGroupExpandedProvider(groupKey).notifier)
              .state = !expanded,
          child: SizedBox(
            height: DashboardLayout.navRowHeight,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: DashboardSpacing.xs),
              child: Row(
                children: [
                  AnimatedRotation(
                    turns: expanded ? 0.25 : 0,
                    duration: DashboardMotion.button,
                    child: Icon(
                      Icons.chevron_right_rounded,
                      color: DashboardColors.textMuted(context),
                    ),
                  ),
                  Icon(
                    icon,
                    size: DashboardIcons.md - 2,
                    color: DashboardColors.textMuted(context),
                  ),
                  const SizedBox(width: DashboardSpacing.xs),
                  Expanded(
                    child: Text(
                      title,
                      style: DashboardTypography.sectionTitle(context),
                    ),
                  ),
                  Text('$count', style: DashboardTypography.label(context)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GroupCardsSliver extends ConsumerWidget {
  const _GroupCardsSliver({
    required this.groupKey,
    required this.cards,
    required this.useDesktop,
    required this.siteId,
    required this.dateSelection,
    required this.onViewReadings,
    this.categoryId,
    this.searchHighlight,
  });

  final String groupKey;
  final List<MeterReadingCardData> cards;
  final bool useDesktop;
  final String siteId;
  final DashboardDateSelection dateSelection;
  final void Function(MeterReadingCardData card) onViewReadings;
  final String? categoryId;
  final String? searchHighlight;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expanded = ref.watch(sourceGroupExpandedProvider(groupKey));
    if (!expanded) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }
    return SliverLayoutBuilder(
      builder: (context, constraints) {
        return _buildCardsSliver(
          context: context,
          ref: ref,
          cards: cards,
          maxWidth: constraints.crossAxisExtent,
          useDesktop: useDesktop,
          siteId: siteId,
          dateSelection: dateSelection,
          onViewReadings: onViewReadings,
          categoryId: categoryId,
          searchHighlight: searchHighlight,
        );
      },
    );
  }
}


/// Fixed grid cell height — keep in sync with [MeterReadingCard] compact layout.
const double _meterCardRowExtent = 236;

Widget _buildCardsSliver({
  required BuildContext context,
  required WidgetRef ref,
  required List<MeterReadingCardData> cards,
  required double maxWidth,
  required bool useDesktop,
  required String siteId,
  required DashboardDateSelection dateSelection,
  required void Function(MeterReadingCardData card) onViewReadings,
  String? categoryId,
  String? searchHighlight,
}) {
  final cardWidth = meterCardLayoutWidth(
    maxWidth: maxWidth,
    useDesktop: useDesktop,
  );
  final useGridLayout = useDesktop && maxWidth >= 520;
  final spacing = DashboardSpacing.sm;

  Widget buildCard(MeterReadingCardData card) {
    return RepaintBoundary(
      child: MeterReadingCard(
        data: card,
        siteId: siteId,
        dateSelection: dateSelection,
        categoryId: categoryId,
        searchHighlight: searchHighlight,
        expandToFill: useGridLayout,
        onViewReadings: () => onViewReadings(card),
        onCompare: categoryId == null
            ? null
            : () => _toggleCompare(
                  ref,
                  siteId: siteId,
                  categoryId: categoryId,
                  meterId: card.meterId,
                ),
      ),
    );
  }

  final crossAxisCount = useGridLayout
      ? ((maxWidth + spacing) / (cardWidth + spacing)).floor().clamp(1, 12)
      : 1;

  if (crossAxisCount <= 1) {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) => Padding(
          padding: const EdgeInsets.only(bottom: DashboardSpacing.sm),
          child: buildCard(cards[index]),
        ),
        childCount: cards.length,
        addRepaintBoundaries: false,
      ),
    );
  }

  return SliverGrid(
    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: crossAxisCount,
      mainAxisSpacing: spacing,
      crossAxisSpacing: spacing,
      mainAxisExtent: _meterCardRowExtent,
    ),
    delegate: SliverChildBuilderDelegate(
      (context, index) => buildCard(cards[index]),
      childCount: cards.length,
      addRepaintBoundaries: false,
    ),
  );
}

void _toggleCompare(
  WidgetRef ref, {
  required String siteId,
  required String categoryId,
  required String meterId,
}) {
  final key = meterComparisonKey(siteId: siteId, categoryId: categoryId);
  final current = ref.read(meterComparisonSelectionProvider(key));
  final next = Set<String>.from(current);
  if (next.contains(meterId)) {
    next.remove(meterId);
  } else {
    if (next.length >= kMeterComparisonMaxSelection) return;
    next.add(meterId);
  }
  ref.read(meterComparisonSelectionProvider(key).notifier).state = next;
}
