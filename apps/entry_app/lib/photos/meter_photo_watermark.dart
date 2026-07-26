import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'reading_photo_models.dart';

const _maxImageWidth = 1920;
const _jpegQuality = 85;

class MeterPhotoWatermarkService {
  Future<Uint8List> applyWatermark({
    required Uint8List imageBytes,
    required ReadingPhotoContext context,
  }) async {
    final decoded = img.decodeImage(imageBytes);
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

class ReadingPhotoFileStore {
  Future<String> saveWatermarkedPhoto({
    required String localId,
    required Uint8List bytes,
  }) async {
    final dir = await _photosDir();
    final file = File(p.join(dir.path, '$localId-watermarked.jpg'));
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  Future<String> saveOriginalPhoto({
    required String localId,
    required Uint8List bytes,
    required String extension,
  }) async {
    final dir = await _photosDir();
    final safeExt = extension.replaceAll('.', '');
    final file = File(p.join(dir.path, '$localId-original.$safeExt'));
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  Future<Uint8List?> readBytes(String? path) async {
    if (path == null || path.isEmpty) {
      return null;
    }
    final file = File(path);
    if (!await file.exists()) {
      return null;
    }
    return file.readAsBytes();
  }

  Future<Directory> _photosDir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(base.path, 'reading_photos'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }
}
