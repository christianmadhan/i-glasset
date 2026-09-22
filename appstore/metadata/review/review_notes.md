# Notes for App Review

Paste the relevant parts into App Store Connect → App Review Information → Notes.

## Sign-in

There are no accounts. The first screen asks only for a display name, which is
stored on the device and shown to the other phones in the room. No demo account
is needed — type any name and tap **Kom i gang**.

## What the app does

I Glasset is a blind-tasting companion for a group of friends in the same room.
One person (the host) enters the bottles on their phone. The other phones join
with a six-character code over the local Wi-Fi network, score each glass blind,
and guess grape, region, price, vintage etc. for points. When the host reveals a
glass, the bottle photo and the points appear on every phone.

The user interface is in Danish. The app is aimed at adults tasting wine, whisky
and similar; see the age rating below.

## How to exercise every screen on a single device

1. Enter a name → **Kom i gang**.
2. Home → **Opret smagning** (bottom of the Profil tab, or the group screen).
   Give the tasting a title and a number of glasses, then add a product with
   **Tilføj produkt**. A photo is optional; the camera and photo-library
   permission prompts appear here.
3. **Åbn venteværelset** puts the host phone on the local network. iOS will show
   the *Local Network* permission prompt at this point. The app remains fully
   usable if the permission is denied — the host can still run the tasting on
   their own phone.
4. **Start smagningen** → score the glass, tap **Gæt vinen** to fill the guess
   sheet, **Send bedømmelse**, then **Afslør produkt** to see the reveal screen,
   **Se stillingen** for the standings, and **Afslut smagningen** for the summary.
5. Groups: the **Grupper** tab → **Opret gruppe**. Standings and spend appear
   after a finished tasting.

A second device on the same Wi-Fi can join with the code shown in the lobby via
**Deltag med kode uden konto** on the first screen.

## Network use

The only network activity is device-to-device on the local network: the host
phone advertises a Bonjour service (`_iglasset._tcp`) and accepts TCP
connections from the guests. Nothing is sent to any server. There is no
analytics, advertising or third-party SDK that talks to the internet.

## Permissions used

| Permission | Why |
| --- | --- |
| Local Network (`NSLocalNetworkUsageDescription`, `NSBonjourServices`) | Find and join tastings on the other phones in the room |
| Camera | Photograph the bottles when setting up a tasting |
| Photo Library | Pick existing bottle photos when setting up a tasting |

All three are optional; every flow degrades gracefully when denied.

## Encryption

`ITSAppUsesNonExemptEncryption = false`. The app uses only the TLS/networking
primitives provided by iOS.

## Answers Apple asked for on the first submission (2.1 Information Needed)

Keep these in the Notes field on every future submission.

- **External services:** none — no server, no auth, no analytics, no ads, no
  payments, no AI. Device-to-device Bonjour + TCP on the local network only.
  Fonts are fetched once from Google Fonts by the `google_fonts` package and
  cached on the device.
- **Regional differences:** none; identical in all regions, Danish UI everywhere.
- **Regulated industry / protected material:** not applicable. The app does not
  sell alcohol and ships no third-party content.
- **User-generated content:** names, scores, notes and bottle photos are shared
  only with the phones that joined that tasting with the host's code, over the
  local network. No public feed, no user discovery, nothing stored by us. The
  host controls the code and ends the evening; any participant can leave.
- **Accounts:** none, therefore no account deletion. All data is on the device
  and removed with the app.
- **Screen recording:** `screen_recording_script.md` lists the flow to record.

## Contact

Christian Witt · christian@huce.dk
