import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_meters_core/smart_meters_core.dart';

import '../providers/entry_providers.dart';
import '../screens/photo_preview_screen.dart';
import '../widgets/reading_photo_section.dart';

class SubmittedReadingView extends ConsumerWidget {
  const SubmittedReadingView({
    super.key,
    required this.reading,
    required this.unit,
    required this.onBackToMeters,
    required this.onNextPending,
    required this.showNextPending,
    this.localPhotoPath,
    this.imageStoragePath,
  });

  final MeterReading reading;
  final MeterUnit unit;
  final VoidCallback onBackToMeters;
  final VoidCallback onNextPending;
  final bool showNextPending;
  final String? localPhotoPath;
  final String? imageStoragePath;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final remoteUrlAsync = imageStoragePath == null
        ? const AsyncValue<String?>.data(null)
        : ref.watch(meterReadingPhotoUrlProvider(imageStoragePath!));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.green.shade200),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.check_circle_outline, color: Colors.green.shade800),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Today\'s reading has already been submitted. '
                  'Contact admin for correction.',
                  style: TextStyle(
                    color: Colors.green.shade900,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.green.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Submitted reading',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${reading.rawValue} ${unit.label}',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: Colors.green.shade900,
                ),
              ),
              const SizedBox(height: 10),
              _DetailLine(
                label: 'Submitted at',
                value: _formatSubmittedAt(reading.enteredAt),
              ),
              if (reading.note != null && reading.note!.trim().isNotEmpty)
                _DetailLine(label: 'Note', value: reading.note!.trim()),
              if (localPhotoPath != null || imageStoragePath != null) ...[
                const SizedBox(height: 12),
                Text(
                  'Meter photo',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 8),
                remoteUrlAsync.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (_, _) => ReadingPhotoThumbnail(
                    localPath: localPhotoPath,
                  ),
                  data: (remoteUrl) => ReadingPhotoThumbnail(
                    localPath: localPhotoPath,
                    remoteUrl: remoteUrl,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => PhotoPreviewScreen(
                            localPath: localPhotoPath,
                            remoteUrl: remoteUrl,
                            storagePath: imageStoragePath,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),
        OutlinedButton(
          onPressed: onBackToMeters,
          child: const Text('Back to meters'),
        ),
        if (showNextPending) ...[
          const SizedBox(height: 8),
          FilledButton(
            onPressed: onNextPending,
            child: const Text('Next pending meter'),
          ),
        ],
      ],
    );
  }

  static String _formatSubmittedAt(DateTime enteredAt) {
    final local = enteredAt.toLocal();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '${formatBusinessDate(local)} at $hour:$minute';
  }
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}
