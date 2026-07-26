import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_meters_core/smart_meters_core.dart';

import '../../l10n/app_strings.dart';
import '../../providers/chart_providers.dart';
import '../../reports/meter_export_service.dart';
import '../../theme/design_system/dashboard_design_system.dart';
import '../../theme/meter_card_decoration.dart';
import '../../utils/dashboard_date_range.dart';
import '../../utils/meter_reading_filters.dart';
import '../premium/meter_status_badge.dart';
import '../premium/utility_colors.dart';
import 'reading_photo_viewer_dialog.dart';

/// Enterprise meter card — name-first hierarchy, hero consumption, minimal chrome.
class MeterReadingCard extends ConsumerWidget {
  const MeterReadingCard({
    super.key,
    required this.data,
    required this.siteId,
    this.dateSelection,
    this.categoryId,
    this.onViewReadings,
    this.onCompare,
    this.compact = false,
    this.isBranch = false,
    this.searchHighlight,
    this.expandToFill = false,
  });

  final MeterReadingCardData data;
  final String siteId;
  final DashboardDateSelection? dateSelection;
  final String? categoryId;
  final VoidCallback? onViewReadings;
  final VoidCallback? onCompare;
  final bool compact;
  final bool isBranch;
  final String? searchHighlight;

  /// When true (desktop grid cells), fill the parent height and pin the footer.
  final bool expandToFill;

  String get _utilityKey => utilityKeyFromCard(data);
  Color get _accent => DashboardUtilityColors.forCategoryCode(_utilityKey);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final utilityKey = _utilityKey;
    final isMain = data.isMain && !isBranch;
    final comparing = onCompare != null &&
        categoryId != null &&
        ref
            .watch(
              meterComparisonSelectionProvider(
                meterComparisonKey(siteId: siteId, categoryId: categoryId!),
              ),
            )
            .contains(data.meterId);

    final body = Padding(
      padding: const EdgeInsets.fromLTRB(
        DashboardSpacing.sm + 4,
        DashboardSpacing.sm - 2,
        DashboardSpacing.sm,
        2,
      ),
      child: Column(
        mainAxisSize: expandToFill ? MainAxisSize.max : MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _CardHeader(
            data: data,
            accent: _accent,
            utilityKey: utilityKey,
            searchHighlight: searchHighlight,
            comparing: comparing,
          ),
          const SizedBox(height: DashboardSpacing.xxs + 2),
          _ReadingRow(
            data: data,
            onPreviousPhoto: () => _openPhoto(
              context,
              ref,
              ReadingPhotoKind.previous,
            ),
            onCurrentPhoto: () => _openPhoto(
              context,
              ref,
              ReadingPhotoKind.current,
            ),
          ),
          const SizedBox(height: DashboardSpacing.xxs + 2),
          _ConsumptionHero(data: data, accent: _accent),
          if (!compact) ...[
            if (expandToFill)
              const Spacer(flex: 1)
            else
              const SizedBox(height: DashboardSpacing.xxs),
            Divider(
              height: 1,
              color: DashboardColors.border(context).withValues(alpha: 0.35),
            ),
            _CardFooter(
              onViewReadings: onViewReadings,
              onCompare: onCompare == null
                  ? null
                  : () => _handleCompare(context, ref),
              onExport: () => _export(context, ref),
              comparing: comparing,
            ),
          ],
        ],
      ),
    );

    return AnimatedContainer(
      duration: DashboardMotion.card,
      curve: DashboardMotion.standard,
      decoration: comparing
          ? BoxDecoration(
              borderRadius: BorderRadius.circular(DashboardRadius.card),
              border: Border.all(color: _accent, width: 1.5),
            )
          : null,
      child: MeterGlassCard(
        utilityKey: utilityKey,
        isMain: isMain,
        child: Stack(
          children: [
            body,
            PositionedDirectional(
              start: 0,
              top: 0,
              bottom: 0,
              child: IgnorePointer(
                child: meterCardAccentStrip(
                  utilityKey: utilityKey,
                  isMain: isMain,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleCompare(BuildContext context, WidgetRef ref) {
    if (onCompare == null || categoryId == null) return;
    final key = meterComparisonKey(siteId: siteId, categoryId: categoryId!);
    final current = ref.read(meterComparisonSelectionProvider(key));
    final wasSelected = current.contains(data.meterId);
    if (!wasSelected && current.length >= kMeterComparisonMaxSelection) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.of(context).compareLimitReached)),
      );
      return;
    }
    onCompare!();
    final next = ref.read(meterComparisonSelectionProvider(key));
    final s = AppStrings.of(context);
    final message = next.contains(data.meterId)
        ? s.compareAdded(data.meterCode)
        : s.compareRemoved(data.meterCode);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  void _openPhoto(
    BuildContext context,
    WidgetRef ref,
    ReadingPhotoKind kind,
  ) {
    showReadingPhotoViewer(
      context: context,
      ref: ref,
      kind: kind,
      meterCode: data.meterCode,
      meterName: data.meterName,
      unitLabel: data.unitLabel,
      value: kind == ReadingPhotoKind.previous
          ? data.previousValue
          : data.latestValue,
      date: kind == ReadingPhotoKind.previous
          ? data.previousDate
          : data.latestEnteredAt ?? data.latestDate,
      hasPhoto: kind == ReadingPhotoKind.previous
          ? data.previousHasPhoto
          : data.hasPhoto,
      storagePath: kind == ReadingPhotoKind.previous
          ? data.previousImageStoragePath
          : data.imageStoragePath,
    );
  }

  Future<void> _export(BuildContext context, WidgetRef ref) async {
    if (dateSelection == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppStrings.of(context).exportFailed)),
        );
      }
      return;
    }
    final s = AppStrings.of(context);
    try {
      await MeterExportService(
        ref.read(dashboardRepositoryProvider),
      ).exportMeterReadings(
        siteId: siteId,
        meter: data,
        dateSelection: dateSelection!,
      );
    } on MeterExportEmptyException {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(s.exportNoReadings)),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(s.exportFailed)),
        );
      }
    }
  }
}

