# Shipping I Glasset to the App Store

The project is configured and builds clean for release. What remains needs your
Apple account, so it can't be done from here.

## Already done

| | |
| --- | --- |
| Bundle id | `dk.huce.iglasset`, matching on iOS and Android |
| Display name | I Glasset |
| Version | `1.0.0+1` — `CFBundleShortVersionString` 1.0.0, build 1 |
| Deployment target | iOS 15.0 |
| Device family | iPhone only (`UIDeviceFamily = 1`) |
| App icon | Generated at every size; the 1024px marketing icon has no alpha, as Apple requires |
| Launch screen | Brand dark green with the mark — no white flash into the sign-in screen |
| Privacy manifest | `ios/Runner/PrivacyInfo.xcprivacy`, in Copy Bundle Resources and verified present in the built bundle |
| Export compliance | `ITSAppUsesNonExemptEncryption = false`, so App Store Connect stops asking each upload |
| Permission strings | Camera, photo library and local network, each saying what it's actually for, in Danish |
| Unused dependencies | Removed (`mobile_scanner`, `qr_flutter`, `cached_network_image`) |
| Release build | `flutter build ios --release` succeeds — 21.4 MB |

## What you need to do

### 1. Signing

You have a development certificate on this Mac, but not a distribution one.
In Xcode → Settings → Accounts, sign in with the Apple Developer account that
owns `dk.huce.*`, then in the Runner target → Signing & Capabilities tick
**Automatically manage signing** and pick the team.

```bash
open ios/Runner.xcworkspace
```

### 2. Create the app in App Store Connect

<https://appstoreconnect.apple.com> → Apps → **+** → New App.

- Platform: iOS
- Name: **I Glasset** (must be unique across the store — check it's free)
- Primary language: Danish
- Bundle ID: `dk.huce.iglasset`
- SKU: anything, e.g. `iglasset-001`

### 3. Age rating — read this one

The app is about tasting alcohol. In the questionnaire, answer
**"Alcohol, Tobacco, or Drug Use or References"** honestly — for an app whose
whole subject is wine and whisky that's *Frequent/Intense*, which lands you at
**17+**. Under-declaring is a common rejection.

Guideline 1.4.3 (apps that encourage excessive consumption) isn't a problem for
a structured tasting app, but don't add anything that gamifies drinking volume.

### 4. Privacy nutrition label

This is the easy part, and worth stating precisely because it's unusually clean:

- **Data collection: none.** Select "Data Not Collected".

There is no server, no analytics, no third-party SDK and no account. Tastings
are shared directly between the phones in the room over the local network;
photos and history stay on the device. If you later switch
`BACKEND=supabase`, this answer changes and the label must be updated.

### 5. Screenshots

Required: 6.7" (1290×2796). Strongly recommended: 6.5" and 5.5" too.

The screens that sell it best, in order: **Live tasting** (the hidden glass),
**Afsløring**, **Smagsskema**, **Gruppe** (the standings), **Hjem**.

Capture them from the simulator:

```bash
xcrun simctl boot "iPhone 15 Pro Max"
flutter run --release -d "iPhone 15 Pro Max"
xcrun simctl io booted screenshot ~/Desktop/iglasset-1.png
```

### 6. Metadata

- **Subtitle** (30 chars): something like `Smag blindt. Gæt. Sammenlign.`
- **Description**: lead with the blind tasting and the guessing game; say
  plainly that it needs no account and works on your own Wi-Fi — that's the
  differentiator.
- **Keywords**: vinsmagning, blindsmagning, whisky, smagning, vinklub, tasting
- **Support URL**: required. A GitHub Pages page or a simple contact page is fine.
- **Privacy policy URL**: required even when you collect nothing. It can be one
  short page saying exactly that.

### 7. Upload

```bash
flutter build ipa --release
open build/ios/archive/Runner.xcarchive
```

Then Xcode Organizer → Distribute App → App Store Connect. Or:

```bash
xcrun altool --upload-app -f build/ios/ipa/*.ipa -t ios \
  --apiKey <KEY_ID> --apiIssuer <ISSUER_ID>
```

## Test this before you submit

Review takes days; these are the things that fail late.

- [ ] **Two real devices, same Wi-Fi.** Host on one, join on the other. The
      simulator shares the Mac's network, so it does not prove the iOS
      **local network permission** prompt behaves — that prompt only appears on
      device, and if it's denied the app must still be usable. Test denying it.
- [ ] Camera and photo-library prompts, including **denying** both.
- [ ] Airplane mode: old tastings and their photos must still open.
- [ ] Background the host mid-tasting, come back, confirm the room recovers.
- [ ] A cold install: no profile, no data, no crash on first run.

## Known gaps before 1.0

- **The app icon is a placeholder.** It's a clean icon and it will pass review,
  but it is not the brand artwork. `assets/i-glasset-app-icon.png` in the Claude
  Design project exceeds the design API's 256 KiB per-file limit and could only
  be fetched truncated. To swap it in: drop the full PNG at
  `assets/icon/app_icon.png`, run `dart run flutter_launcher_icons`, and replace
  the body of `AppMark` with an `Image.asset`.
- **Android release signing** is not configured — `android/app/build.gradle.kts`
  still signs release with the debug key. Needed only when you go to Play.
