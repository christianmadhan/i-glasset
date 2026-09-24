import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:i_glasset/app.dart';
import 'package:i_glasset/core/providers.dart';
import 'package:i_glasset/core/router/app_router.dart';
import 'package:i_glasset/core/theme/glas_theme.dart';
import 'package:i_glasset/data/local/local_media_store.dart';
import 'package:i_glasset/data/repositories/local/local_store.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Every screen, on every phone the app supports, must lay out without a
/// single overflow — at the default text size, at the larger sizes people
/// actually pick, and with the keyboard up on the screens that type.
///
/// The screens render the real app (router, providers, theme) over a copy of
/// the demo wine club in `test/fixtures/club/`, with the bundled fonts loaded,
/// so text is measured exactly as it is on a phone. The fixture is lengthened
/// in a few plausible places (a long club name, a five-figure bottle, a
/// double-barrelled name) so the layouts are tested with room to spare.
void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    GoogleFonts.config.allowRuntimeFetching = false;
    await initializeDateFormatting('da');
  });

  final fixture = _Fixture.load();

  // Width × height in logical pixels. 320 wide is the iPhone SE (1st gen) and
  // iPod touch, both still on iOS 15; 360 the common small Android.
  const phones = {
    'se1': Size(320, 568),
    'android-s': Size(360, 640),
    'se3': Size(375, 667),
    'pro-max': Size(440, 956),
  };

  // 1.0 is the default; 1.35 is iOS "XXXL", the largest non-accessibility
  // Dynamic Type step, and close to Android's largest font setting.
  const scales = [1.0, 1.35];

  for (final screen in fixture.screens) {
    for (final phone in phones.entries) {
      for (final scale in scales) {
        testWidgets(
          '${screen.name} · ${phone.key} · text ${scale}x',
          (tester) => _expectNoOverflow(
            tester,
            fixture,
            screen,
            size: phone.value,
            scale: scale,
          ),
        );
      }
    }
  }

  // The screens with a text field, with the keyboard taking its bite.
  for (final screen in fixture.screens.where((s) => s.types)) {
    for (final phone in ['se1', 'se3']) {
      testWidgets(
        '${screen.name} · $phone · keyboard up',
        (tester) => _expectNoOverflow(
          tester,
          fixture,
          screen,
          size: phones[phone]!,
          scale: 1.0,
          keyboard: true,
        ),
      );
    }
  }
}

// ---------------------------------------------------------------------------

