import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/theme_mode_provider.dart';
import '../../l10n/app_strings.dart';

class ThemeModeToggle extends ConsumerWidget {
  const ThemeModeToggle({
    super.key,
    this.compact = false,
    this.lightForeground = false,
  });

  final bool compact;
  final bool lightForeground;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    final platformDark =
        MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    final effectiveDark =
        mode == ThemeMode.dark || (mode == ThemeMode.system && platformDark);
    final icon = effectiveDark
        ? Icons.dark_mode_outlined
        : Icons.light_mode_outlined;
    final label = effectiveDark ? 'Dark' : 'Light';

    if (compact) {
      return IconButton(
        tooltip: 'Switch to ${effectiveDark ? 'light' : 'dark'} theme',
        onPressed: () => ref
            .read(themeModeProvider.notifier)
            .toggleLightDark(MediaQuery.platformBrightnessOf(context)),
        icon: Icon(icon, color: lightForeground ? Colors.white70 : null),
      );
    }

    return PopupMenuButton<ThemeMode>(
      tooltip: 'Theme: $label',
      icon: Icon(icon, color: lightForeground ? Colors.white70 : null),
      onSelected: ref.read(themeModeProvider.notifier).setMode,
      itemBuilder: (context) => [
        PopupMenuItem(
          value: ThemeMode.light,
          child: Text(dashboardText(context, 'Light', 'فاتح')),
        ),
        PopupMenuItem(
          value: ThemeMode.dark,
          child: Text(dashboardText(context, 'Dark', 'داكن')),
        ),
        PopupMenuItem(
          value: ThemeMode.system,
          child: Text(dashboardText(context, 'System', 'النظام')),
        ),
      ],
    );
  }
}
