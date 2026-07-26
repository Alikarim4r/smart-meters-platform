import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_meters_core/smart_meters_core.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../l10n/app_strings.dart';
import '../../providers/locale_provider.dart';
import '../../providers/theme_mode_provider.dart';
import '../../theme/dashboard_theme.dart';

Future<void> showDashboardSettingsSheet(
  BuildContext context, {
  VoidCallback? onSignOut,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    // Transparent so sheet chrome is painted by [DashboardSettingsSheet]
    // and updates immediately when theme mode changes.
    backgroundColor: Colors.transparent,
    showDragHandle: false,
    builder: (context) => DashboardSettingsSheet(onSignOut: onSignOut),
  );
}

class DashboardSettingsSheet extends ConsumerStatefulWidget {
  const DashboardSettingsSheet({super.key, this.onSignOut});

  final VoidCallback? onSignOut;

  @override
  ConsumerState<DashboardSettingsSheet> createState() =>
      _DashboardSettingsSheetState();
}

class _DashboardSettingsSheetState
    extends ConsumerState<DashboardSettingsSheet> {
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _savingPassword = false;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _savePassword(AppStrings s) async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _savingPassword = true);
    try {
      await ref
          .read(authProvider.notifier)
          .updatePassword(_passwordController.text);
      if (!mounted) return;
      _passwordController.clear();
      _confirmController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.passwordUpdated)),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$error')),
      );
    } finally {
      if (mounted) setState(() => _savingPassword = false);
    }
  }

  Future<void> _launchUri(Uri uri) async {
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = dashboardColors(context);
    final locale = ref.watch(localeProvider);
    final s = AppStrings(locale);
    final profile = ref.watch(authProvider).profile;
    final themeMode = ref.watch(themeModeProvider);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      elevation: 0,
      shadowColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      clipBehavior: Clip.antiAlias,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: BrandChrome.cardWash(isDark: isDark),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border(
            top: BorderSide(
              color: BrandChrome.border(
                isDark: isDark,
                scheme: Theme.of(context).colorScheme,
              ),
            ),
          ),
        ),
        child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            8,
            20,
            24 + bottomInset + MediaQuery.viewPaddingOf(context).bottom,
          ),
          child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: colors.textMuted.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              Text(
                s.settings,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: colors.textPrimary,
                    ),
              ),
              const SizedBox(height: 16),
              _SectionCard(
                title: s.accountDetails,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading:
                          Icon(Icons.person_outline, color: colors.textMuted),
                      title: Text(
                        profile?.fullName.trim().isNotEmpty == true
                            ? profile!.fullName
                            : (profile?.email ?? '—'),
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        profile != null
                            ? '${s.role}: ${s.userRole(profile.role)}'
                            : s.account,
                        style: TextStyle(color: colors.textMuted),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      s.email,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: colors.textMuted,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 4),
                    _LtrText(
                      profile?.email ?? '—',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: colors.textPrimary,
                          ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      s.changePassword,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: colors.textPrimary,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscureNew,
                            decoration: InputDecoration(
                              labelText: s.newPassword,
                              suffixIcon: IconButton(
                                onPressed: () => setState(
                                  () => _obscureNew = !_obscureNew,
                                ),
                                icon: Icon(
                                  _obscureNew
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                  color: colors.textMuted,
                                ),
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return s.passwordRequired;
                              }
                              if (value.length < 6) return s.passwordTooShort;
                              return null;
                            },
                          ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _confirmController,
                          obscureText: _obscureConfirm,
                          decoration: InputDecoration(
                            labelText: s.confirmPassword,
                            suffixIcon: IconButton(
                              onPressed: () => setState(
                                () => _obscureConfirm = !_obscureConfirm,
                              ),
                              icon: Icon(
                                _obscureConfirm
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                                color: colors.textMuted,
                              ),
                            ),
                          ),
                          validator: (value) {
                            if (value != _passwordController.text) {
                              return s.passwordsDoNotMatch;
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: FilledButton(
                            onPressed:
                                _savingPassword ? null : () => _savePassword(s),
                            child: _savingPassword
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Text(s.savePassword),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _SectionCard(
              title: s.language,
              child: SizedBox(
                width: double.infinity,
                child: SegmentedButton<String>(
                  showSelectedIcon: false,
                  style: _segmentStyle(context, colors, isDark),
                  segments: [
                    ButtonSegment(value: 'ar', label: Text(s.arabic)),
                    ButtonSegment(value: 'en', label: Text(s.english)),
                  ],
                  selected: {locale.languageCode},
                  onSelectionChanged: (values) {
                    ref
                        .read(localeProvider.notifier)
                        .setLocale(Locale(values.first));
                  },
                ),
              ),
            ),
            const SizedBox(height: 12),
            _SectionCard(
              title: s.appearance,
              child: Column(
                children: [
                  _ThemeOptionTile(
                    value: ThemeMode.light,
                    groupValue: themeMode,
                    icon: Icons.light_mode_outlined,
                    title: s.lightTheme,
                    subtitle: s.lightThemeHint,
                    onChanged: (mode) =>
                        ref.read(themeModeProvider.notifier).setMode(mode),
                  ),
                  Divider(height: 1, color: colors.border.withValues(alpha: 0.7)),
                  _ThemeOptionTile(
                    value: ThemeMode.dark,
                    groupValue: themeMode,
                    icon: Icons.dark_mode_outlined,
                    title: s.darkTheme,
                    subtitle: s.darkThemeHint,
                    onChanged: (mode) =>
                        ref.read(themeModeProvider.notifier).setMode(mode),
                  ),
                  Divider(height: 1, color: colors.border.withValues(alpha: 0.7)),
                  _ThemeOptionTile(
                    value: ThemeMode.system,
                    groupValue: themeMode,
                    icon: Icons.brightness_auto_outlined,
                    title: s.systemTheme,
                    subtitle: s.systemThemeHint,
                    onChanged: (mode) =>
                        ref.read(themeModeProvider.notifier).setMode(mode),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _SectionCard(
              title: s.designerContact,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    s.designerCredit,
                    textAlign: TextAlign.start,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontSize: 12,
                          height: 1.35,
                          fontWeight: FontWeight.w500,
                          color: colors.textMuted,
                        ),
                  ),
                  const SizedBox(height: 14),
                  _ContactRow(
                    icon: Icons.email_outlined,
                    label: s.email,
                    value: s.designerEmail,
                    actionTooltip: s.sendEmail,
                    actionIcon: Icons.open_in_new_rounded,
                    onAction: () {
                      Clipboard.setData(ClipboardData(text: s.designerEmail));
                      _launchUri(
                        Uri(scheme: 'mailto', path: s.designerEmail),
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  _ContactRow(
                    icon: Icons.phone_outlined,
                    label: s.call,
                    value: s.designerPhone,
                    actionTooltip: s.call,
                    actionIcon: Icons.call_outlined,
                    onAction: () {
                      Clipboard.setData(ClipboardData(text: s.designerPhone));
                      _launchUri(Uri(scheme: 'tel', path: '+97430058899'));
                    },
                  ),
                ],
              ),
            ),
            if (widget.onSignOut != null) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    widget.onSignOut!();
                  },
                  icon: const Icon(Icons.logout_rounded),
                  label: Text(s.logout),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.error,
                    side: BorderSide(
                      color: Theme.of(context)
                          .colorScheme
                          .error
                          .withValues(alpha: 0.45),
                    ),
                    minimumSize: const Size(0, 48),
                  ),
                ),
              ),
            ],
          ],
        ),
          ),
        ),
      ),
      ),
    );
  }

  ButtonStyle _segmentStyle(
    BuildContext context,
    DashboardThemeColors colors,
    bool isDark,
  ) {
    final primary = Theme.of(context).colorScheme.primary;
    return ButtonStyle(
      visualDensity: VisualDensity.compact,
      foregroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return isDark ? const Color(0xFFE8EEF7) : colors.textPrimary;
        }
        return colors.textMuted;
      }),
      backgroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return primary.withValues(alpha: isDark ? 0.28 : 0.14);
        }
        return colors.inputFill;
      }),
      side: WidgetStatePropertyAll(BorderSide(color: colors.border)),
    );
  }
}

