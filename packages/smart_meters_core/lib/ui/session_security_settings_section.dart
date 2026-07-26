import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/auth_provider.dart';
import '../providers/session_security_provider.dart';

/// In-app settings: stay signed in + biometric unlock (fingerprint / face).
///
/// Biometric enable uses a dedicated dialog (not [Switch.onChanged]) to avoid
/// Flutter's `_dependents.isEmpty` assertion when opening routes from a Switch.
class SessionSecuritySettingsSection extends ConsumerStatefulWidget {
  const SessionSecuritySettingsSection({
    super.key,
    required this.locale,
    this.dense = false,
  });

  final Locale locale;
  final bool dense;

  @override
  ConsumerState<SessionSecuritySettingsSection> createState() =>
      _SessionSecuritySettingsSectionState();
}

class _SessionSecuritySettingsSectionState
    extends ConsumerState<SessionSecuritySettingsSection> {
  bool _busy = false;
  String? _statusMessage;
  bool _statusIsError = false;

  bool get _isAr => widget.locale.languageCode == 'ar';

  void _setStatus(String message, {required bool isError}) {
    if (!mounted) return;
    setState(() {
      _statusMessage = message;
      _statusIsError = isError;
    });
  }

  Future<void> _onStaySignedInChanged(bool value) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _statusMessage = null;
    });
    try {
      await ref.read(sessionSecurityProvider.notifier).setStaySignedIn(value);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _disableBiometric() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _statusMessage = null;
    });
    try {
      await ref.read(sessionSecurityProvider.notifier).setBiometricEnabled(false);
      _setStatus(
        _isAr ? 'تم إيقاف الدخول بالبصمة/الوجه' : 'Biometric sign-in disabled',
        isError: false,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _enableBiometric() async {
    if (_busy) return;
    final security = ref.read(sessionSecurityProvider);
    final isAr = _isAr;
    if (!security.canUseBiometrics) {
      _setStatus(
        isAr
            ? 'هذا الجهاز لا يدعم البصمة أو الوجه'
            : 'This device does not support biometrics',
        isError: true,
      );
      return;
    }

    final email = ref.read(authProvider).profile?.email.trim();
    if (email == null || email.isEmpty) {
      _setStatus(
        isAr ? 'لا يمكن قراءة البريد' : 'Could not read account email',
        isError: true,
      );
      return;
    }

    await ref
        .read(sessionSecurityProvider.notifier)
        .refreshBiometricLabel(isArabic: isAr);
    if (!mounted) return;

    final label = ref.read(sessionSecurityProvider).biometricLabel;
    final result = await showDialog<Object>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: false,
      builder: (dialogContext) {
        return _EnableBiometricDialog(
          email: email,
          isArabic: isAr,
          biometricLabel: label,
          onEnable: (password) {
            return ref
                .read(sessionSecurityProvider.notifier)
                .enableBiometricFromSettings(
                  email: email,
                  password: password,
                  reason: isAr
                      ? 'أكد $label للتفعيل'
                      : 'Confirm $label to enable',
                );
          },
        );
      },
    );

    if (!mounted) return;
    if (result == null) {
      // Dismissed.
      return;
    }
    if (result == true) {
      _setStatus(
        isAr ? 'تم تفعيل الدخول بالبصمة/الوجه' : 'Biometric sign-in enabled',
        isError: false,
      );
      return;
    }
    if (result is String) {
      _setStatus(_localizeError(result, isAr), isError: true);
    }
  }

  String _localizeError(String raw, bool isAr) {
    final lower = raw.toLowerCase();
    if (lower.contains('invalid')) {
      return isAr ? 'كلمة المرور غير صحيحة' : 'Invalid password.';
    }
    if (lower.contains('cancel') || lower.contains('failed')) {
      return isAr
          ? 'تم إلغاء التحقق البيومتري أو فشل'
          : 'Biometric confirmation was cancelled or failed.';
    }
    if (lower.contains('unavailable')) {
      return isAr
          ? 'البصمة/الوجه غير متاحة على هذا الجهاز'
          : 'Biometrics unavailable on this device.';
    }
    return raw;
  }

  @override
  Widget build(BuildContext context) {
    final security = ref.watch(sessionSecurityProvider);
    final theme = Theme.of(context);
    final isAr = _isAr;
    final padding = widget.dense ? EdgeInsets.zero : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SwitchListTile(
          contentPadding: padding,
          dense: widget.dense,
          secondary: const Icon(Icons.cloud_done_outlined),
          title: Text(isAr ? 'البقاء قيد الاتصال' : 'Stay signed in'),
          subtitle: Text(
            isAr
                ? 'إبقاء الجلسة بعد إغلاق التطبيق'
                : 'Keep your session after closing the app',
          ),
          value: security.staySignedIn,
          onChanged: _busy ? null : _onStaySignedInChanged,
        ),
        if (!security.canUseBiometrics)
          ListTile(
            contentPadding: padding,
            dense: widget.dense,
            leading: const Icon(Icons.fingerprint_rounded),
            title: Text(
              isAr ? 'البصمة / الوجه غير متاحة' : 'Biometrics unavailable',
            ),
            subtitle: Text(
              isAr
                  ? 'الجهاز لا يدعم البصمة أو Face ID'
                  : 'This device has no fingerprint or Face ID',
            ),
          )
        else if (security.biometricEnabled)
          ListTile(
            contentPadding: padding,
            dense: widget.dense,
            leading: const Icon(Icons.fingerprint_rounded),
            title: Text(
              isAr
                  ? 'الدخول عبر ${security.biometricLabel}'
                  : 'Sign in with ${security.biometricLabel}',
            ),
            subtitle: Text(
              isAr ? 'مفعّل — اضغط لإيقافه' : 'Enabled — tap to turn off',
            ),
            trailing: _busy
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(Icons.toggle_on, color: theme.colorScheme.primary, size: 36),
            onTap: _busy ? null : _disableBiometric,
          )
        else
          ListTile(
            contentPadding: padding,
            dense: widget.dense,
            leading: const Icon(Icons.fingerprint_rounded),
            title: Text(
              isAr
                  ? 'تفعيل ${security.biometricLabel}'
                  : 'Enable ${security.biometricLabel}',
            ),
            subtitle: Text(
              isAr
                  ? 'بصمة الإصبع أو التعرف على الوجه'
                  : 'Fingerprint or face unlock after sign-in',
            ),
            trailing: _busy
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    Icons.toggle_off_outlined,
                    color: theme.colorScheme.outline,
                    size: 36,
                  ),
            onTap: _busy ? null : _enableBiometric,
          ),
        if (_statusMessage != null) ...[
          const SizedBox(height: 6),
          Text(
            _statusMessage!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: _statusIsError
                  ? theme.colorScheme.error
                  : theme.colorScheme.primary,
              height: 1.3,
            ),
          ),
        ],
      ],
    );
  }
}

