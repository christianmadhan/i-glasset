# Google Play kit for I Glasset

The Android counterpart of [appstore/](../appstore/README.md). The app itself
is ready: `flutter build appbundle --release` produces a bundle, the manifest
carries the permissions the local-network discovery needs, the adaptive icon is
generated, and `targetSdk` follows Flutter's default (API 36), which satisfies
Play's target-level policy for new apps.

```
playstore/
  README.md                         this file — the submission walk-through
  metadata/da-DK/                   title (30), short description (80), full description (4000)
  metadata/en-US/                   the same in English
  graphics/icon-512.png             hi-res icon, 512×512 PNG
  graphics/feature-graphic-1024x500.png
  screenshots/da-DK/phone/          framed phone screenshots, 1080×2160 (Play's 2:1 limit)
  screenshots/en-US/phone/
  screenshots/raw/                  untouched emulator captures, 1080×2400
```

## What can be done from the terminal, and what cannot

Google's publishing API (driven here by fastlane, set up in `android/fastlane/`)
covers everything *after* the app exists in the console. These steps are
console-only, once:

| Console only (you) | Terminal (`fastlane`, from `android/`) |
| --- | --- |
| Create the developer account, pay, verify identity | `fastlane android build` — signed bundle |
| *Create app* (name, language, free) | `fastlane android internal` — upload bundle to internal testing |
| Content rating, target audience, data safety, app access, ads declarations | `fastlane android listing` — descriptions, icon, feature graphic, screenshots, changelogs |
| Create a service account and grant it Play access | `fastlane android promote` — internal → production |
| The very first bundle upload (the API refuses until one exists) | every later upload |
| Countries, pricing, review submission | |

Service account for the API: Google Cloud Console → IAM → Service accounts →
create one, make a JSON key, save it as `~/Keys/iglasset-play-api.json`
(anywhere outside git; set `PLAY_JSON_KEY` if elsewhere). Then Play Console →
Users and permissions → Invite user → the service account's e-mail → grant
*Release to production* and *Manage store presence* for I Glasset.

The store text and images fastlane pushes live in
`android/fastlane/metadata/android/<locale>/` — the same content as
`playstore/`, in the layout the tool expects.

## 1. Create the upload key — once, and keep it forever

**Done on 2026-09-21**: `~/Keys/iglasset-upload.jks` (alias `upload`, PKCS12,
RSA 4096, valid to 2054) with a generated password stored in the git-ignored
`android/key.properties`. Copy both to a password manager now; the keystore is
not backed up anywhere else. If it is ever lost before the first upload, just
run the command below again. After the first upload, Play support has to reset
it.

Play signs the APKs it ships with a key Google holds (Play App Signing). You
sign the bundle you *upload* with your own **upload key**. Lose it and you can
still recover through Play support, but don't plan on it.

```bash
keytool -genkey -v -keystore ~/Keys/iglasset-upload.jks -storetype JKS \
  -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

Then create `android/key.properties` (git-ignored; template in
`android/key.properties.example`):

```
storeFile=/Users/christianwitt/Keys/iglasset-upload.jks
storePassword=…
keyAlias=upload
keyPassword=…
```

`android/app/build.gradle.kts` picks this up automatically. Without the file a
release build is signed with the debug key and Play rejects it, which is the
intended failure mode.

## 2. Build the bundle

```bash
flutter build appbundle --release
```

Output: `build/app/outputs/bundle/release/app-release.aab`. Play only accepts
bundles, not APKs. Every upload needs a higher version code — bump the `+N` in
`pubspec.yaml` (`1.0.0+1` → `1.0.0+2`) before each new upload; the name part
can stay.

## 3. Play Console account

<https://play.google.com/console> — one-time USD 25 registration, then identity
verification.

- **Organisation account** (recommended for HUCE, since the app is published
  under the company): needs a D-U-N-S number for the company, and a verified
  website/e-mail on the huce.dk domain. No tester quota.
- **Personal account** created after November 2023: before you can apply for
  production you must run a **closed test with at least 12 opted-in testers
  for 14 consecutive days**. Budget two to three weeks for that.

## 4. Create the app

Console → *Create app*: name **I Glasset**, default language **Danish
(Denmark)**, *App*, *Free*. Accept the declarations.

Then work through the *Set up your app* checklist on the dashboard:

| Task | Answer |
| --- | --- |
| Privacy policy | `https://huce.dk/privacy/iglasset` |
| App access | *All functionality is available without special access* — there is no login, only a display name |
| Ads | No |
| Content rating | Start the IARC questionnaire, category *Utility / Productivity / Other*. Answer **yes** to references to alcohol; everything else no. Expect a PEGI 16 / ESRB Teen-to-Mature rating — do not under-declare. |
| Target audience | **18 and over** only. Not appealing to children. |
| News app | No |
| Data safety | See below |
| Government app | No |
| Financial features | No |
| Health | No |
| App category | Food & Drink |
| Contact details | christian@huce.dk; website `https://huce.dk/products/iglasset` |

