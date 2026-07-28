import 'dart:typed_data';

import '../models/profile.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileRepository {
  ProfileRepository(this._client);

  final SupabaseClient _client;

  static const avatarBucket = 'profile-avatars';

  Future<Profile> getProfile(String userId) async {
    // Prefer SECURITY DEFINER RPC — avoids profiles RLS recursion hangs after login.
    try {
      final data = await _client.rpc('get_own_profile');
      final map = _asProfileMap(data);
      if (map != null && map['id']?.toString() == userId) {
        return Profile.fromJson(map);
      }
    } catch (_) {
      // Fall through.
    }

    // Self-registration may lack a profiles row if the auth trigger failed.
    try {
      final ensured = await _client.rpc('ensure_own_pending_profile');
      final map = _asProfileMap(ensured);
      if (map != null && map['id']?.toString() == userId) {
        return Profile.fromJson(map);
      }
    } catch (_) {
      // Fall through to direct select for older backends / other-user reads.
    }

    final data = await _client
        .from('profiles')
        .select()
        .eq('id', userId)
        .single();

    return Profile.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Map<String, dynamic>? _asProfileMap(dynamic data) {
    if (data == null) return null;
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }
    if (data is List && data.isNotEmpty && data.first is Map) {
      return Map<String, dynamic>.from(data.first as Map);
    }
    return null;
  }

  /// Updates editable Entry profile fields for the signed-in user.
  Future<Profile> updateOwnProfile({
    required String userId,
    required String fullName,
    String? phone,
    String? companyName,
    String? avatarPath,
    bool clearAvatarPath = false,
  }) async {
    final payload = <String, dynamic>{
      'full_name': fullName.trim(),
      'phone': phone?.trim().isEmpty == true ? null : phone?.trim(),
      'company_name': companyName?.trim().isEmpty == true
          ? null
          : companyName?.trim(),
    };
    if (clearAvatarPath) {
      payload['avatar_path'] = null;
    } else if (avatarPath != null) {
      payload['avatar_path'] = avatarPath;
    }

    final row = await _client
        .from('profiles')
        .update(payload)
        .eq('id', userId)
        .select()
        .single();

    return Profile.fromJson(Map<String, dynamic>.from(row));
  }

  /// Uploads avatar bytes to `{userId}/avatar.{ext}` and returns storage path.
  Future<String> uploadAvatar({
    required String userId,
    required Uint8List bytes,
    String contentType = 'image/jpeg',
  }) async {
    final ext = contentType.contains('png')
        ? 'png'
        : contentType.contains('webp')
        ? 'webp'
        : 'jpg';
    final path = '$userId/avatar.$ext';
    await _client.storage
        .from(avatarBucket)
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: contentType, upsert: true),
        );
    return path;
  }

  String? publicAvatarUrl(String? avatarPath) {
    if (avatarPath == null || avatarPath.trim().isEmpty) return null;
    return _client.storage.from(avatarBucket).getPublicUrl(avatarPath);
  }
}
