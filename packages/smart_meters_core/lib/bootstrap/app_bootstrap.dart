import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';
import '../models/enums.dart';
import '../models/profile.dart';
import '../providers/auth_provider.dart';
import '../providers/supabase_provider.dart';
import '../ui/demo_branding.dart';

// dart:async for Future.timeout used by site-access gate
import 'dart:async';

Future<void> bootstrapSupabase({
  SupabaseConfig config = SupabaseConfig.fromEnvironment,
}) async {
  config.validate();
  await Supabase.initialize(url: config.url, publishableKey: config.anonKey);
}

typedef AppBuilder = Widget Function(BuildContext context);

/// Login → approval status → role gate → optional site access → home.
class AuthGate extends ConsumerWidget {
  const AuthGate({
    super.key,
    required this.appTitle,
    required this.allowedForProfile,
    required this.homeBuilder,
    this.accessDeniedMessage,
    @Deprecated('Staging hints are no longer shown on login.') this.stagingHint,
    this.brandMarkAsset = BrandMarkAssets.dashboard,
    this.siteAccessRequirement = SiteAccessRequirement.none,
    this.allowSelfRegistration = false,
    this.locale,
    this.onLocaleChanged,
  });

  final String appTitle;
  final bool Function(Profile profile) allowedForProfile;
  final AppBuilder homeBuilder;
  final String? accessDeniedMessage;

  /// Ignored — kept for call-site compatibility.
  @Deprecated('Staging hints are no longer shown on login.')
  final String? stagingHint;

  /// Package asset path for the login METERS mark.
  final String brandMarkAsset;

  /// When [read] or [write], approved users without site assignment see a
  /// dedicated screen instead of the app home.
  final SiteAccessRequirement siteAccessRequirement;

  /// When true, login screen offers technician self-registration (pending approval).
  final bool allowSelfRegistration;

  /// Current UI locale for the login language toggle (E / ع).
  final Locale? locale;

  /// Called when the user picks English or Arabic on the login screen.
  final ValueChanged<Locale>? onLocaleChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);

    if (auth.isLoadingProfile) {
      return const Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (!auth.isAuthenticated || auth.profile == null) {
      return LoginScreen(
        appTitle: appTitle,
        brandMarkAsset: brandMarkAsset,
        allowSelfRegistration: allowSelfRegistration,
        locale: locale,
        onLocaleChanged: onLocaleChanged,
      );
    }

    final profile = auth.profile!;
    final approvalScreen = _approvalStatusScreen(
      profile: profile,
      onSignOut: () => ref.read(authProvider.notifier).signOut(),
    );
    if (approvalScreen != null) {
      return approvalScreen;
    }

    if (!allowedForProfile(profile)) {
      return _AccessDeniedScreen(
        message:
            accessDeniedMessage ??
            'Your role (${profile.role.dbValue}) cannot access $appTitle.',
        onSignOut: () => ref.read(authProvider.notifier).signOut(),
      );
    }

    if (siteAccessRequirement == SiteAccessRequirement.none ||
        profile.isSuperAdmin) {
      return homeBuilder(context);
    }

    return _SiteAccessGate(
      profile: profile,
      requirement: siteAccessRequirement,
      onSignOut: () => ref.read(authProvider.notifier).signOut(),
      homeBuilder: homeBuilder,
    );
  }
}

/// Returns a blocking screen when the user may sign in but cannot use the app.
Widget? _approvalStatusScreen({
  required Profile profile,
  required VoidCallback onSignOut,
}) {
  switch (profile.approvalStatus) {
    case ApprovalStatus.pending:
      return _AccountStatusScreen(
        title: 'Account pending',
        message: 'Your account is pending admin approval.',
        onSignOut: onSignOut,
      );
    case ApprovalStatus.rejected:
      return _AccountStatusScreen(
        title: 'Account rejected',
        message: 'Your account request was rejected.',
        onSignOut: onSignOut,
      );
    case ApprovalStatus.suspended:
      return _AccountStatusScreen(
        title: 'Account suspended',
        message: 'Your account is suspended. Contact admin.',
        onSignOut: onSignOut,
      );
    case ApprovalStatus.approved:
      if (!profile.isActive) {
        return _AccountStatusScreen(
          title: 'Account suspended',
          message: 'Your account is suspended. Contact admin.',
          onSignOut: onSignOut,
        );
      }
      return null;
  }
}

class _SiteAccessGate extends ConsumerStatefulWidget {
  const _SiteAccessGate({
    required this.profile,
    required this.requirement,
    required this.onSignOut,
    required this.homeBuilder,
  });

  final Profile profile;
  final SiteAccessRequirement requirement;
  final VoidCallback onSignOut;
  final AppBuilder homeBuilder;

  @override
  ConsumerState<_SiteAccessGate> createState() => _SiteAccessGateState();
}

class _SiteAccessGateState extends ConsumerState<_SiteAccessGate> {
  late Future<bool> _hasSitesFuture;

  @override
  void initState() {
    super.initState();
    _hasSitesFuture = _loadHasSites();
  }

