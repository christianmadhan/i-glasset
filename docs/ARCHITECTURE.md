# Where the data lives

The app runs against one of two backends. Which one is a build-time flag; no
screen knows the difference.

| | **local** (ships today) | **supabase** (parked) |
| --- | --- | --- |
| Storage | JSON documents in the app's own folder | Postgres |
| Sharing | Direct sockets between the phones in the room | Hosted, over the internet |
| Accounts | A name on the device | Email and password |
| The blind | The host phone redacts before sending | A Postgres view redacts before selecting |
| Guess points | The host phone settles them at reveal | `reveal_item()` settles them at reveal |
| Images | Sent over the tasting socket | Sent through a private storage bucket |

```bash
flutter run                                   # local
flutter run --dart-define=BACKEND=supabase \
            --dart-define-from-file=dart_define.json   # hosted
```

## The seam

Six interfaces in `lib/data/repositories/`:

```
TastingRepository   GroupRepository   ProfileRepository
AuthService         MediaService      GroupStatsSource
```

Each has two implementations — `local/` and `supabase/` — and
[`lib/core/providers.dart`](../lib/core/providers.dart) picks between them in one
place. That file is the only thing in the app that mentions either backend.

Two consequences worth knowing:

- **Screens never change when you switch.** They ask for
  `tastingRepositoryProvider` and get whatever was chosen.
- **The rules are duplicated on purpose.** The blind and the scoring exist twice:
  once in Dart ([`guess_scorer.dart`](../lib/data/scoring/guess_scorer.dart),
  `LocalTastingRepository._visibleItem`) and once in SQL
  ([`0001_init.sql`](../supabase/migrations/0001_init.sql)). They are tested
  against the same cases so an evening hosted on a phone and re-opened against
  Supabase later shows the same points.

## Phone to phone

Whoever creates a tasting hosts it. Their phone is the truth; everyone else
mirrors it.

```
   HOST                                    GUEST
   ────                                    ─────
   openLobby()
     ├─ ServerSocket.bind(port 0)
     └─ Bonjour: _iglasset._tcp
          TXT code=GLAS42 title=… host=… glasses=6 v=1
                                           │
                                           │  browse + resolve
                                           ▼
                                     Socket.connect(host, port)
                                           │
                     ◀───────────────  hello {profile, code}
      admit(): code? open? guest?
                     ───────────────▶  welcome {snapshot}
                                           │  write to own store
   reveal / advance / edit                 │
                     ───────────────▶  sync {snapshot}
                     ◀───────────────  rating {…}
      merge, persist, re-broadcast
                     ◀───────────────  requestImage {item}
                     ───────────────▶  image {…} + bytes
```

**Discovery** is Bonjour on the local Wi-Fi — no pairing, no account, no
internet. The TCP port is ephemeral and published in the record, so several
tastings can run in the same house without colliding.

**Framing.** TCP has no message boundaries, so each frame is length-prefixed:

```
[4 bytes] payload length   [4 bytes] header length   [header JSON]   [blob]
```

The blob is why: an 8 MB photo travels as raw bytes rather than base64, which
would cost 11 MB of string. `PeerDecoder` queues incoming chunks rather than
re-joining a growing buffer, because a photo arrives over a hundred packets and
concatenating each time would be quadratic.

**Conflicts don't arise.** Every writer owns a disjoint slice: the host owns the
tasting and the glasses, each guest owns their own rating. The host merges and
re-broadcasts; there is nothing to reconcile.

## What the host will not send

`LocalTastingRepository._visibleItem` is the whole blind. Until a glass is
revealed, a guest's snapshot carries its position and nothing else — no name, no
producer, no price, not even the photo path. Host notes never travel, revealed or
not.

This matters more here than with a server: a guest's phone is not trusted, so
the rule is enforced at the moment of sending rather than at the moment of
display. Same reason the Supabase build makes `tasting_items` host-only and
hands participants a view.

Likewise `applyRating` strips `points` from anything a guest sends, and refuses
edits to a glass that has already been revealed.

## What local mode cannot do

Honest limits, all of them consequences of there being no server:

- **Everyone must be on the same Wi-Fi.** No remote tastings.
- **The host must stay in the app** for the evening to keep running. Phones
  suspend sockets in the background.
- **Group discovery is local.** "Find grupper" lists the clubs this phone
  already knows; there is no directory to search. A group arrives when you join
  a tasting that belongs to one.
- **Standings only count evenings this phone attended.** Nothing back-fills.
- **Nothing syncs between your own devices.** One phone, one archive.

Each of these disappears when `BACKEND=supabase` is switched on.

## Turning Supabase on

1. Run the two migrations — see [SUPABASE_SETUP.md](SUPABASE_SETUP.md).
2. `cp dart_define.example.json dart_define.json` and fill in the values.
3. Run with `--dart-define=BACKEND=supabase --dart-define-from-file=dart_define.json`.

Existing local data is not migrated. Writing that import is the one piece of
work the switch still needs; the store is plain JSON, and the collection names
match the SQL tables one for one, so it is a read-and-insert rather than a
translation.
