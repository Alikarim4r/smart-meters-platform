import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../security/biometric_auth_service.dart';
import '../security/session_security_store.dart';

final biometricAuthServiceProvider = Provider<BiometricAuthService>((ref) {
  return BiometricAuthService();
});

class SessionSecurityState {
  const SessionSecurityState({
    this.staySignedIn = true,
    this.biometricEnabled = false,
    this.canUseBiometrics = false,
    this.hasStoredCredentials = false,
    this.savedEmail,
    this.biometricLabel = 'Biometrics',
    this.unlocked = false,
    this.isReady = false,
  });

  final bool staySignedIn;
  final bool biometricEnabled;
  final bool canUseBiometrics;
  final bool hasStoredCredentials;
  final String? savedEmail;
  final String biometricLabel;

  /// True after biometric/device unlock for this process, or when biometrics off.
  final bool unlocked;
  final bool isReady;

  /// True when a live session must pass biometrics before the app home.
  bool get requiresUnlock => biometricEnabled && canUseBiometrics && !unlocked;

  SessionSecurityState copyWith({
    bool? staySignedIn,
    bool? biometricEnabled,
    bool? canUseBiometrics,
    bool? hasStoredCredentials,
    String? savedEmail,
    String? biometricLabel,
    bool? unlocked,
    bool? isReady,
    bool clearSavedEmail = false,
  }) {
    return SessionSecurityState(
      staySignedIn: staySignedIn ?? this.staySignedIn,
      biometricEnabled: biometricEnabled ?? this.biometricEnabled,
      canUseBiometrics: canUseBiometrics ?? this.canUseBiometrics,
      hasStoredCredentials: hasStoredCredentials ?? this.hasStoredCredentials,
      savedEmail: clearSavedEmail ? null : (savedEmail ?? this.savedEmail),
      biometricLabel: biometricLabel ?? this.biometricLabel,
      unlocked: unlocked ?? this.unlocked,
      isReady: isReady ?? this.isReady,
    );
  }
}

class SessionSecurityNotifier extends StateNotifier<SessionSecurityState> {
  SessionSecurityNotifier(this._bio) : super(const SessionSecurityState()) {
    _bootstrap();
  }

  final BiometricAuthService _bio;
  final SessionSecurityStore _store = SessionSecurityStore.instance;

  Future<void> _bootstrap() async {
    await _store.load();
    final canUse = await _bio.canUseBiometrics();
    final hasCreds = await _store.hasStoredCredentials;
    final label = await _bio.preferredLabel(isArabic: false);
    // Gate only applies once a restored session is present (AuthGate checks session).
    state = SessionSecurityState(
      staySignedIn: _store.staySignedIn,
      biometricEnabled: _store.biometricEnabled && canUse,
      canUseBiometrics: canUse,
      hasStoredCredentials: hasCreds,
      savedEmail: _store.savedEmail,
      biometricLabel: label,
      unlocked: !(_store.biometricEnabled && canUse),
      isReady: true,
    );
  }

  Future<void> refreshBiometricLabel({required bool isArabic}) async {
    final label = await _bio.preferredLabel(isArabic: isArabic);
    state = state.copyWith(biometricLabel: label);
  }

  Future<void> setStaySignedIn(bool value) async {
    await _store.setStaySignedIn(value);
    state = state.copyWith(
      staySignedIn: _store.staySignedIn,
      biometricEnabled: _store.biometricEnabled,
      hasStoredCredentials: await _store.hasStoredCredentials,
      savedEmail: _store.savedEmail,
      clearSavedEmail: _store.savedEmail == null,
    );
  }

  Future<void> setBiometricEnabled(bool value) async {
    if (value && !state.canUseBiometrics) return;
    await _store.setBiometricEnabled(value);
    state = state.copyWith(
      biometricEnabled: _store.biometricEnabled,
      hasStoredCredentials: await _store.hasStoredCredentials,
      savedEmail: _store.savedEmail,
      clearSavedEmail: _store.savedEmail == null,
      unlocked: value ? state.unlocked : true,
    );
  }

