import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_meters_core/smart_meters_core.dart';

import '../providers/chart_providers.dart';
import '../providers/dashboard_providers.dart';
import '../utils/dashboard_date_range.dart';
import '../utils/dashboard_filters.dart';
import 'excel_report_service.dart';
import 'pdf_report_service.dart';
import 'report_data_service.dart';
import 'report_export_dialog.dart';
import 'report_export_log.dart';
import 'report_file_service.dart';
import 'report_filename.dart';
import 'report_models.dart';

final reportDataServiceProvider = Provider<ReportDataService>((ref) {
  return ReportDataService(
    ref.read(dashboardRepositoryProvider),
    ref.read(alertRepositoryProvider),
    ref.read(policySettingsRepositoryProvider),
  );
});

final pdfReportServiceProvider = Provider<PdfReportService>((ref) {
  return PdfReportService();
});

final excelReportServiceProvider = Provider<ExcelReportService>((ref) {
  return ExcelReportService();
});

final reportFileServiceProvider = Provider<ReportFileService>((ref) {
  return ReportFileService();
});

class ReportExportController {
  ReportExportController(this.ref);

  final WidgetRef ref;
  bool _isExporting = false;

  Future<void> showExportDialog({
    required BuildContext context,
    required ReportType defaultType,
    String? siteId,
    String? categoryId,
    ChartPeriod? defaultPeriod,
    DashboardDateSelection? defaultDateSelection,
  }) async {
    if (_isExporting) return;

    final resolvedDateSelection = defaultDateSelection ??
        (siteId != null ? ref.read(siteDateSelectionProvider(siteId)) : null);

    final options = await showReportExportDialog(
      context: context,
      defaultType: defaultType,
      categoryId: categoryId,
      defaultPeriod: defaultPeriod,
      defaultDateSelection: resolvedDateSelection,
    );
    if (options == null || !context.mounted) return;

    await _runExport(context: context, options: options, siteId: siteId);
  }

  Future<void> _runExport({
    required BuildContext context,
    required ReportExportOptions options,
    String? siteId,
  }) async {
    if (_isExporting) return;
    _isExporting = true;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Expanded(child: Text('Generating report…')),
          ],
        ),
      ),
    );

    try {
      final profile = ref.read(authProvider).profile!;
      final DateTime businessDate = resolveBusinessDate(
        override: options.dataAnchorDate,
        fallback: ref.read(businessDateProvider),
      );
      final dataService = ref.read(reportDataServiceProvider);
      final fileService = ref.read(reportFileServiceProvider);
      final generatedAt = DateTime.now();

      late final List<int> bytes;
      late final String filename;
      late final ReportFormat format;

      if (options.type == ReportType.allSitesSummary) {
        final bundle = await dataService.loadAllSitesReport(
          userEmail: profile.email,
          period: options.period,
          businessDate: businessDate,
        );
        filename = buildReportFilename(
          type: options.type,
          format: options.format,
          period: options.period,
          generatedAt: generatedAt,
        );
        format = options.format;
        if (options.format == ReportFormat.pdf) {
          reportExportLog('G', 'generate all-sites PDF start');
          bytes = await ref.read(pdfReportServiceProvider).buildAllSitesPdf(bundle);
          reportExportLog('G', 'generate all-sites PDF ok (${bytes.length} bytes)');
        } else {
          reportExportLog('H', 'generate all-sites Excel start');
          bytes = await ref.read(excelReportServiceProvider).buildAllSitesExcel(bundle);
          reportExportLog('H', 'generate all-sites Excel ok (${bytes.length} bytes)');
        }
      } else {
        if (siteId == null) {
          throw StateError('Site id is required for site reports');
        }
        final bundle = await dataService.loadSiteReport(
          siteId: siteId,
          userEmail: profile.email,
          period: options.period,
          businessDate: businessDate,
          categoryId: options.categoryId,
          type: options.type,
        );
        filename = buildReportFilename(
          siteName: bundle.meta.siteName,
          type: options.type,
          format: options.format,
          period: options.period,
          generatedAt: generatedAt,
        );
        format = options.format;
        if (options.format == ReportFormat.pdf) {
          reportExportLog('G', 'generate site PDF start');
          bytes = await ref.read(pdfReportServiceProvider).buildSitePdf(
                bundle: bundle,
                type: options.type,
                includePhotos: options.includePhotos,
              );
          reportExportLog('G', 'generate site PDF ok (${bytes.length} bytes)');
        } else if (options.type == ReportType.readings) {
          reportExportLog('H', 'generate readings Excel start');
          bytes = await ref.read(excelReportServiceProvider).buildReadingsExcel(bundle);
          reportExportLog('H', 'generate readings Excel ok (${bytes.length} bytes)');
        } else {
          reportExportLog('H', 'generate site Excel start');
          bytes = await ref.read(excelReportServiceProvider).buildSiteExcel(
                bundle: bundle,
                type: options.type,
              );
          reportExportLog('H', 'generate site Excel ok (${bytes.length} bytes)');
        }
      }

      if (bytes.isEmpty) {
        throw StateError('Generated report is empty');
      }

      final path = await fileService.saveReportBytes(bytes: bytes, filename: filename);
      final generated = GeneratedReportFile(
        path: path,
        filename: filename,
        format: format,
      );

      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        await _showSuccessDialog(context, generated, fileService);
      }
    } catch (error, stack) {
      reportExportLog('export', 'failed', error: error, stack: stack);
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $error')),
        );
      }
    } finally {
      _isExporting = false;
    }
  }

  Future<void> _showSuccessDialog(
    BuildContext context,
    GeneratedReportFile file,
    ReportFileService fileService,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Report ready'),
        content: Text('Saved to device:\n${file.filename}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Close'),
          ),
          TextButton(
            onPressed: () async {
              try {
                await fileService.shareReport(file);
              } catch (error) {
                if (dialogContext.mounted) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    SnackBar(content: Text('Share failed: $error')),
                  );
                }
              }
            },
            child: const Text('Share'),
          ),
          FilledButton(
            onPressed: () async {
              final result = await fileService.openReport(file);
              if (!result.success && dialogContext.mounted) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  SnackBar(
                    content: Text(
                      result.message == null
                          ? 'No app found to open this file. Use Share instead.'
                          : 'Open failed: ${result.message}. Use Share instead.',
                    ),
                  ),
                );
              }
            },
            child: const Text('Open'),
          ),
        ],
      ),
    );
  }
}
