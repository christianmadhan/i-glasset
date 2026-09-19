import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:i_glasset/core/theme/glas_theme.dart';
import 'package:i_glasset/core/widgets/glas_widgets.dart';

/// The score, price, ABV and vintage bars all fill from the left edge of a
/// full-width track. Under a parent that hands down loose width — a plain
/// `Column`, which is what the guess sheet uses — the slider used to
/// shrink-wrap to the fill and render as a short centred pill instead.
void main() {
  Widget wrap(Widget child, {double width = 300}) => MaterialApp(
        theme: buildGlasTheme(GlasColors.of(GlasThemeName.cellarModern)),
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: width,
              // Loose cross-axis width, exactly like _GuessCard.
              child: Column(mainAxisSize: MainAxisSize.min, children: [child]),
            ),
          ),
        ),
      );

  testWidgets('the track spans the full width and fills from the left',
      (tester) async {
    await tester.pumpWidget(wrap(
      GlasSlider(value: 2021, min: 1990, max: 2026, onChanged: (_) {}),
    ));

    final track = tester.getRect(find.byType(GlasSlider));
    expect(track.width, 300, reason: 'the bar should not shrink to its fill');

    final fill = tester.getRect(find.byType(FractionallySizedBox));
    expect(fill.left, track.left, reason: 'the fill starts at the left edge');
    expect(fill.width, closeTo(300 * (2021 - 1990) / (2026 - 1990), 0.5));
  });

  testWidgets('dragging maps position to value across the whole track',
      (tester) async {
    double? got;
    await tester.pumpWidget(wrap(
      GlasSlider(value: 1, min: 1, max: 10, onChanged: (v) => got = v),
    ));

    // Half way along the bar is the middle of the range.
    await tester.tapAt(tester.getCenter(find.byType(GlasSlider)));
    expect(got, closeTo(6, 0.51));
  });
}
