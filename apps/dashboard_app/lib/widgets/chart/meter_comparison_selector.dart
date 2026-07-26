import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_meters_core/smart_meters_core.dart';

import '../../l10n/app_strings.dart';
import '../../providers/chart_providers.dart';
import '../../providers/shell_providers.dart';
import '../../theme/design_system/dashboard_design_system.dart';
import '../../theme/dashboard_theme.dart';

class MeterComparisonSelector extends ConsumerStatefulWidget {
  const MeterComparisonSelector({
    super.key,
    required this.siteId,
    required this.categoryId,
    required this.meters,
    required this.comparisonKey,
  });

  final String siteId;
  final String categoryId;
  final List<MeterReadingCardData> meters;
  final String comparisonKey;

  @override
  ConsumerState<MeterComparisonSelector> createState() =>
      _MeterComparisonSelectorState();
}

class _MeterComparisonSelectorState extends ConsumerState<MeterComparisonSelector> {
  final _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  String _query = '';

  @override
  void dispose() {
    _removeOverlay();
    super.dispose();
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _toggleOverlay() {
    if (_overlayEntry != null) {
      _removeOverlay();
      setState(() {});
      return;
    }
    _overlayEntry = _buildOverlay();
    Overlay.of(context).insert(_overlayEntry!);
    setState(() {});
  }

  OverlayEntry _buildOverlay() {
    return OverlayEntry(
      builder: (context) {
        // Read selection inside the builder so checkbox taps refresh the UI.
        final selected =
            ref.read(meterComparisonSelectionProvider(widget.comparisonKey));
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  _removeOverlay();
                  setState(() {});
                },
              ),
            ),
            CompositedTransformFollower(
              link: _layerLink,
              showWhenUnlinked: false,
              offset: const Offset(0, 44),
              child: Material(
                elevation: 8,
                shadowColor: Colors.black26,
                borderRadius: BorderRadius.circular(12),
                color: dashboardColors(context).card,
                clipBehavior: Clip.antiAlias,
                child: SizedBox(
                  width: (MediaQuery.sizeOf(context).width - 24).clamp(280.0, 360.0),
                  height: 320,
                    child: _ComparisonDropdownBody(
                      meters: widget.meters,
                      selected: selected,
                      query: _query,
                      onQueryChanged: (value) {
                        setState(() => _query = value);
                        _overlayEntry?.markNeedsBuild();
                      },
                      onSelectionChanged: (next) {
                        ref
                            .read(
                              meterComparisonSelectionProvider(
                                widget.comparisonKey,
                              ).notifier,
                            )
                            .state = next;
                        ref
                            .read(
                              meterComparisonRecentProvider(
                                widget.comparisonKey,
                              ).notifier,
                            )
                            .state = next.toList();
                        _overlayEntry?.markNeedsBuild();
                      },
                      onOverlayRefresh: () => _overlayEntry?.markNeedsBuild(),
                      comparisonKey: widget.comparisonKey,
                    ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  String _meterLabel(String meterId) {
    for (final meter in widget.meters) {
      if (meter.meterId == meterId) return meter.meterCode;
    }
    return meterId;
  }

  @override
  Widget build(BuildContext context) {
    final colors = dashboardColors(context);
    final selected = ref.watch(meterComparisonSelectionProvider(widget.comparisonKey));
    final isOpen = _overlayEntry != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Compare meters',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: colors.textPrimary,
              ),
        ),
        const SizedBox(height: DashboardSpacing.xs),
        CompositedTransformTarget(
          link: _layerLink,
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: widget.meters.length < 2 ? null : _toggleOverlay,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 44),
                alignment: Alignment.centerLeft,
                backgroundColor: isOpen
                    ? colors.cardElevated
                    : colors.card.withValues(alpha: 0.92),
              ),
              child: Row(
                children: [
                  Icon(Icons.search, size: 18, color: colors.textMuted),
                  const SizedBox(width: DashboardSpacing.xs),
                  Expanded(
                    child: Text(
                      selected.isEmpty
                          ? 'Search and select meters (max $kMeterComparisonMaxSelection)'
                          : '${selected.length} meter${selected.length == 1 ? '' : 's'} selected',
                      style: TextStyle(
                        fontSize: 13,
                        color: colors.textPrimary,
                      ),
                    ),
                  ),
                  Icon(
                    isOpen
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: colors.textMuted,
                  ),
                ],
              ),
            ),
          ),
        ),
        if (selected.isNotEmpty) ...[
          const SizedBox(height: DashboardSpacing.xs),
          Wrap(
            spacing: DashboardSpacing.xxs,
            runSpacing: DashboardSpacing.xxs,
            children: [
              for (final meterId in selected)
                InputChip(
                  label: Text(_meterLabel(meterId)),
                  labelStyle: TextStyle(fontSize: 11, color: colors.textPrimary),
                  deleteIcon: const Icon(Icons.close, size: 14),
                  onDeleted: () {
                    final next = Set<String>.from(selected)..remove(meterId);
                    ref
                        .read(meterComparisonSelectionProvider(widget.comparisonKey).notifier)
                        .state = next;
                  },
                ),
              if (selected.isNotEmpty)
                ActionChip(
                  label: const Text('Clear'),
                  onPressed: () => ref
                      .read(meterComparisonSelectionProvider(widget.comparisonKey).notifier)
                      .state = {},
                ),
            ],
          ),
        ],
        if (selected.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: DashboardSpacing.xxs),
            child: Text(
              'Main meters are selected by default. Add others to compare.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.textMuted,
                  ),
            ),
          ),
      ],
    );
  }
}

