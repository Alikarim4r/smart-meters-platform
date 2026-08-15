import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:smart_meters_core/smart_meters_core.dart';

import '../utils/platform_image_picker.dart';
import 'meter_photo_watermark.dart';
import 'reading_photo_models.dart';

final imagePickerProvider = Provider<ImagePicker>((ref) => ImagePicker());

final meterPhotoWatermarkServiceProvider =
    Provider<MeterPhotoWatermarkService>((ref) {
  return MeterPhotoWatermarkService();
});

final readingPhotoFileStoreProvider = Provider<ReadingPhotoFileStore>((ref) {
  return ReadingPhotoFileStore();
});

class ReadingPhotoService {
  ReadingPhotoService({
    required this._picker,
    required this._watermarkService,
    required this._fileStore,
    required this._siteRepository,
  });

  final ImagePicker _picker;
  final MeterPhotoWatermarkService _watermarkService;
  final ReadingPhotoFileStore _fileStore;
  final SiteRepository _siteRepository;

  /// Must be called first from a user tap — do not await network before this.
  Future<XFile?> pickImage(ReadingPhotoSource source) {
    final imageSource = source == ReadingPhotoSource.camera
        ? ImageSource.camera
        : ImageSource.gallery;
    return pickPlatformImage(
      source: imageSource,
      picker: _picker,
      imageQuality: 92,
      maxWidth: 2400,
    );
  }

  Future<({
    String localPhotoPath,
    String watermarkedPhotoPath,
    ReadingPhotoSource source,
  })> processPickedImage({
    required XFile picked,
    required String localId,
    required ReadingPhotoContext context,
    required ReadingPhotoSource source,
  }) async {
    final originalBytes = await picked.readAsBytes();
    if (originalBytes.isEmpty) {
      throw const FormatException('Selected image is empty.');
    }

    final nameHint = picked.name.isNotEmpty ? picked.name : picked.path;
    final extension = nameHint.contains('.')
        ? nameHint.split('.').last
        : (picked.mimeType?.split('/').last ?? 'jpg');
    final localPhotoPath = await _fileStore.saveOriginalPhoto(
      localId: localId,
      bytes: originalBytes,
      extension: extension,
    );

    final watermarkedBytes = await _watermarkService.applyWatermark(
      imageBytes: originalBytes,
      context: context,
    );
    final watermarkedPhotoPath = await _fileStore.saveWatermarkedPhoto(
      localId: localId,
      bytes: watermarkedBytes,
    );

    return (
      localPhotoPath: localPhotoPath,
      watermarkedPhotoPath: watermarkedPhotoPath,
      source: source,
    );
  }

  Future<({
    String localPhotoPath,
    String watermarkedPhotoPath,
    ReadingPhotoSource source,
  })?> captureAndWatermark({
    required ReadingPhotoSource source,
    required String localId,
    required ReadingPhotoContext context,
  }) async {
    final picked = await pickImage(source);
    if (picked == null) return null;
    return processPickedImage(
      picked: picked,
      localId: localId,
      context: context,
      source: source,
    );
  }

  Future<ReadingPhotoContext> buildContext({
    required Site site,
    required Meter meter,
    required MeterCategoryConfig category,
    required DateTime businessDate,
    required Profile profile,
    required ReadingPhotoSource source,
    DateTime? capturedAt,
  }) async {
    String? organizationName;
    try {
      final orgs = await _siteRepository
          .getOrganizationsForAdmin()
          .timeout(const Duration(seconds: 3));
      final match = orgs
          .where((org) => org.id == site.organizationId)
          .toList();
      if (match.isNotEmpty) {
        organizationName = match.first.nameEn;
      }
    } catch (_) {
      // Organization name is optional for watermark — never block photo attach.
    }

    final technicianLabel = profile.fullName.trim().isNotEmpty
        ? profile.fullName.trim()
        : profile.email;

    return ReadingPhotoContext(
      organizationName: organizationName,
      siteName: site.nameEn,
      zoneName: site.displayZoneName,
      meterName: meter.nameEn,
      meterCode: meter.meterCode,
      categoryName: category.displayName,
      readingDate: formatBusinessDate(businessDate),
      technicianLabel: technicianLabel,
      source: source,
      capturedAt: capturedAt ?? DateTime.now(),
    );
  }

  Future<Uint8List?> readWatermarkedBytes(String? path) {
    return _fileStore.readBytes(path);
  }
}

final readingPhotoServiceProvider = Provider<ReadingPhotoService>((ref) {
  return ReadingPhotoService(
    picker: ref.watch(imagePickerProvider),
    watermarkService: ref.watch(meterPhotoWatermarkServiceProvider),
    fileStore: ref.watch(readingPhotoFileStoreProvider),
    siteRepository: ref.watch(siteRepositoryProvider),
  );
});
