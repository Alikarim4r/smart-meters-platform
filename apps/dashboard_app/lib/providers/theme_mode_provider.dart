import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _themeModeKey = 'dashboard_theme_mode';

final themeModeProvider =
    StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  return ThemeModeNotifier();
});

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier() : super(ThemeMode.system) {
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final value = prefs.getString(_themeModeKey);
      if (value == null) return;
      state = ThemeMode.values.firstWhere(
        (mode) => mode.name == value,
        orElse: () => ThemeMode.system,
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

  /// One-tap light/dark toggle (skips system so the first press always changes UI).
  void toggleLightDark([Brightness? platformBrightness]) {
    final brightness = platformBrightness ??
        WidgetsBinding.instance.platformDispatcher.platformBrightness;
    final isDark = state == ThemeMode.dark ||
        (state == ThemeMode.system && brightness == Brightness.dark);
    setMode(isDark ? ThemeMode.light : ThemeMode.dark);
  }

  void cycleMode() {
    final next = switch (state) {
      ThemeMode.light => ThemeMode.dark,
      ThemeMode.dark => ThemeMode.system,
      ThemeMode.system => ThemeMode.light,
    };
    setMode(next);
  }
}
