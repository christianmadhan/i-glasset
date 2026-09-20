import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:i_glasset/core/theme/glas_theme.dart';
import 'package:i_glasset/features/auth/onboarding_screen.dart';

/// Exercises the light "paper" surface end to end — the shared scaffold, the
/// display/label type roles, and the four-step flow.
///
/// The step card carries an endlessly repeating light sweep, so these pump a
/// fixed duration rather than `pumpAndSettle`, which would never return.
void main() {
  Widget wrap(Widget child) => MaterialApp(
        theme: buildGlasTheme(GlasColors.of(GlasThemeName.cellarModern)),
        locale: const Locale('da'),
        supportedLocales: const [Locale('da'), Locale('en')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: child,
      );

  // The card plus the family lockup is taller than the 600px default
  // surface; a phone is taller still.
  Future<void> show(WidgetTester tester,
      {Size size = const Size(414, 900)}) async {
    tester.view.physicalSize = size * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(wrap(const OnboardingScreen()));
  }

  testWidgets('walks through all four onboarding steps', (tester) async {
    await show(tester);

    expect(find.text('TRIN 1 AF 4'), findsOneWidget);
    expect(find.text('Værten samler flaskerne'), findsOneWidget);
    expect(find.text('Videre'), findsOneWidget);

    for (var step = 2; step <= 4; step++) {
      await tester.tap(find.text(step == 5 ? 'Kom i gang' : 'Videre'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('TRIN $step AF 4'), findsOneWidget);
    }

    // The last step offers the way in rather than another "Videre".
    expect(find.text('Kom i gang'), findsOneWidget);
    expect(find.text('Afsløring og arkiv'), findsOneWidget);
  });

  testWidgets('the back arrow only appears after the first step',
      (tester) async {
    await show(tester);
    expect(find.text('←'), findsNothing);

    await tester.tap(find.text('Videre'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('←'), findsOneWidget);

    await tester.tap(find.text('←'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('TRIN 1 AF 4'), findsOneWidget);
  });

  testWidgets('the progress dots jump straight to a step', (tester) async {
    await show(tester);

    // Tapping the last dot skips straight to that step.
    await tester.tap(find.byKey(const ValueKey('guide-dot-3')));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('TRIN 4 AF 4'), findsOneWidget);
  });

  testWidgets('renders without overflowing a small phone', (tester) async {
    await show(tester, size: const Size(360, 640));
    await tester.pump(const Duration(milliseconds: 400));

    expect(tester.takeException(), isNull);
  });
}
