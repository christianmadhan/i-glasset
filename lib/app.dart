import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/config/env.dart';
import 'core/providers.dart';
import 'core/router/app_router.dart';
import 'core/theme/glas_theme.dart';
import 'data/peer/tasting_guest.dart';

class IGlassetApp extends ConsumerStatefulWidget {
  const IGlassetApp({super.key});

  @override
  ConsumerState<IGlassetApp> createState() => _IGlassetAppState();
}

class _IGlassetAppState extends ConsumerState<IGlassetApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// A locked phone drops its socket to the host; the guest redials on its
  /// own every few seconds, but iOS suspends those timers too. Waking up is
  /// the moment to try again straight away.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || !Env.isLocal) return;
    final guest = ref.read(localTastingRepositoryProvider).guest;
    if (guest.state == GuestState.disconnected) guest.reconnect();
  }

  @override
  Widget build(BuildContext context) {
    final colors = GlasColors.of(ref.watch(themeProvider));

    return MaterialApp.router(
      title: 'I Glasset',
      debugShowCheckedModeBanner: false,
      routerConfig: ref.watch(routerProvider),
      theme: buildGlasTheme(colors),
      // The app is Danish throughout — the design's copy, the date formats and
      // the material pickers all follow from this.
      locale: const Locale('da'),
      supportedLocales: const [Locale('da'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }
}
