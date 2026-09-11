/// Whoever is using the app right now.
class AuthUser {
  const AuthUser({required this.id, this.email, this.isAnonymous = false});

  final String id;
  final String? email;
  final bool isAnonymous;
}

/// Signing in, independent of whether there is a server to sign in to.
///
/// In local mode there is no account in the usual sense: the device holds one
/// profile, created the first time someone types their name, and [signUp] is
/// what creates it. [supportsPasswords] tells the sign-in screen which of its
/// two shapes to take.
abstract interface class AuthService {
  AuthUser? get currentUser;

  /// Emits on sign-in and sign-out.
  Stream<AuthUser?> get changes;

  /// Whether this backend has passwords, email confirmation and recovery at
  /// all. False in local mode, where the sign-in screen collapses to a name.
  bool get supportsPasswords;

  Future<AuthUser> signIn({required String email, required String password});

  Future<AuthUser> signUp({
    required String displayName,
    String? email,
    String? password,
  });

  /// "Deltag med kode uden konto".
  Future<AuthUser> signInAsGuest();

  Future<void> sendPasswordReset(String email);

  Future<void> signOut();
}
