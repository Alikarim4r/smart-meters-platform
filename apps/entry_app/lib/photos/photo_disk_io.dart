import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

Future<void> writePhotoBytesToDisk({
  required String absolutePath,
  required Uint8List bytes,
}) async {
  final file = File(absolutePath);
  await file.parent.create(recursive: true);
  await file.writeAsBytes(bytes, flush: true);
}

Future<Uint8List?> readPhotoBytesFromDisk(String absolutePath) async {
  final file = File(absolutePath);
  if (!await file.exists()) return null;
  return file.readAsBytes();
}

Future<String?> resolvePhotoDocumentsPath(String relativeFileName) async {
  final base = await getApplicationDocumentsDirectory();
  final dir = Directory(p.join(base.path, 'reading_photos'));
  if (!await dir.exists()) {
    await dir.create(recursive: true);
  }
  return p.join(dir.path, relativeFileName);
}

Future<void> deletePhotoFromDisk(String absolutePath) async {
  if (absolutePath.isEmpty) return;
  final file = File(absolutePath);
  if (await file.exists()) {
    await file.delete();
  }
}
