import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthUser;

import '../data/local/local_media_store.dart';
import '../data/models/group.dart';
import '../data/models/profile.dart';
import '../data/models/rating.dart';
import '../data/models/tasting.dart';
import '../data/models/tasting_item.dart';
import '../data/peer/tasting_guest.dart';
import '../data/peer/tasting_host.dart';
import '../data/repositories/auth_service.dart';
import '../data/repositories/group_repository.dart';
import '../data/repositories/group_stats.dart';
import '../data/repositories/local/local_auth_service.dart';
import '../data/repositories/local/local_group_repository.dart';
import '../data/repositories/local/local_group_stats_source.dart';
import '../data/repositories/local/local_media_service.dart';
import '../data/repositories/local/local_session.dart';
import '../data/repositories/local/local_store.dart';
import '../data/repositories/local/local_tasting_repository.dart';
import '../data/repositories/media_service.dart';
import '../data/repositories/supabase/supabase_auth_service.dart';
import '../data/repositories/supabase/supabase_group_repository.dart';
import '../data/repositories/supabase/supabase_group_stats_source.dart';
import '../data/repositories/supabase/supabase_media_service.dart';
import '../data/repositories/supabase/supabase_tasting_repository.dart';
import '../data/repositories/tasting_repository.dart';
import 'config/env.dart';
import 'theme/glas_theme.dart';

// ---------------------------------------------------------------------------
// the switch
// ---------------------------------------------------------------------------
//
// Every backend choice is made once, here. No screen knows or cares which
// implementation it got, so moving to the hosted backend is
// `--dart-define=BACKEND=supabase` and nothing else.

final localStoreProvider = Provider<LocalStore>((ref) {
  final store = LocalStore();
  ref.onDispose(store.dispose);
  return store;
});

final localSessionProvider = Provider<LocalSession>((ref) {
  final session = LocalSession(ref.watch(localStoreProvider));
  ref.onDispose(session.dispose);
  return session;
});

final localMediaStoreProvider =
    Provider<LocalMediaStore>((ref) => LocalMediaStore());

/// Only touched when [Env.isSupabase]; reading it in local mode would throw,
/// because `Supabase.initialize` is never called.
final supabaseClientProvider =
    Provider<SupabaseClient>((ref) => Supabase.instance.client);

/// The device-local repository, exposed concretely as well as behind the
/// interface — the join screen and lobby need the peer session it owns.
final localTastingRepositoryProvider = Provider<LocalTastingRepository>((ref) {
  final repository = LocalTastingRepository(
    ref.watch(localStoreProvider),
    ref.watch(localSessionProvider),
    ref.watch(localMediaStoreProvider),
  );
  ref.onDispose(repository.dispose);
  return repository;
});

final tastingRepositoryProvider = Provider<TastingRepository>(
  (ref) => Env.isSupabase
      ? SupabaseTastingRepository(ref.watch(supabaseClientProvider))
      : ref.watch(localTastingRepositoryProvider),
);

final groupRepositoryProvider = Provider<GroupRepository>(
  (ref) => Env.isSupabase
      ? SupabaseGroupRepository(ref.watch(supabaseClientProvider))
      : LocalGroupRepository(
          ref.watch(localStoreProvider),
          ref.watch(localSessionProvider),
        ),
);

final profileRepositoryProvider = Provider<ProfileRepository>(
  (ref) => Env.isSupabase
      ? SupabaseProfileRepository(ref.watch(supabaseClientProvider))
      : LocalProfileRepository(
          ref.watch(localStoreProvider),
          ref.watch(localSessionProvider),
        ),
);

final authServiceProvider = Provider<AuthService>(
  (ref) => Env.isSupabase
      ? SupabaseAuthService(ref.watch(supabaseClientProvider))
      : LocalAuthService(
          ref.watch(localStoreProvider),
          ref.watch(localSessionProvider),
        ),
);

final mediaServiceProvider = Provider<MediaService>(
  (ref) => Env.isSupabase
      ? SupabaseMediaService(
          ref.watch(supabaseClientProvider),
          ref.watch(localMediaStoreProvider),
        )
      : LocalMediaService(
          ref.watch(localMediaStoreProvider),
          ref.watch(localTastingRepositoryProvider),
        ),
);

final groupStatsSourceProvider = Provider<GroupStatsSource>(
  (ref) => Env.isSupabase
      ? SupabaseGroupStatsSource(ref.watch(supabaseClientProvider))
      : LocalGroupStatsSource(ref.watch(localStoreProvider)),
);

// ---------------------------------------------------------------------------
// the evening, phone to phone
// ---------------------------------------------------------------------------

/// The tastings being hosted on this Wi-Fi right now.
final nearbyTastingsProvider = StreamProvider<List<NearbyTasting>>((ref) {
  if (Env.isSupabase) return const Stream<List<NearbyTasting>>.empty();

  final nearby = ref.watch(localTastingRepositoryProvider).nearby;
  nearby.start();
  ref.onDispose(nearby.stop);
  return _startWith(nearby.stream, nearby.current);
});