class _CardHeader extends StatelessWidget {
  const _CardHeader({
    required this.data,
    required this.accent,
    required this.utilityKey,
    this.searchHighlight,
    this.comparing = false,
  });

  final MeterReadingCardData data;
  final Color accent;
  final String utilityKey;
  final String? searchHighlight;
  final bool comparing;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final displayName =
        s.localizedName(en: data.meterName, ar: data.meterNameAr);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _HighlightedText(
          text: displayName,
          highlight: searchHighlight,
          style: DashboardTypography.meterName(context),
        ),
        const SizedBox(height: 2),
        _HighlightedText(
          text: data.meterCode,
          highlight: searchHighlight,
          style: DashboardTypography.meterCode(context),
        ),
        const SizedBox(height: DashboardSpacing.xxs),
        // Keep badges on one row so fixed grid height never overflows.
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: [
              MeterStatusBadge(
                label: s.catalogLabel(data.categoryName),
                color: accent,
                compact: true,
                muted: true,
              ),
              const SizedBox(width: DashboardSpacing.xxs),
              MeterStatusBadge(
                label: s.catalogLabel(data.sourceName),
                color: accent,
                compact: true,
              ),
              const SizedBox(width: DashboardSpacing.xxs),
              MeterStatusBadge(
                label: s.cardStatus(data.status),
                color: _statusColor(context, data.status),
                compact: true,
              ),
              if (comparing) ...[
                const SizedBox(width: DashboardSpacing.xxs),
                MeterStatusBadge(
                  label: s.compare,
                  color: accent,
                  compact: true,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Color _statusColor(BuildContext context, MeterReadingCardStatus status) =>
      switch (status) {
        MeterReadingCardStatus.submittedOnDate => DashboardColors.success(context),
        MeterReadingCardStatus.pendingOnDate => DashboardColors.warning(context),
        MeterReadingCardStatus.noReadingOnDate => DashboardColors.textMuted(context),
      };
}

class _HighlightedText extends StatelessWidget {
  const _HighlightedText({
    required this.text,
    required this.style,
    this.highlight,
  });

  final String text;
  final TextStyle style;
  final String? highlight;

  @override
  Widget build(BuildContext context) {
    final query = highlight?.trim().toLowerCase() ?? '';
    if (query.isEmpty || !text.toLowerCase().contains(query)) {
      return Text(
        text,
        style: style,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }
    final index = text.toLowerCase().indexOf(query);
    return RichText(
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(
        style: style,
        children: [
          TextSpan(text: text.substring(0, index)),
          TextSpan(
            text: text.substring(index, index + query.length),
            style: style.copyWith(
              backgroundColor:
                  DashboardColors.accent(context).withValues(alpha: 0.18),
            ),
          ),
          TextSpan(text: text.substring(index + query.length)),
        ],
      ),
    );
  }
}

class _ReadingRow extends StatelessWidget {
  const _ReadingRow({
    required this.data,
    required this.onPreviousPhoto,
    required this.onCurrentPhoto,
  });

  final MeterReadingCardData data;
  final VoidCallback onPreviousPhoto;
  final VoidCallback onCurrentPhoto;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    return Row(
      children: [
        Expanded(
          child: _ReadingCell(
            label: s.previous,
            value: data.hasPrevious ? _fmt(data.previousValue!) : '—',
            dateLabel: data.previousDate == null
                ? null
                : formatBusinessDateDisplay(data.previousDate!),
            onPhoto: onPreviousPhoto,
            enabled: photoButtonEnabled(
              hasPhoto: data.previousHasPhoto,
              storagePath: data.previousImageStoragePath,
            ),
          ),
        ),
        const SizedBox(width: DashboardSpacing.sm),
        Expanded(
          child: _ReadingCell(
            label: s.current,
            value: data.hasLatestOnDate ? _fmt(data.latestValue!) : '—',
            dateLabel: data.latestDate == null
                ? null
                : formatBusinessDateDisplay(data.latestDate!),
            onPhoto: onCurrentPhoto,
            enabled: photoButtonEnabled(
              hasPhoto: data.hasPhoto,
              storagePath: data.imageStoragePath,
            ),
          ),
        ),
      ],
    );
  }

  String _fmt(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);
}

class _ReadingCell extends StatelessWidget {
  const _ReadingCell({
    required this.label,
    required this.value,
    required this.onPhoto,
    required this.enabled,
    this.dateLabel,
  });

  final String label;
  final String value;
  final String? dateLabel;
  final VoidCallback onPhoto;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: DashboardTypography.label(context)),
        const SizedBox(height: DashboardSpacing.xxs),
        Row(
          children: [
            Expanded(
              child: Text(
                value,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: DashboardColors.textPrimary(context),
                    ),
              ),
            ),
            _PhotoButton(enabled: enabled, onTap: onPhoto),
          ],
        ),
        if (dateLabel != null && dateLabel!.isNotEmpty) ...[
          const SizedBox(height: 1),
          Text(
            dateLabel!,
            style: DashboardTypography.label(context).copyWith(fontSize: 10),
          ),
        ],
      ],
    );
  }
}

