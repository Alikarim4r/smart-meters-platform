import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:smart_meters_core/smart_meters_core.dart';

import '../../l10n/app_strings.dart';
import '../../theme/dashboard_theme.dart';
import '../../utils/chart_period_selection.dart';
import '../../utils/dashboard_date_range.dart';

Future<DashboardDateSelection?> showDashboardDatePicker({
  required BuildContext context,
  required DashboardDateSelection initial,
  String? siteId,
}) {
  final useSheet = MediaQuery.sizeOf(context).width < 900;
  if (useSheet) {
    return showModalBottomSheet<DashboardDateSelection>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: dashboardColors(context).dialog,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
        child: DashboardDatePickerPanel(
          initial: initial,
          siteId: siteId,
          embedded: true,
        ),
      ),
    );
  }

  return showDialog<DashboardDateSelection>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => DashboardDatePickerPanel(
      initial: initial,
      siteId: siteId,
    ),
  );
}

class DashboardDateSelector extends StatelessWidget {
  const DashboardDateSelector({
    super.key,
    required this.selection,
    required this.onChanged,
    this.siteId,
    this.width = 260,
    this.compact = false,
  });

  final DashboardDateSelection selection;
  final ValueChanged<DashboardDateSelection> onChanged;
  final String? siteId;
  final double width;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = dashboardColors(context);
    final s = AppStrings.of(context);
    final iconSize = compact ? 18.0 : 20.0;
    final label = s.compactDateSelectorLabel(selection);
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    final previousIcon =
        isRtl ? Icons.chevron_right_rounded : Icons.chevron_left_rounded;
    final nextIcon =
        isRtl ? Icons.chevron_left_rounded : Icons.chevron_right_rounded;

