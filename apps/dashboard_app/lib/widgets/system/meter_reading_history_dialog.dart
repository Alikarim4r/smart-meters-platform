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
          constraints: const BoxConstraints(maxWidth: 960, maxHeight: 720),
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
      final from = normalizeDashboardDate(widget.dateSelection.startDate);
      final to = normalizeDashboardDate(widget.dateSelection.endDate);
      final rows = await ref
          .read(dashboardRepositoryProvider)
          .getRecentSiteReadings(
            siteId: widget.siteId,
            filters: DashboardReadingFilters(
              fromDate: from,
              toDate: to,
              meterId: widget.meter.meterId,
              hasPhoto: _photoFilter,
              // Full selected period (daily meters ≈ 31–366 rows).
              limit: 5000,
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
    final s = AppStrings.of(context);
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            s.meterReadingHistory,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              color: DashboardPalette.navy,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${widget.meter.meterName} · ${widget.meter.meterCode}',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: DashboardPalette.textMuted),
          ),
          const SizedBox(height: 4),
          Text(
            formatDashboardDateSelectionLabel(widget.dateSelection),
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: DashboardPalette.textMuted),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<bool?>(
            isExpanded: true,
            initialValue: _photoFilter,
            decoration: premiumFilterDecoration(
              context: context,
              labelText: s.isAr ? 'فلتر الصورة' : 'Photo filter',
            ),
            items: [
              DropdownMenuItem(
                value: null,
                child: Text(s.isAr ? 'كل القراءات' : 'All readings'),
              ),
              DropdownMenuItem(
                value: true,
                child: Text(s.isAr ? 'به صورة' : 'Has photo'),
              ),
              DropdownMenuItem(value: false, child: Text(s.noPhoto)),
            ],
            onChanged: (value) {
              setState(() => _photoFilter = value);
              _loadReadings();
            },
          ),
          const SizedBox(height: 8),
          _readings.maybeWhen(
            data: (rows) => Text(
              s.isAr
                  ? '${rows.length} قراءة في الفترة المحددة'
                  : '${rows.length} readings in selected period',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: DashboardPalette.textMuted,
                fontWeight: FontWeight.w600,
              ),
            ),
            orElse: () => const SizedBox.shrink(),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _readings.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Text(
                  s.isAr
                      ? 'تعذّر تحميل القراءات. يُرجى المحاولة مرة أخرى.'
                      : 'Could not load readings. Please try again.',
                  style: TextStyle(color: DashboardPalette.textMuted),
                  textAlign: TextAlign.center,
                ),
              ),
              data: (rows) {
                if (rows.isEmpty) {
                  return Center(
                    child: Text(
                      s.isAr
                          ? 'لا توجد قراءات لنطاق التاريخ المحدد.'
                          : 'No readings for the selected date range.',
                    ),
                  );
                }

                // Vertical scroll for all period rows + horizontal for wide table.
                return Scrollbar(
                  thumbVisibility: true,
                  child: SingleChildScrollView(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minWidth: MediaQuery.sizeOf(context).width > 900
                              ? 860
                              : MediaQuery.sizeOf(context).width - 80,
                        ),
                        child: DataTable(
                          headingRowHeight: 44,
                          dataRowMinHeight: 48,
                          dataRowMaxHeight: 64,
                          columns: [
                            DataColumn(label: Text(s.date)),
                            DataColumn(label: Text(s.reading)),
                            DataColumn(label: Text(s.consumption)),
                            DataColumn(label: Text(s.photo)),
                            DataColumn(label: Text(s.note)),
                            DataColumn(
                              label: Text(
                                s.isAr ? 'أُدخل بواسطة' : 'Submitted by',
                              ),
                            ),
                          ],
                          rows: [
                            for (var i = 0; i < rows.length; i++)
                              _buildRow(rows, i, s),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(s.close),
            ),
          ),
        ],
      ),
    );
  }

  DataRow _buildRow(List<DashboardReadingRow> rows, int index, AppStrings s) {
    final row = rows[index];
    final reading = row.reading;
    double? consumption;
    if (index + 1 < rows.length) {
      final prev = rows[index + 1].reading.rawValue;
      consumption = reading.rawValue - prev;
    }

    final hasPhoto = reading.hasPhoto;
    final photoPath = reading.imageStoragePath?.trim();

    return DataRow(
      cells: [
        DataCell(Text(formatDashboardDate(reading.readingDate))),
        DataCell(Text('${reading.rawValue} ${row.unitLabel}')),
        DataCell(
          Text(consumption != null ? consumption.toStringAsFixed(2) : '—'),
        ),
        DataCell(
          hasPhoto && photoPath != null && photoPath.isNotEmpty
              ? TextButton.icon(
                  onPressed: () => _openPhoto(photoPath),
                  icon: const Icon(Icons.photo_outlined, size: 18),
                  label: Text(s.isAr ? 'عرض' : 'View'),
                )
              : Text(
                  s.isAr ? 'لا صورة' : s.no,
                  style: TextStyle(color: DashboardPalette.textMuted),
                ),
        ),
        DataCell(
          SizedBox(
            width: 220,
            child: Text(
              row.reading.note?.trim().isNotEmpty == true
                  ? row.reading.note!
                  : '—',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        DataCell(Text(row.enteredByName ?? '—')),
      ],
    );
  }

  Future<void> _openPhoto(String storagePath) async {
    final s = AppStrings.of(context);
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
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          s.isAr ? 'صورة القراءة' : 'Reading photo',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: InteractiveViewer(
                    child: Image.network(
                      url,
                      fit: BoxFit.contain,
                      loadingBuilder: (context, child, progress) {
                        if (progress == null) return child;
                        return const Center(child: CircularProgressIndicator());
                      },
                      errorBuilder: (_, _, _) => Center(
                        child: Text(
                          s.isAr
                              ? 'تعذّر تحميل الصورة'
                              : 'Could not load photo',
                        ),
                      ),
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
          content: Text(s.isAr ? 'تعذّر فتح الصورة' : 'Could not open photo'),
        ),
      );
    }
  }
}
