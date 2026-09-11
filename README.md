# I Glasset

Blind-tasting app for wine, whisky and whatever else ends up in the glass.
A host builds a tasting, the phones in the room join with a code, everyone
scores blind and guesses for points, and each reveal puts the bottle photo on
every device.

- **Org / bundle id:** `dk.huce.iglasset`
- **Backend:** the device itself, with tastings shared phone-to-phone over the
  local Wi-Fi. Supabase is written and parked behind the same interfaces —
  see [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).
- **State:** Riverpod · **Routing:** go_router · **Language:** Danish throughout

## Getting started

```bash
flutter pub get
flutter run
```

That's it — no account, no server, no configuration. Two phones on the same
Wi-Fi can run a tasting together.

To switch to the hosted backend later:

```bash
flutter run --dart-define=BACKEND=supabase --dart-define-from-file=dart_define.json
```

Database setup for that day: [docs/SUPABASE_SETUP.md](docs/SUPABASE_SETUP.md).

## Screens

Implemented from `I Glasset.dc.html`:

| | |
| --- | --- |
| Log ind · Opret konto · Kom godt i gang | onboarding |
| Hjem · Grupper · Top · Profil | the four tabs |
| Find grupper · Opret gruppe · Gruppe | clubs, standings, spend, records |
| Opret smagning · Rediger smagning · Tilføj produkt | the host's build |
| Venteværelse · Live tasting · Smagsskema | the evening |
| Afsløring · Live resultater · Opsummering | the payoff |
| Tidligere smagning · Produkt · Mine topsmagninger · Smagsprofil | the archive |

## Layout

```
lib/
  core/config/          the backend switch (Env)
  core/constants/       the Danish option lists the guess sheet offers
  core/theme/           the three palettes, and the type roles
  core/widgets/         the shared component vocabulary
  core/router/          go_router routes
  core/providers.dart   every provider — and the only file that picks a backend
  data/models/          Tasting, TastingItem, Rating, Group, TastingConfig
  data/peer/            the wire format, the host, and the guest
  data/scoring/         the guess rules, in Dart
  data/local/           LocalMediaStore — the on-device image folder
  data/repositories/    the six interfaces, with local/ and supabase/ behind them
  features/             one folder per screen group
supabase/migrations/    the SQL for the day the hosted backend is switched on
```

## Three things worth knowing

**The evening is served by a phone.** The host's device binds a socket,
advertises `_iglasset._tcp` on the Wi-Fi, and answers the others. Discovery,
framing and the snapshot protocol are in `lib/data/peer/`.

**The blind is enforced at the point of sending.** Until a glass is revealed, a
guest's phone is sent its position and nothing else — no name, no price, not
even the photo. Host notes never travel at all. A guest's device is not trusted
to hide what it has been given.

**Points are the host's to award.** The host phone scores every guess at reveal
from its own answer key, and strips `points` from anything a guest sends up.

## Images never go in a database

A glass records a file name, a sha256 and a byte count. The photo itself lives
in `<app documents>/I Glasset/tastings/<id>/items/` — a folder iOS exposes in
the Files app — and travels to the other phones over the tasting socket, once,
only after that glass is revealed. Old tastings work with no network at all.

## Known gaps

- **App icon.** The real artwork (`assets/i-glasset-app-icon.png` in the Claude
  Design project) exceeds the design API's 256 KiB per-file limit and could only
  be fetched truncated. `AppMark` draws a stand-in; drop the full PNG into
  `assets/images/`, re-enable the `assets:` block in `pubspec.yaml`, and swap
  the widget body for an `Image.asset`. Launcher icons are Flutter's defaults
  for the same reason.
- **Local-mode limits** — same Wi-Fi, host stays in the app, no cross-device
  sync. Listed in full in [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).
