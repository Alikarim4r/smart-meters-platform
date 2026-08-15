import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../photos/reading_photo_service.dart';

/// Cross-platform local photo preview (disk path or Hive key).
class LocalPhotoImage extends ConsumerWidget {
  const LocalPhotoImage({
    super.key,
    required this.path,
    this.fit = BoxFit.cover,
  });

  final String? path;
  final BoxFit fit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = path;
    if (key == null || key.isEmpty) {
      return const SizedBox.shrink();
    }
    return FutureBuilder<Uint8List?>(
      future: ref.read(readingPhotoServiceProvider).readWatermarkedBytes(key),
      builder: (context, snapshot) {
        final bytes = snapshot.data;
        if (bytes == null || bytes.isEmpty) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            );
          }
          return const ColoredBox(
            color: Color(0xFFE2E6EB),
            child: Icon(Icons.broken_image_outlined),
          );
        }
        return Image.memory(bytes, fit: fit, gaplessPlayback: true);
      },
    );
  }
}

Future<bool> localPhotoExists(WidgetRef ref, String? path) async {
  if (path == null || path.isEmpty) return false;
  final bytes =
      await ref.read(readingPhotoServiceProvider).readWatermarkedBytes(path);
  return bytes != null && bytes.isNotEmpty;
}
