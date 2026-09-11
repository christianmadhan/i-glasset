import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/providers.dart';
import 'core/router/app_router.dart';
import 'core/theme/glas_theme.dart';

class IGlassetApp extends ConsumerWidget {
  const IGlassetApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
