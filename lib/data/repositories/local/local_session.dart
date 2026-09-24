import 'dart:async';

import '../auth_service.dart';
import 'local_store.dart';

/// Who this device belongs to.
///
/// Local mode has no accounts in the usual sense: the phone holds one profile,
/// created the first time someone types their name. Its id is what every row
/// this device writes is stamped with, and what identifies it to the other
/// phones in the room.
class LocalSession {
  LocalSession(this._store);

  final LocalStore _store;
  final _changes = StreamController<AuthUser?>.broadcast();

  AuthUser? _user;

  AuthUser? get user => _user;
  String? get userId => _user?.id;
  Stream<AuthUser?> get changes => _changes.stream;

  String requireUserId() {
    final id = userId;
    if (id == null) {
      throw StateError('Ingen profil på denne enhed endnu.');
    }
    return id;
  }

  /// Reads the remembered profile back after a restart.
  Future<AuthUser?> restore() async {
    final row = await _store.byId(LocalStore.session, 'current');
    final userId = row?['user_id'] as String?;
    if (userId == null) return null;

    final profile = await _store.byId(LocalStore.profiles, userId);
    if (profile == null) return null;

    final user = AuthUser(
      id: userId,
      isAnonymous: profile['is_guest'] as bool? ?? false,
    );
    _set(user);
    return user;
  }

  Future<AuthUser> adopt(AuthUser user) async {
    await _store.upsert(LocalStore.session, {
      'id': 'current',
      'user_id': user.id,
    });
    _set(user);
    return user;
  }

  /// Signs out, but remembers whose phone this is: the next sign-in reattaches
  /// to the same profile instead of minting a stranger and orphaning every
  /// tasting on the device.
  Future<void> clear() async {
    final id = userId;
    if (id != null) {
      await _store.upsert(LocalStore.session, {'id': 'last', 'user_id': id});
    }
    await _store.delete(LocalStore.session, 'current');
    _set(null);
  }

  /// The profile this device last signed out of, if any.
  Future<String?> lastUserId() async {
    final row = await _store.byId(LocalStore.session, 'last');
    return row?['user_id'] as String?;
  }

  /// Forgets everything, the remembered profile included. Only the
  /// erase-all-data flow calls this.
  Future<void> forget() async {
    await _store.delete(LocalStore.session, 'current');
    await _store.delete(LocalStore.session, 'last');
    _set(null);
  }

  Future<void> dispose() => _changes.close();

  void _set(AuthUser? user) {
    _user = user;
    if (!_changes.isClosed) _changes.add(user);
  }
}
