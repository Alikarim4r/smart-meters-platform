import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/profile.dart';
import 'session_security_provider.dart';
import 'supabase_provider.dart';

class AuthState {
  const AuthState({
    this.session,
    this.profile,
    this.isLoadingProfile = false,
    this.errorMessage,
    this.infoMessage,
  });

  final Session? session;
  final Profile? profile;
  final bool isLoadingProfile;
  final String? errorMessage;
  /// Non-error guidance (e.g. registration submitted / await approval).
  final String? infoMessage;

  bool get isAuthenticated => session != null;

  AuthState copyWith({
    Session? session,
    Profile? profile,
    bool? isLoadingProfile,
    String? errorMessage,
    String? infoMessage,
    bool clearError = false,
    bool clearInfo = false,
    bool clearProfile = false,
  }) {
    return AuthState(
      session: session ?? this.session,
      profile: clearProfile ? null : (profile ?? this.profile),
      isLoadingProfile: isLoadingProfile ?? this.isLoadingProfile,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      infoMessage: clearInfo ? null : (infoMessage ?? this.infoMessage),
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier(this._ref) : super(const AuthState()) {
    _bootstrap();
  }

  final Ref _ref;

  Future<void> _bootstrap() async {
    final authRepo = _ref.read(authRepositoryProvider);
    final session = authRepo.currentSession;
    if (session == null) {
      return;
    }

    state = state.copyWith(session: session, isLoadingProfile: true);
    await _loadProfile(session.user.id);
  }

  Future<void> signIn({required String email, required String password}) async {
    state = state.copyWith(
      clearError: true,
      clearInfo: true,
      isLoadingProfile: true,
    );

    try {
      final authRepo = _ref.read(authRepositoryProvider);
      await authRepo.signInWithEmail(email: email, password: password);
      final session = authRepo.currentSession;
      if (session == null) {
        throw const AuthException(
          'Sign-in succeeded but no session was created.',
        );
      }

      state = state.copyWith(session: session);
      await _loadProfile(session.user.id);
    } on AuthException catch (error) {
      final lower = error.message.toLowerCase();
      final message = lower.contains('invalid')
          ? 'Invalid email or password.'
          : (lower.contains('confirm') || lower.contains('verified')
                ? 'Confirm your email first, then sign in. An admin must still approve the account.'
                : error.message);
      state = state.copyWith(
        clearProfile: true,
        isLoadingProfile: false,
        errorMessage: message,
      );
    } on TimeoutException {
      state = state.copyWith(
        clearProfile: true,
        isLoadingProfile: false,
        errorMessage: 'Connection timed out. Check your network and try again.',
      );
    } catch (error) {
      state = state.copyWith(
        clearProfile: true,
        isLoadingProfile: false,
        errorMessage: 'Sign-in failed. Check credentials and try again.',
      );
    }
  }

  Future<void> signUp({
    required String email,
    required String password,
    required String fullName,
    String requestedRole = 'technician_request',
  }) async {
    state = state.copyWith(
      clearError: true,
      clearInfo: true,
      isLoadingProfile: true,
    );
    try {
      final authRepo = _ref.read(authRepositoryProvider);
      await authRepo.signUpWithEmail(
        email: email,
        password: password,
        fullName: fullName,
        requestedRole: requestedRole,
      );
      final session = authRepo.currentSession;
      if (session == null) {
        // Email confirmation may be required — treat as success waiting state.
        state = state.copyWith(
          isLoadingProfile: false,
          clearError: true,
          infoMessage:
              'Registration submitted. Confirm email if required, then wait for admin approval before signing in.',
        );
        return;
      }
      state = state.copyWith(session: session);
      await _loadProfile(session.user.id);
    } on AuthException catch (error) {
      final lower = error.message.toLowerCase();
      final message = lower.contains('rate limit') ||
              lower.contains('over_email') ||
              lower.contains('email rate')
          ? 'Registration temporarily limited by email sending. Try again in a few minutes, or ask an admin to create the account.'
          : (lower.contains('already') || lower.contains('registered')
                ? 'This email is already registered. Sign in or use another email.'
                : error.message);
      state = state.copyWith(
        clearProfile: true,
        isLoadingProfile: false,
        errorMessage: message,
      );
    } catch (_) {
      state = state.copyWith(
        clearProfile: true,
        isLoadingProfile: false,
        errorMessage: 'Registration failed. Try again.',
      );
    }
  }

  Future<void> signOut() async {
    await _ref.read(authRepositoryProvider).signOut();
    try {
      await _ref.read(sessionSecurityProvider.notifier).onSignOut();
    } catch (_) {}
    state = const AuthState();
  }

  Future<void> updatePassword(String newPassword) async {
    try {
      await _ref.read(authRepositoryProvider).updatePassword(newPassword);
    } on AuthException {
      rethrow;
    } catch (_) {
      throw const AuthException('Could not update password. Try again.');
    }
  }

  /// Reloads the signed-in profile from the server.
  Future<void> refreshProfile() async {
    final userId = state.session?.user.id ?? state.profile?.id;
    if (userId == null) return;
    await _loadProfile(userId);
  }

  /// Updates Entry-facing profile fields and refreshes auth state.
  Future<Profile> updateOwnProfile({
    required String fullName,
    String? phone,
    String? companyName,
    String? avatarPath,
    bool clearAvatarPath = false,
  }) async {
    final userId = state.profile?.id;
    if (userId == null) {
      throw const AuthException('Not signed in.');
    }
    final updated = await _ref
        .read(profileRepositoryProvider)
        .updateOwnProfile(
          userId: userId,
          fullName: fullName,
          phone: phone,
          companyName: companyName,
          avatarPath: avatarPath,
          clearAvatarPath: clearAvatarPath,
        );
    state = state.copyWith(profile: updated, clearError: true);
    return updated;
  }

  Future<void> _loadProfile(String userId) async {
    try {
      final profile = await _ref
          .read(profileRepositoryProvider)
          .getProfile(userId)
          .timeout(const Duration(seconds: 12));
      state = state.copyWith(
        profile: profile,
        isLoadingProfile: false,
        clearError: true,
        clearInfo: true,
      );
    } catch (error) {
      // Keep the session so the user can retry / wait for approval screens.
      // Signing out here made new registrations look completely broken.
      state = state.copyWith(
        isLoadingProfile: false,
        errorMessage: error.toString().contains('Timeout')
            ? 'Connection timed out. Check your network and tap retry.'
            : 'Could not load profile for this account. Pull to refresh or try again.',
      );
    }
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref);
});
