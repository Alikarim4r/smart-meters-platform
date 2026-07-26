import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:smart_meters_core/smart_meters_core.dart';

import '../utils/dashboard_date_range.dart';
import '../utils/dashboard_filters.dart';
import 'report_models.dart';

Future<ReportExportOptions?> showReportExportDialog({
  required BuildContext context,
  required ReportType defaultType,
  String? categoryId,
  ChartPeriod? defaultPeriod,
  DashboardDateSelection? defaultDateSelection,
}) async {
  var type = defaultType;
  var format = ReportFormat.pdf;
  var period = defaultPeriod ?? ChartPeriod.last30Days;
  var includePhotos = false;
  var includeCharts = false;
  var useDashboardRange = defaultDateSelection != null;
  var dateSelection = defaultDateSelection ??
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
            title: const Text('Export report'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DropdownButtonFormField<ReportFormat>(
                    initialValue: format,
                    decoration: const InputDecoration(
                      labelText: 'Format',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      for (final item in allowedFormats)
                        DropdownMenuItem(
                          value: item,
                          child: Text(item.label),
                        ),
                    ],
                    onChanged: (value) {
                      if (value != null) setState(() => format = value);
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<ChartPeriod>(
                    initialValue: period,
                    decoration: const InputDecoration(
                      labelText: 'Period',
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
                    title: const Text('Use dashboard selected range'),
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
                      decoration: const InputDecoration(
                        labelText: 'Date preset',
                        border: OutlineInputBorder(),
                        helperText: kImportedReadingsHint,
                      ),
                      items: [
                        for (final item in [
                          DashboardDatePreset.currentMonth,
                          DashboardDatePreset.last30Days,
                          DashboardDatePreset.customRange,
                          if (kDebugMode) ...[
                            DashboardDatePreset.march2026,
                            DashboardDatePreset.april2026,
                            DashboardDatePreset.may2026,
                          ],
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
                      title: const Text('Include photo indicator'),
                      subtitle:
                          const Text('Shows yes/no; no full photos by default'),
                      value: includePhotos,
                      onChanged: (value) =>
                          setState(() => includePhotos = value),
                    ),
                  ],
                  if (format == ReportFormat.pdf) ...[
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Include charts'),
                      subtitle:
                          const Text('Charts as tables in PDF for now'),
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
                child: const Text('Cancel'),
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
                child: const Text('Export'),
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
    ReportType.allSitesSummary => [ReportFormat.excel, ReportFormat.pdf],
    ReportType.siteSummary => [ReportFormat.pdf, ReportFormat.excel],
  };
}
