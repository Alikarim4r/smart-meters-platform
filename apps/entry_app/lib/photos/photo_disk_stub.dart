import 'dart:typed_data';

/// Disk helpers — real IO when dart:io is available.
Future<void> writePhotoBytesToDisk({
  required String absolutePath,
  required Uint8List bytes,
}) async {}

Future<Uint8List?> readPhotoBytesFromDisk(String absolutePath) async => null;

Future<String?> resolvePhotoDocumentsPath(String relativeFileName) async =>
    null;

Future<void> deletePhotoFromDisk(String absolutePath) async {}
