import 'dart:math';

import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_service.dart';

class AuthSession {
  const AuthSession({
    this.id,
    required this.method,
    required this.email,
    required this.displayName,
    this.photoUrl,
  });

  final int? id;
  final String method;
  final String email;
  final String displayName;
  final String? photoUrl;

  bool get isGoogle => method == 'google';
  bool get isGuest => method == 'guest';
  bool get isEmail => method == 'email';
}

/// Thrown when the backend refuses login (ban / suspend / deleted).
class AuthBlockedException implements Exception {
  AuthBlockedException(this.message);
  final String message;
  @override
  String toString() => message;
}

class AuthService {
  static const String _googleClientIdEnv = String.fromEnvironment(
    'GOOGLE_CLIENT_ID',
    defaultValue: '',
  );

  AuthService({required ApiService apiService, GoogleSignIn? googleSignIn})
      : _apiService = apiService,
        _googleSignIn = googleSignIn ??
            (_googleClientIdEnv.isNotEmpty
                ? GoogleSignIn(
                    scopes: const ['email', 'profile'],
                    serverClientId: _googleClientIdEnv,
                  )
                : GoogleSignIn(scopes: const ['email', 'profile']));

  static const String _methodKey = 'auth_method';
  static const String _idKey = 'auth_id';
  static const String _emailKey = 'auth_email';
  static const String _displayNameKey = 'auth_display_name';
  static const String _photoUrlKey = 'auth_photo_url';
  static const String _tokenKey = 'auth_token';
  static const String _deviceIdKey = 'auth_device_id';

  final ApiService _apiService;
  final GoogleSignIn _googleSignIn;

  Future<String> _deviceId() async {
    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString(_deviceIdKey);
    if (id == null || id.length < 16) {
      final rnd = Random.secure();
      id = List.generate(32, (_) => rnd.nextInt(16).toRadixString(16)).join();
      await prefs.setString(_deviceIdKey, id);
    }
    return id;
  }

  String _friendlyAuthError(Object e) {
    final raw = e.toString();
    final lower = raw.toLowerCase();
    if (lower.contains('banned')) {
      return 'This account is banned. Contact support if you believe this is a mistake.';
    }
    if (lower.contains('suspended')) {
      return 'This account is temporarily suspended. Try again later or contact support.';
    }
    if (lower.contains('deleted')) {
      return 'This account has been deleted by an administrator.';
    }
    if (lower.contains('session revoked')) {
      return 'Your session was ended (security). Please sign in again.';
    }
    if (lower.contains('invalid email or password') ||
        lower.contains('invalid email or password')) {
      return 'Invalid email or password.';
    }
    if (lower.contains('already exists')) {
      return 'An account with this email already exists. Sign in instead.';
    }
    if (lower.contains('403')) {
      return raw.replaceFirst(RegExp(r'^Exception:\s*'), '');
    }
    return raw.replaceFirst(RegExp(r'^Exception:\s*'), '');
  }

  /// Restore session only if the server still accepts the token.
  /// Banned / suspended / revoked sessions are cleared immediately.
  Future<AuthSession?> restoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    final method = prefs.getString(_methodKey);
    if (method == null || method.isEmpty) {
      return null;
    }

    final token = prefs.getString(_tokenKey);
    if (token == null || token.isEmpty) {
      await _clearLocalSession(keepDeviceId: true);
      return null;
    }

