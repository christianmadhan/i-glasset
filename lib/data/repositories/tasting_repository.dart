import '../models/profile.dart';
import '../models/rating.dart';
import '../models/tasting.dart';
import '../models/tasting_config.dart';
import '../models/tasting_item.dart';

/// One archived glass: what it was, who was pouring, and what you said.
typedef ArchiveEntry = ({Rating rating, TastingItem item, Tasting tasting});

/// Everything the app needs to know about tastings, independent of where the
/// data lives.
///
/// Two implementations exist:
///
/// * `LocalTastingRepository` — the device's own store, with the evening shared
///   phone-to-phone over the local network. This is what ships today.
/// * `SupabaseTastingRepository` — the hosted backend, ready to switch on.
///
/// Both are written against the same rules, so swapping them doesn't change a
/// single screen. In particular **both must redact unrevealed glasses**: a
/// participant's device is never sent the answer early, whether the blind is
/// enforced by a Postgres view or by the host phone.
abstract interface class TastingRepository {
  // ------------------------------------------------------------------ reading

  /// Everything this user hosts, has joined, or can see through a group.
  Future<List<Tasting>> myTastings({int limit});

  Future<List<Tasting>> finishedTastings({String? groupId, int limit});

  Future<Tasting> byId(String tastingId);

  /// Glasses as the *host* sees them: every field, plus host notes.
  Future<List<TastingItem>> hostItems(String tastingId);

  /// Glasses as a *participant* sees them — identifying fields are null until
  /// that glass is revealed.
  Future<List<TastingItem>> items(String tastingId);

  Future<List<({Profile profile, bool isHost})>> participants(String tastingId);

  /// Ratings for a whole tasting, filtered by the tasting's "Se andres
  /// karakterer" setting.
  Future<List<Rating>> ratings(String tastingId);

  Future<Rating?> myRating(String itemId);

  /// Every glass this user has ever scored and seen revealed.
  Future<List<ArchiveEntry>> myArchive({int limit});

  // ----------------------------------------------------------------- watching

  /// Emits when the tasting changes — the host moving on, or finishing.
  Stream<Tasting> watchTasting(String tastingId);

  /// Emits when any glass changes — in practice, when one is revealed.
  Stream<List<TastingItem>> watchItems(String tastingId);

  Stream<int> watchParticipantCount(String tastingId);

  /// Emits whenever *anything* about this tasting changes — a glass revealed,
  /// someone joining, a rating arriving.
  ///
  /// The read methods above are one-shot queries, so the UI needs a single
  /// signal to hang them off. Locally this fires on every host push and local
  /// write; against Supabase it merges the realtime subscriptions.
  Stream<int> watchRevisions(String tastingId);

  // ------------------------------------------------------------------ writing

  Future<Tasting> createTasting({
    required String title,
    String? groupId,
    String? theme,
    String? description,
    String category,
    DateTime? scheduledFor,
    TastingConfig config,
    String? joinCode,
  });

  Future<Tasting> updateTasting(
    String tastingId, {
    String? title,
    String? theme,
    String? description,
    String? category,
    DateTime? scheduledFor,
    TastingConfig? config,
    TastingStatus? status,
  });

  /// Opens the room and puts the host in it.
  Future<Tasting> openLobby(String tastingId);

  /// Returns the id of the tasting joined. Throws [TastingException] with a
  /// readable Danish message when the code is unknown or the room is closed.
  Future<String> joinByCode(String code);

  Future<void> leave(String tastingId);

  /// Moves the room to a glass. Position 0 means back to the lobby.
  Future<Tasting> advance(String tastingId, int position);

  /// Reveals one glass and settles everyone's guess points for it.
  Future<TastingItem> revealItem(String itemId);

  Future<Tasting> finish(String tastingId);

  // -------------------------------------------------------------------- items

  Future<TastingItem> createItem({
    required String tastingId,
    required int position,
  });

  Future<TastingItem> saveItem(TastingItem item);

  Future<void> deleteItem(String itemId);

  Future<void> reorderItems(List<TastingItem> ordered);

  // ------------------------------------------------------------------ ratings

  Future<Rating> saveRating(Rating rating);
}

/// An error with a message already written for the person reading it.
class TastingException implements Exception {
  const TastingException(this.message);

  final String message;

  @override
  String toString() => message;
}
