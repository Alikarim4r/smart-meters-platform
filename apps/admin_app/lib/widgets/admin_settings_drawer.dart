import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_meters_core/smart_meters_core.dart';

import '../l10n/admin_strings.dart';
import '../providers/preferences_providers.dart';
import '../screens/catalog_dashboard_screen.dart';
import '../screens/corrections_tab.dart';
import '../screens/settings_tab.dart';
import '../utils/user_validation.dart';

/// Settings-only drawer: account, language, appearance, and advanced tools.
/// The five main sections live exclusively in the bottom navigation bar.
class AdminSettingsDrawer extends ConsumerWidget {
  const AdminSettingsDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(adminLocaleProvider);
    final s = AdminStrings(locale);
    final themeMode = ref.watch(adminThemeModeProvider);
    final profile = ref.watch(authProvider).profile;
    final theme = Theme.of(context);

    final displayName = profile == null
        ? ''
        : (profile.fullName.trim().isEmpty ? profile.email : profile.fullName);
    final initials = _initials(displayName);

    return Drawer(
      child: Column(
        children: [
          _DrawerHeader(
            initials: initials,
            displayName: displayName,
            roleLabel: profile == null ? '' : userRoleLabel(profile.role),
            email: profile?.email ?? '',
            title: s.settings,
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                _SectionLabel(icon: Icons.palette_outlined, text: s.appearance),
                const SizedBox(height: 8),
                SegmentedButton<ThemeMode>(
                  segments: [
                    ButtonSegment(
                      value: ThemeMode.light,
                      icon: const Icon(Icons.light_mode_outlined, size: 18),
                      label: Text(s.themeLight),
                    ),
                    ButtonSegment(
                      value: ThemeMode.dark,
                      icon: const Icon(Icons.dark_mode_outlined, size: 18),
                      label: Text(s.themeDark),
                    ),
                    ButtonSegment(
                      value: ThemeMode.system,
                      icon: const Icon(
                        Icons.brightness_auto_outlined,
                        size: 18,
                      ),
                      label: Text(s.themeSystem),
                    ),
                  ],
                  selected: {themeMode},
                  showSelectedIcon: false,
                  onSelectionChanged: (selection) => ref
                      .read(adminThemeModeProvider.notifier)
                      .setMode(selection.first),
                ),
                const SizedBox(height: 20),
                _SectionLabel(icon: Icons.translate_outlined, text: s.language),
                const SizedBox(height: 8),
                SegmentedButton<String>(
                  segments: [
                    ButtonSegment(value: 'en', label: Text(s.languageEnglish)),
                    ButtonSegment(value: 'ar', label: Text(s.languageArabic)),
                  ],
                  selected: {locale.languageCode},
                  showSelectedIcon: false,
                  onSelectionChanged: (selection) => ref
                      .read(adminLocaleProvider.notifier)
                      .setLocale(Locale(selection.first)),
                ),
                const SizedBox(height: 20),
                _SectionLabel(icon: Icons.person_outline, text: s.account),
                const SizedBox(height: 4),
                SessionSecuritySettingsSection(locale: locale, dense: true),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.lock_outline),
                  title: Text(s.changePassword),
                  onTap: () => _showChangePasswordDialog(context, ref, s),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.logout, color: theme.colorScheme.error),
                  title: Text(
                    s.signOut,
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                  onTap: () => ref.read(authProvider.notifier).signOut(),
                ),
                const Divider(height: 28),
                _SectionLabel(
                  icon: Icons.handyman_outlined,
                  text: s.advancedTools,
                ),
                const SizedBox(height: 4),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.edit_note_outlined),
                  title: Text(s.corrections),
                  trailing: const Icon(Icons.chevron_right, size: 20),
                  onTap: () => _pushTool(
                    context,
                    title: s.corrections,
                    child: const CorrectionsTab(),
                  ),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.tune_outlined),
                  title: Text(s.policySettings),
                  trailing: const Icon(Icons.chevron_right, size: 20),
                  onTap: () => _pushTool(
                    context,
                    title: s.policySettings,
                    child: const SettingsTab(),
                  ),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.category_outlined),
                  title: Text(s.catalogAdvanced),
                  trailing: const Icon(Icons.chevron_right, size: 20),
                  onTap: () => _pushTool(
                    context,
                    title: s.catalogAdvanced,
                    child: const CatalogDashboardBody(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _initials(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      return parts.first.characters.first.toUpperCase();
    }
    return (parts.first.characters.first + parts.last.characters.first)
        .toUpperCase();
  }

  void _pushTool(
    BuildContext context, {
    required String title,
    required Widget child,
  }) {
    Navigator.of(context).pop(); // close drawer
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          appBar: AppBar(title: Text(title)),
          body: child,
        ),
      ),
    );
  }

  Future<void> _showChangePasswordDialog(
    BuildContext context,
    WidgetRef ref,
    AdminStrings s,
  ) async {
    final formKey = GlobalKey<FormState>();
    final passwordController = TextEditingController();
    final confirmController = TextEditingController();

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.changePassword),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: passwordController,
                obscureText: true,
                decoration: InputDecoration(labelText: s.newPassword),
                validator: (value) => (value == null || value.length < 8)
                    ? s.passwordTooShort
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: confirmController,
                obscureText: true,
                decoration: InputDecoration(labelText: s.confirmPassword),
                validator: (value) => value != passwordController.text
                    ? s.passwordsDoNotMatch
                    : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(s.cancel),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(ctx, true);
              }
            },
            child: Text(s.save),
          ),
        ],
      ),
    );

    if (saved == true) {
      try {
        await ref
            .read(authProvider.notifier)
            .updatePassword(passwordController.text);
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(s.passwordUpdated)));
        }
      } catch (error) {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('$error')));
        }
      }
    }
    passwordController.dispose();
    confirmController.dispose();
  }
}

class _DrawerHeader extends StatelessWidget {
  const _DrawerHeader({
    required this.initials,
    required this.displayName,
    required this.roleLabel,
    required this.email,
    required this.title,
  });

  final String initials;
  final String displayName;
  final String roleLabel;
  final String email;
  final String title;

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.paddingOf(context).top;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final titleColor = isDark ? Colors.white70 : BrandChrome.inkMuted;
    final nameColor = isDark ? Colors.white : BrandChrome.ink;
    final emailColor = isDark ? Colors.white60 : BrandChrome.inkMuted;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(20, topPadding + 20, 20, 18),
      decoration: BoxDecoration(
        gradient: BrandChrome.cardWash(isDark: isDark),
        border: Border(
          bottom: BorderSide(
            color: isDark
                ? Theme.of(context).colorScheme.outline.withValues(alpha: 0.4)
                : BrandChrome.borderLight,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: titleColor,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: BrandChrome.accent,
                child: Text(
                  initials,
                  style: const TextStyle(
                    color: BrandChrome.onAccent,
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: nameColor,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (roleLabel.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: BrandChrome.accent.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: BrandChrome.accent.withValues(alpha: 0.45),
                          ),
                        ),
                        child: Text(
                          roleLabel,
                          style: TextStyle(
                            color: isDark
                                ? AppColors.goldSoft
                                : BrandChrome.iconGlyph,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    const SizedBox(height: 4),
                    Text(
                      email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: emailColor, fontSize: 12.5),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).textTheme.bodySmall?.color;
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Text(
          text.toUpperCase(),
          style: TextStyle(
            fontSize: 11.5,
            letterSpacing: 0.8,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }
}