  Future<bool> _loadHasSites() async {
    final repo = ref.read(siteRepositoryProvider);
    final sites = widget.requirement == SiteAccessRequirement.write
        ? await repo
              .getAccessibleSites(widget.profile)
              .timeout(const Duration(seconds: 12))
        : await repo
              .getReadableSites(widget.profile)
              .timeout(const Duration(seconds: 12));
    return sites.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _hasSitesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return _AccountStatusScreen(
            title: 'Could not load sites',
            message:
                'Timed out or failed while checking site access. Check your connection and try again.',
            onSignOut: widget.onSignOut,
          );
        }

        if (snapshot.data != true) {
          return _AccountStatusScreen(
            title: 'No sites assigned',
            message: 'No sites assigned. Contact admin.',
            onSignOut: widget.onSignOut,
          );
        }

        return widget.homeBuilder(context);
      },
    );
  }
}

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({
    super.key,
    required this.appTitle,
    this.brandMarkAsset = BrandMarkAssets.dashboard,
    this.allowSelfRegistration = false,
    this.locale,
    this.onLocaleChanged,
  });

  final String appTitle;
  final String brandMarkAsset;
  final bool allowSelfRegistration;
  final Locale? locale;
  final ValueChanged<Locale>? onLocaleChanged;

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _registerMode = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_registerMode) {
      await ref.read(authProvider.notifier).signUp(
            email: _emailController.text.trim(),
            password: _passwordController.text,
            fullName: _nameController.text.trim(),
          );
      return;
    }

    await ref.read(authProvider.notifier).signIn(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final theme = Theme.of(context);
    final locale = widget.locale ?? Localizations.localeOf(context);
    final isAr = locale.languageCode == 'ar';
    final registering = widget.allowSelfRegistration && _registerMode;

    final subtitle = registering
        ? (isAr
              ? 'أنشئ حساب فني. سيظهر لدى المشرف للموافقة قبل الدخول.'
              : 'Create a technician account. An admin must approve before access.')
        : (isAr ? 'سجّل الدخول بحسابك للمتابعة.' : 'Sign in to your account to continue.');

    return DemoLoginPanel(
      title: widget.appTitle,
      subtitle: subtitle,
      brandMark: AppBrandMark(assetPath: widget.brandMarkAsset, size: 72),
      locale: locale,
      onLocaleChanged: widget.onLocaleChanged,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (registering) ...[
              TextFormField(
                controller: _nameController,
                textInputAction: TextInputAction.next,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: isAr ? 'الاسم الكامل' : 'Full name',
                  prefixIcon: const Icon(Icons.person_outline_rounded),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return isAr ? 'الاسم مطلوب' : 'Name is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),
            ],
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autocorrect: false,
              enableSuggestions: false,
              autofillHints: const [
                AutofillHints.email,
                AutofillHints.username,
              ],
              decoration: InputDecoration(
                labelText: isAr ? 'البريد الإلكتروني' : 'Email',
                prefixIcon: const Icon(Icons.mail_outline_rounded),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return isAr ? 'البريد الإلكتروني مطلوب' : 'Email is required';
                }
                return null;
              },
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              textInputAction: TextInputAction.done,
              autofillHints: registering
                  ? const [AutofillHints.newPassword]
                  : const [AutofillHints.password],
              decoration: InputDecoration(
                labelText: isAr ? 'كلمة المرور' : 'Password',
                prefixIcon: const Icon(Icons.lock_outline_rounded),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                  onPressed: () {
                    setState(() => _obscurePassword = !_obscurePassword);
                  },
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return isAr ? 'كلمة المرور مطلوبة' : 'Password is required';
                }
                if (registering && value.length < 6) {
                  return isAr
                      ? 'كلمة المرور يجب ألا تقل عن 6 أحرف'
                      : 'Password must be at least 6 characters';
                }
                return null;
              },
              onFieldSubmitted: (_) => _submit(),
            ),
            if (auth.errorMessage != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.error.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: theme.colorScheme.error.withValues(alpha: 0.35),
                  ),
                ),
                child: Text(
                  auth.errorMessage!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.error,
                    height: 1.35,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 22),
            FilledButton(
              onPressed: auth.isLoadingProfile ? null : _submit,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: auth.isLoadingProfile
                  ? SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: theme.colorScheme.onPrimary,
                      ),
                    )
                  : Text(
                      registering
                          ? (isAr ? 'إنشاء حساب' : 'Create account')
                          : (isAr ? 'تسجيل الدخول' : 'Sign in'),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
            ),
            if (widget.allowSelfRegistration) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: auth.isLoadingProfile
                    ? null
                    : () => setState(() => _registerMode = !_registerMode),
                child: Text(
                  registering
                      ? (isAr
                            ? 'لديك حساب؟ سجّل الدخول'
                            : 'Have an account? Sign in')
                      : (isAr
                            ? 'فني جديد؟ طلب تسجيل'
                            : 'New technician? Request access'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AccountStatusScreen extends StatelessWidget {
  const _AccountStatusScreen({
    required this.title,
    required this.message,
    required this.onSignOut,
  });

  final String title;
  final String message;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(message, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                OutlinedButton(
                  onPressed: onSignOut,
                  child: const Text('Sign out'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AccessDeniedScreen extends StatelessWidget {
  const _AccessDeniedScreen({required this.message, required this.onSignOut});

  final String message;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: onSignOut,
                child: const Text('Sign out'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
