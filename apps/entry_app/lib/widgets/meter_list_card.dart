import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_meters_core/smart_meters_core.dart';

import '../models/meter_entry_status.dart';
import '../photos/reading_photo_models.dart';
import '../providers/entry_providers.dart';
import 'reading_photo_section.dart';

class MeterListCard extends StatelessWidget {
  const MeterListCard({
    super.key,
    required this.status,
    required this.onTap,
  });

  final MeterEntryStatus status;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final borderColor = _borderColor(status.workStatus);

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: borderColor),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      status.meter.nameEn,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      status.meter.meterCode,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Unit: ${status.meter.unitDisplayLabel}',
                      style: theme.textTheme.bodySmall,
                    ),
                    Text(
                      _lastReadingLabel(status),
                      style: theme.textTheme.bodySmall,
                    ),
                    if (status.workStatus == MeterWorkStatus.submitted &&
                        status.todayReading != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          'Today: ${status.todayReading!.rawValue} ${status.meter.unitDisplayLabel}',
                          style: TextStyle(
                            color: Colors.green.shade800,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      )
                    else if (status.localDraft != null &&
                        status.workStatus != MeterWorkStatus.pending)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          'Local: ${status.localDraft!.rawValue} ${status.meter.unitDisplayLabel}',
                          style: TextStyle(
                            color: Colors.indigo.shade800,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    if (status.localDraft?.errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          status.localDraft!.errorMessage!,
                          style: TextStyle(
                            color: Colors.red.shade700,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    if (status.localDraft?.photoUploadStatus ==
                            PhotoUploadStatus.attachedLocally ||
                        status.localDraft?.photoUploadStatus ==
                            PhotoUploadStatus.uploaded)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Row(
                          children: [
                            ReadingPhotoThumbnail(
                              localPath:
                                  status.localDraft?.watermarkedPhotoPath,
                              remoteUrl: status.localDraft?.remotePhotoUrl,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              status.localDraft!.photoUploadStatus.label,
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    if (status.workStatus == MeterWorkStatus.submitted &&
                        status.todayReading?.hasPhoto == true)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: _SubmittedPhotoThumb(
                          storagePath: status.todayReading!.imageStoragePath!,
                        ),
                      ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _StatusBadge(status: status.workStatus),
                  const SizedBox(height: 8),
                  Icon(
                    status.isReadOnly
                        ? Icons.visibility_outlined
                        : Icons.chevron_right,
                    color: Colors.grey.shade600,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _lastReadingLabel(MeterEntryStatus status) {
    final last = status.lastReading;
    if (last == null) {
      return 'Last reading: none';
    }
    return 'Last: ${last.rawValue} ${status.meter.unitDisplayLabel} '
        '(${formatBusinessDate(last.readingDate)})';
  }

  Color _borderColor(MeterWorkStatus workStatus) {
    switch (workStatus) {
      case MeterWorkStatus.submitted:
        return Colors.green.shade200;
      case MeterWorkStatus.savedLocally:
      case MeterWorkStatus.syncing:
        return Colors.indigo.shade200;
      case MeterWorkStatus.failedSync:
      case MeterWorkStatus.conflict:
        return Colors.red.shade200;
      case MeterWorkStatus.pending:
        return Colors.orange.shade200;
    }
  }
}

class _SubmittedPhotoThumb extends ConsumerWidget {
  const _SubmittedPhotoThumb({required this.storagePath});

  final String storagePath;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final urlAsync = ref.watch(meterReadingPhotoUrlProvider(storagePath));
    return urlAsync.when(
      loading: () => const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
      error: (_, _) => const SizedBox.shrink(),
      data: (url) => Row(
        children: [
          ReadingPhotoThumbnail(remoteUrl: url, localPath: null),
          const SizedBox(width: 8),
          Text(
            'Photo uploaded',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final MeterWorkStatus status;

  @override
  Widget build(BuildContext context) {
    final colors = _colors(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: colors.$1,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: colors.$2,
        ),
      ),
    );
  }

  (Color, Color) _colors(MeterWorkStatus status) {
    switch (status) {
      case MeterWorkStatus.submitted:
        return (Colors.green.shade100, Colors.green.shade900);
      case MeterWorkStatus.savedLocally:
        return (Colors.indigo.shade100, Colors.indigo.shade900);
      case MeterWorkStatus.syncing:
        return (Colors.blue.shade100, Colors.blue.shade900);
      case MeterWorkStatus.failedSync:
      case MeterWorkStatus.conflict:
        return (Colors.red.shade100, Colors.red.shade900);
      case MeterWorkStatus.pending:
        return (Colors.orange.shade100, Colors.orange.shade900);
    }
  }
}
