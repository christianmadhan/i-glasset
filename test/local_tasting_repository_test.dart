import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:i_glasset/data/local/local_media_store.dart';
import 'package:i_glasset/data/models/rating.dart';
import 'package:i_glasset/data/models/tasting.dart';
import 'package:i_glasset/data/models/tasting_config.dart';
import 'package:i_glasset/data/peer/peer_protocol.dart';
import 'package:i_glasset/data/repositories/local/local_auth_service.dart';
import 'package:i_glasset/data/repositories/local/local_session.dart';
import 'package:i_glasset/data/repositories/local/local_store.dart';
import 'package:i_glasset/data/repositories/local/local_tasting_repository.dart';
import 'package:i_glasset/data/repositories/tasting_repository.dart';

/// Exercises the device-only build: hosting an evening, the blind, the scoring
/// at reveal, and what a guest is actually sent.
void main() {
  late Directory temp;
  late LocalStore store;
  late LocalSession session;
  late LocalAuthService auth;
  late LocalTastingRepository repo;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('i_glasset_repo');
    store = LocalStore(root: temp);
    session = LocalSession(store);
    auth = LocalAuthService(store, session);
    repo = LocalTastingRepository(store, session, LocalMediaStore(root: temp));

    await auth.signUp(displayName: 'Martin');
  });

  tearDown(() async {
    await repo.dispose();
    await store.dispose();
    await session.dispose();
    if (await temp.exists()) await temp.delete(recursive: true);
  });

  Future<Tasting> aTasting({TastingConfig? config}) => repo.createTasting(
        title: 'Italienske rødvine',
        theme: 'Piemonte mod Toscana',
        config: config ?? const TastingConfig(),
      );

  group('hosting', () {
    test('creating a tasting puts the host in the room', () async {
      final tasting = await aTasting();

      expect(tasting.title, 'Italienske rødvine');
      expect(tasting.status, TastingStatus.draft);
      expect(tasting.joinCode, matches(RegExp(r'^[A-Z0-9]{6}$')));

      final people = await repo.participants(tasting.id);
      expect(people, hasLength(1));
      expect(people.single.profile.displayName, 'Martin');
      expect(people.single.isHost, isTrue);
    });

    test('join codes do not collide', () async {
      final codes = <String>{};
      for (var i = 0; i < 12; i++) {
        codes.add((await aTasting()).joinCode);
      }
      expect(codes, hasLength(12));
    });

    test('survives a restart — it is on disk, not in memory', () async {
      final tasting = await aTasting();
      await repo.createItem(tastingId: tasting.id, position: 1);
      await store.flush();

      final reopened = LocalStore(root: temp);
      final reopenedSession = LocalSession(reopened);
      await LocalAuthService(reopened, reopenedSession).signUp(
        displayName: 'Martin',
      );
      addTearDown(reopened.dispose);

      final rows = await reopened.all(LocalStore.tastings);
      expect(rows, hasLength(1));
      expect(rows.single['title'], 'Italienske rødvine');
    });

    test('reopening a live evening does not send the room back to the lobby',
        () async {
      // The host taps the same button to get back in after closing the app;
      // it must not rewind an evening that is already pouring.
      final tasting = await aTasting();
      await repo.createItem(tastingId: tasting.id, position: 1);
      await repo.updateTasting(tasting.id, status: TastingStatus.live);

      // openLobby goes on to advertise over Bonjour, which has no platform
      // channel here. The status decision is made before that, so letting the
      // advertisement fail still exercises the rule.
      try {
        await repo.openLobby(tasting.id);
      } on Object {
        // no mDNS in a unit test
      }

      expect((await repo.byId(tasting.id)).status, TastingStatus.live);
    });
  });

  group('the blind', () {
    test('a guest is sent nothing identifying before the reveal', () async {
      final tasting = await aTasting();
      final item = await repo.createItem(tastingId: tasting.id, position: 1);
      await repo.saveItem(item.copyWith(
        name: 'Barbaresco 2021',
        producer: 'Produttori del Barbaresco',
        grape: 'Nebbiolo',
        region: 'Piemonte',
        price: 315,
        hostNotes: 'Dekanteres en time før',
      ));
      await repo.updateTasting(tasting.id, status: TastingStatus.lobby);

      final guestId = await _addGuest(store, repo, tasting.joinCode);
      final snapshot = await repo.snapshotFor(guestId);

      final sent = snapshot.items.single;
      expect(sent['position'], 1);
      expect(sent['is_revealed'], isFalse);
      // None of the answer travels — not the name, not the price, not even the
      // producer that would give it away.
      expect(sent['name'], isNull);
      expect(sent['producer'], isNull);
      expect(sent['grape'], isNull);
      expect(sent['price'], isNull);
      expect(sent.containsKey('host_notes'), isFalse);
    });

    test('after the reveal everything but the host notes travels', () async {
      final tasting = await aTasting();
      final item = await repo.createItem(tastingId: tasting.id, position: 1);
      await repo.saveItem(item.copyWith(
        name: 'Barbaresco 2021',
        grape: 'Nebbiolo',
        price: 315,
        hostNotes: 'Dekanteres en time før',
      ));
      await repo.updateTasting(tasting.id, status: TastingStatus.lobby);

      final guestId = await _addGuest(store, repo, tasting.joinCode);
      await repo.revealItem(item.id);

      final sent = (await repo.snapshotFor(guestId)).items.single;
      expect(sent['is_revealed'], isTrue);
      expect(sent['name'], 'Barbaresco 2021');
      expect(sent['grape'], 'Nebbiolo');
      expect(sent['price'], 315);
      // Still the host's own: revealed or not, these are never shared.
      expect(sent['host_notes'], isNull);
    });

    test('the host still sees their own glasses in full', () async {
      final tasting = await aTasting();
      final item = await repo.createItem(tastingId: tasting.id, position: 1);
      await repo.saveItem(item.copyWith(name: 'Barbaresco 2021'));

      final asHost = await repo.items(tasting.id);
      expect(asHost.single.name, 'Barbaresco 2021');
    });

    test('seeing a glass is not the same as having revealed it', () async {
      // The host reads every field from the start, but `isRevealed` is the
      // room's state — the host's own screens count off poured glasses with
      // it, so it must not run ahead of the reveal.
      final tasting = await aTasting();
      final item = await repo.createItem(tastingId: tasting.id, position: 1);
      await repo.saveItem(item.copyWith(name: 'Barbaresco 2021'));

      expect((await repo.items(tasting.id)).single.isRevealed, isFalse);
      expect((await repo.hostItems(tasting.id)).single.isRevealed, isFalse);

      await repo.revealItem(item.id);

      expect((await repo.items(tasting.id)).single.isRevealed, isTrue);
      expect((await repo.hostItems(tasting.id)).single.isRevealed, isTrue);
    });
  });

  group('revealing', () {
    test('settles every guess against the answer', () async {
      final tasting = await aTasting();
      final item = await repo.createItem(tastingId: tasting.id, position: 1);
      await repo.saveItem(item.copyWith(
        name: 'Barbaresco 2021',
        grape: 'Nebbiolo',
        country: 'Italien',
        region: 'Piemonte',
        vintage: 2021,
        abv: 14,
        price: 315,
        extra: 'Tre år på store fade',
        aromas: ['Kirsebær', 'Rose'],
        flavours: ['Rød frugt'],
      ));

      await repo.saveRating(Rating(
        id: 'r-host',
        tastingItemId: item.id,
        userId: 'ignored — the repository stamps the real one',
        score: 9,
        guessGrape: 'Nebbiolo',
        guessCountry: 'Italien',
        guessPrice: 300,
        guessVintage: 2021,
      ));

      await repo.revealItem(item.id);

      final settled = await repo.myRating(item.id);
      expect(settled!.pointsTotal, isNotNull);
      // grape 3 + country 3 + price 3 (within 25) + vintage 3
      expect(settled.pointsTotal, 12);
      expect(settled.points[GuessCategory.drue]?.got, 3);
      expect(settled.points[GuessCategory.pris]?.got, 3);
    });

    test('a second reveal keeps the first timestamp', () async {
      final tasting = await aTasting();
      final item = await repo.createItem(tastingId: tasting.id, position: 1);

      final first = await repo.revealItem(item.id);
      await Future<void>.delayed(const Duration(milliseconds: 5));
      final second = await repo.revealItem(item.id);

      expect(second.revealedAt, first.revealedAt);
    });

    test('a guest cannot change a rating once the glass is settled', () async {
      final tasting = await aTasting();
      final item = await repo.createItem(tastingId: tasting.id, position: 1);
      await repo.updateTasting(tasting.id, status: TastingStatus.lobby);
      final guestId = await _addGuest(store, repo, tasting.joinCode);

      await repo.applyRating(guestId, {
        'id': 'r-guest',
        'tasting_item_id': item.id,
        'user_id': guestId,
        'score': 7,
      });
      await repo.revealItem(item.id);

      // Too late — the evening has moved on.
      await repo.applyRating(guestId, {
        'id': 'r-guest',
        'tasting_item_id': item.id,
        'user_id': guestId,
        'score': 10,
      });

      final stored = await store.find(
        LocalStore.ratings,
        (row) => row['user_id'] == guestId,
      );
      expect(stored!['score'], 7);
    });

    test('a guest cannot award themselves points', () async {
      final tasting = await aTasting();
      final item = await repo.createItem(tastingId: tasting.id, position: 1);
      await repo.updateTasting(tasting.id, status: TastingStatus.lobby);
      final guestId = await _addGuest(store, repo, tasting.joinCode);

      await repo.applyRating(guestId, {
        'id': 'r-guest',
        'tasting_item_id': item.id,
        'user_id': guestId,
        'score': 7,
        'points_total': 999,
        'points': {'drue': {'got': 99, 'max': 99}},
      });

      final stored = await store.find(
        LocalStore.ratings,
        (row) => row['user_id'] == guestId,
      );
      expect(stored!['points_total'], isNull);
      expect(stored['points'], isNull);
    });
  });

  group('admitting guests', () {
    test('turns away the wrong code', () async {
      await aTasting();
      final refusal = await repo.admit(
        joinCode: 'NOPE12',
        profile: {'id': 'u2', 'display_name': 'Sofie'},
      );
      expect(refusal, 'Koden findes ikke.');
    });

    test('turns away a tasting that has not been opened', () async {
      final tasting = await aTasting();
      final refusal = await repo.admit(
        joinCode: tasting.joinCode,
        profile: {'id': 'u2', 'display_name': 'Sofie'},
      );
      expect(refusal, 'Smagningen er ikke åbnet endnu.');
    });

    test('turns away a tasting that is over', () async {
      final tasting = await aTasting();
      await repo.updateTasting(tasting.id, status: TastingStatus.finished);
      final refusal = await repo.admit(
        joinCode: tasting.joinCode,
        profile: {'id': 'u2', 'display_name': 'Sofie'},
      );
      expect(refusal, 'Smagningen er slut.');
    });

    test('lets an open room in, and remembers who arrived', () async {
      final tasting = await aTasting();
      await repo.updateTasting(tasting.id, status: TastingStatus.lobby);

      final refusal = await repo.admit(
        joinCode: tasting.joinCode.toLowerCase(),
        profile: {'id': 'u2', 'display_name': 'Sofie Bak'},
      );

      expect(refusal, isNull);
      final people = await repo.participants(tasting.id);
      expect(people.map((p) => p.profile.displayName), contains('Sofie Bak'));
    });
  });

  group('images', () {
    test('an unrevealed glass will not hand over its photo', () async {
      final tasting = await aTasting();
      final item = await repo.createItem(tastingId: tasting.id, position: 1);
      await repo.saveItem(item.copyWith(imagePath: 'image.jpg'));

      expect(await repo.imageFor(item.id), isNull);
    });
  });

  group('guest mirror', () {
    test('a snapshot is written to the guest\'s own store', () async {
      const snapshot = TastingSnapshot(
        tasting: {
          'id': 't-remote',
          'host_id': 'someone-else',
          'title': 'Blind champagne',
          'category': 'Vin',
          'status': 'live',
          'join_code': 'BOBLER',
          'current_position': 1,
          'config': <String, dynamic>{},
          'created_at': '2026-09-11T18:00:00.000Z',
        },
        items: [
          {
            'id': 'i-remote',
            'tasting_id': 't-remote',
            'position': 1,
            'is_revealed': false,
            'revealed_at': null,
          },
        ],
        participants: [
          {
            'id': 'p1',
            'tasting_id': 't-remote',
            'user_id': 'someone-else',
            'is_host': true,
            'joined_at': '2026-09-11T18:00:00.000Z',
          },
        ],
        profiles: [
          {'id': 'someone-else', 'display_name': 'Lise'},
        ],
        ratings: [],
      );

      await repo.onSnapshot(snapshot);

      final tasting = await repo.byId('t-remote');
      expect(tasting.title, 'Blind champagne');
      expect(await repo.items('t-remote'), hasLength(1));
      expect((await repo.participants('t-remote')).single.profile.displayName,
          'Lise');
    });

    test('a later snapshot replaces the earlier picture', () async {
      const base = {
        'id': 't-remote',
        'host_id': 'someone-else',
        'title': 'Blind champagne',
        'category': 'Vin',
        'status': 'live',
        'join_code': 'BOBLER',
        'current_position': 1,
        'config': <String, dynamic>{},
        'created_at': '2026-09-11T18:00:00.000Z',
      };

      await repo.onSnapshot(const TastingSnapshot(
        tasting: base,
        items: [
          {'id': 'i1', 'tasting_id': 't-remote', 'position': 1, 'is_revealed': false},
          {'id': 'i2', 'tasting_id': 't-remote', 'position': 2, 'is_revealed': false},
        ],
        participants: [],
        profiles: [],
        ratings: [],
      ));

      // The host dropped a glass from the programme.
      await repo.onSnapshot(const TastingSnapshot(
        tasting: base,
        items: [
          {'id': 'i1', 'tasting_id': 't-remote', 'position': 1, 'is_revealed': false},
        ],
        participants: [],
        profiles: [],
        ratings: [],
      ));

      expect(await repo.items('t-remote'), hasLength(1));
    });
  });

  test('only the host may change the evening', () async {
    final tasting = await aTasting();
    await store.upsert(LocalStore.tastings, {
      ...(await store.byId(LocalStore.tastings, tasting.id))!,
      'host_id': 'someone-else',
    });

    expect(
      () => repo.advance(tasting.id, 1),
      throwsA(isA<TastingException>()),
    );
  });
}

/// Puts a second person in the room the way the socket would.
Future<String> _addGuest(
  LocalStore store,
  LocalTastingRepository repo,
  String joinCode,
) async {
  const guestId = 'guest-1';
  final refusal = await repo.admit(
    joinCode: joinCode,
    profile: {'id': guestId, 'display_name': 'Sofie'},
  );
  expect(refusal, isNull, reason: 'the guest should have been admitted');
  return guestId;
}
