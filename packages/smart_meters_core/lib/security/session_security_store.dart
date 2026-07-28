import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Per-app preferences for stay-signed-in and biometric unlock.
class SessionSecurityStore {
  SessionSecurityStore._(this._appKey);

  static SessionSecurityStore? _instance;
  static String? _configuredAppKey;

  /// Call once from [bootstrapSupabase] before any reads.
  static void configure(String appKey) {
    final key = appKey.trim();
    if (key.isEmpty) {
      throw ArgumentError('appKey must not be empty');
    }
    if (_configuredAppKey == key && _instance != null) {
      return;
    }
    _configuredAppKey = key;
    _instance = SessionSecurityStore._(key);
  }

  static SessionSecurityStore get instance {
    final current = _instance;
    if (current == null) {
      throw StateError(
        'SessionSecurityStore.configure(appKey) must run before use.',
      );
    }
    return current;
  }

  final String _appKey;
  final FlutterSecureStorage _secure = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    mOptions: MacOsOptions(
      useDataProtectionKeyChain: false,
    ),
  );

  bool staySignedIn = true;
  bool biometricEnabled = false;
  String? savedEmail;

  String get _prefsStay => 'session.$_appKey.stay_signed_in';
  String get _prefsBio => 'session.$_appKey.biometric_enabled';
  String get _secureEmail => 'session.$_appKey.email';
  String get _securePassword => 'session.$_appKey.password';

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    staySignedIn = prefs.getBool(_prefsStay) ?? true;
    biometricEnabled = prefs.getBool(_prefsBio) ?? false;
    savedEmail = await _safeRead(_secureEmail);
  }

  Future<void> setStaySignedIn(bool value) async {
    staySignedIn = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsStay, value);
    if (!value) {
      await setBiometricEnabled(false);
      await clearCredentials();
    }
  }

  Future<void> setBiometricEnabled(bool value) async {
    biometricEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsBio, value);
    if (!value) {
      await clearCredentials();
    }
  }

  Future<bool> get hasStoredCredentials async {
    final email = await _safeRead(_secureEmail);
    final password = await _safeRead(_securePassword);
    return email != null &&
        email.isNotEmpty &&
        password != null &&
        password.isNotEmpty;
  }

  Future<void> saveCredentials({
    required String email,
    required String password,
  }) async {
    savedEmail = email.trim();
    await _safeWrite(_secureEmail, savedEmail!);
    await _safeWrite(_securePassword, password);
  }

  Future<({String email, String password})?> readCredentials() async {
    final email = await _safeRead(_secureEmail);
    final password = await _safeRead(_securePassword);
    if (email == null ||
        email.isEmpty ||
        password == null ||
        password.isEmpty) {
      return null;
    }
    return (email: email, password: password);
  }

  Future<void> clearCredentials() async {
    savedEmail = null;
    await _safeDelete(_secureEmail);
    await _safeDelete(_securePassword);
  }

  /// Keychain / secure-storage can throw on macOS when the user cancels the
  /// system prompt (error -128). Never let that crash app bootstrap.
  Future<String?> _safeRead(String key) async {
    try {
      return await _secure.read(key: key);
    } catch (_) {
      return null;
    }
  }

  Future<void> _safeWrite(String key, String value) async {
    try {
      await _secure.write(key: key, value: value);
    } catch (_) {}
  }

  Future<void> _safeDelete(String key) async {
    try {
      await _secure.delete(key: key);
    } catch (_) {}
  }
}
