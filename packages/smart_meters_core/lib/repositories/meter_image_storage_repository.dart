import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/meter_image_path.dart';

class MeterImageStorageRepository {
  MeterImageStorageRepository(this._client);

  final SupabaseClient _client;

  Future<String> uploadMeterReadingImage({
    required String storagePath,
    required Uint8List bytes,
  }) async {
    await _client.storage
        .from(kMeterImagesBucket)
        .uploadBinary(
          storagePath,
          bytes,
          fileOptions: const FileOptions(
            contentType: 'image/jpeg',
            upsert: true,
          ),
        );
    return storagePath;
  }

  Future<String> createSignedUrl(
    String storagePath, {
    int expiresInSeconds = 3600,
  }) async {
    return _client.storage
        .from(kMeterImagesBucket)
        .createSignedUrl(storagePath, expiresInSeconds);
  }
}
