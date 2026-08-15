import 'dart:io';
import 'dart:typed_data';

/// Converts HEIC/other formats to JPEG using macOS `sips` when available.
Future<Uint8List?> convertUnsupportedImageBytes(Uint8List bytes) async {
  if (!(Platform.isMacOS || Platform.isLinux)) {
    return null;
  }

  Directory? tmp;
  try {
    tmp = await Directory.systemTemp.createTemp('meter_photo_');
    final input = File('${tmp.path}/in.bin');
    final output = File('${tmp.path}/out.jpg');
    await input.writeAsBytes(bytes, flush: true);

    if (Platform.isMacOS) {
      final result = await Process.run('sips', <String>[
        '-s',
        'format',
        'jpeg',
        input.path,
        '--out',
        output.path,
      ]);
      if (result.exitCode == 0 && await output.exists()) {
        return output.readAsBytes();
      }
    }

    // Optional ImageMagick fallback (Linux / some Mac installs).
    final magick = await Process.run('magick', <String>[
      input.path,
      output.path,
    ]);
    if (magick.exitCode == 0 && await output.exists()) {
      return output.readAsBytes();
    }
  } catch (_) {
    return null;
  } finally {
    try {
      await tmp?.delete(recursive: true);
    } catch (_) {}
  }
  return null;
}