class _LtrText extends StatelessWidget {
  const _LtrText(this.text, {this.style});

  final String text;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Text(
          text,
          textAlign: TextAlign.left,
          style: style,
        ),
      ),
    );
  }
}

class _ContactRow extends StatelessWidget {
  const _ContactRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.actionTooltip,
    required this.actionIcon,
    required this.onAction,
  });

  final IconData icon;
  final String label;
  final String value;
  final String actionTooltip;
  final IconData actionIcon;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final colors = dashboardColors(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(icon, size: 20, color: colors.textMuted),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: colors.textMuted,
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 2),
              Directionality(
                textDirection: TextDirection.ltr,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: SelectableText(
                    value,
                    textAlign: TextAlign.left,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: colors.textPrimary,
                          letterSpacing: 0.2,
                        ),
                  ),
                ),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: actionTooltip,
          onPressed: onAction,
          icon: Icon(actionIcon, size: 18, color: colors.textMuted),
        ),
      ],
    );
  }
}

class _ThemeOptionTile extends StatelessWidget {
  const _ThemeOptionTile({
    required this.value,
    required this.groupValue,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onChanged,
  });

  final ThemeMode value;
  final ThemeMode groupValue;
  final IconData icon;
  final String title;
  final String subtitle;
  final ValueChanged<ThemeMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = dashboardColors(context);
    final selected = value == groupValue;
    final primary = Theme.of(context).colorScheme.primary;

    return InkWell(
      onTap: () => onChanged(value),
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Icon(
              icon,
              size: 22,
              color: selected ? primary : colors.textMuted,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: colors.textMuted,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              selected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_off_rounded,
              color: selected ? primary : colors.textMuted,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = dashboardColors(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: isDark ? colors.cardElevated : colors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: colors.border.withValues(alpha: isDark ? 0.9 : 0.75),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: colors.textPrimary,
                  ),
            ),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }
}