    return SizedBox(
      width: width,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.card.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colors.border),
        ),
        child: Row(
          children: [
            IconButton(
              tooltip: s.previousPeriod,
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: BoxConstraints(
                minWidth: compact ? 32 : 36,
                minHeight: compact ? 32 : 36,
              ),
              onPressed: () => onChanged(
                shiftDashboardDateSelection(selection, step: -1),
              ),
              icon: Icon(
                previousIcon,
                size: iconSize,
                color: colors.textPrimary,
              ),
            ),
            Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () async {
                  final result = await showDashboardDatePicker(
                    context: context,
                    initial: selection,
                    siteId: siteId,
                  );
                  if (result != null) {
                    if (kDebugMode) {
                      debugPrint(
                        '[date] picker applied mode=${result.mode.name} '
                        'preset=${result.preset.name} '
                        'range=${result.startDate.toIso8601String().substring(0, 10)}..'
                        '${result.endDate.toIso8601String().substring(0, 10)}',
                      );
                    }
                    onChanged(result);
                  }
                },
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: compact ? 2 : 4,
                    vertical: compact ? 8 : 10,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.calendar_today_outlined,
                        size: compact ? 14 : 16,
                        color: colors.textPrimary,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          label,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: compact ? 11 : 12,
                            fontWeight: FontWeight.w600,
                            color: colors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            IconButton(
              tooltip: s.nextPeriod,
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: BoxConstraints(
                minWidth: compact ? 32 : 36,
                minHeight: compact ? 32 : 36,
              ),
              onPressed: () => onChanged(
                shiftDashboardDateSelection(selection, step: 1),
              ),
              icon: Icon(
                nextIcon,
                size: iconSize,
                color: colors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _PickerKind { last30Days, twelveMonths, fiveYears, customRange }

class DashboardDatePickerPanel extends StatefulWidget {
  const DashboardDatePickerPanel({
    super.key,
    required this.initial,
    this.siteId,
    this.embedded = false,
  });

  final DashboardDateSelection initial;
  final String? siteId;
  final bool embedded;

  @override
  State<DashboardDatePickerPanel> createState() =>
      _DashboardDatePickerPanelState();
}

class _DashboardDatePickerPanelState extends State<DashboardDatePickerPanel> {
  late DateTime _businessDay;
  late _PickerKind _kind;
  DashboardDateSelection? _pendingSelection;
  DateTime? _rangeAnchor;
  DateTime? _rangeEnd;

  @override
  void initState() {
    super.initState();
    _businessDay = widget.initial.subsequentReadingDate;
    _kind = _kindFromSelection(widget.initial);
    _pendingSelection = widget.initial;
    if (_kind == _PickerKind.customRange && !widget.initial.isSingleDay) {
      _rangeAnchor = widget.initial.startDate;
      _rangeEnd = widget.initial.endDate;
    }
  }

  _PickerKind _kindFromSelection(DashboardDateSelection selection) {
    final matched = chartPeriodStateForDateSelection(selection);
    if (matched != null) {
      return switch (matched.kind) {
        UtilityChartPeriodKind.last7Days => _PickerKind.last30Days,
        UtilityChartPeriodKind.last30Days => _PickerKind.last30Days,
        UtilityChartPeriodKind.twelveMonths => _PickerKind.twelveMonths,
        UtilityChartPeriodKind.fiveYears => _PickerKind.fiveYears,
      };
    }
    if (selection.isSingleDay) return _PickerKind.customRange;
    return _PickerKind.customRange;
  }

  DashboardDateSelection _selectionForKind(_PickerKind kind, DateTime anchor) {
    return switch (kind) {
      _PickerKind.last30Days => dateSelectionForChartPeriodKind(
          kind: UtilityChartPeriodKind.last30Days,
          anchorDate: anchor,
        ),
      _PickerKind.twelveMonths => dateSelectionForChartPeriodKind(
          kind: UtilityChartPeriodKind.twelveMonths,
          anchorDate: anchor,
        ),
      _PickerKind.fiveYears => dateSelectionForChartPeriodKind(
          kind: UtilityChartPeriodKind.fiveYears,
          anchorDate: anchor,
        ),
      _PickerKind.customRange => DashboardDateSelection.singleDay(
          day: normalizeDashboardDate(anchor),
          preset: DashboardDatePreset.pickDay,
        ),
    };
  }

  /// Prepares a period — does NOT close the dialog. User must press Apply.
  /// Re-tapping the same kind is a no-op (no double-tap toggle).
  void _selectKind(_PickerKind kind) {
    if (kind == _kind && kind != _PickerKind.customRange) return;
    setState(() {
      _kind = kind;
      _rangeAnchor = null;
      _rangeEnd = null;
      if (kind == _PickerKind.customRange) {
        _pendingSelection = null;
      } else {
        // Preset windows end at the currently selected business day.
        _pendingSelection = _selectionForKind(kind, _businessDay);
      }
    });
  }

  void _onCalendarDayPressed(DateTime date) {
    final day = normalizeDashboardDate(date);
    setState(() {
      _businessDay = day;
      switch (_kind) {
        case _PickerKind.last30Days:
        case _PickerKind.twelveMonths:
        case _PickerKind.fiveYears:
          // Preset ranges are anchored to today; calendar is for custom only.
          _kind = _PickerKind.customRange;
          _rangeAnchor = day;
          _rangeEnd = null;
          _pendingSelection = null;
        case _PickerKind.customRange:
          if (_rangeAnchor == null || _rangeEnd != null) {
            _rangeAnchor = day;
            _rangeEnd = null;
            _pendingSelection = null;
          } else {
            final start = _rangeAnchor!;
            final end = day;
            final orderedStart = end.isBefore(start) ? end : start;
            final orderedEnd = end.isBefore(start) ? start : end;
            _rangeAnchor = orderedStart;
            _rangeEnd = orderedEnd;
            _pendingSelection = DashboardDateSelection.forPreset(
              preset: DashboardDatePreset.customRange,
              currentBusinessDate: qatarBusinessDate(),
              customStart: orderedStart,
              customEnd: orderedEnd,
            );
          }
      }
    });
  }

  void _applyToday() {
    final today = qatarBusinessDate();
    Navigator.of(context).pop(
      DashboardDateSelection.forPreset(
        preset: DashboardDatePreset.today,
        currentBusinessDate: today,
      ),
    );
  }

  void _apply() {
    final result = _pendingSelection ??
        DashboardDateSelection.singleDay(
          day: _businessDay,
          preset: DashboardDatePreset.pickDay,
        );
    if (kDebugMode) {
      debugPrint(
        '[date] apply pressed mode=${result.mode.name} '
        '${result.startDate.toIso8601String().substring(0, 10)}..'
        '${result.endDate.toIso8601String().substring(0, 10)}',
      );
    }
    Navigator.of(context).pop(result);
  }

  void _cancel() => Navigator.of(context).pop();

  Widget _periodButton({
    required String label,
    required _PickerKind kind,
    required ColorScheme scheme,
  }) {
    final selected = _kind == kind;
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 6, bottom: 6),
      child: OutlinedButton(
        onPressed: () => _selectKind(kind),
        style: OutlinedButton.styleFrom(
          backgroundColor:
              selected ? scheme.primary.withValues(alpha: 0.12) : null,
          foregroundColor: selected ? scheme.primary : null,
          side: BorderSide(
            color: selected ? scheme.primary : scheme.outlineVariant,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          visualDensity: VisualDensity.compact,
        ),
        child: Text(label),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = dashboardColors(context);
    final s = AppStrings.of(context);
    final today = qatarBusinessDate();
    final calendarDay = _businessDay.isAfter(today) ? today : _businessDay;
    final scheme = Theme.of(context).colorScheme;
    final canApply =
        !(_kind == _PickerKind.customRange && _pendingSelection == null);

    final body = SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            s.isAr
                ? 'اختر آخر ٣١ يوماً، ١٢ شهراً، ٥ سنوات، أو حدّد فترة يدوياً. ثم اضغط تطبيق.'
                : 'Choose Last 31 days, 12 months, 5 years, or a custom range. Then press Apply.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colors.textMuted,
                  height: 1.35,
                ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              onPressed: _applyToday,
              icon: const Icon(Icons.today_outlined, size: 18),
              label: Text(s.isAr ? 'اليوم (تطبيق مباشر)' : 'Today (apply now)'),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            s.isAr ? 'الفترة' : 'Period',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: colors.textPrimary,
                ),
          ),
          const SizedBox(height: 6),
          Wrap(
            children: [
              _periodButton(
                label: s.isAr ? 'آخر ٣١ يوماً' : 'Last 31 days',
                kind: _PickerKind.last30Days,
                scheme: scheme,
              ),
              _periodButton(
                label: s.isAr ? '١٢ شهراً' : '12 months',
                kind: _PickerKind.twelveMonths,
                scheme: scheme,
              ),
              _periodButton(
                label: s.isAr ? '٥ سنوات' : '5 years',
                kind: _PickerKind.fiveYears,
                scheme: scheme,
              ),
              _periodButton(
                label: s.customRange,
                kind: _PickerKind.customRange,
                scheme: scheme,
              ),
            ],
          ),
          if (_pendingSelection != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: colors.cardElevated,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: colors.border),
              ),
              child: Text(
                s.isAr
                    ? 'المعاينة: ${s.compactDateSelectorLabel(_pendingSelection!)} — اضغط تطبيق للتأكيد'
                    : 'Preview: ${s.compactDateSelectorLabel(_pendingSelection!)} — press Apply to confirm',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: colors.textPrimary,
                    ),
              ),
            ),
          ],
          if (_kind == _PickerKind.customRange) ...[
            const SizedBox(height: 8),
            Text(
              _rangeAnchor == null
                  ? (s.isAr ? 'اضغط تاريخ البداية' : 'Tap the start date')
                  : _rangeEnd == null
                      ? (s.isAr ? 'اضغط تاريخ النهاية' : 'Tap the end date')
                      : (s.isAr
                          ? 'النطاق جاهز — اضغط تطبيق'
                          : 'Range ready — press Apply'),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.textMuted,
                  ),
            ),
          ],
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colors.cardElevated,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: colors.border),
            ),
            child: SizedBox(
              height: 320,
              child: CalendarDatePicker(
                initialDate: calendarDay,
                currentDate: today,
                firstDate: DateTime(2020, 1, 1),
                lastDate: DateTime(2035, 12, 31),
                onDateChanged: _onCalendarDayPressed,
              ),
            ),
          ),
        ],
      ),
    );

    final actions = Row(
      children: [
        TextButton(
          onPressed: _cancel,
          child: Text(s.cancel),
        ),
        const Spacer(),
        FilledButton(
          onPressed: canApply ? _apply : null,
          child: Text(s.apply),
        ),
      ],
    );

    if (widget.embedded) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              s.isAr ? 'اختيار تاريخ العمل' : 'Select business date',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: colors.textPrimary,
                  ),
            ),
            const SizedBox(height: 12),
            body,
            const SizedBox(height: 12),
            actions,
          ],
        ),
      );
    }

    return AlertDialog(
      backgroundColor: colors.dialog,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        s.isAr ? 'اختيار تاريخ العمل' : 'Select business date',
        style: TextStyle(
          color: colors.textPrimary,
          fontWeight: FontWeight.w700,
        ),
      ),
      content: SizedBox(width: 420, child: body),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      actions: [actions],
    );
  }
}
