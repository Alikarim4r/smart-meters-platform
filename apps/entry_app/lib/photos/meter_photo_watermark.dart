import 'dart:typed_data';

import 'package:hive_flutter/hive_flutter.dart';
import 'package:image/image.dart' as img;

import 'photo_decode.dart';
import 'photo_disk.dart';
import 'reading_photo_models.dart';

const _maxImageWidth = 1920;
const _jpegQuality = 85;
const readingPhotoBytesBoxName = 'reading_photo_bytes';

class MeterPhotoWatermarkService {
  Future<Uint8List> applyWatermark({
    required Uint8List imageBytes,
    required ReadingPhotoContext context,
  }) async {
    // HEIC from macOS Photos is common; convert before decode when needed.
    final bytes = await ensureDecodableImageBytes(imageBytes);
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      throw const FormatException('Could not decode image for watermarking.');
    }

    var image = decoded;
    if (image.width > _maxImageWidth) {
      image = img.copyResize(image, width: _maxImageWidth);
    }

    final lines = context.watermarkLines();
    const lineHeight = 36;
    const padding = 24;
    final font = img.arial24;
    final textBlockHeight = lines.length * lineHeight + padding * 2;
    final barTop = (image.height - textBlockHeight).clamp(0, image.height);

    img.fillRect(
      image,
      x1: 0,
      y1: barTop,
      x2: image.width,
      y2: image.height,
      color: img.ColorRgba8(0, 0, 0, 170),
    );

    var y = barTop + padding;
    for (final line in lines) {
      img.drawString(
        image,
        line,
        font: font,
        x: padding,
        y: y,
        color: img.ColorRgba8(255, 255, 255, 255),
      );
      y += lineHeight;
    }

    return Uint8List.fromList(img.encodeJpg(image, quality: _jpegQuality));
  }
}

/// Stores meter photos in Hive (works on web + desktop + mobile) and mirrors
/// to disk on platforms that support `dart:io`.
class ReadingPhotoFileStore {
  Future<Box<dynamic>> _box() async {
    if (Hive.isBoxOpen(readingPhotoBytesBoxName)) {
      return Hive.box<dynamic>(readingPhotoBytesBoxName);
    }
    return Hive.openBox<dynamic>(readingPhotoBytesBoxName);
  }

  Future<String> saveWatermarkedPhoto({
    required String localId,
    required Uint8List bytes,
  }) {
    return _save(
      logicalKey: '$localId-watermarked.jpg',
      fileName: '$localId-watermarked.jpg',
      bytes: bytes,
    );
  }

  Future<String> saveOriginalPhoto({
    required String localId,
    required Uint8List bytes,
    required String extension,
  }) {
    final safeExt = extension.replaceAll('.', '').toLowerCase();
    final name = '$localId-original.${safeExt.isEmpty ? 'jpg' : safeExt}';
    return _save(logicalKey: name, fileName: name, bytes: bytes);
  }

  Future<String> _save({
    required String logicalKey,
    required String fileName,
    required Uint8List bytes,
  }) async {
    final box = await _box();
    await box.put(logicalKey, bytes);

    final diskPath = await resolvePhotoDocumentsPath(fileName);
    if (diskPath != null) {
      try {
        await writePhotoBytesToDisk(absolutePath: diskPath, bytes: bytes);
        // Prefer absolute disk path for legacy readers / share sheets.
        await box.put(diskPath, bytes);
        return diskPath;
      } catch (_) {
        // Fall through — Hive key still works.
      }
    }
    return logicalKey;
  }

  Future<void> deletePhoto(String? path) async {
    if (path == null || path.isEmpty) return;
    final box = await _box();
    await box.delete(path);

    // Disk-backed saves are mirrored under their basename in Hive as well.
    final normalized = path.replaceAll('\\', '/');
    final basename = normalized.split('/').last;
    if (basename.isNotEmpty && basename != path) {
      await box.delete(basename);
    }

    try {
      await deletePhotoFromDisk(path);
    } catch (_) {
      // Best-effort cleanup; stale local files must never block user actions.
    }
  }

  Future<Uint8List?> readBytes(String? path) async {
    if (path == null || path.isEmpty) return null;
    final box = await _box();
    final cached = box.get(path);
    if (cached is Uint8List) return cached;
    if (cached is List) {
      return Uint8List.fromList(cached.cast<int>());
    }

    final fromDisk = await readPhotoBytesFromDisk(path);
    if (fromDisk != null) {
      await box.put(path, fromDisk);
      return fromDisk;
    }
    return null;
  }
}