Future<void> _expectNoOverflow(
  WidgetTester tester,
  _Fixture fixture,
  _Screen screen, {
  required Size size,
  required double scale,
  bool keyboard = false,
}) async {
  tester.view.devicePixelRatio = 3;
  tester.view.physicalSize = size * 3;
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  // A notch and a home indicator, as on every current iPhone.
  tester.view.padding = const FakeViewPadding(top: 47 * 3, bottom: 34 * 3);
  if (keyboard) {
    tester.view.viewInsets = const FakeViewPadding(bottom: 291 * 3);
  }
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

  final root = (await tester.runAsync(
    () => Directory.systemTemp.createTemp('i_glasset_layout'),
  ))!;
  addTearDown(() => tester.runAsync(() => root.delete(recursive: true)));

  // Built in real time: the store chains its writes off a future created
  // here, and one born in the fake clock's zone would never complete.
  final store = (await tester.runAsync(() async => LocalStore(root: root)))!;
  final container = ProviderContainer(overrides: [
    localStoreProvider.overrideWithValue(store),
    localMediaStoreProvider.overrideWithValue(LocalMediaStore(root: root)),
    // Discovery is a platform channel; the join screen just needs a list.
    nearbyTastingsProvider.overrideWith((ref) => Stream.value(const [])),
  ]);
  addTearDown(container.dispose);

  await tester.runAsync(() async {
    await preloadGlasFonts();
    await fixture.writeTo(root);
    await fixture.stretch(store);
    await screen.prepare?.call(store, fixture);
    // Read every collection once, so later reads are served from memory and
    // complete inside the test's fake clock.
    for (final c in _collections) {
      await store.all(c);
    }
    await container.read(localSessionProvider).restore();
    await container.read(localTastingRepositoryProvider).warmCaches();
  });

  final overflows = <String>[];
  final previous = FlutterError.onError;
  FlutterError.onError = (details) {
    final text = details.exceptionAsString();
    if (text.contains('overflowed')) {
      // "The relevant error-causing widget was: Row  Row:file:///…/lib/x.dart:12:9"
      final where = RegExp(r'lib/[\w/]+\.dart:\d+:\d+')
              .firstMatch(details.toString(minLevel: DiagnosticLevel.info))
              ?.group(0) ??
          '?';
      overflows.add('${text.split('\n').first} at $where');
      if (const bool.fromEnvironment('LAYOUT_VERBOSE')) debugPrint(details.toString());
    } else {
      previous?.call(details);
    }
  };

  try {
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const IGlassetApp(),
    ));
    container.read(routerProvider).go(screen.path(fixture));

    // Let file reads, font loads and entry animations all finish.
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 120));
      await tester.runAsync(() async {
        await GoogleFonts.pendingFonts();
        await Future<void>.delayed(const Duration(milliseconds: 30));
      });
    }
    await tester.pump(const Duration(milliseconds: 800));
  } finally {
    FlutterError.onError = previous;
  }

  // Text squeezed into a box shorter than it needs is clipped without any
  // error being raised — a label cut in half inside a fixed-height button.
  for (final paragraph in tester.allRenderObjects.whereType<RenderParagraph>()) {
    if (!paragraph.attached || !paragraph.hasSize) continue;
    final needed = TextPainter(
      text: paragraph.text,
      textDirection: paragraph.textDirection,
      textScaler: paragraph.textScaler,
      maxLines: paragraph.maxLines,
      ellipsis: paragraph.overflow == TextOverflow.ellipsis ? '…' : null,
      strutStyle: paragraph.strutStyle,
      textWidthBasis: paragraph.textWidthBasis,
      locale: paragraph.locale,
    )..layout(maxWidth: paragraph.constraints.maxWidth);
    if (needed.height > paragraph.size.height + 0.5) {
      final where = RegExp(r'lib/[\w/]+\.dart:\d+:\d+')
              .firstMatch(paragraph.debugCreator?.toString() ?? '')
              ?.group(0) ??
          '?';
      overflows.add('"${paragraph.text.toPlainText()}" clipped by '
          '${(needed.height - paragraph.size.height).toStringAsFixed(1)} px '
          'at $where');
    }
    needed.dispose();

    // A single word wider than its box is split mid-word ("topsmagninge/r"):
    // no error, but it reads as a typo.
    if (paragraph.maxLines == 1 || paragraph.size.width < 1) continue;
    final style = paragraph.text.style;
    for (final word in paragraph.text.toPlainText().split(RegExp(r'[\s\-/·]+'))) {
      if (word.length < 3) continue;
      final w = TextPainter(
        text: TextSpan(text: word, style: style),
        textDirection: paragraph.textDirection,
        textScaler: paragraph.textScaler,
        maxLines: 1,
      )..layout();
      if (w.width > paragraph.size.width + 0.5) {
        overflows.add('"$word" split across lines in '
            '"${paragraph.text.toPlainText()}"');
      }
      w.dispose();
    }
  }

  if (const bool.fromEnvironment('LAYOUT_GOLDENS')) {
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/${screen.name.replaceAll(RegExp('[^a-z]+'), '_')}'
          '_${size.width.toInt()}_$scale${keyboard ? '_kb' : ''}.png'),
    );
  }

  expect(
    overflows.toSet().toList(),
    isEmpty,
    reason: '${screen.name} overflows at ${size.width.toInt()}×'
        '${size.height.toInt()}, text ${scale}x'
        '${keyboard ? ', keyboard up' : ''}',
  );

  // Unmount inside the test so repeating animations stop with it.
  await tester.pumpWidget(const SizedBox());
}

const _collections = [
  LocalStore.profiles,
  LocalStore.groups,
  LocalStore.groupMembers,
  LocalStore.tastings,
  LocalStore.items,
  LocalStore.participants,
  LocalStore.ratings,
  LocalStore.session,
];

// ---------------------------------------------------------------------------

class _Screen {
  const _Screen(this.name, this.path, {this.prepare, this.types = false});

  final String name;
  final String Function(_Fixture f) path;
  final Future<void> Function(LocalStore store, _Fixture f)? prepare;

  /// Has a text field, so it is also checked with the keyboard up.
  final bool types;
}

class _Fixture {
  _Fixture._(this.files);

  final Map<String, String> files;

