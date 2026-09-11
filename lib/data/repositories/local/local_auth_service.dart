import 'dart:math';

import 'package:uuid/uuid.dart';

import '../auth_service.dart';
import 'local_session.dart';
import 'local_store.dart';

/// Signing in when there is nothing to sign in to.
///
/// There are no passwords here, and nothing leaves the phone. [signUp] creates
/// the device's profile; [signIn] is not offered, because a password would be
/// theatre. The sign-in screen reads [supportsPasswords] and collapses to a
/// single name field.
class LocalAuthService implements AuthService {
  LocalAuthService(this._store, this._session);

  final LocalStore _store;
  final LocalSession _session;

  static const _uuid = Uuid();

  @override
  bool get supportsPasswords => false;

  @override
  AuthUser? get currentUser => _session.user;

  @override
  Stream<AuthUser?> get changes => _session.changes;

  @override
  Future<AuthUser> signIn({
    required String email,
    required String password,
  }) async {
    throw UnsupportedError(
      'Der er ingen konti i denne udgave — appen kører lokalt på telefonen.',
    );
  }

  @override
  Future<AuthUser> signUp({
    required String displayName,
    String? email,
    String? password,
  }) async {
    final name = displayName.trim();
    if (name.isEmpty) {
      throw ArgumentError('Skriv dit navn.');
    }

    // Re-running this renames the existing profile rather than making a second
    // identity, so a guest's ratings stay attached to them.
    final existing = _session.userId;
    final id = existing ?? _uuid.v4();

    await _store.upsert(LocalStore.profiles, {
      'id': id,
      'display_name': name,
      'avatar_seed': _seed(),
      'is_guest': false,
      'created_at': (await _store.byId(LocalStore.profiles, id))?['created_at'] ??
          DateTime.now().toUtc().toIso8601String(),
    });

    return _session.adopt(AuthUser(id: id, email: email));
  }

  @override
  Future<AuthUser> signInAsGuest() async {
    final existing = _session.user;
    if (existing != null) return existing;

    final id = _uuid.v4();
    await _store.upsert(LocalStore.profiles, {
      'id': id,
      'display_name': 'Gæst',
      'avatar_seed': _seed(),
      'is_guest': true,
      'created_at': DateTime.now().toUtc().toIso8601String(),
    });
    return _session.adopt(AuthUser(id: id, isAnonymous: true));
  }

  @override
  Future<void> sendPasswordReset(String email) async {
    throw UnsupportedError('Der er ingen adgangskode at nulstille.');
  }

  /// Signs out without destroying anything: the profile, the tastings and the
  /// photos stay on the device, and signing back in with the same name picks
  /// them up again.
  @override
  Future<void> signOut() => _session.clear();

  static String _seed() {
    final random = Random();
    return List.generate(
      8,
      (_) => random.nextInt(16).toRadixString(16),
    ).join();
  }
}
