import '../../models/profile.dart';
import '../../models/rating.dart';
import '../../models/tasting.dart';
import '../../models/tasting_item.dart';
import '../group_stats.dart';
import 'local_store.dart';

/// Group numbers, from what this device has seen.
///
/// A club's standings are only as complete as the evenings this phone took part
/// in — which is the honest answer without a server, and matches what the host
/// actually shared at the time.
class LocalGroupStatsSource implements GroupStatsSource {
  LocalGroupStatsSource(this._store);

  final LocalStore _store;

  @override
  Future<List<GroupRatingRow>> groupRatings(String groupId) async {
    final tastings = {
      for (final row in await _store.where(
        LocalStore.tastings,
        (row) => row['group_id'] == groupId,
      ))
        row['id'] as String: row,
    };
    if (tastings.isEmpty) return [];

    final items = {
      for (final row in await _store.where(
        LocalStore.items,
        (row) =>
            tastings.containsKey(row['tasting_id']) &&
            row['revealed_at'] != null,
      ))
        row['id'] as String: row,
    };
    if (items.isEmpty) return [];

    final ratings = await _store.where(
      LocalStore.ratings,
      (row) => items.containsKey(row['tasting_item_id']),
    );

    final out = <GroupRatingRow>[];
    for (final rating in ratings) {
      final profile = await _store.byId(
        LocalStore.profiles,
        rating['user_id'] as String,
      );
      if (profile == null) continue;

      final item = items[rating['tasting_item_id']]!;
      out.add((
        rating: Rating.fromJson(rating),
        taster: Profile.fromJson(profile),
        item: TastingItem.fromJson({...item, 'is_revealed': true}),
        tasting: Tasting.fromJson(tastings[item['tasting_id']]!),
      ));
    }
    return out;
  }
}