  static const _dir = 'test/fixtures/club';

  factory _Fixture.load() => _Fixture._({
        for (final f in Directory(_dir).listSync().whereType<File>())
          f.uri.pathSegments.last: f.readAsStringSync(),
      });

  List<Map<String, dynamic>> rows(String collection) =>
      (jsonDecode(files['$collection.json']!) as List)
          .cast<Map<String, dynamic>>();

  Map<String, dynamic> tasting(String title) =>
      rows(LocalStore.tastings).firstWhere((t) => t['title'] == title);

  String get me => rows(LocalStore.session).single['user_id'] as String;
  String get groupId => rows(LocalStore.groups).single['id'] as String;
  String get live => tasting('Rundt om Italien')['id'] as String;
  String get finished => tasting('Piemonte-aften')['id'] as String;
  String get lobbyCopy => 'layout-lobby';
  String get guestCopy => 'layout-guest';

  String itemAt(String tastingId, int position) =>
      rows(LocalStore.items).firstWhere((i) =>
          i['tasting_id'] == tastingId && i['position'] == position)['id']
      as String;

  String personNamed(String first) => rows(LocalStore.profiles).firstWhere(
      (p) => (p['display_name'] as String).startsWith(first))['id'] as String;

  Future<void> writeTo(Directory root) async {
    final data = Directory('${root.path}/I Glasset/data');
    await data.create(recursive: true);
    for (final entry in files.entries) {
      await File('${data.path}/${entry.key}').writeAsString(entry.value);
    }
  }

  /// Longer, still plausible, values in the places that most often break a
  /// row: a club name, a person, a title, a bottle and its price.
  Future<void> stretch(LocalStore store) async {
    await store.patch(LocalStore.groups, groupId,
        (g) => {...g, 'name': 'Vinklubben Østerbro & Omegn'});
    await store.patch(LocalStore.profiles, personNamed('Line'),
        (p) => {...p, 'display_name': 'Anne-Mette Kristoffersen'});
    await store.patch(LocalStore.profiles, me,
        (p) => {...p, 'display_name': 'Christian Alexander Witt'});
    await store.patch(LocalStore.tastings, live,
        (t) => {...t, 'title': 'Rundt om Italien på seks glas'});
    await store.patch(LocalStore.items, itemAt(finished, 4), (i) => {
          ...i,
          'name': 'Barolo Riserva Cannubi Boschis Vigna Alta',
          'producer': 'Tenuta Marchesa di Barolo e Monforte',
          'price': 12500.0,
        });
  }

  /// A room still in the lobby: the live evening, rewound.
  Future<void> addLobby(LocalStore store) async {
    final t = await store.byId(LocalStore.tastings, live);
    await store.upsert(LocalStore.tastings, {
      ...t!,
      'id': lobbyCopy,
      'join_code': 'LOBB42',
      'status': 'lobby',
      'current_position': 0,
    });
    for (final p in rows(LocalStore.participants)
        .where((p) => p['tasting_id'] == live)) {
      await store.upsert(LocalStore.participants,
          {...p, 'id': 'lobby-${p['id']}', 'tasting_id': lobbyCopy});
    }
    for (final i in rows(LocalStore.items).where((i) => i['tasting_id'] == live)) {
      await store.upsert(LocalStore.items, {
        ...i,
        'id': 'lobby-${i['id']}',
        'tasting_id': lobbyCopy,
        'revealed_at': null,
      });
    }
  }

  /// The live evening seen from a guest's phone: someone else hosts it.
  Future<void> addGuestView(LocalStore store) async {
    final t = await store.byId(LocalStore.tastings, live);
    final host = personNamed('Jonas');
    await store.upsert(LocalStore.tastings,
        {...t!, 'id': guestCopy, 'join_code': 'GUES42', 'host_id': host});
    for (final p in rows(LocalStore.participants)
        .where((p) => p['tasting_id'] == live)) {
      await store.upsert(LocalStore.participants, {
        ...p,
        'id': 'guest-${p['id']}',
        'tasting_id': guestCopy,
        'is_host': p['user_id'] == host,
      });
    }
    for (final i in rows(LocalStore.items).where((i) => i['tasting_id'] == live)) {
      await store.upsert(LocalStore.items,
          {...i, 'id': 'guest-${i['id']}', 'tasting_id': guestCopy});
    }
  }

