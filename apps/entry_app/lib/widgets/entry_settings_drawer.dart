import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_meters_core/smart_meters_core.dart';

import '../l10n/entry_strings.dart';
import '../providers/preferences_providers.dart';
import '../screens/entry_profile_edit_screen.dart';
import '../theme/entry_chrome.dart';

/// Fixed settings drawer: appearance / language / password + pinned sign-out.
/// Profile editing opens on a separate screen from the header.
class EntrySettingsDrawer extends ConsumerWidget {
  const EntrySettingsDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(entryLocaleProvider);
    final s = EntryStrings(locale);
    final themeMode = ref.watch(entryThemeModeProvider);
    final profile = ref.watch(authProvider).profile;
    final theme = Theme.of(context);

    final displayName = profile == null
        ? ''
        : (profile.fullName.trim().isEmpty ? profile.email : profile.fullName);
    final initials = _initials(displayName);
    final avatarUrl = profile == null
        ? null
        : ref.read(profileRepositoryProvider).publicAvatarUrl(profile.avatarPath);

    return Drawer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _DrawerHeader(
            initials: initials,
            displayName: displayName,
            roleLabel: profile == null ? '' : s.roleLabel(profile.role),
            email: profile?.email ?? '',
            title: s.settings,
            avatarUrl: avatarUrl,
            editHint: s.editProfile,
            onOpenProfile: () {
              final navigator = Navigator.of(context);
              Scaffold.maybeOf(context)?.closeDrawer();
              navigator.push(
                MaterialPageRoute<void>(
                  builder: (_) => const EntryProfileEditScreen(),
                ),
              );
            },
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              children: [
                  _SectionLabel(
                    icon: Icons.palette_outlined,
                    text: s.appearance,
                  ),
                  const SizedBox(height: 8),
                  SegmentedButton<ThemeMode>(
                    style: theme.segmentedButtonTheme.style,
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
                        .read(entryThemeModeProvider.notifier)
                        .setMode(selection.first),
                  ),
                  const SizedBox(height: 20),
                  _SectionLabel(
                    icon: Icons.translate_outlined,
                    text: s.language,
                  ),
                  const SizedBox(height: 8),
                  SegmentedButton<String>(
                    style: theme.segmentedButtonTheme.style,
                    segments: [
                      ButtonSegment(
                        value: 'en',
                        label: Text(s.languageEnglish),
                      ),
                      ButtonSegment(
                        value: 'ar',
                        label: Text(s.languageArabic),
                      ),
                    ],
                    selected: {locale.languageCode},
                    showSelectedIcon: false,
                    onSelectionChanged: (selection) => ref
                        .read(entryLocaleProvider.notifier)
                        .setLocale(Locale(selection.first)),
                  ),
                  const SizedBox(height: 20),
                  _SectionLabel(
                    icon: Icons.person_outline,
                    text: s.account,
                  ),
                  const SizedBox(height: 4),
                  SessionSecuritySettingsSection(locale: locale, dense: true),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.lock_outline),
                    title: Text(s.changePassword),
                    onTap: () => _showChangePasswordDialog(context, ref, s),
                  ),
                  const SizedBox(height: 12),
                  _SectionLabel(
                    icon: Icons.info_outline,
                    text: s.aboutApp,
                  ),
                  const SizedBox(height: 6),
                  _DeveloperCredit(
                    title: s.createdDevelopedBy,
                    name: s.developerName,
                    phone: s.developerPhone,
                    email: s.developerEmail,
                  ),
                  const SizedBox(height: 16),
              ],
            ),
          ),
          SafeArea(
            top: false,
            minimum: const EdgeInsets.only(bottom: 8),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: theme.colorScheme.error,
                  side: BorderSide(
                    color: theme.colorScheme.error.withValues(alpha: 0.45),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: () => ref.read(authProvider.notifier).signOut(),
                icon: const Icon(Icons.logout),
                label: Text(s.signOut),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _initials(String name) {
    final parts =
        name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      return parts.first.characters.first.toUpperCase();
    }
    return (parts.first.characters.first + parts.last.characters.first)
        .toUpperCase();
  }

  Future<void> _showChangePasswordDialog(
    BuildContext context,
    WidgetRef ref,
    EntryStrings s,
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
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(s.passwordUpdated)),
          );
        }
      } catch (error) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$error')),
          );
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
    required this.editHint,
    required this.onOpenProfile,
    this.avatarUrl,
  });

  final String initials;
  final String displayName;
  final String roleLabel;
  final String email;
  final String title;
  final String editHint;
  final VoidCallback onOpenProfile;
  final String? avatarUrl;

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.paddingOf(context).top;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    ImageProvider? image;
    if (avatarUrl != null && avatarUrl!.isNotEmpty) {
      image = NetworkImage(avatarUrl!);
    }

    final titleColor = isDark ? Colors.white70 : EntryChrome.inkMuted;
    final nameColor = isDark ? Colors.white : EntryChrome.ink;
    final emailColor = isDark ? Colors.white60 : EntryChrome.inkMuted;

    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(
          gradient: EntryChrome.cardWash(isDark: isDark),
          border: Border(
            bottom: BorderSide(
              color: isDark
                  ? Theme.of(context).colorScheme.outline.withValues(alpha: 0.4)
                  : EntryChrome.borderLight,
            ),
          ),
        ),
        child: InkWell(
          onTap: onOpenProfile,
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, topPadding + 16, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
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
                    const Spacer(),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 18,
                      color: titleColor,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: EntryChrome.accent,
                      backgroundImage: image,
                      child: image == null
                          ? Text(
                              initials,
                              style: TextStyle(
                                color: EntryChrome.onAccent,
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(width: 12),
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
                              fontSize: 15,
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
                                color:
                                    EntryChrome.accent.withValues(alpha: 0.16),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: EntryChrome.accent
                                      .withValues(alpha: 0.45),
                                ),
                              ),
                              child: Text(
                                roleLabel,
                                style: TextStyle(
                                  color: isDark
                                      ? AppColors.goldSoft
                                      : EntryChrome.iconGlyph,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          const SizedBox(height: 2),
                          Text(
                            email,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: emailColor,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            editHint,
                            style: TextStyle(
                              color: EntryChrome.iconGlyph.withValues(
                                alpha: isDark ? 0.9 : 1,
                              ),
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
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

class _DeveloperCredit extends StatelessWidget {
  const _DeveloperCredit({
    required this.title,
    required this.name,
    required this.phone,
    required this.email,
  });

  final String title;
  final String name;
  final String phone;
  final String email;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.85),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            name,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Directionality(
            textDirection: TextDirection.ltr,
            child: Text(phone, style: theme.textTheme.bodyMedium),
          ),
          Text(email, style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }
}
