import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../auth_service.dart';

/// Accounts, hosted. **Parked** alongside the other Supabase repositories.
class SupabaseAuthService implements AuthService {
  SupabaseAuthService(this._client);

  final sb.SupabaseClient _client;

  @override
  bool get supportsPasswords => true;

  @override
  AuthUser? get currentUser => _wrap(_client.auth.currentUser);

  @override
  Stream<AuthUser?> get changes =>
      _client.auth.onAuthStateChange.map((state) => _wrap(state.session?.user));

  @override
  Future<AuthUser> signIn({
    required String email,
    required String password,
  }) async {
    final response = await _client.auth
        .signInWithPassword(email: email.trim(), password: password);
    return _require(response.user);
  }

  @override
  Future<AuthUser> signUp({
    required String displayName,
    String? email,
    String? password,
  }) async {
    if (email == null || password == null) {
      throw const sb.AuthException(
        'E-mail og adgangskode er påkrævet, når appen kører mod serveren.',
      );
    }
    final response = await _client.auth.signUp(
      email: email.trim(),
      password: password,
      data: {'display_name': displayName.trim()},
    );
    return _require(response.user);
  }

  @override
  Future<AuthUser> signInAsGuest() async {
    final existing = _client.auth.currentUser;
    if (existing != null) return _require(existing);
    final response = await _client.auth.signInAnonymously();
    return _require(response.user);
  }

  @override
  Future<void> sendPasswordReset(String email) => _client.auth
      .resetPasswordForEmail(
        email.trim(),
        redirectTo: 'dk.huce.iglasset://login-callback/',
      );

  @override
  Future<void> signOut() => _client.auth.signOut();

  static AuthUser? _wrap(sb.User? user) => user == null
      ? null
      : AuthUser(
          id: user.id,
          email: user.email,
          isAnonymous: user.isAnonymous,
        );

  static AuthUser _require(sb.User? user) {
    final wrapped = _wrap(user);
    if (wrapped == null) {
      throw const sb.AuthException('Kunne ikke logge ind.');
    }
    return wrapped;
  }
}
