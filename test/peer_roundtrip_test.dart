import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:i_glasset/data/local/local_media_store.dart';
import 'package:i_glasset/data/models/rating.dart';
import 'package:i_glasset/data/models/tasting.dart';
import 'package:i_glasset/data/models/tasting_config.dart';
import 'package:i_glasset/data/peer/tasting_guest.dart';
import 'package:i_glasset/data/repositories/local/local_auth_service.dart';
import 'package:i_glasset/data/repositories/local/local_session.dart';
import 'package:i_glasset/data/repositories/local/local_store.dart';
import 'package:i_glasset/data/repositories/local/local_tasting_repository.dart';

/// Two phones on one loopback: the host's repository serving a real socket,
/// the guest's repository dialling it. Bonjour has no platform channel in a
/// test, so the guest is handed the address directly — everything after
/// discovery is the real wire.
///
/// This is the evening the two-iPhone test tripped over: does the host see
/// the guest arrive and send their rating, does a phone that lost its socket
/// get its rating through when it comes back, and does the finish reach it.
class _Phone {
  _Phone(this.temp, this.store, this.session, this.repo);

  final Directory temp;
  final LocalStore store;
  final LocalSession session;
  final LocalTastingRepository repo;

  static Future<_Phone> signUp(String name) async {
    final temp = await Directory.systemTemp.createTemp('i_glasset_$name');
    final store = LocalStore(root: temp);
    final session = LocalSession(store);
    await LocalAuthService(store, session).signUp(displayName: name);
    final repo =
        LocalTastingRepository(store, session, LocalMediaStore(root: temp));
    return _Phone(temp, store, session, repo);
  }

  String get userId => session.requireUserId();

  Future<Map<String, dynamic>> get profile async =>
      (await store.byId(LocalStore.profiles, userId))!;

  Future<void> dispose() async {
    await repo.dispose();
    await store.dispose();
    await session.dispose();
    try {
      if (await temp.exists()) await temp.delete(recursive: true);
    } on FileSystemException {
      // Windows may still hold a handle on a just-written file; the temp
      // folder is not what these tests are about.
    }
  }
}

/// Polls until [test] is true; the socket delivers on its own schedule.
Future<void> eventually(
  Future<bool> Function() test, {
  String? reason,
}) async {
  final deadline = DateTime.now().add(const Duration(seconds: 5));
  while (DateTime.now().isBefore(deadline)) {
    if (await test()) return;
    await Future<void>.delayed(const Duration(milliseconds: 40));
  }
  fail(reason ?? 'condition never became true');
}

