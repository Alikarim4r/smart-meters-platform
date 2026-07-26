import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _localeKey = 'entry_locale_code';
const _themeModeKey = 'entry_theme_mode';

final entryLocaleProvider = StateNotifierProvider<EntryLocaleNotifier, Locale>(
  (ref) => EntryLocaleNotifier(),
);

class EntryLocaleNotifier extends StateNotifier<Locale> {
  EntryLocaleNotifier() : super(const Locale('en')) {
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

final entryThemeModeProvider =
    StateNotifierProvider<EntryThemeModeNotifier, ThemeMode>(
  (ref) => EntryThemeModeNotifier(),
);

class EntryThemeModeNotifier extends StateNotifier<ThemeMode> {
  EntryThemeModeNotifier() : super(ThemeMode.light) {
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
