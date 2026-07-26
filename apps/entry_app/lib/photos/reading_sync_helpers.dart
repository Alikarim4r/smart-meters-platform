import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:smart_meters_core/smart_meters_core.dart';

import '../offline/local_reading_draft.dart';
import '../photos/reading_photo_models.dart';
import '../photos/reading_photo_service.dart';
import '../providers/connectivity_provider.dart';

Future<String?> uploadDraftPhotoIfNeeded({
  required Ref ref,
  required LocalReadingDraft draft,
}) async {
  if (draft.remotePhotoPath != null && draft.remotePhotoPath!.isNotEmpty) {
    return draft.remotePhotoPath;
  }

  if (!draft.hasLocalPhoto) {
    return null;
  }

  final organizationId = draft.organizationId;
  final categoryCode = draft.categoryCode;
  if (organizationId == null ||
      organizationId.isEmpty ||
      categoryCode == null ||
      categoryCode.isEmpty) {
    throw Exception('Missing site metadata for photo upload.');
  }

  final bytes = await ref
      .read(readingPhotoFileStoreProvider)
      .readBytes(draft.watermarkedPhotoPath);
  if (bytes == null) {
    throw Exception('Local watermarked photo file is missing.');
  }

  final storagePath = buildMeterImageStoragePath(
    organizationId: organizationId,
    siteId: draft.siteId,
    categoryCode: categoryCode,
    readingDate: draft.readingDate,
    meterId: draft.meterId,
    capturedAt: draft.photoCapturedAt ?? draft.updatedAt,
  );

  await ref.read(meterImageStorageRepositoryProvider).uploadMeterReadingImage(
        storagePath: storagePath,
        bytes: bytes,
      );

  return storagePath;
}

Future<LocalReadingDraft> syncSingleDraft({
  required Ref ref,
  required LocalReadingDraft draft,
  required String userId,
  required Future<void> Function(LocalReadingDraft) persistDraft,
}) async {
  if (draft.status == LocalReadingStatus.conflict) {
    return draft;
  }

  var working = draft.copyWith(
    status: LocalReadingStatus.syncing,
    updatedAt: DateTime.now(),
    clearError: true,
    clearPhotoErrorMessage: true,
  );
  await persistDraft(working);

  try {
    String? imagePath = working.remotePhotoPath;

    if (working.hasLocalPhoto) {
      working = working.copyWith(photoUploadStatus: PhotoUploadStatus.uploading);
      await persistDraft(working);

      imagePath = await uploadDraftPhotoIfNeeded(ref: ref, draft: working);
      working = working.copyWith(
        remotePhotoPath: imagePath,
        photoUploadStatus: PhotoUploadStatus.uploaded,
        clearPhotoErrorMessage: true,
      );
      await persistDraft(working);
    }

    final reading = await ref.read(meterReadingRepositoryProvider).createReading(
          siteId: working.siteId,
          meterId: working.meterId,
          rawValue: working.rawValue,
          readingDate: DateTime.parse(working.readingDate),
          note: working.note,
          imageStoragePath: imagePath,
          enteredByUserId: userId,
        );

    String? signedUrl;
    if (imagePath != null) {
      try {
        signedUrl = await ref
            .read(meterImageStorageRepositoryProvider)
            .createSignedUrl(imagePath);
      } catch (_) {
        // Signed URL is optional for local draft state.
      }
    }

    return working.copyWith(
      status: LocalReadingStatus.synced,
      syncedAt: DateTime.now(),
      updatedAt: DateTime.now(),
      remotePhotoPath: imagePath ?? reading.imageStoragePath,
      remotePhotoUrl: signedUrl,
      photoUploadStatus: imagePath == null
          ? PhotoUploadStatus.none
          : PhotoUploadStatus.uploaded,
      clearError: true,
      clearPhotoErrorMessage: true,
    );
  } on DuplicateReadingException {
    return working.copyWith(
      status: LocalReadingStatus.conflict,
      errorMessage:
          'This reading already exists on server. Contact admin if correction is needed.',
      photoUploadStatus: working.remotePhotoPath != null
          ? PhotoUploadStatus.uploaded
          : working.photoUploadStatus,
      updatedAt: DateTime.now(),
    );
  } on PostgrestException catch (error) {
    return working.copyWith(
      status: LocalReadingStatus.failed,
      errorMessage: readablePostgrestError(error),
      photoUploadStatus: working.remotePhotoPath != null
          ? PhotoUploadStatus.uploaded
          : PhotoUploadStatus.failed,
      photoErrorMessage: working.remotePhotoPath != null
          ? 'Photo uploaded but reading insert failed.'
          : null,
      updatedAt: DateTime.now(),
    );
  } catch (error) {
    final photoFailed = working.hasLocalPhoto && working.remotePhotoPath == null;
    return working.copyWith(
      status: LocalReadingStatus.failed,
      errorMessage: isNetworkError(error)
          ? 'Network error while syncing.'
          : 'Could not sync reading. Try again later.',
      photoUploadStatus: photoFailed
          ? PhotoUploadStatus.failed
          : working.photoUploadStatus,
      photoErrorMessage: photoFailed
          ? 'Photo upload failed. Local image preserved.'
          : working.photoErrorMessage,
      updatedAt: DateTime.now(),
    );
  }
}
