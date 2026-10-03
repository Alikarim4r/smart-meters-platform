import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/profile.dart';

/// Last-known profile for offline resumes after first successful login.
///
/// Profile data contains identity and authorization metadata, so it is kept in
/// platform-protected secure storage. A legacy SharedPreferences value is
/// migrated once and then deleted.
class ProfileOfflineCache {
  ProfileOfflineCache._();

  static const _key = 'smart_meters.cached_profile_v2';
  static const _legacyPrefsKey = 'smart_meters.cached_profile_v1';
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static Future<void> save(Profile profile) async {
    await _storage.write(key: _key, value: jsonEncode(profile.toJson()));
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_legacyPrefsKey);
  }

  static Future<Profile?> loadMatching(String userId) async {
    var raw = await _storage.read(key: _key);
    if (raw == null || raw.isEmpty) {
      raw = await _readAndMigrateLegacy();
    }
    if (raw == null || raw.isEmpty) return null;
    try {
      final profile = Profile.fromJson(
        Map<String, dynamic>.from(jsonDecode(raw) as Map),
      );
      if (profile.id != userId) return null;
      return profile;
    } catch (_) {
      await clear();
      return null;
    }
  }

  static Future<String?> _readAndMigrateLegacy() async {
    final prefs = await SharedPreferences.getInstance();
    final legacy = prefs.getString(_legacyPrefsKey);
    if (legacy == null || legacy.isEmpty) return null;
    await _storage.write(key: _key, value: legacy);
    await prefs.remove(_legacyPrefsKey);
    return legacy;
  }

  static Future<void> clear() async {
    await _storage.delete(key: _key);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_legacyPrefsKey);
  }
}