  /// A lobby seen from a guest's phone: someone else hosts it.
  Future<void> addGuestLobby(LocalStore store) async {
    await addLobby(store);
    await store.patch(LocalStore.tastings, lobbyCopy,
        (t) => {...t, 'host_id': personNamed('Line')});
    for (final p in await store.where(
        LocalStore.participants, (p) => p['tasting_id'] == lobbyCopy)) {
      await store.patch(LocalStore.participants, p['id'] as String,
          (row) => {...row, 'is_host': row['user_id'] == personNamed('Line')});
    }
  }

  /// A phone that has just been set up: a name, and nothing else yet.
  Future<void> startFresh(LocalStore store) async {
    for (final c in [
      LocalStore.groups,
      LocalStore.groupMembers,
      LocalStore.tastings,
      LocalStore.items,
      LocalStore.participants,
      LocalStore.ratings,
    ]) {
      await store.deleteWhere(c, (_) => true);
    }
    await store.deleteWhere(LocalStore.profiles, (p) => p['id'] != me);
  }

  /// Marks my rating for the live glass as sent, for the waiting state.
  Future<void> sendMyRating(LocalStore store) async {
    final glass = itemAt(live, 3);
    final mine = rows(LocalStore.ratings).firstWhere(
        (r) => r['tasting_item_id'] == glass && r['user_id'] == me);
    await store.patch(LocalStore.ratings, mine['id'] as String,
        (r) => {...r, 'submitted_at': DateTime.now().toUtc().toIso8601String()});
  }

  late final List<_Screen> screens = [
    _Screen('login', (_) => '/login',
        types: true,
        prepare: (s, _) => s.delete(LocalStore.session, 'current')),
    _Screen('guide', (_) => '/guide'),
    _Screen('home (new user)', (_) => '/?tab=0',
        prepare: (s, f) => f.startFresh(s)),
    _Screen('groups (new user)', (_) => '/?tab=1',
        prepare: (s, f) => f.startFresh(s)),
    _Screen('top (new user)', (_) => '/?tab=2',
        prepare: (s, f) => f.startFresh(s)),
    _Screen('profile (new user)', (_) => '/?tab=3',
        prepare: (s, f) => f.startFresh(s)),
    _Screen('home', (_) => '/?tab=0'),
    _Screen('groups', (_) => '/?tab=1', types: true),
    _Screen('top', (_) => '/?tab=2'),
    _Screen('profile', (_) => '/?tab=3'),
    _Screen('join', (_) => '/join', types: true),
    _Screen('create group', (_) => '/groups/new', types: true),
    _Screen('group', (f) => '/groups/${f.groupId}'),
    _Screen('create tasting', (f) => '/tastings/new?group=${f.groupId}',
        types: true),
    _Screen('program', (f) => '/tastings/${f.live}/program'),
    _Screen('edit glass', (f) => '/tastings/${f.live}/items/${f.itemAt(f.live, 3)}',
        types: true),
    _Screen('lobby (host)', (f) => '/tastings/${f.lobbyCopy}/lobby',
        prepare: (s, f) => f.addLobby(s)),
    _Screen('lobby (guest)', (f) => '/tastings/${f.lobbyCopy}/lobby',
        prepare: (s, f) => f.addGuestLobby(s)),
    _Screen('live (host)', (f) => '/tastings/${f.live}/live', types: true),
    _Screen('live (host, sent)', (f) => '/tastings/${f.live}/live',
        prepare: (s, f) => f.sendMyRating(s)),
    _Screen('live (guest)', (f) => '/tastings/${f.guestCopy}/live',
        prepare: (s, f) => f.addGuestView(s)),
    _Screen('guess sheet',
        (f) => '/tastings/${f.live}/sheet?item=${f.itemAt(f.live, 3)}',
        types: true),
    _Screen('reveal', (f) => '/tastings/${f.finished}/reveal'),
    _Screen('results (live)', (f) => '/tastings/${f.live}/results'),
    _Screen('results (finished)', (f) => '/tastings/${f.finished}/results'),
    _Screen('summary', (f) => '/tastings/${f.finished}/summary'),
    _Screen('previous tasting', (f) => '/tastings/${f.finished}/archive'),
    _Screen('product', (f) => '/items/${f.itemAt(f.finished, 4)}'),
    _Screen('taste profile', (_) => '/taste'),
    _Screen('storage', (_) => '/storage'),
  ];
}