void main() {
  late _Phone host;
  late _Phone guest;
  late Tasting tasting;
  late NearbyTasting address;

  setUp(() async {
    host = await _Phone.signUp('Martin');
    guest = await _Phone.signUp('Sofie');

    tasting = await host.repo.createTasting(
      title: 'Italienske rødvine',
      theme: 'Piemonte mod Toscana',
      config: const TastingConfig(),
    );
    final glass1 =
        await host.repo.createItem(tastingId: tasting.id, position: 1);
    await host.repo.saveItem(glass1.copyWith(
      name: 'Barbaresco 2021',
      grape: 'Nebbiolo',
      extra: 'Tre år på store fade',
    ));
    final glass2 =
        await host.repo.createItem(tastingId: tasting.id, position: 2);
    await host.repo.saveItem(glass2.copyWith(name: 'Lagrein 2022'));

    // openLobby binds the socket; the Bonjour advertisement fails harmlessly.
    await host.repo.openLobby(tasting.id);
    expect(host.repo.host.isRunning, isTrue);

    address = NearbyTasting(
      code: tasting.joinCode,
      title: tasting.title,
      hostName: 'Martin',
      glasses: 2,
      addresses: const ['127.0.0.1'],
      port: host.repo.host.port,
    );
  });

  tearDown(() async {
    await guest.dispose();
    await host.dispose();
  });

  Future<void> join() async => guest.repo.guest.connect(
        host: address,
        joinCode: tasting.joinCode,
        profile: await guest.profile,
      );

  test('the host sees the guest arrive, and sees their rating land', () async {
    await join();

    // Arrival: the lobby's participant list on the host's phone.
    final people = await host.repo.participants(tasting.id);
    expect(people.map((p) => p.profile.displayName), contains('Sofie'));

    // The guest holds the redacted evening — and knows glass 1 has something
    // extraordinary to guess at without knowing what it is.
    final blind = await guest.repo.items(tasting.id);
    expect(blind, hasLength(2));
    expect(blind.first.name, isNull);
    expect(blind.first.hasExtra, isTrue);
    expect(blind.last.hasExtra, isFalse);

    // "Send bedømmelse" on the guest's phone.
    await host.repo.advance(tasting.id, 1);
    await guest.repo.saveRating(Rating(
      id: 'r-sofie-1',
      tastingItemId: blind.first.id,
      userId: guest.userId,
      score: 8.5,
      guessGrape: 'Nebbiolo',
      guessExtra: 'Tre år på store fade',
      submittedAt: DateTime.now(),
    ));

    // The host reads every rating before the reveal — that is how the host
    // knows the room is ready.
    await eventually(
      () async => (await host.repo.ratings(tasting.id))
          .any((r) => r.userId == guest.userId && r.isSubmitted),
      reason: "the guest's rating never reached the host",
    );
  });

  test('a rating made while the socket was down arrives on reconnect',
      () async {
    await join();
    await host.repo.advance(tasting.id, 1);
    final blind = await guest.repo.items(tasting.id);

    // The phone locks: iOS drops the socket. The guest rates anyway.
    await guest.repo.guest.disconnect();
    await guest.repo.saveRating(Rating(
      id: 'r-offline',
      tastingItemId: blind.first.id,
      userId: guest.userId,
      score: 7.0,
      submittedAt: DateTime.now(),
    ));
    expect((await host.repo.ratings(tasting.id)).where((r) => r.userId == guest.userId),
        isEmpty);

    // Unlock: the guest redials, and what it rated meanwhile goes through.
    await join();
    await eventually(
      () async => (await host.repo.ratings(tasting.id))
          .any((r) => r.userId == guest.userId && r.score == 7.0),
      reason: 'the offline rating was never resent',
    );
    // And the welcome snapshot did not wipe the guest's own copy.
    expect((await guest.repo.myRating(blind.first.id))?.score, 7.0);
  });

  test('reveals, points and the finish all reach the guest', () async {
    await join();
    await host.repo.advance(tasting.id, 1);
    final blind = await guest.repo.items(tasting.id);

    await guest.repo.saveRating(Rating(
      id: 'r1',
      tastingItemId: blind.first.id,
      userId: guest.userId,
      score: 8.0,
      guessGrape: 'Nebbiolo',
      guessExtra: 'Tre år på store fade',
      submittedAt: DateTime.now(),
    ));
    await eventually(() async =>
        (await host.repo.ratings(tasting.id)).any((r) => r.userId == guest.userId));

    await host.repo.revealItem(blind.first.id);
    await eventually(
      () async => (await guest.repo.items(tasting.id)).first.isRevealed,
      reason: 'the reveal never reached the guest',
    );
    final revealed = (await guest.repo.items(tasting.id)).first;
    expect(revealed.name, 'Barbaresco 2021');

    final mine = await guest.repo.myRating(blind.first.id);
    expect(mine?.points[GuessCategory.drue]?.got, 3);
    expect(mine?.points[GuessCategory.ekstra]?.got, 3);

    // Glass 2 has nothing extraordinary: the category is not in play there.
    await host.repo.advance(tasting.id, 2);
    await guest.repo.saveRating(Rating(
      id: 'r2',
      tastingItemId: blind.last.id,
      userId: guest.userId,
      score: 6.0,
      guessExtra: 'Økologisk',
      submittedAt: DateTime.now(),
    ));
    await eventually(() async => (await host.repo.ratings(tasting.id))
        .any((r) => r.tastingItemId == blind.last.id && r.userId == guest.userId));
    await host.repo.revealItem(blind.last.id);
    await eventually(() async =>
        (await guest.repo.myRating(blind.last.id))?.pointsTotal != null);
    expect((await guest.repo.myRating(blind.last.id))!.points.containsKey(GuessCategory.ekstra),
        isFalse);

    // "Afslut smagningen" on the host lands on the guest as finished — the
    // reveal screen's cue to move to the summary.
    await host.repo.finish(tasting.id);
    await eventually(
      () async =>
          (await guest.repo.byId(tasting.id)).status == TastingStatus.finished,
      reason: 'the finish never reached the guest',
    );

    // A phone that dropped out during the last glass can still come back for
    // the final picture: the room is off the air, not gone.
    await guest.repo.guest.disconnect();
    await join();
    expect(guest.repo.guest.isConnected, isTrue);
  });

  test('a stranger cannot join an evening that is over', () async {
    await host.repo.advance(tasting.id, 1);
    await host.repo.finish(tasting.id);
    await expectLater(
      join(),
      throwsA(predicate((e) => '$e'.contains('Smagningen er slut'))),
    );
  });
}
