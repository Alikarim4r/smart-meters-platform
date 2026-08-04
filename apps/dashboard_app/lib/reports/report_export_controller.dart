import 'dart:typed_data';

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
    ref.read(supabaseClientProvider),
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

    // Capture container + navigator before any dialog/async — WidgetRef may die.
    final container = ProviderScope.containerOf(context, listen: false);
    final navigator = Navigator.of(context, rootNavigator: true);
    final messenger = ScaffoldMessenger.maybeOf(context);

    final resolvedDateSelection = defaultDateSelection ??
        (siteId != null
            ? container.read(siteDateSelectionProvider(siteId))
            : null);

    final options = await showReportExportDialog(
      context: context,
      defaultType: defaultType,
      categoryId: categoryId,
      defaultPeriod: defaultPeriod,
      defaultDateSelection: resolvedDateSelection,
    );
    if (options == null) return;

    await _runExport(
      navigator: navigator,
      messenger: messenger,
      container: container,
      options: options,
      siteId: siteId,
    );
  }

  Future<void> _runExport({
    required NavigatorState navigator,
    required ScaffoldMessengerState? messenger,
    required ProviderContainer container,
    required ReportExportOptions options,
    String? siteId,
  }) async {
    if (_isExporting) return;
    _isExporting = true;
    reportExportLogReset();
    reportExportLog('export', 'begin type=${options.type} period=${options.period} charts=${options.includeCharts} format=${options.format}');

    var loadingVisible = true;
    showDialog<void>(
      context: navigator.context,
      barrierDismissible: false,
      useRootNavigator: true,
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

    void dismissLoading() {
      if (!loadingVisible) return;
      loadingVisible = false;
      if (navigator.canPop()) {
        navigator.pop();
      }
    }

    final profile = container.read(authProvider).profile;
    if (profile == null) {
      dismissLoading();
      messenger?.showSnackBar(
        const SnackBar(content: Text('Export failed: not signed in')),
      );
      _isExporting = false;
      return;
    }

    final DateTime businessDate = resolveBusinessDate(
      override: options.dataAnchorDate,
      fallback: container.read(businessDateProvider),
    );
    final dataService = container.read(reportDataServiceProvider);
    final fileService = container.read(reportFileServiceProvider);
    final pdfService = container.read(pdfReportServiceProvider);
    final excelService = container.read(excelReportServiceProvider);
    final client = container.read(supabaseClientProvider);
    final generatedAt = DateTime.now();

    try {
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
          bytes = await pdfService.buildAllSitesPdf(bundle);
          reportExportLog(
            'G',
            'generate all-sites PDF ok (${bytes.length} bytes)',
          );
        } else {
          reportExportLog('H', 'generate all-sites Excel start');
          bytes = await excelService.buildAllSitesExcel(bundle);
          reportExportLog(
            'H',
            'generate all-sites Excel ok (${bytes.length} bytes)',
          );
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
          format: options.format,
          includeCharts: options.includeCharts,
          rangeStart: options.rangeStart,
          rangeEnd: options.rangeEnd,
        );
        final enriched = await _attachReportLogos(bundle, client);
        filename = buildReportFilename(
          siteName: enriched.meta.siteName,
          type: options.type,
          format: options.format,
          period: options.period,
          generatedAt: generatedAt,
        );
        format = options.format;
        if (options.format == ReportFormat.pdf) {
          reportExportLog('G', 'generate site PDF start');
          bytes = await pdfService.buildSitePdf(
            bundle: enriched,
            type: options.type,
            includePhotos: options.includePhotos,
            includeCharts: options.includeCharts,
          );
          reportExportLog(
            'G',
            'generate site PDF ok (${bytes.length} bytes)',
          );
        } else if (options.type == ReportType.readings) {
          reportExportLog('H', 'generate readings Excel start');
          bytes = await excelService.buildReadingsExcel(enriched);
          reportExportLog(
            'H',
            'generate readings Excel ok (${bytes.length} bytes)',
          );
        } else {
          reportExportLog('H', 'generate site Excel start');
          bytes = await excelService.buildSiteExcel(
            bundle: enriched,
            type: options.type,
          );
          reportExportLog(
            'H',
            'generate site Excel ok (${bytes.length} bytes)',
          );
        }
      }

      if (bytes.isEmpty) {
        throw StateError('Generated report is empty');
      }

      final path =
          await fileService.saveReportBytes(bytes: bytes, filename: filename);
      final generated = GeneratedReportFile(
        path: path,
        filename: filename,
        format: format,
      );
      reportExportLog('export', 'success ($path)');

      dismissLoading();

      if (navigator.mounted) {
        await _showSuccessDialog(navigator.context, generated, fileService);
      } else {
        // Still open the file so export is not a silent success.
        await fileService.openReport(generated);
      }
    } catch (error, stack) {
      reportExportLog('export', 'failed', error: error, stack: stack);
      dismissLoading();
      messenger?.showSnackBar(
        SnackBar(content: Text('Export failed: $error')),
      );
    } finally {
      _isExporting = false;
    }
  }

  Future<SiteReportBundle> _attachReportLogos(
    SiteReportBundle bundle,
    dynamic client,
  ) async {
    final primaryPath = bundle.meta.reportLogoPrimaryPath;
    final secondaryPath = bundle.meta.reportLogoSecondaryPath;
    if ((primaryPath == null || primaryPath.isEmpty) &&
        (secondaryPath == null || secondaryPath.isEmpty)) {
      return bundle;
    }

    Future<Uint8List?> load(String? path) async {
      if (path == null || path.trim().isEmpty) return null;
      try {
        final bytes = await client.storage
            .from('report-logos')
            .download(path)
            .timeout(const Duration(seconds: 3));
        if (bytes is Uint8List) return bytes;
        if (bytes is List<int>) return Uint8List.fromList(bytes);
        return null;
      } catch (_) {
        return null;
      }
    }

    final primary = load(primaryPath);
    final secondary = load(secondaryPath);
    final loaded = await Future.wait<Uint8List?>([primary, secondary]);
    return bundle.copyWith(
      meta: bundle.meta.withLogoBytes(
        primary: loaded[0],
        secondary: loaded[1],
      ),
    );
  }

  Future<void> _showSuccessDialog(
    BuildContext context,
    GeneratedReportFile file,
    ReportFileService fileService,
  ) async {
    await showDialog<void>(
      context: context,
      useRootNavigator: true,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Report ready'),
        content: Text(
          file.path.startsWith('download://')
              ? 'Report ready:\n${file.filename}\n\nOn web, use the browser download/share prompt.'
              : 'Saved to device:\n${file.filename}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Close'),
          ),
          if (!file.path.startsWith('download://'))
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
          if (!file.path.startsWith('download://'))
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
          if (file.path.startsWith('download://'))
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Done'),
            ),
        ],
      ),
    );
  }
}
