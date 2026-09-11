/// Which backend the app runs against.
enum Backend {
  /// Everything on the device, with the evening shared phone-to-phone over the
  /// local network. No account, no server, no internet. This is the default.
  local,

  /// The hosted Supabase project. Ready to switch on: the SQL is written and
  /// the repositories are kept compiling, so this is a one-line change plus
  /// credentials.
  supabase;

  static Backend fromWire(String value) => switch (value.toLowerCase()) {
        'supabase' => Backend.supabase,
        _ => Backend.local,
      };
}

/// Build-time configuration.
///
/// Values arrive via `--dart-define` (or `--dart-define-from-file`) so that no
/// credentials are baked into a bundled asset file. Running with no defines at
/// all gives you the local build, which is the point: the app works out of the
/// box with nothing to set up.
class Env {
  const Env._();

  /// `--dart-define=BACKEND=supabase` to switch.
  static const backendName =
      String.fromEnvironment('BACKEND', defaultValue: 'local');

  static Backend get backend => Backend.fromWire(backendName);

  static bool get isLocal => backend == Backend.local;
  static bool get isSupabase => backend == Backend.supabase;

  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');

  /// Supabase calls this the *publishable* key in the current dashboard; older
  /// projects still label it the anon key. Either name works.
  static const supabasePublishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: String.fromEnvironment('SUPABASE_ANON_KEY'),
  );

  /// Storage bucket used purely as transport for tasting images.
  static const mediaBucket = String.fromEnvironment(
    'SUPABASE_MEDIA_BUCKET',
    defaultValue: 'tasting-media',
  );

  static bool get isConfigured =>
      isLocal || (supabaseUrl.isNotEmpty && supabasePublishableKey.isNotEmpty);

  static void assertConfigured() {
    if (isConfigured) return;
    throw StateError(
      'BACKEND=supabase needs SUPABASE_URL and SUPABASE_PUBLISHABLE_KEY.\n'
      'Run with: flutter run --dart-define-from-file=dart_define.json\n'
      'Or drop the defines entirely to run the local, device-only build.',
    );
  }
}