/// Whether this device is currently serving an evening to others.
final hostStatusProvider = StreamProvider<HostStatus>((ref) {
  if (Env.isSupabase) return const Stream<HostStatus>.empty();
  return ref.watch(localTastingRepositoryProvider).host.status;
});

/// Whether this device is currently attached to someone else's evening.
final guestStateProvider = StreamProvider<GuestState>((ref) {
  if (Env.isSupabase) return const Stream<GuestState>.empty();
  return ref.watch(localTastingRepositoryProvider).guest.states;
});

Stream<T> _startWith<T>(Stream<T> stream, T value) async* {
  yield value;
  yield* stream;
}

// ---------------------------------------------------------------------------
// auth
// ---------------------------------------------------------------------------

final authStateProvider = StreamProvider<AuthUser?>(
  (ref) => ref.watch(authServiceProvider).changes,
);

final currentUserProvider = Provider<AuthUser?>((ref) {
  ref.watch(authStateProvider);
  return ref.watch(authServiceProvider).currentUser;
});

final currentUserIdProvider =
    Provider<String?>((ref) => ref.watch(currentUserProvider)?.id);

final myProfileProvider = FutureProvider<Profile?>((ref) async {
  ref.watch(currentUserProvider);
  return ref.watch(profileRepositoryProvider).me();
});

// ---------------------------------------------------------------------------
// preferences
// ---------------------------------------------------------------------------

/// A plain mutable value. Riverpod 3 retired StateProvider, and these pieces of
/// transient UI state don't warrant a class each.
class ValueController<T> extends Notifier<T> {
  ValueController(this._initial);

  final T _initial;

  @override
  T build() => _initial;

  void set(T value) => state = value;
}

/// Which of the three visual directions is in use. Persisted so it survives a
/// restart; the profile screen is where it's changed.
class ThemeController extends Notifier<GlasThemeName> {
  static const _key = 'glas_theme';

  @override
  GlasThemeName build() {
    _restore();
    return GlasThemeName.cellarModern;
  }

  Future<void> _restore() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_key);
    if (stored == null) return;
    final match = GlasThemeName.values.where((t) => t.name == stored);
    if (match.isNotEmpty) state = match.first;
  }

  Future<void> set(GlasThemeName theme) async {
    state = theme;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, theme.name);
  }
}

final themeProvider =
    NotifierProvider<ThemeController, GlasThemeName>(ThemeController.new);

/// The prototype's "Værtsvisning" switch, kept as a debug-only override so the
/// host layout can be inspected without a second device. Off in release.
final forceHostViewProvider =
    NotifierProvider<ValueController<bool>, bool>(() => ValueController(false));

// ---------------------------------------------------------------------------
// groups
// ---------------------------------------------------------------------------

final myGroupsProvider = FutureProvider<List<Group>>((ref) {
  ref.watch(currentUserIdProvider);
  return ref.watch(groupRepositoryProvider).myGroups();
});

final groupSearchProvider =
    NotifierProvider<ValueController<String>, String>(() => ValueController(''));

final discoverGroupsProvider = FutureProvider<List<Group>>((ref) {
  final query = ref.watch(groupSearchProvider);
  return ref.watch(groupRepositoryProvider).discover(query: query);
});

final groupProvider = FutureProvider.family<Group, String>((ref, groupId) {
  ref.watch(myGroupsProvider);
  return ref.watch(groupRepositoryProvider).byId(groupId);
});

final groupMembersProvider =
    FutureProvider.family<List<GroupMember>, String>((ref, groupId) {
  return ref.watch(groupRepositoryProvider).members(groupId);
});

final groupHistoryProvider =
    FutureProvider.family<List<Tasting>, String>((ref, groupId) {
  return ref.watch(tastingRepositoryProvider).finishedTastings(groupId: groupId);
});

/// The numbers on the group screen — leaderboard, spend, guess accuracy,
/// records. Derived on every load rather than cached, so they can never drift
/// from the ratings they came from.
final groupStatsProvider =
    FutureProvider.family<GroupStats, String>((ref, groupId) async {
  final rows = await ref.watch(groupStatsSourceProvider).groupRatings(groupId);
  final history = await ref.watch(groupHistoryProvider(groupId).future);
  return const GroupStatsCalculator().summarise(rows, history);
});

// ---------------------------------------------------------------------------
// tastings
// ---------------------------------------------------------------------------

final myTastingsProvider = FutureProvider<List<Tasting>>((ref) async {
  ref.watch(currentUserIdProvider);
  if (Env.isLocal) {
    await ref.watch(localTastingRepositoryProvider).warmCaches();
  }
  return ref.watch(tastingRepositoryProvider).myTastings();
});

