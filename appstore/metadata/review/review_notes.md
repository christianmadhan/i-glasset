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

## Contact

Christian Witt · christian@huce.dk
