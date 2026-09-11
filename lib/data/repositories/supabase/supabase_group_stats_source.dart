import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/profile.dart';
import '../../models/rating.dart';
import '../../models/tasting.dart';
import '../../models/tasting_item.dart';
import '../group_stats.dart';

/// Group numbers, hosted. **Parked** alongside the other Supabase repositories.
///
/// RLS decides what actually comes back: other people's rows only appear once
/// the glass they belong to is revealed, so a tasting still in progress can't
/// leak through the group screen.
class SupabaseGroupStatsSource implements GroupStatsSource {
  SupabaseGroupStatsSource(this._client);

  final SupabaseClient _client;

  @override
  Future<List<GroupRatingRow>> groupRatings(String groupId) async {
    final rows = await _client
        .from('ratings')
        .select(
          '*, profiles(id, display_name, avatar_seed), '
          'tasting_items!inner(*, tastings!inner(*))',
        )
        .eq('tasting_items.tastings.group_id', groupId)
        .not('tasting_items.revealed_at', 'is', null);

    return rows.map<GroupRatingRow>((row) {
      final item = row['tasting_items'] as Map<String, dynamic>;
      final tasting = item['tastings'] as Map<String, dynamic>;
      return (
        rating: Rating.fromJson(row),
        taster: Profile.fromJson(row['profiles'] as Map<String, dynamic>),
        item: TastingItem.fromJson({...item, 'is_revealed': true}),
        tasting: Tasting.fromJson(tasting),
      );
    }).toList();
  }
}