  Future<bool> authenticate({required String reason}) {
    return _bio.authenticate(localizedReason: reason);
  }

  Future<void> markUnlocked() async {
    state = state.copyWith(unlocked: true);
  }

  Future<void> lockIfNeeded() async {
    if (state.biometricEnabled &&
        state.canUseBiometrics &&
        state.hasStoredCredentials) {
      state = state.copyWith(unlocked: false);
    }
  }

  /// After password login: keep existing biometric prefs; refresh stored password if enabled.
  Future<void> onPasswordSignInSuccess({
    required String email,
    required String password,
    required bool staySignedIn,
  }) async {
    await _store.setStaySignedIn(staySignedIn);
    if (_store.biometricEnabled && state.canUseBiometrics) {
      await _store.saveCredentials(email: email, password: password);
    }
    state = SessionSecurityState(
      staySignedIn: _store.staySignedIn,
      biometricEnabled: _store.biometricEnabled && state.canUseBiometrics,
      canUseBiometrics: state.canUseBiometrics,
      hasStoredCredentials: await _store.hasStoredCredentials,
      savedEmail: _store.savedEmail,
      biometricLabel: state.biometricLabel,
      unlocked: true,
      isReady: true,
    );
  }

  /// Enable biometrics from Settings. Returns null on success, else error message.
  Future<String?> enableBiometricFromSettings({
    required String email,
    required String password,
    required String reason,
  }) async {
    if (!state.canUseBiometrics) {
      return 'Biometrics unavailable on this device.';
    }

    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
    } on AuthException catch (e) {
      final invalid = e.message.toLowerCase().contains('invalid');
      return invalid ? 'Invalid password.' : e.message;
    } catch (_) {
      return 'Could not verify password.';
    }

    // Run biometric prompt without touching Riverpod mid-flight.
    final ok = await authenticate(reason: reason);
    if (!ok) {
      return 'Biometric confirmation was cancelled or failed.';
    }

    await _store.setStaySignedIn(true);
    await _store.setBiometricEnabled(true);
    await _store.saveCredentials(email: email, password: password);

    // Defer provider notify until after the biometric Activity has resumed.
    await Future<void>.delayed(const Duration(milliseconds: 16));
    state = SessionSecurityState(
      staySignedIn: true,
      biometricEnabled: true,
      canUseBiometrics: state.canUseBiometrics,
      hasStoredCredentials: true,
      savedEmail: email.trim(),
      biometricLabel: state.biometricLabel,
      unlocked: true,
      isReady: true,
    );
    return null;
  }

  Future<({String email, String password})?> readCredentials() {
    return _store.readCredentials();
  }

  /// Clears session preferences used at next cold start; keeps staySignedIn flag.
  Future<void> onSignOut({bool forgetDevice = false}) async {
    if (forgetDevice) {
      await _store.setBiometricEnabled(false);
      await _store.clearCredentials();
      await _store.setStaySignedIn(false);
    }
    state = state.copyWith(
      staySignedIn: _store.staySignedIn,
      biometricEnabled: _store.biometricEnabled,
      hasStoredCredentials: await _store.hasStoredCredentials,
      savedEmail: _store.savedEmail,
      clearSavedEmail: _store.savedEmail == null,
      // Allow password login screen after explicit sign-out.
      unlocked: true,
    );
  }

  /// Opens password form while keeping stored biometric credentials.
  Future<void> preferPasswordLogin() async {
    state = state.copyWith(unlocked: true);
  }
}

final sessionSecurityProvider =
    StateNotifierProvider<SessionSecurityNotifier, SessionSecurityState>((ref) {
      return SessionSecurityNotifier(ref.watch(biometricAuthServiceProvider));
    });
