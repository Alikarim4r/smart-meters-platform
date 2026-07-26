import 'package:dashboard_app/providers/theme_mode_provider.dart';
import 'package:dashboard_app/theme/dashboard_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('dark mode palette has required colors', () {
    const dark = DashboardThemeColors.dark;
    expect(dark.background, isNot(dark.card));
    expect(dark.textPrimary, isNot(dark.textMuted));
    expect(dark.dialog, isNot(Colors.white));
  });

  test('theme mode notifier toggles light and dark in one step', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final notifier = container.read(themeModeProvider.notifier);
    expect(container.read(themeModeProvider), ThemeMode.system);

    notifier.toggleLightDark(Brightness.light);
    expect(container.read(themeModeProvider), ThemeMode.dark);

    notifier.toggleLightDark(Brightness.light);
    expect(container.read(themeModeProvider), ThemeMode.light);
  });

  test('theme mode notifier cycles modes', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final notifier = container.read(themeModeProvider.notifier);
    await notifier.setMode(ThemeMode.dark);
    expect(container.read(themeModeProvider), ThemeMode.dark);

    notifier.cycleMode();
    expect(container.read(themeModeProvider), ThemeMode.system);
  });
}