    _apiService.setAuthToken(token);
    try {
      final me = await _apiService.fetchMeStrict();
      if (me.isEmpty || me['id'] == null) {
        await signOut();
        return null;
      }
      if (me['email'] != null) {
        await prefs.setString(_emailKey, me['email'].toString());
      }
      if (me['display_name'] != null) {
        await prefs.setString(_displayNameKey, me['display_name'].toString());
      }
      if (me['id'] is num) {
        await prefs.setInt(_idKey, (me['id'] as num).toInt());
      }
      return AuthSession(
        id: prefs.getInt(_idKey),
        method: method,
        email: prefs.getString(_emailKey) ?? me['email']?.toString() ?? '',
        displayName: prefs.getString(_displayNameKey) ??
            me['display_name']?.toString() ??
            'Reader',
        photoUrl: prefs.getString(_photoUrlKey) ?? me['photo_url']?.toString(),
      );
    } on AuthBlockedException {
      await signOut();
      rethrow;
    } catch (e) {
      final msg = e.toString().toLowerCase();
      if (msg.contains('banned') ||
          msg.contains('suspended') ||
          msg.contains('deleted') ||
          msg.contains('403') ||
          msg.contains('401') ||
          msg.contains('revoked') ||
          msg.contains('expired')) {
        await signOut();
        if (msg.contains('banned') ||
            msg.contains('suspended') ||
            msg.contains('deleted')) {
          throw AuthBlockedException(_friendlyAuthError(e));
        }
        return null;
      }
      // Transient network error: keep local session for offline UI, token may still work later.
      final email = prefs.getString(_emailKey) ?? '';
      final displayName = prefs.getString(_displayNameKey) ?? email;
      if (email.isEmpty && method != 'guest') {
        return null;
      }
      return AuthSession(
        id: prefs.getInt(_idKey),
        method: method,
        email: email.isEmpty ? 'guest@novel.app' : email,
        displayName: displayName.isEmpty
            ? (method == 'guest' ? 'Guest' : email)
            : displayName,
        photoUrl: prefs.getString(_photoUrlKey),
      );
    }
  }

  Future<AuthSession> signInWithGoogle() async {
    final user = await _googleSignIn.signIn();
    if (user == null) {
      throw Exception('Google sign-in was cancelled.');
    }
    final auth = await user.authentication;
    if (auth.idToken == null && auth.accessToken == null) {
      throw Exception(
        'Google sign-in returned no token. Configure GOOGLE_CLIENT_ID when building the app.',
      );
    }
    try {
      final payload = await _apiService.verifyGoogleSignIn(
        idToken: auth.idToken,
        accessToken: auth.accessToken,
      );
      _apiService.setAuthToken(payload['token']?.toString());
      final session = AuthSession(
        id: payload['id'] is num ? (payload['id'] as num).toInt() : null,
        method: 'google',
        email: payload['email']?.toString() ?? user.email,
        displayName: payload['display_name']?.toString() ??
            user.displayName ??
            user.email,
        photoUrl: payload['photo_url']?.toString() ?? user.photoUrl,
      );
      await _persistSession(session);
      return session;
    } catch (e) {
      try {
        await _googleSignIn.signOut();
      } catch (_) {}
      throw Exception(_friendlyAuthError(e));
    }
  }

  /// Email + password. [mode] is `login` or `register`.
  Future<AuthSession> signInWithEmail(
    String email, {
    required String password,
    String mode = 'login',
    String? displayName,
  }) async {
    final normalized = email.trim().toLowerCase();
    if (normalized.isEmpty || !normalized.contains('@')) {
      throw Exception('Enter a valid email address.');
    }
    if (password.length < 6) {
      throw Exception('Password must be at least 6 characters.');
    }
    try {
      final payload = await _apiService.verifyEmailSignIn(
        normalized,
        password: password,
        mode: mode,
        displayName: displayName,
      );
      _apiService.setAuthToken(payload['token']?.toString());
      final session = AuthSession(
        id: payload['id'] is num ? (payload['id'] as num).toInt() : null,
        method: 'email',
        email: payload['email']?.toString() ?? normalized,
        displayName: payload['display_name']?.toString() ??
            normalized.split('@').first,
      );
      await _persistSession(session);
      return session;
    } catch (e) {
      throw Exception(_friendlyAuthError(e));
    }
  }

  Future<AuthSession> signInAsGuest() async {
    final deviceId = await _deviceId();
    try {
      final payload = await _apiService.verifyGuestSignIn(deviceId: deviceId);
      _apiService.setAuthToken(payload['token']?.toString());
      final session = AuthSession(
        id: payload['id'] is num ? (payload['id'] as num).toInt() : null,
        method: 'guest',
        email: payload['email']?.toString() ?? 'guest@novel.app',
        displayName: payload['display_name']?.toString() ?? 'Guest',
        photoUrl: payload['photo_url']?.toString(),
      );
      await _persistSession(session);
      return session;
    } catch (e) {
      throw Exception(_friendlyAuthError(e));
    }
  }

  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
    } catch (_) {}
    _apiService.setAuthToken(null);
    await _clearLocalSession(keepDeviceId: true);
  }

  Future<void> _clearLocalSession({required bool keepDeviceId}) async {
    final prefs = await SharedPreferences.getInstance();
    final deviceId = keepDeviceId ? prefs.getString(_deviceIdKey) : null;
    await prefs.remove(_methodKey);
    await prefs.remove(_idKey);
    await prefs.remove(_emailKey);
    await prefs.remove(_displayNameKey);
    await prefs.remove(_photoUrlKey);
    await prefs.remove(_tokenKey);
    if (deviceId != null) {
      await prefs.setString(_deviceIdKey, deviceId);
    }
  }

  Future<void> _persistSession(AuthSession session) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_methodKey, session.method);
    final token = _apiService.authTokenForPersistence;
    if (token != null && token.isNotEmpty) {
      await prefs.setString(_tokenKey, token);
    } else {
      await prefs.remove(_tokenKey);
    }
    if (session.id != null) {
      await prefs.setInt(_idKey, session.id!);
    } else {
      await prefs.remove(_idKey);
    }
    await prefs.setString(_emailKey, session.email);
    await prefs.setString(_displayNameKey, session.displayName);
    if (session.photoUrl != null && session.photoUrl!.isNotEmpty) {
      await prefs.setString(_photoUrlKey, session.photoUrl!);
    } else {
      await prefs.remove(_photoUrlKey);
    }
  }
}
