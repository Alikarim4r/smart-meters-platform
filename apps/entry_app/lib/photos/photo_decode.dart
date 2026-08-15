import 'dart:typed_data';

import 'package:image/image.dart' as img;

import 'photo_decode_io.dart'
    if (dart.library.html) 'photo_decode_stub.dart';

/// Ensures image bytes can be decoded by the `image` package (JPEG/PNG/…).
/// On macOS, HEIC/HEIF from Photos is converted via `sips` when needed.
Future<Uint8List> ensureDecodableImageBytes(Uint8List bytes) async {
  if (bytes.isEmpty) {
    throw const FormatException('Selected image is empty.');
  }
  if (img.decodeImage(bytes) != null) {
    return bytes;
  }

  final converted = await convertUnsupportedImageBytes(bytes);
  if (converted != null &&
      converted.isNotEmpty &&
      img.decodeImage(converted) != null) {
    return converted;
  }

  throw const FormatException(
    'Could not decode image. Please choose a JPG or PNG file.',
  );
}
