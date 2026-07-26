import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:smart_meters_core/smart_meters_core.dart';

import 'report_export_log.dart';
import 'report_models.dart';
import 'report_text_sanitize.dart';

class PdfReportService {
  static final _tableHeaderStyle = pw.TextStyle(
    fontSize: 8,
    fontWeight: pw.FontWeight.bold,
  );
  static final _tableCellStyle = pw.TextStyle(fontSize: 7);

  Future<Uint8List> buildAllSitesPdf(AllSitesReportBundle bundle) async {
    reportExportLog('G', 'buildAllSitesPdf start');
    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
          _header(bundle.meta),
          pw.SizedBox(height: 12),
          _sectionTitle('Accessible Sites'),
          if (bundle.sites.isEmpty)
            _emptyNote('No accessible sites for this user.')
          else
            _table(
              headers: const [
                'Site',
                'Zone',
                'Type',
                'Meters',
                'Today',
                'Last Reading',
              ],
              rows: [
                for (final item in bundle.sites)
                  [
                    item.site.nameEn,
                    item.site.displayZoneName,
                    item.site.siteType.label,
                    '${item.meterCount}',
                    item.todayProgressLabel,
                    item.lastReadingDate == null
                        ? '-'
                        : formatBusinessDate(item.lastReadingDate!),
                  ],
              ],
            ),
          pw.SizedBox(height: 16),
          _alertsSection(bundle.alerts),
        ],
      ),
    );
    final bytes = await doc.save();
    reportExportLog('G', 'buildAllSitesPdf ok (${bytes.length} bytes)');
    return bytes;
  }

  Future<Uint8List> buildSitePdf({
    required SiteReportBundle bundle,
    required ReportType type,
    bool includePhotos = false,
  }) async {
    reportExportLog('G', 'buildSitePdf start ($type)');
    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        footer: (context) => _footer(bundle.meta),
        build: (context) => [
          _header(bundle.meta),
          pw.SizedBox(height: 12),
          _summaryCards(bundle),
          pw.SizedBox(height: 16),
          if (type == ReportType.siteSummary ||
              type == ReportType.consumption ||
              type == ReportType.categoryConsumption) ...[
            _sectionTitle('Category Summary'),
            _categoryTable(bundle),
            pw.SizedBox(height: 16),
          ],
          if (type == ReportType.siteSummary ||
              type == ReportType.consumption ||
              type == ReportType.readings) ...[
            _sectionTitle('Meter Summary'),
            _meterTable(bundle),
            pw.SizedBox(height: 16),
          ],
          if (type == ReportType.consumption ||
              type == ReportType.categoryConsumption ||
              type == ReportType.siteSummary) ...[
            _sectionTitle('Consumption by Category'),
            _consumptionTable(bundle),
            pw.SizedBox(height: 16),
            _sectionTitle('Top Meters by Consumption'),
            _rankingTable(bundle),
            pw.SizedBox(height: 16),
          ],
          if (type == ReportType.readings || type == ReportType.siteSummary) ...[
            _sectionTitle('Recent Readings'),
            _readingsTable(bundle, includePhotos: includePhotos),
            pw.SizedBox(height: 16),
          ],
          if (type == ReportType.cop || type == ReportType.siteSummary) ...[
            _sectionTitle('COP Groups'),
            _copSection(bundle),
          ],
          if (bundle.meta.includeAlertsSection) ...[
            _sectionTitle('Active Alerts'),
            _alertsSection(bundle.alerts),
          ],
        ],
      ),
    );
    final bytes = await doc.save();
    reportExportLog('G', 'buildSitePdf ok (${bytes.length} bytes)');
    return bytes;
  }

  pw.Widget _footer(ReportMeta meta) {
    final footer = sanitizePdfText(meta.reportFooterText, fallback: '');
    if (footer.isEmpty) {
      return pw.SizedBox();
    }
    return pw.Container(
      alignment: pw.Alignment.centerLeft,
      padding: const pw.EdgeInsets.only(top: 8),
      child: pw.Text(
        footer,
        style: pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
      ),
    );
  }

  pw.Widget _header(ReportMeta meta) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        if (meta.organizationDisplayName?.trim().isNotEmpty == true)
          pw.Text(
            sanitizePdfText(meta.organizationDisplayName),
            style: pw.TextStyle(fontSize: 12, color: PdfColors.grey700),
          ),
        pw.Text(
          sanitizePdfText(meta.title),
          style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
        ),
        if (meta.siteName != null)
          pw.Text('Site: ${sanitizePdfText(meta.siteName)}'),
        if (meta.zoneName != null)
          pw.Text('Zone: ${sanitizePdfText(meta.zoneName)}'),
        if (meta.siteType != null)
          pw.Text('Type: ${sanitizePdfText(meta.siteType)}'),
        if (meta.location != null && meta.location!.trim().isNotEmpty)
          pw.Text('Location: ${sanitizePdfText(meta.location)}'),
        pw.Text('Period: ${sanitizePdfText(meta.period.label)}'),
        pw.Text('Generated: ${_formatDateTime(meta.generatedAt)}'),
        pw.Text('Generated by: ${sanitizePdfText(meta.generatedByEmail)}'),
      ],
    );
  }

  pw.Widget _summaryCards(SiteReportBundle bundle) {
    final summary = bundle.summary;
    return pw.Wrap(
      spacing: 12,
      runSpacing: 8,
      children: [
        _chip('Total meters', '${summary.totalMeters}'),
        _chip('Active meters', '${summary.activeMeters}'),
        _chip('Submitted today', '${summary.readingsSubmittedToday}'),
        _chip('Pending today', '${summary.pendingReadingsToday}'),
        _chip('Categories', '${summary.categoriesCount}'),
        _chip(
          'Last reading',
          summary.lastReadingDate == null
              ? '-'
              : formatBusinessDate(summary.lastReadingDate!),
        ),
      ],
    );
  }

  pw.Widget _chip(String label, String value) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            sanitizePdfText(value),
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
          pw.Text(sanitizePdfText(label), style: const pw.TextStyle(fontSize: 9)),
        ],
      ),
    );
  }

  pw.Widget _sectionTitle(String title) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 6),
      child: pw.Text(
        sanitizePdfText(title),
        style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
      ),
    );
  }

  pw.Widget _emptyNote(String message) {
    return pw.Text(
      sanitizePdfText(message),
      style: const pw.TextStyle(color: PdfColors.grey700),
    );
  }

  pw.Widget _table({
    required List<String> headers,
    required List<List<dynamic>> rows,
  }) {
    return pw.TableHelper.fromTextArray(
      headers: headers.map(sanitizePdfText).toList(),
      data: rows
          .map((row) => row.map((cell) => sanitizePdfText(cell)).toList())
          .toList(),
      headerStyle: _tableHeaderStyle,
      cellStyle: _tableCellStyle,
      cellAlignment: pw.Alignment.centerLeft,
      headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
    );
  }

  pw.Widget _categoryTable(SiteReportBundle bundle) {
    if (bundle.categories.isEmpty) {
      return _emptyNote('No categories at this site.');
    }
    return _table(
      headers: const [
        'Category',
        'Meters',
        'Submitted Today',
        'Pending',
        'Today Consumption',
      ],
      rows: [
        for (final item in bundle.categories)
          [
            item.category.displayName,
            '${item.meterCount}',
            '${item.readingsSubmittedToday}',
            '${item.pendingToday}',
            item.totalDailyConsumption?.toStringAsFixed(2) ??
                'Not enough readings',
          ],
      ],
    );
  }

  pw.Widget _meterTable(SiteReportBundle bundle) {
    if (bundle.meters.isEmpty) {
      return _emptyNote('No meters at this site.');
    }
    return _table(
      headers: const [
        'Code',
        'Name',
        'Category',
        'Unit',
        'Latest',
        'Today',
      ],
      rows: [
        for (final meter in bundle.meters.take(200))
          [
            meter.meterCode,
            meter.nameEn,
            meter.categoryName,
            meter.unitLabel,
            meter.latestRawValue == null
                ? '-'
                : '${meter.latestRawValue} ${meter.unitLabel}',
            meter.hasSubmittedToday ? 'Submitted' : 'Pending',
          ],
      ],
    );
  }

  pw.Widget _consumptionTable(SiteReportBundle bundle) {
    if (!bundle.consumptionTrend.hasData) {
      return _emptyNote(
        bundle.consumptionTrend.emptyMessage ??
            'Not enough readings to calculate consumption',
      );
    }
    return _table(
      headers: const ['Category', 'Unit', 'Period Total'],
      rows: [
        for (final item in bundle.consumptionTrend.series)
          [
            item.categoryName,
            item.unitCode,
            item.totalConsumption.toStringAsFixed(2),
          ],
      ],
    );
  }

  pw.Widget _rankingTable(SiteReportBundle bundle) {
    final rows = <List<dynamic>>[];
    for (final entry in bundle.categoryRankings.entries) {
      final category = bundle.categories
              .where((c) => c.category.id == entry.key)
              .map((c) => c.category.displayName)
              .firstOrNull ??
          'Category';
      for (final item in entry.value.take(5)) {
        rows.add([
          category,
          item.meterCode,
          item.meterName,
          item.totalConsumption.toStringAsFixed(2),
        ]);
      }
    }
    if (rows.isEmpty) {
      return _emptyNote('No consumption ranking data for this period.');
    }
    return _table(
      headers: const ['Category', 'Code', 'Meter', 'Total'],
      rows: rows,
    );
  }

  pw.Widget _readingsTable(
    SiteReportBundle bundle, {
    required bool includePhotos,
  }) {
    if (bundle.readings.isEmpty) {
      return _emptyNote('No readings for this period.');
    }
    return _table(
      headers: [
        'Date',
        'Code',
        'Meter',
        'Category',
        'Value',
        'User',
        if (includePhotos) 'Photo',
        'Note',
      ],
      rows: [
        for (final row in bundle.readings.take(100))
          [
            formatBusinessDate(row.reading.readingDate),
            row.meterCode,
            row.meterName,
            row.categoryName,
            '${row.reading.rawValue} ${row.unitLabel}',
            row.enteredByName?.trim().isNotEmpty == true
                ? row.enteredByName!
                : row.enteredByEmail ?? '-',
            if (includePhotos) row.hasPhoto ? 'Yes' : 'No',
            row.reading.note ?? '',
          ],
      ],
    );
  }

  pw.Widget _copSection(SiteReportBundle bundle) {
    if (bundle.copResults.isEmpty) {
      return _emptyNote('No COP groups configured for this site.');
    }
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        for (final cop in bundle.copResults) ...[
          pw.Text(
            sanitizePdfText(cop.copGroupName),
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
          pw.Text('BTU meters: ${cop.btuMeterCount}'),
          pw.Text('Electricity meters: ${cop.electricityMeterCount}'),
          if (!cop.hasData)
            _emptyNote(
              cop.emptyMessage ?? 'Not enough readings to calculate COP',
            )
          else ...[
            pw.Text('Average COP: ${cop.averageCop?.toStringAsFixed(2) ?? '-'}'),
            pw.Text('Min COP: ${cop.minCop?.toStringAsFixed(2) ?? '-'}'),
            pw.Text('Max COP: ${cop.maxCop?.toStringAsFixed(2) ?? '-'}'),
            _table(
              headers: const ['Date', 'COP', 'BTU', 'Electricity'],
              rows: [
                for (final point in cop.points.take(60))
                  [
                    formatBusinessDate(point.date),
                    point.cop?.toStringAsFixed(2) ?? '-',
                    point.btuConsumption?.toStringAsFixed(2) ?? '-',
                    point.electricityConsumption?.toStringAsFixed(2) ?? '-',
                  ],
              ],
            ),
          ],
          pw.SizedBox(height: 12),
        ],
      ],
    );
  }

  pw.Widget _alertsSection(List<DashboardAlert> alerts) {
    if (alerts.isEmpty) {
      return _emptyNote('No active alerts.');
    }
    return _table(
      headers: const ['Severity', 'Title', 'Site', 'Meter', 'Message'],
      rows: [
        for (final alert in alerts.take(50))
          [
            alert.severity.label,
            alert.title,
            alert.siteName,
            alert.meterCode ?? '-',
            alert.message,
          ],
      ],
    );
  }

  String _formatDateTime(DateTime value) {
    final local = value.toLocal();
    final h = local.hour.toString().padLeft(2, '0');
    final m = local.minute.toString().padLeft(2, '0');
    return '${formatBusinessDate(local)} $h:$m';
  }
}
