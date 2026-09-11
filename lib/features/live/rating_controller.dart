import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/providers.dart';
import '../../data/models/rating.dart';
import '../../data/models/tasting_config.dart';

/// The draft of what you're saying about the glass in front of you.
///
/// Every change lands in local state immediately so the sliders and chips stay
/// responsive, and is written to Supabase on a short debounce — enough that a
/// backgrounded app or a dropped connection doesn't cost someone their notes,
/// without a round trip per pixel of slider drag.
class RatingController extends AsyncNotifier<Rating> {
  RatingController(this.itemId);

  /// The glass this draft belongs to. Family notifiers take their argument
  /// through the constructor in Riverpod 3.
  final String itemId;

  static const _uuid = Uuid();
  Timer? _debounce;

  @override
  Future<Rating> build() async {
    ref.onDispose(() => _debounce?.cancel());

    final existing =
        await ref.watch(tastingRepositoryProvider).myRating(itemId);
    if (existing != null) return existing;

    return Rating.empty(
      id: _uuid.v4(),
      tastingItemId: itemId,
      userId: ref.watch(currentUserIdProvider) ?? '',
    );
  }

  Rating get _current => state.value!;

  void _update(Rating next, {bool persist = true}) {
    state = AsyncData(next);
    if (persist) _schedule();
  }

  void _schedule() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 600), save);
  }

  /// Writes the draft. Safe to call repeatedly — the row is upserted on
  /// (tasting_item_id, user_id).
  Future<void> save() async {
    _debounce?.cancel();
    final draft = state.value;
    if (draft == null || draft.userId.isEmpty) return;

    try {
      final saved =
          await ref.read(tastingRepositoryProvider).saveRating(draft);
      // Keep the server's id so later upserts update the same row.
      state = AsyncData(saved);
    } on Object {
      // A failed save leaves the draft in memory; the next change retries.
    }
  }

  void setScore(double score) => _update(_current.copyWith(score: score));

  void setNotes(String notes) => _update(_current.copyWith(notes: notes));

  /// Aroma and flavour notes are capped — the cap is what makes a guess a
  /// choice rather than a shotgun.
  void toggleAroma(String value, {int max = 4}) {
    final list = [..._current.guessAromas];
    if (list.contains(value)) {
      list.remove(value);
    } else if (list.length < max) {
      list.add(value);
    } else {
      return;
    }
    _update(_current.copyWith(guessAromas: list));
  }

  void toggleFlavour(String value, {int max = 4}) {
    final list = [..._current.guessFlavours];
    if (list.contains(value)) {
      list.remove(value);
    } else if (list.length < max) {
      list.add(value);
    } else {
      return;
    }
    _update(_current.copyWith(guessFlavours: list));
  }

  void setGrape(String? value) => _update(
        value == null || value == _current.guessGrape
            ? _current.copyWith(clearGrape: true)
            : _current.copyWith(guessGrape: value),
      );

  void setCountry(String? value) => _update(
        value == null || value == _current.guessCountry
            ? _current.copyWith(clearCountry: true)
            : _current.copyWith(guessCountry: value),
      );

  void setRegion(String? value) => _update(
        value == null || value == _current.guessRegion
            ? _current.copyWith(clearRegion: true)
            : _current.copyWith(guessRegion: value),
      );

  void setExtra(String? value) => _update(
        value == null || value == _current.guessExtra
            ? _current.copyWith(clearExtra: true)
            : _current.copyWith(guessExtra: value),
      );

  void setPrice(double value) => _update(_current.copyWith(guessPrice: value));

  void setAbv(double value) => _update(_current.copyWith(guessAbv: value));

  void setVintage(int value) =>
      _update(_current.copyWith(guessVintage: value));

  /// "Send bedømmelse". Stamps the submission time and writes immediately —
  /// this one isn't debounced, because the host is waiting on the count.
  Future<void> submit() async {
    _update(_current.copyWith(submittedAt: DateTime.now()), persist: false);
    await save();
  }

  /// "Ret" — reopen a submitted rating. The database refuses this once the
  /// glass is revealed, so the button is hidden by then.
  Future<void> unsubmit() async {
    _update(_current.copyWith(clearSubmitted: true), persist: false);
    await save();
  }

  /// Sensible starting points for the three sliders, so a guest who opens the
  /// sheet and drags nothing still submits something meaningful.
  void seedDefaults(TastingConfig config) {
    var draft = _current;
    if (config.isOn(GuessCategory.pris) && draft.guessPrice == null) {
      draft = draft.copyWith(guessPrice: 250);
    }
    if (config.isOn(GuessCategory.alkohol) && draft.guessAbv == null) {
      draft = draft.copyWith(guessAbv: 13.5);
    }
    if (config.isOn(GuessCategory.argang) && draft.guessVintage == null) {
      draft = draft.copyWith(guessVintage: DateTime.now().year - 4);
    }
    if (draft.score == null) {
      draft = draft.copyWith(score: 7.0);
    }
    if (!identical(draft, _current)) _update(draft, persist: false);
  }
}

final ratingProvider =
    AsyncNotifierProvider.family<RatingController, Rating, String>(
  RatingController.new,
);
