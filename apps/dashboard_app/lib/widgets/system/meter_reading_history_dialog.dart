import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_meters_core/smart_meters_core.dart';

import '../../l10n/app_strings.dart';
import '../../theme/dashboard_palette.dart';
import '../../utils/dashboard_date_range.dart';
import '../../utils/dashboard_filters.dart';
import '../premium/dashboard_filter_decorations.dart';

Future<void> showMeterReadingHistoryDialog({
  required BuildContext context,
  required WidgetRef ref,
  required String siteId,
  required MeterReadingCardData meter,
  required DashboardDateSelection dateSelection,
}) {
  final useWide = MediaQuery.sizeOf(context).width >= 720;

  if (useWide) {
    return showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900, maxHeight: 640),
          child: MeterReadingHistoryContent(
            siteId: siteId,
            meter: meter,
            dateSelection: dateSelection,
          ),
        ),
      ),
    );
  }

  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => Scaffold(
        appBar: AppBar(
          title: Text('${meter.meterCode} · ${AppStrings.of(context).history}'),
        ),
        body: MeterReadingHistoryContent(
          siteId: siteId,
          meter: meter,
          dateSelection: dateSelection,
        ),
      ),
    ),
  );
}

class MeterReadingHistoryContent extends ConsumerStatefulWidget {
  const MeterReadingHistoryContent({
    super.key,
    required this.siteId,
    required this.meter,
    required this.dateSelection,
  });

  final String siteId;
  final MeterReadingCardData meter;
  final DashboardDateSelection dateSelection;

  @override
  ConsumerState<MeterReadingHistoryContent> createState() =>
      _MeterReadingHistoryContentState();
}

class _MeterReadingHistoryContentState
    extends ConsumerState<MeterReadingHistoryContent> {
  bool? _photoFilter;
  AsyncValue<List<DashboardReadingRow>> _readings = const AsyncValue.loading();

  @override
  void initState() {
    super.initState();
    _loadReadings();
  }

  Future<void> _loadReadings() async {
    setState(() => _readings = const AsyncValue.loading());
    try {
      final rows = await ref.read(dashboardRepositoryProvider).getRecentSiteReadings(
            siteId: widget.siteId,
            filters: DashboardReadingFilters(
              fromDate: widget.dateSelection.startDate,
              toDate: widget.dateSelection.endDate,
              meterId: widget.meter.meterId,
              hasPhoto: _photoFilter,
              limit: 2000,
            ),
          );
      if (mounted) {
        setState(() => _readings = AsyncValue.data(rows));
      }
    } catch (error, stack) {
      if (mounted) {
        setState(() => _readings = AsyncValue.error(error, stack));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            AppStrings.of(context).meterReadingHistory,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: DashboardPalette.navy,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            '${widget.meter.meterCode} · ${widget.meter.meterName}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: DashboardPalette.textMuted,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            formatDashboardDateSelectionLabel(widget.dateSelection),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: DashboardPalette.textMuted,
                ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<bool?>(
            isExpanded: true,
            initialValue: _photoFilter,
            decoration: premiumFilterDecoration(
              context: context,
              labelText: AppStrings.of(context).isAr
                  ? 'فلتر الصورة'
                  : 'Photo filter',
            ),
            items: [
              DropdownMenuItem(
                value: null,
                child: Text(
                  AppStrings.of(context).isAr
                      ? 'كل القراءات'
                      : 'All readings',
                ),
              ),
              DropdownMenuItem(
                value: true,
                child: Text(
                  AppStrings.of(context).isAr ? 'به صورة' : 'Has photo',
                ),
              ),
              DropdownMenuItem(
                value: false,
                child: Text(AppStrings.of(context).noPhoto),
              ),
            ],
            onChanged: (value) {
              setState(() => _photoFilter = value);
              _loadReadings();
            },
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _readings.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Text(
                  'Could not load readings',
                  style: TextStyle(color: DashboardPalette.textMuted),
                ),
              ),
              data: (rows) {
                if (rows.isEmpty) {
                  return Center(
                    child: Text(
                      AppStrings.of(context).isAr
                          ? 'لا توجد قراءات لنطاق التاريخ المحدد.'
                          : 'No readings for the selected date range.',
                    ),
                  );
                }

                final s = AppStrings.of(context);
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columns: [
                      DataColumn(label: Text(s.date)),
                      DataColumn(label: Text(s.reading)),
                      DataColumn(label: Text(s.consumption)),
                      DataColumn(label: Text(s.note)),
                      DataColumn(label: Text(s.photo)),
                      DataColumn(
                        label: Text(
                          s.isAr ? 'أُدخل بواسطة' : 'Submitted by',
                        ),
                      ),
                    ],
                    rows: [
                      for (var i = 0; i < rows.length; i++)
                        _buildRow(rows, i),
                    ],
                  ),
                );
              },
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(AppStrings.of(context).close),
            ),
          ),
        ],
      ),
    );
  }

  DataRow _buildRow(List<DashboardReadingRow> rows, int index) {
    final row = rows[index];
    final reading = row.reading;
    double? consumption;
    if (index + 1 < rows.length) {
      final prev = rows[index + 1].reading.rawValue;
      consumption = reading.rawValue - prev;
    }

    return DataRow(
      cells: [
        DataCell(Text(formatDashboardDate(reading.readingDate))),
        DataCell(Text('${reading.rawValue} ${row.unitLabel}')),
        DataCell(Text(
          consumption != null ? consumption.toStringAsFixed(2) : '—',
        )),
        DataCell(Text(row.reading.note ?? '—')),
        DataCell(
          reading.hasPhoto
              ? IconButton(
                  tooltip: AppStrings.of(context).photo,
                  icon: const Icon(Icons.photo_outlined),
                  onPressed: () => _openPhoto(reading.imageStoragePath!),
                )
              : Text(AppStrings.of(context).no),
        ),
        DataCell(Text(row.enteredByName ?? '—')),
      ],
    );
  }

  Future<void> _openPhoto(String storagePath) async {
    try {
      final url = await ref
          .read(meterImageStorageRepositoryProvider)
          .createSignedUrl(storagePath);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => Dialog(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720, maxHeight: 560),
            child: Column(
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: IconButton(
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.close),
                  ),
                ),
                Expanded(
                  child: InteractiveViewer(
                    child: Image.network(
                      url,
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) =>
                          const Center(child: Icon(Icons.broken_image)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppStrings.of(context).isAr
                ? 'تعذّر فتح الصورة'
                : 'Could not open photo',
          ),
        ),
      );
    }
  }
}
