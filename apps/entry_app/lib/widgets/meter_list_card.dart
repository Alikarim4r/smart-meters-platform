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
    this.isArabic = false,
  });

  final MeterEntryStatus status;
  final VoidCallback onTap;
  final bool isArabic;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final localPhoto =
        status.localDraft?.photoUploadStatus ==
            PhotoUploadStatus.attachedLocally ||
        status.localDraft?.photoUploadStatus == PhotoUploadStatus.uploaded;
    final meterName = isArabic && status.meter.nameAr.trim().isNotEmpty
        ? status.meter.nameAr
        : status.meter.nameEn;
    final location = status.meter.placeLabel(isAr: isArabic);

    return BrandLedgerRow(
      title: meterName,
      subtitle: status.meter.meterCode,
      onTap: onTap,
      leading: localPhoto
          ? ReadingPhotoThumbnail(
              localPath: status.localDraft?.watermarkedPhotoPath,
              remoteUrl: status.localDraft?.remotePhotoUrl,
            )
          : Icon(
              status.isReadOnly
                  ? Icons.visibility_outlined
                  : Icons.speed_outlined,
              size: 22,
              color: theme.colorScheme.onSurfaceVariant,
            ),
      meta: [
        BrandStatusMark(
          label: status.workStatus.localizedLabel(isArabic),
          tone: _tone(status.workStatus),
          compact: true,
        ),
        if (location != null)
          BrandMeta(location, icon: Icons.location_on_outlined),
        BrandMeta(
          '${isArabic ? 'الوحدة' : 'Unit'}: ${status.meter.unitDisplayLabel}',
        ),
        BrandMeta(_lastReadingLabel(status), icon: Icons.history),
        if (status.workStatus == MeterWorkStatus.submitted &&
            status.todayReading != null)
          BrandMeta(
            '${isArabic ? 'اليوم' : 'Today'}: '
            '${status.todayReading!.rawValue} ${status.meter.unitDisplayLabel}',
            color: BrandStatus.success(
              isDark: theme.brightness == Brightness.dark,
            ),
          )
        else if (status.localDraft != null &&
            status.workStatus != MeterWorkStatus.pending)
          BrandMeta(
            '${isArabic ? 'محلي' : 'Local'}: '
            '${status.localDraft!.rawValue} ${status.meter.unitDisplayLabel}',
            color: theme.colorScheme.primary,
          ),
        if (status.localDraft?.errorMessage != null)
          BrandMeta(
            isArabic ? 'تحتاج المزامنة إلى مراجعة' : 'Sync needs attention',
            icon: Icons.error_outline,
            color: theme.colorScheme.error,
          ),
        if (localPhoto)
          BrandMeta(
            isArabic ? 'الصورة مرفقة' : 'Photo attached',
            icon: Icons.photo_outlined,
          ),
        if (status.workStatus == MeterWorkStatus.submitted &&
            status.todayReading?.hasPhoto == true)
          _SubmittedPhotoThumb(
            storagePath: status.todayReading!.imageStoragePath!,
            isArabic: isArabic,
          ),
      ],
    );
  }

  String _lastReadingLabel(MeterEntryStatus status) {
    final last = status.lastReading;
    if (last == null) {
      return isArabic ? 'آخر قراءة: لا يوجد' : 'Last reading: none';
    }
    final prefix = isArabic ? 'السابق' : 'Last';
    return '$prefix: ${last.rawValue} ${status.meter.unitDisplayLabel} '
        '(${formatBusinessDate(last.readingDate)})';
  }

  BrandStatusTone _tone(MeterWorkStatus workStatus) {
    return switch (workStatus) {
      MeterWorkStatus.submitted => BrandStatusTone.success,
      MeterWorkStatus.savedLocally ||
      MeterWorkStatus.syncing => BrandStatusTone.info,
      MeterWorkStatus.failedSync ||
      MeterWorkStatus.conflict => BrandStatusTone.danger,
      MeterWorkStatus.pending => BrandStatusTone.warning,
    };
  }
}

class _SubmittedPhotoThumb extends ConsumerWidget {
  const _SubmittedPhotoThumb({
    required this.storagePath,
    this.isArabic = false,
  });

  final String storagePath;
  final bool isArabic;

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
            isArabic ? 'تم رفع الصورة' : 'Photo uploaded',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
