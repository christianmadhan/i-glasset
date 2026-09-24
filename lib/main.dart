import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/config/env.dart';
import 'core/providers.dart';
import 'core/theme/glas_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Env.assertConfigured();

  // Every face the app uses ships in assets/google_fonts/. Fetching is off so
  // a missing file shows up in development rather than as a silent download,
  // and so text is never laid out in a fallback font while one arrives.
  GoogleFonts.config.allowRuntimeFetching = false;
  _registerFontLicenses();
  // Otherwise the first frames are laid out in a fallback face and reflow
  // when the real one arrives.
  await preloadGlasFonts();

  await initializeDateFormatting('da');

  // Only reached when the hosted backend is switched on. The local build never
  // opens a connection to anything.
  if (Env.isSupabase) {
    await Supabase.initialize(
      url: Env.supabaseUrl,
      publishableKey: Env.supabasePublishableKey,
    );
  }

  final container = ProviderContainer();

  // Pick up the profile this device already has, so a returning user lands on
  // Hjem rather than being asked their name again.
  if (Env.isLocal) {
    await container.read(localSessionProvider).restore();
  }

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const IGlassetApp(),
    ),
  );
}

/// The bundled fonts are under the SIL Open Font License, which asks that the
/// licence travel with them. Flutter's licence page picks these up.
void _registerFontLicenses() {
  const fonts = {
    'publicsans': 'Public Sans',
    'librecaslontext': 'Libre Caslon Text',
    'azeretmono': 'Azeret Mono',
  };
  LicenseRegistry.addLicense(() async* {
    for (final entry in fonts.entries) {
      final text =
          await rootBundle.loadString('assets/google_fonts/OFL-${entry.key}.txt');
      yield LicenseEntryWithLineBreaks([entry.value], text);
    }
  });
}
