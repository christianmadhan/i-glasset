import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/config/env.dart';
import 'core/providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Env.assertConfigured();

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
