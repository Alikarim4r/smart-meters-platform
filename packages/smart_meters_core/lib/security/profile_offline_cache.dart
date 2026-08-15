import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/profile.dart';

/// Last-known profile for offline resumes after first successful login.
class ProfileOfflineCache {
  ProfileOfflineCache._();

  static const _prefsKey = 'smart_meters.cached_profile_v1';

  static Future<void> save(Profile profile) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, jsonEncode(profile.toJson()));
  }

  static Future<Profile?> loadMatching(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final profile = Profile.fromJson(
        Map<String, dynamic>.from(jsonDecode(raw) as Map),
      );
      if (profile.id != userId) return null;
      return profile;
    } catch (_) {
      return null;
    }
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey);
  }
}
