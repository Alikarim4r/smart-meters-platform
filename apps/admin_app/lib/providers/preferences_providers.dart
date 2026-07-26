import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _localeKey = 'admin_locale_code';
const _themeModeKey = 'admin_theme_mode';

final adminLocaleProvider = StateNotifierProvider<AdminLocaleNotifier, Locale>(
  (ref) => AdminLocaleNotifier(),
);

class AdminLocaleNotifier extends StateNotifier<Locale> {
  AdminLocaleNotifier() : super(const Locale('en')) {
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final code = prefs.getString(_localeKey);
      if (code == null || code.isEmpty) return;
      state = Locale(code);
    } catch (_) {
      // Keep default English.
    }
  }

  Future<void> setLocale(Locale locale) async {
    state = locale;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_localeKey, locale.languageCode);
    } catch (_) {
      // Keep in-memory preference.
    }
  }
}

final adminThemeModeProvider =
    StateNotifierProvider<AdminThemeModeNotifier, ThemeMode>(
      (ref) => AdminThemeModeNotifier(),
    );

class AdminThemeModeNotifier extends StateNotifier<ThemeMode> {
  AdminThemeModeNotifier() : super(ThemeMode.light) {
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final value = prefs.getString(_themeModeKey);
      if (value == null) return;
      state = ThemeMode.values.firstWhere(
        (mode) => mode.name == value,
        orElse: () => ThemeMode.light,
      );
    } catch (_) {
      // Session memory only if storage unavailable.
    }
  }

  Future<void> setMode(ThemeMode mode) async {
    state = mode;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_themeModeKey, mode.name);
    } catch (_) {
      // Keep in-memory preference.
    }
  }
}
