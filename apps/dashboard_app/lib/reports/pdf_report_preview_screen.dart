import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

import 'report_file_service.dart';
import 'report_models.dart';
import '../l10n/app_strings.dart';

/// On-screen preview of an A4 PDF, scaled to fit the phone width while
/// keeping true A4 proportions (210×297 mm).
class PdfReportPreviewScreen extends StatelessWidget {
  const PdfReportPreviewScreen({
    super.key,
    required this.bytes,
    required this.filename,
    this.savedFile,
    this.fileService,
  });

  final Uint8List bytes;
  final String filename;
  final GeneratedReportFile? savedFile;
  final ReportFileService? fileService;

  /// Portrait A4 width ÷ height.
  static const double a4Aspect = 210 / 297;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final padding = MediaQuery.paddingOf(context);
    final availableWidth = size.width - 24;
    final availableHeight =
        size.height - padding.top - padding.bottom - kToolbarHeight - 24;

    // Fit an A4 sheet inside the phone viewport (letterboxed if needed).
    final maxByWidth = availableWidth;
    final maxByHeight = availableHeight * a4Aspect;
    final pageMaxWidth = math.min(maxByWidth, maxByHeight);

    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surfaceContainerHighest,
      appBar: AppBar(
        title: Text(filename, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          if (savedFile != null && fileService != null) ...[
            IconButton(
              tooltip: dashboardText(context, 'Share', 'مشاركة'),
              icon: const Icon(Icons.share_outlined),
              onPressed: () async {
                try {
                  await fileService!.shareReport(savedFile!);
                } catch (error) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(AppStrings.of(context).genericError),
                      ),
                    );
                  }
                }
              },
            ),
            IconButton(
              tooltip: dashboardText(context, 'Open', 'فتح'),
              icon: const Icon(Icons.open_in_new),
              onPressed: () async {
                final result = await fileService!.openReport(savedFile!);
                if (!result.success && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        result.message == null
                            ? 'No app found to open this file. Use Share instead.'
                            : 'Open failed: ${result.message}',
                      ),
                    ),
                  );
                }
              },
            ),
          ],
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: pageMaxWidth,
              maxHeight: pageMaxWidth / a4Aspect,
            ),
            child: Material(
              elevation: 2,
              color: Colors.white,
              borderRadius: BorderRadius.circular(4),
              clipBehavior: Clip.antiAlias,
              child: PdfPreview(
                build: (format) async => bytes,
                initialPageFormat: PdfPageFormat.a4,
                canChangePageFormat: false,
                canChangeOrientation: false,
                canDebug: false,
                allowPrinting: true,
                allowSharing: true,
                maxPageWidth: pageMaxWidth,
                pdfFileName: filename,
                actions: const [],
                previewPageMargin: const EdgeInsets.all(8),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
