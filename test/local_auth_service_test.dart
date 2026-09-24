import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:i_glasset/data/local/local_media_store.dart';
import 'package:i_glasset/data/models/tasting.dart';
import 'package:i_glasset/data/repositories/local/local_auth_service.dart';
import 'package:i_glasset/data/repositories/local/local_session.dart';
import 'package:i_glasset/data/repositories/local/local_store.dart';
import 'package:i_glasset/data/repositories/local/local_tasting_repository.dart';

/// Whose phone is this? The device-only build has one profile per phone, and
/// signing out must not turn the owner into a stranger.
void main() {
  late Directory temp;
  late LocalStore store;
  late LocalSession session;
  late LocalAuthService auth;
  late LocalTastingRepository repo;
  late LocalMediaStore media;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('i_glasset_auth');
    store = LocalStore(root: temp);
    session = LocalSession(store);
    auth = LocalAuthService(store, session);
    media = LocalMediaStore(root: temp);
    repo = LocalTastingRepository(store, session, media);
  });

  tearDown(() async {
    await repo.dispose();
    await store.dispose();
    await session.dispose();
    if (await temp.exists()) await temp.delete(recursive: true);
  });

  test('signing out and back in keeps the profile and its tastings', () async {
    final me = await auth.signUp(displayName: 'Martin');
    final tasting = await repo.createTasting(title: 'Piemonte-aften');

    await auth.signOut();
    expect(auth.currentUser, isNull);

    final again = await auth.signUp(displayName: 'Martin Holm');
    expect(again.id, me.id);

    final mine = await repo.myTastings();
    expect(mine.map((t) => t.id), contains(tasting.id));

    final profiles = await store.all(LocalStore.profiles);
    expect(profiles, hasLength(1));
    expect(profiles.single['display_name'], 'Martin Holm');
    expect(profiles.single['is_guest'], isFalse);
  });

  test('coming back as a guest reuses the remembered profile too', () async {
    final me = await auth.signUp(displayName: 'Martin');
    await auth.signOut();

    final guest = await auth.signInAsGuest();
    expect(guest.id, me.id);
    expect(guest.isAnonymous, isFalse);
    expect(await store.all(LocalStore.profiles), hasLength(1));
  });

  test('a fresh phone still gets a fresh identity', () async {
    final guest = await auth.signInAsGuest();
    expect(guest.isAnonymous, isTrue);
    await auth.signOut();

    // Forgetting is what "Slet alle mine data" does before wiping.
    await session.forget();
    final next = await auth.signUp(displayName: 'Ny');
    expect(next.id, isNot(guest.id));
  });

  test('wiping the store leaves nothing and keeps working', () async {
    await auth.signUp(displayName: 'Martin');
    await repo.createTasting(title: 'Aften');
    await session.forget();
    await store.wipe();
    await media.wipe();

    expect(await store.all(LocalStore.tastings), isEmpty);
    expect(await store.all(LocalStore.profiles), isEmpty);
    expect(await session.restore(), isNull);

    // The folder was deleted underneath the store; a new write must succeed.
    final user = await auth.signUp(displayName: 'Igen');
    expect((await store.byId(LocalStore.profiles, user.id))?['display_name'],
        'Igen');
  });

  group('removing a participant', () {
    test('bars the code for them and drops their ratings', () async {
      await auth.signUp(displayName: 'Vært');
      final tasting = await repo.createTasting(title: 'Aften');
      await repo.updateTasting(tasting.id, status: TastingStatus.lobby);
      final glass = await repo.createItem(tastingId: tasting.id, position: 1);

      const guestId = 'guest-1';
      final guestProfile = {
        'id': guestId,
        'display_name': 'Gæsten',
        'avatar_seed': 'abc',
        'created_at': '2026-01-01T00:00:00.000Z',
      };
      expect(await repo.admit(joinCode: tasting.joinCode, profile: guestProfile),
          isNull);
      await repo.applyRating(guestId, {
        'tasting_item_id': glass.id,
        'score': 7.0,
      });
      expect(await repo.participants(tasting.id), hasLength(2));
      expect(await repo.ratings(tasting.id), hasLength(1));

      await repo.removeParticipant(tasting.id, guestId);

      expect(await repo.participants(tasting.id), hasLength(1));
      expect(await repo.ratings(tasting.id), isEmpty);
      expect(
        await repo.admit(joinCode: tasting.joinCode, profile: guestProfile),
        'Værten har fjernet dig fra smagningen.',
      );
      // The door list stays with the host.
      final snapshot =
          await repo.snapshotFor('someone', joinCode: tasting.joinCode);
      expect(snapshot.tasting.containsKey('blocked_user_ids'), isFalse);
    });

    test('the host cannot remove themself', () async {
      final me = await auth.signUp(displayName: 'Vært');
      final tasting = await repo.createTasting(title: 'Aften');
      expect(repo.removeParticipant(tasting.id, me.id), throwsA(anything));
    });
  });
}