final nextTastingProvider = FutureProvider<Tasting?>((ref) async {
  final all = await ref.watch(myTastingsProvider.future);
  final upcoming = all.where((t) => t.status.isOpen).toList()
    ..sort((a, b) {
      final da = a.scheduledFor ?? a.createdAt;
      final db = b.scheduledFor ?? b.createdAt;
      return da.compareTo(db);
    });
  return upcoming.isEmpty ? null : upcoming.first;
});

final recentTastingsProvider = FutureProvider<List<Tasting>>((ref) async {
  final all = await ref.watch(myTastingsProvider.future);
  return all.where((t) => t.status == TastingStatus.finished).take(5).toList();
});

/// The live tasting. Locally this is fed by the host's pushes over the socket;
/// against Supabase it's a realtime subscription. Either way a host moving on
/// lands on every screen without anyone refreshing.
final tastingStreamProvider =
    StreamProvider.family<Tasting, String>((ref, tastingId) {
  return ref.watch(tastingRepositoryProvider).watchTasting(tastingId);
});

final tastingProvider = FutureProvider.family<Tasting, String>((ref, tastingId) {
  ref.watch(tastingRevisionProvider(tastingId));
  return ref.watch(tastingRepositoryProvider).byId(tastingId);
});

/// Ticks whenever anything about a tasting changes. The one-shot reads below
/// watch it, so a glass revealed on the host's phone refreshes every list on
/// every phone without each screen wiring up its own subscription.
final tastingRevisionProvider =
    StreamProvider.family<int, String>((ref, tastingId) {
  return ref.watch(tastingRepositoryProvider).watchRevisions(tastingId);
});

/// Glasses as the signed-in user is allowed to see them: the full rows for the
/// host, the redacted view for everyone else.
final itemsProvider =
    FutureProvider.family<List<TastingItem>, String>((ref, tastingId) async {
  ref.watch(tastingRevisionProvider(tastingId));
  final repo = ref.watch(tastingRepositoryProvider);
  final tasting = await repo.byId(tastingId);
  final me = ref.watch(currentUserIdProvider);
  return tasting.isHostedBy(me)
      ? repo.hostItems(tastingId)
      : repo.items(tastingId);
});

final participantsProvider =
    FutureProvider.family<List<({Profile profile, bool isHost})>, String>(
        (ref, tastingId) {
  ref.watch(tastingRevisionProvider(tastingId));
  return ref.watch(tastingRepositoryProvider).participants(tastingId);
});

final participantCountProvider =
    StreamProvider.family<int, String>((ref, tastingId) {
  return ref.watch(tastingRepositoryProvider).watchParticipantCount(tastingId);
});

final ratingsProvider =
    FutureProvider.family<List<Rating>, String>((ref, tastingId) {
  ref.watch(tastingRevisionProvider(tastingId));
  return ref.watch(tastingRepositoryProvider).ratings(tastingId);
});

// ---------------------------------------------------------------------------
// personal archive
// ---------------------------------------------------------------------------

final archiveProvider = FutureProvider<List<ArchiveEntry>>((ref) async {
  ref.watch(currentUserIdProvider);
  if (Env.isLocal) {
    await ref.watch(localTastingRepositoryProvider).warmCaches();
  }
  return ref.watch(tastingRepositoryProvider).myArchive();
});

final topProductsFilterProvider =
    NotifierProvider<ValueController<String>, String>(
        () => ValueController('Alle'));

/// Everything the user has scored, best first, filtered by the chip row.
final topProductsProvider = FutureProvider<List<ArchiveEntry>>((ref) async {
  final all = await ref.watch(archiveProvider.future);
  final filter = ref.watch(topProductsFilterProvider);

  final matching = filter == 'Alle'
      ? all
      : all.where((e) {
          final type = e.item.productType ?? e.tasting.category;
          return type.toLowerCase() == filter.toLowerCase();
        }).toList();

  return matching.where((e) => e.rating.score != null).toList()
    ..sort((a, b) => b.rating.score!.compareTo(a.rating.score!));
});

final profileStatsProvider = FutureProvider<ProfileStats>((ref) async {
  final archive = await ref.watch(archiveProvider.future);
  final groups = await ref.watch(myGroupsProvider.future);
  final profile = await ref.watch(myProfileProvider.future);

  final scored = archive.where((e) => e.rating.score != null).toList();
  final tastingIds = archive.map((e) => e.tasting.id).toSet();

  return ProfileStats(
    products: archive.length,
    tastings: tastingIds.length,
    average: scored.isEmpty
        ? null
        : scored.fold<double>(0, (sum, e) => sum + e.rating.score!) /
            scored.length,
    groups: groups.where((g) => g.isMember).length,
    memberSince: profile?.createdAt,
  );
});

/// Whether the app should show host controls for a tasting. In debug builds the
/// prototype's host toggle can force this on.
bool isHostOf(WidgetRef ref, Tasting tasting) {
  if (kDebugMode && ref.watch(forceHostViewProvider)) return true;
  return tasting.isHostedBy(ref.watch(currentUserIdProvider));
}