/// Self-contained enable flow so password + biometric never run from a Switch.
class _EnableBiometricDialog extends StatefulWidget {
  const _EnableBiometricDialog({
    required this.email,
    required this.isArabic,
    required this.biometricLabel,
    required this.onEnable,
  });

  final String email;
  final bool isArabic;
  final String biometricLabel;
  final Future<String?> Function(String password) onEnable;

  @override
  State<_EnableBiometricDialog> createState() => _EnableBiometricDialogState();
}

class _EnableBiometricDialogState extends State<_EnableBiometricDialog> {
  final _controller = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _busy = true;
      _error = null;
    });

    final password = _controller.text;
    // Yield so this dialog finishes rebuilding before system biometric UI.
    await Future<void>.delayed(Duration.zero);
    if (!mounted) return;

    final error = await widget.onEnable(password);
    if (!mounted) return;

    if (error == null) {
      // Pop on next frame after biometric Activity returns — avoids dependents crash.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).pop(true);
      });
      return;
    }

    setState(() {
      _busy = false;
      _error = error;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isAr = widget.isArabic;
    return AlertDialog(
      title: Text(
        isAr
            ? 'تفعيل ${widget.biometricLabel}'
            : 'Enable ${widget.biometricLabel}',
      ),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              isAr
                  ? 'أدخل كلمة المرور ثم أكّد بالبصمة أو الوجه.'
                  : 'Enter your password, then confirm with biometrics.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _controller,
              obscureText: true,
              enabled: !_busy,
              autofocus: true,
              decoration: InputDecoration(
                labelText: isAr ? 'كلمة المرور الحالية' : 'Current password',
              ),
              validator: (v) {
                if (v == null || v.isEmpty) {
                  return isAr ? 'مطلوبة' : 'Required';
                }
                return null;
              },
              onFieldSubmitted: (_) => _submit(),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: Text(isAr ? 'إلغاء' : 'Cancel'),
        ),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(isAr ? 'تفعيل' : 'Enable'),
        ),
      ],
    );
  }
}