class _ComparisonDropdownBody extends ConsumerWidget {
  const _ComparisonDropdownBody({
    required this.meters,
    required this.selected,
    required this.query,
    required this.onQueryChanged,
    required this.onSelectionChanged,
    required this.comparisonKey,
    this.onOverlayRefresh,
  });

  final List<MeterReadingCardData> meters;
  final Set<String> selected;
  final String query;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<Set<String>> onSelectionChanged;
  final String comparisonKey;
  final VoidCallback? onOverlayRefresh;

  List<MeterReadingCardData> get _filtered {
    if (query.trim().isEmpty) return meters;
    final q = query.trim().toLowerCase();
    return meters
        .where(
          (m) =>
              m.meterCode.toLowerCase().contains(q) ||
              m.meterName.toLowerCase().contains(q),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = dashboardColors(context);
    final filtered = _filtered;
    final favorites = ref.watch(meterComparisonFavoritesProvider(comparisonKey));
    final recent = ref.watch(meterComparisonRecentProvider(comparisonKey));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(DashboardSpacing.sm),
          child: TextField(
            autofocus: true,
            style: TextStyle(color: colors.textPrimary, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Search meters',
              hintStyle: TextStyle(color: colors.textMuted),
              prefixIcon: Icon(Icons.search, size: 18, color: colors.textMuted),
              isDense: true,
              filled: true,
              fillColor: colors.inputFill,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: colors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: colors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: colors.navy.withValues(alpha: 0.5)),
              ),
            ),
            onChanged: onQueryChanged,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: DashboardSpacing.sm),
          child: Wrap(
            spacing: DashboardSpacing.xxs,
            children: [
              Text(
                '${selected.length}/$kMeterComparisonMaxSelection',
                style: DashboardTypography.label(context),
              ),
              ActionChip(
                label: const Text('Select mains'),
                onPressed: () => onSelectionChanged(
                  defaultChartComparisonMeterIds(meters),
                ),
              ),
              ActionChip(
                label: const Text('Clear'),
                onPressed: () => onSelectionChanged({}),
              ),
            ],
          ),
        ),
        if (recent.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: DashboardSpacing.sm),
            child: Text('Recent', style: DashboardTypography.label(context)),
          ),
        if (recent.isNotEmpty)
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: DashboardSpacing.sm),
              children: [
                for (final id in recent)
                  Padding(
                    padding: const EdgeInsets.only(right: DashboardSpacing.xxs),
                    child: FilterChip(
                      label: Text(_labelFor(id)),
                      selected: selected.contains(id),
                      onSelected: (_) {
                        final next = Set<String>.from(selected);
                        if (next.contains(id)) {
                          next.remove(id);
                        } else if (next.length < kMeterComparisonMaxSelection) {
                          next.add(id);
                        }
                        onSelectionChanged(next);
                      },
                    ),
                  ),
              ],
            ),
          ),
        const SizedBox(height: DashboardSpacing.xs),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: DashboardSpacing.xs),
            itemCount: filtered.length,
            itemBuilder: (context, index) {
              final meter = filtered[index];
              final checked = selected.contains(meter.meterId);
              final isFavorite = favorites.contains(meter.meterId);
              return CheckboxListTile(
                dense: true,
                controlAffinity: ListTileControlAffinity.leading,
                value: checked,
                secondary: IconButton(
                  icon: Icon(
                    isFavorite ? Icons.star_rounded : Icons.star_outline_rounded,
                    size: 18,
                    color: isFavorite
                        ? DashboardColors.accentGold(context)
                        : colors.textMuted,
                  ),
                  onPressed: () {
                    final next = Set<String>.from(favorites);
                    if (isFavorite) {
                      next.remove(meter.meterId);
                    } else {
                      next.add(meter.meterId);
                    }
                    ref
                        .read(meterComparisonFavoritesProvider(comparisonKey).notifier)
                        .state = next;
                    onOverlayRefresh?.call();
                  },
                ),
                title: Text(
                  meter.meterCode,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: colors.textPrimary,
                    fontSize: 13,
                  ),
                ),
                subtitle: Text(
                  AppStrings.of(context).localizedName(
                    en: meter.meterName,
                    ar: meter.meterNameAr,
                  ),
                  style: TextStyle(color: colors.textMuted, fontSize: 11),
                ),
                onChanged: (value) {
                  final next = Set<String>.from(selected);
                  if (value == true) {
                    if (next.length >= kMeterComparisonMaxSelection) return;
                    next.add(meter.meterId);
                  } else {
                    next.remove(meter.meterId);
                  }
                  onSelectionChanged(next);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  String _labelFor(String meterId) {
    for (final meter in meters) {
      if (meter.meterId == meterId) return meter.meterCode;
    }
    return meterId;
  }
}