class _ConsumptionHero extends StatelessWidget {
  const _ConsumptionHero({required this.data, required this.accent});

  final MeterReadingCardData data;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final negative = data.hasNegativeConsumption;
    final color = negative ? DashboardColors.danger(context) : accent;
    return AnimatedContainer(
      duration: DashboardMotion.card,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: DashboardSpacing.sm - 2,
        vertical: DashboardSpacing.xxs + 1,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: 0.14),
            color.withValues(alpha: 0.06),
          ],
        ),
        borderRadius: BorderRadius.circular(DashboardRadius.control),
        border: Border.all(color: color.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppStrings.of(context).consumption,
            style: DashboardTypography.label(context).copyWith(fontSize: 10),
          ),
          const SizedBox(height: 1),
          Text(
            data.hasConsumption
                ? '${_fmt(data.consumptionValue!)} ${data.unitLabel}'
                : '—',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: DashboardTypography.kpiValue(context).copyWith(
              fontSize: 18,
              color: color,
              height: 1.05,
            ),
          ),
        ],
      ),
    );
  }

  String _fmt(double v) {
    final abs = v.abs();
    if (abs >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (abs >= 10000) return '${(v / 1000).toStringAsFixed(1)}k';
    if (v == v.roundToDouble()) return v.toStringAsFixed(0);
    return v.toStringAsFixed(2);
  }
}

class _PhotoButton extends StatelessWidget {
  const _PhotoButton({required this.enabled, required this.onTap});

  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    return Semantics(
      button: true,
      label: enabled ? s.viewPhoto : s.noPhoto,
      child: SizedBox(
        width: 22,
        height: 22,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(6),
          child: Icon(
            enabled ? DashboardIcons.camera : DashboardIcons.cameraOff,
            size: DashboardIcons.photo,
            color: enabled
                ? DashboardColors.textMuted(context)
                : DashboardColors.textMuted(context).withValues(alpha: 0.3),
          ),
        ),
      ),
    );
  }
}

class _CardFooter extends StatelessWidget {
  const _CardFooter({
    this.onViewReadings,
    this.onCompare,
    required this.onExport,
    this.comparing = false,
  });

  final VoidCallback? onViewReadings;
  final VoidCallback? onCompare;
  final VoidCallback onExport;
  final bool comparing;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    return Material(
      type: MaterialType.transparency,
      child: Row(
        children: [
          if (onViewReadings != null)
            _FooterAction(
              icon: DashboardIcons.history,
              label: s.history,
              onTap: onViewReadings!,
            ),
          _FooterAction(
            icon: DashboardIcons.export,
            label: s.export,
            onTap: onExport,
          ),
          if (onCompare != null)
            _FooterAction(
              icon: DashboardIcons.compare,
              label: s.compare,
              onTap: onCompare!,
              active: comparing,
            ),
        ],
      ),
    );
  }
}

class _FooterAction extends StatelessWidget {
  const _FooterAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final color = active
        ? DashboardColors.accent(context)
        : DashboardColors.textMuted(context);
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(DashboardRadius.chip),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(height: 2),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: DashboardTypography.label(context).copyWith(
                  fontSize: 10,
                  color: color,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
