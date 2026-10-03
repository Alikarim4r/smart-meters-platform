import 'package:flutter/material.dart';
import 'package:smart_meters_core/smart_meters_core.dart';

import '../utils/dashboard_date_range.dart';
import 'report_models.dart';
import '../l10n/app_strings.dart';

Future<ReportExportOptions?> showReportExportDialog({
  required BuildContext context,
  required ReportType defaultType,
  String? categoryId,
  ChartPeriod? defaultPeriod,
  DashboardDateSelection? defaultDateSelection,
}) async {
  var type = defaultType;
  var format = ReportFormat.pdf;
  var period = defaultPeriod ?? ChartPeriod.weekly;
  var includePhotos = false;
  var includeCharts = false;
  var useDashboardRange = defaultDateSelection != null;
  var dateSelection =
      defaultDateSelection ??
      DashboardDateSelection.forPreset(
        preset: DashboardDatePreset.currentMonth,
        currentBusinessDate: DateTime.now(),
      );

  final allowedFormats = _formatsForType(type);

  return showDialog<ReportExportOptions>(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text(
              dashboardText(context, 'Export report', 'تصدير التقرير'),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DropdownButtonFormField<ReportFormat>(
                    initialValue: format,
                    decoration: InputDecoration(
                      labelText: dashboardText(context, 'Format', 'الصيغة'),
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      for (final item in allowedFormats)
                        DropdownMenuItem(value: item, child: Text(item.label)),
                    ],
                    onChanged: (value) {
                      if (value != null) setState(() => format = value);
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<ChartPeriod>(
                    initialValue: period,
                    decoration: InputDecoration(
                      labelText: dashboardText(context, 'Period', 'الفترة'),
                      border: OutlineInputBorder(),
                    ),
                    items: ChartPeriod.values
                        .map(
                          (item) => DropdownMenuItem(
                            value: item,
                            child: Text(item.label),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) setState(() => period = value);
                    },
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      dashboardText(
                        context,
                        'Use dashboard selected range',
                        'استخدام النطاق المحدد في لوحة العرض',
                      ),
                    ),
                    subtitle: Text(
                      defaultDateSelection?.displayLabel ??
                          'Use the date range shown on the dashboard',
                    ),
                    value: useDashboardRange,
                    onChanged: defaultDateSelection == null
                        ? null
                        : (value) => setState(() => useDashboardRange = value),
                  ),
                  if (!useDashboardRange) ...[
                    DropdownButtonFormField<DashboardDatePreset>(
                      initialValue: dateSelection.preset,
                      decoration: InputDecoration(
                        labelText: dashboardText(
                          context,
                          'Date preset',
                          'النطاق الزمني',
                        ),
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        for (final item in [
                          DashboardDatePreset.currentMonth,
                          DashboardDatePreset.last30Days,
                          DashboardDatePreset.customRange,
                        ])
                          DropdownMenuItem(
                            value: item,
                            child: Text(item.label),
                          ),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() {
                          dateSelection = DashboardDateSelection.forPreset(
                            preset: value,
                            currentBusinessDate: DateTime.now(),
                            customStart: dateSelection.startDate,
                            customEnd: dateSelection.endDate,
                          );
                        });
                      },
                    ),
                    if (dateSelection.preset ==
                        DashboardDatePreset.customRange) ...[
                      const SizedBox(height: 8),
                      Text(
                        formatDashboardDateSelectionLabel(dateSelection),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ] else if (defaultDateSelection != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      defaultDateSelection.displayLabel,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                  if (format == ReportFormat.pdf &&
                      (type == ReportType.readings ||
                          type == ReportType.siteSummary)) ...[
                    const SizedBox(height: 8),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        dashboardText(
                          context,
                          'Include photo indicator',
                          'تضمين مؤشر الصورة',
                        ),
                      ),
                      subtitle: Text(
                        dashboardText(
                          context,
                          'Shows yes/no; no full photos by default',
                          'يعرض نعم/لا؛ لا يتم تضمين الصور الكاملة افتراضيًا',
                        ),
                      ),
                      value: includePhotos,
                      onChanged: (value) =>
                          setState(() => includePhotos = value),
                    ),
                  ],
                  if (format == ReportFormat.pdf) ...[
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        dashboardText(
                          context,
                          'Include charts',
                          'تضمين الرسوم',
                        ),
                      ),
                      subtitle: Text(
                        dashboardText(
                          context,
                          'Slower — loads full-period consumption for chart/ranking sections',
                          'أبطأ — يحمّل استهلاك الفترة بالكامل للرسوم والترتيب',
                        ),
                      ),
                      value: includeCharts,
                      onChanged: (value) =>
                          setState(() => includeCharts = value),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(dashboardText(context, 'Cancel', 'إلغاء')),
              ),
              FilledButton(
                onPressed: () {
                  final effectiveSelection = useDashboardRange
                      ? defaultDateSelection!
                      : dateSelection;
                  Navigator.of(context).pop(
                    ReportExportOptions(
                      type: type,
                      format: format,
                      period: period,
                      categoryId: categoryId,
                      includePhotos: includePhotos,
                      includeCharts: includeCharts,
                      dataAnchorDate: effectiveSelection.businessDate,
                      rangeStart: effectiveSelection.isRangeMode
                          ? effectiveSelection.startDate
                          : null,
                      rangeEnd: effectiveSelection.endDate,
                    ),
                  );
                },
                child: Text(dashboardText(context, 'Export', 'تصدير')),
              ),
            ],
          );
        },
      );
    },
  );
}

List<ReportFormat> _formatsForType(ReportType type) {
  return switch (type) {
    ReportType.readings => [ReportFormat.excel, ReportFormat.pdf],
    ReportType.consumption => [ReportFormat.excel, ReportFormat.pdf],
    ReportType.categoryConsumption => [ReportFormat.excel, ReportFormat.pdf],
    ReportType.cop => [ReportFormat.excel, ReportFormat.pdf],
    ReportType.conservation => [ReportFormat.excel, ReportFormat.pdf],
    ReportType.allSitesSummary => [ReportFormat.excel, ReportFormat.pdf],
    ReportType.siteSummary => [ReportFormat.pdf, ReportFormat.excel],
  };
}
