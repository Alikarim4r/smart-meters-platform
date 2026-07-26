import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/dashboard_providers.dart';
import '../../theme/design_system/dashboard_design_system.dart';
import '../../utils/dashboard_filters.dart';

enum ReadingPhotoKind { previous, current }

Future<void> showReadingPhotoViewer({
  required BuildContext context,
  required WidgetRef ref,
  required ReadingPhotoKind kind,
  required String meterCode,
  required String meterName,
  required String unitLabel,
  required double? value,
  required DateTime? date,
  required bool hasPhoto,
  required String? storagePath,
}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close photo viewer',
    barrierColor: DashboardColors.photoScrim(context).withValues(alpha: 0.92),
    transitionDuration: DashboardMotion.dialog,
    pageBuilder: (dialogContext, _, _) {
      return SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: 420,
              maxHeight: 760,
            ),
            child: Material(
              color: DashboardColors.photoScrim(dialogContext),
              borderRadius: BorderRadius.circular(DashboardRadius.dialog),
              clipBehavior: Clip.antiAlias,
              child: ReadingPhotoViewerContent(
                meterName: meterName,
                unitLabel: unitLabel,
                value: value,
                date: date,
                hasPhoto: hasPhoto,
                storagePath: storagePath,
              ),
            ),
          ),
        ),
      );
    },
    transitionBuilder: (context, animation, _, child) {
      return DashboardAnimations.fadeScale(child: child, animation: animation);
    },
  );
}

class ReadingPhotoViewerContent extends StatelessWidget {
  const ReadingPhotoViewerContent({
    super.key,
    required this.meterName,
    required this.unitLabel,
    required this.value,
    required this.date,
    required this.hasPhoto,
    required this.storagePath,
  });

  final String meterName;
  final String unitLabel;
  final double? value;
  final DateTime? date;
  final bool hasPhoto;
  final String? storagePath;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 10, 14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      formatDashboardDateTime(date),
                      style: const TextStyle(
                        color: Color(0xFFF2EFEA),
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      meterName,
                      style: const TextStyle(
                        color: Color(0xFF9AA3B2),
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      value != null
                          ? '${_formatValue(value!)} $unitLabel'
                          : '—',
                      style: const TextStyle(
                        color: Color(0xFFF2EFEA),
                        fontWeight: FontWeight.w800,
                        fontSize: 20,
                        height: 1.1,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Close (Esc)',
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(
                  Icons.close_rounded,
                  color: Color(0xFFF2EFEA),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 520,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(12),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: !hasPhoto ||
                        storagePath == null ||
                        storagePath!.isEmpty
                    ? const Center(
                        child: Text(
                          'No photo available for this reading.',
                          style: TextStyle(color: Color(0xFF9AA3B2)),
                          textAlign: TextAlign.center,
                        ),
                      )
                    : _ZoomablePhoto(storagePath: storagePath!),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatValue(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);
}

class _ZoomablePhoto extends ConsumerWidget {
  const _ZoomablePhoto({required this.storagePath});

  final String storagePath;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final urlAsync = ref.watch(meterReadingPhotoUrlProvider(storagePath));
    return urlAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: Color(0xFF6B9BD1)),
      ),
      error: (_, _) => const Center(
        child: Text(
          'Could not load photo',
          style: TextStyle(color: Color(0xFF9AA3B2)),
        ),
      ),
      data: (url) {
        if (url == null || url.isEmpty) {
          return const Center(
            child: Text(
              'No photo available for this reading.',
              style: TextStyle(color: Color(0xFF9AA3B2)),
            ),
          );
        }
        return InteractiveViewer(
          minScale: 0.9,
          maxScale: 4,
          child: Center(
            child: Image.network(
              url,
              fit: BoxFit.contain,
              loadingBuilder: (_, child, progress) {
                if (progress == null) return child;
                return const Center(
                  child: CircularProgressIndicator(color: Color(0xFF6B9BD1)),
                );
              },
              errorBuilder: (_, _, _) => const Center(
                child: Text(
                  'Could not load photo',
                  style: TextStyle(color: Color(0xFF9AA3B2)),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
