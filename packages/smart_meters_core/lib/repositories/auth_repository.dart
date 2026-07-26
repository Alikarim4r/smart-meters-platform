import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

class AuthRepository {
  AuthRepository(this._client);

  final SupabaseClient _client;
  static const _authTimeout = Duration(seconds: 20);

  Session? get currentSession => _client.auth.currentSession;

  User? get currentUser => _client.auth.currentUser;

  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    await _client.auth
        .signInWithPassword(
          email: email.trim(),
          password: password,
        )
        .timeout(_authTimeout);
  }

  /// Self-registration. Profile is created pending via `handle_new_user`.
  Future<void> signUpWithEmail({
    required String email,
    required String password,
    required String fullName,
    String requestedRole = 'technician_request',
  }) async {
    await _client.auth
        .signUp(
          email: email.trim(),
          password: password,
          data: {
            'full_name': fullName.trim(),
            'requested_role': requestedRole,
          },
        )
        .timeout(_authTimeout);
  }

  Future<void> signOut() async {
    await _client.auth.signOut().timeout(const Duration(seconds: 10));
  }

  Future<void> updatePassword(String newPassword) async {
    await _client.auth
        .updateUser(UserAttributes(password: newPassword))
        .timeout(_authTimeout);
  }
}