### Data safety

The honest answer for the shipping local build: **the app does not collect or
share user data**. Nothing is transmitted to HUCE or to any third party; there
is no analytics or advertising SDK. Two things to state consciously:

- Tasting data (display name, scores, guesses, bottle photos after reveal)
  travels **directly to the other participants' phones over the local Wi-Fi**.
  That is device-to-device between users the person chose to taste with, not a
  transfer to the developer, so it does not count as "collection" in Play's
  definition — but if a reviewer asks, that is the explanation.
- If the Supabase backend is ever switched on, this form must be redone
  (account e-mail, user content, identifiers), exactly like the iOS label.

Also tick *Data is encrypted in transit*: **No** is the truthful answer for the
local socket protocol, which is unencrypted on the room's own network. Play
allows "No" when no data is collected.

## 5. Store listing

*Grow → Store presence → Main store listing*:

- App name, short and full description from `metadata/da-DK/` (limits: 30 / 80 / 4000).
- Add the English translation from `metadata/en-US/` under *Manage translations*.
- App icon: `graphics/icon-512.png`.
- Feature graphic: `graphics/feature-graphic-1024x500.png` (required).
- Phone screenshots: upload `screenshots/da-DK/phone/*.png` in numbered order
  (minimum 2, maximum 8; PNG/JPEG, no alpha, 320–3840 px, aspect at most 2:1).
  No tablet screenshots are needed for a phone-only listing.

## 6. Release

1. *Testing → Internal testing*: create a release, upload the `.aab`, add
   yourself and a few phones as testers by e-mail, roll out. Installs within
   minutes via the opt-in link — this is the fastest way to get the real build
   onto two Android phones.
2. *Closed testing* (mandatory for personal accounts, optional otherwise) — same
   bundle, promote from internal.
3. *Production*: countries (Denmark, or worldwide), release notes from
   `metadata/*/release_notes.txt`, then *Review release → Start rollout*. First
   review of a new app typically takes a few days; later updates are usually
   hours.

## Test on Android before you submit

The iOS checklist in [docs/RELEASE.md](../docs/RELEASE.md) applies, plus:

- [ ] **Two Android phones, and one Android + one iPhone, on the same Wi-Fi.**
      Discovery uses mDNS; Android needs the multicast lock the manifest
      declares. Some routers (guest networks, "AP isolation") block it — the
      app must say so rather than hang.
- [ ] Photo picking on Android 13+ uses the system photo picker and needs no
      permission prompt; on Android 12 and below the storage prompt appears.
      Deny it and confirm the tasting still works without photos.
- [ ] Back gesture and the system back button on every night screen: leaving a
      live tasting must ask, the way "← Forlad" does.
- [ ] Battery saver / Doze on the **host** phone: background the host for five
      minutes mid-tasting and confirm guests reconnect.
- [ ] Launch screen: Android still shows the default white/black system window
      before the first Flutter frame (iOS got a branded one). Cosmetic; fix in
      `android/app/src/main/res/drawable*/launch_background.xml` if it bothers you.
- [ ] Cold install from Play (internal testing track), not from `flutter run`.

## Regenerating the graphics

Raw captures come from the `Medium_Phone_API_36` emulator with the status bar
in demo mode (09:41, full battery and signal). The demo data is the same wine
club as on iOS, pushed into the debug build's private storage with `run-as`:

```bash
emulator -avd Medium_Phone_API_36 &
flutter build apk --debug && adb install -r build/app/outputs/flutter-apk/app-debug.apk
.venv/bin/python tools/appstore/seed.py /tmp/seed
(cd /tmp/seed && tar cf ../seed.tar "I Glasset") && adb push /tmp/seed.tar /data/local/tmp/seed.tar
adb shell am force-stop dk.huce.iglasset
adb shell "cat /data/local/tmp/seed.tar | run-as dk.huce.iglasset sh -c 'mkdir -p app_flutter && tar xf - -C app_flutter'"
adb shell monkey -p dk.huce.iglasset -c android.intent.category.LAUNCHER 1
adb exec-out screencap -p > playstore/screenshots/raw/05-live.png
# …then frame them:
.venv/bin/python tools/appstore/market.py playstore/screenshots/raw playstore/screenshots tools/appstore/fonts play
```

The feature graphic and 512 px icon are produced by `tools/appstore/play_graphics.py`.
