import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:i_glasset/core/theme/glas_theme.dart';
import 'package:i_glasset/core/widgets/glas_widgets.dart';

/// A bare `Row(crossAxisAlignment: stretch)` has nothing to stretch to inside a
/// scroll view, and failing to lay out takes every sibling *below* it down with
/// it — the whole lower half of the screen silently stops being laid out and
/// paints at the origin instead. Hjem, Profil, Produkt and Afsløring all put a
/// tile row in exactly that position, so this guards [StatRow] for all of them.
void main() {
  Widget wrap(List<Widget> children) => MaterialApp(
        theme: buildGlasTheme(GlasColors.of(GlasThemeName.cellarModern)),
        home: PaperScreen(children: children),
      );

  testWidgets('tiles share the tallest tile height', (tester) async {
    await tester.pumpWidget(wrap(const [
      StatRow(children: [
        StatTile(value: '7,9', label: 'kort'),
        StatTile(
          value: 'Rødvin fra Piemonte',
          label: 'en noget længere etiket der brydes over flere linjer',
        ),
      ]),
    ]));

    final heights = tester
        .widgetList<StatTile>(find.byType(StatTile))
        .map((t) => tester.getSize(find.byWidget(t)).height)
        .toSet();
    expect(heights, hasLength(1), reason: 'tiles should be equal height');
  });

  testWidgets('siblings below a tile row are still laid out', (tester) async {
    await tester.pumpWidget(wrap(const [
      Text('over'),
      StatRow(children: [
        StatTile(value: '1', label: 'a'),
        StatTile(value: '2', label: 'b'),
      ]),
      Text('under'),
    ]));

    expect(tester.takeException(), isNull);

    final over = tester.getTopLeft(find.text('over')).dy;
    final row = tester.getTopLeft(find.byType(StatRow)).dy;
    final under = tester.getTopLeft(find.text('under')).dy;

    expect(row, greaterThan(over));
    expect(under, greaterThan(row),
        reason: 'a sibling that failed to lay out paints at the origin');
  });
}
