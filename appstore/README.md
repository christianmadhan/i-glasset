# App Store kit for I Glasset

Everything App Store Connect asks for, ready to paste or upload. Regenerate the
images with the two scripts described at the bottom whenever the app's screens
change.

```
appstore/
  README.md                     this file — the submission checklist
  icon/AppIcon-1024.png         the marketing icon, no alpha (App Store Connect → App Icon)
  metadata/
    da-DK/                      primary language — one field per file
    en-US/                      optional English localisation, same fields
    review/
      review_notes.md           paste into App Review Information → Notes
      age_rating.md             the questionnaire answers (lands at 17+)
      privacy_labels.md         App Privacy → "Data Not Collected", and why
  screenshots/
    raw/                        untouched simulator captures, 1290×2796
    da-DK/iphone-6.7/           framed marketing shots with Danish captions (1290×2796)
    da-DK/iphone-6.5/           the same, 1242×2688
    da-DK/iphone-5.5/           the same, 1242×2208
    en-US/…                     English captions, all three sizes
```

## Field limits — all checked

| Field | Limit | da-DK | en-US |
| --- | --- | --- | --- |
| Name | 30 | I Glasset | I Glasset |
| Subtitle | 30 | 26 | 26 |
| Promotional text | 170 | 163 | 165 |
| Keywords | 100 | 90 | 95 |
| Description | 4000 | 1836 | 1919 |

## Submission checklist

1. **Signing** — Xcode → Runner target → Signing & Capabilities → Automatically
   manage signing, team `VX764PB74V`. A distribution certificate is created on
   first archive.
2. **Create the app** in App Store Connect: iOS · name *I Glasset* · primary
   language Danish · bundle id `dk.huce.iglasset` · SKU `iglasset-001`.
3. **App Information** → Age rating: answer per `metadata/review/age_rating.md`
   (alcohol = Frequent/Intense → 17+). Category: *Food & Drink*; secondary
   *Lifestyle*.
4. **App Privacy** → *Data Not Collected*. Privacy policy URL from
   `metadata/da-DK/privacy_url.txt`.
5. **Version 1.0.0** → paste `metadata/da-DK/*.txt` into the matching fields.
   Add the English localisation from `metadata/en-US/` if you want the listing
   to read in English for non-Danish devices.
6. **Screenshots** — upload `screenshots/da-DK/iphone-6.7/*.png` (required)
   and `iphone-6.5/`, `iphone-5.5/` (recommended). Upload in the numbered
   order; the first two are what people see in search results.
7. **App Review Information** → paste `metadata/review/review_notes.md`. No
   demo account exists — say so in the sign-in fields.
8. **EU trader** — the DSA trader status, the Labels & Markings URL
   (`https://huce.dk/labels/iglasset`) and the privacy URL are all served by the
   HUCE site; deploy the site before submitting.
9. **Build** — from the repo root:

   ```bash
   flutter build ipa --release
   open build/ios/archive/Runner.xcarchive
   ```

   Xcode Organizer → Distribute App → App Store Connect, then pick the build on
   the version page. Export compliance is answered by the Info.plist key, so no
   prompt appears.

10. **Before pressing Submit** — run the device checklist in
    [docs/RELEASE.md](../docs/RELEASE.md): two real phones on one Wi-Fi, denied
    permissions, airplane mode, host backgrounded mid-tasting, cold install.

## Regenerating the images

The raw captures come from an iPhone 15 Pro Max simulator with the status bar
overridden to 9:41, full battery and full signal:

```bash
xcrun simctl status_bar booted override --time 9:41 --batteryState charged --batteryLevel 100 --wifiBars 3 --cellularBars 4
xcrun simctl io booted screenshot --type=png appstore/screenshots/raw/05-live.png
```

The framed marketing shots are composed by `tools/appstore/market.py` from the
raw captures (captions and order live at the top of that script), and the
seeded demo data the screens show comes from `tools/appstore/seed.py`, which
writes a complete wine club — profiles, a group, three finished tastings and
one live one, with rendered bottle photos — straight into the simulator's app
container:

```bash
python3 -m venv .venv && .venv/bin/pip install pillow fonttools brotli
CONTAINER=$(xcrun simctl get_app_container booted dk.huce.iglasset data)
xcrun simctl terminate booted dk.huce.iglasset
.venv/bin/python tools/appstore/seed.py "$CONTAINER/Documents"
xcrun simctl launch booted dk.huce.iglasset
# …capture the raw screens, then:
.venv/bin/python tools/appstore/market.py appstore/screenshots/raw appstore/screenshots tools/appstore/fonts
```

`tools/appstore/fonts/` holds Libre Caslon Text and Public Sans (both SIL Open
Font License), the faces the app itself uses.
