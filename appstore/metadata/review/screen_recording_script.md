# Screen recording for App Review — shot list

Apple wants one continuous recording, on a physical iPhone running the latest
iOS, starting from the app launch. Record with the built-in screen recorder
(Control Center → Record), landscape not needed. Aim for 3–4 minutes. Use a
second phone (iPhone or Android) on the same Wi-Fi as the guest; if the
reviewer sees two devices interacting, the "no server" claim explains itself.

Before you start: delete the app and reinstall the TestFlight/App Store build
so the recording begins on a cold start with the name screen. Put both phones
on the same Wi-Fi.

| # | On the host phone (recorded) | Say nothing — just let it show |
| --- | --- | --- |
| 1 | Launch the app. | Sign-in screen: only a name is asked for. |
| 2 | Type a name, tap **Kom i gang**. | Home, empty. |
| 3 | Profil → **Kom godt i gang**, page through the four onboarding cards, **Færdig**. | Explains the concept. |
| 4 | Grupper → **Opret gruppe**, name it, save. | Group screen. |
| 5 | **Opret smagning i gruppen**: title, 2–3 glasses, save. | Program screen with the join code. |
| 6 | **Tilføj glas** / edit glass 1: name, grape, country, region, price, take a photo of a bottle (Camera permission prompt appears — allow). Fill glass 2 quickly. | Camera prompt visible on device. |
| 7 | **Åbn venteværelset**. iOS shows the *Local Network* permission prompt — allow. | Lobby with the code. |
| 8 | On the second phone: open the app → **Deltag med kode uden konto** → type the code → it appears in the host's lobby. Hold the second phone into frame for a second if you can. | Proves phone-to-phone joining. |
| 9 | **Start glas 1**. Score with the slider, write a note, **Gæt vinen**, pick a few chips, **Færdig med gættet**, **Send bedømmelse**. | The blind glass; the guess sheet. |
| 10 | Roster shows who has scored. **Afslør produkt**. | Reveal: photo, details, points. |
| 11 | **Se stillingen**, back, **Videre til glas 2**. Repeat scoring briefly, reveal, **Afslut smagningen**. | Summary screen. |
| 12 | Home → the finished tasting → tap a glass → product screen with your note. | Archive. |
| 13 | Profil → **Log ud** → confirm. | Shows there is no account to delete; data lives on the device and is removed with the app. |

Upload the file in the App Store Connect reply (it accepts video), and keep a
copy in this folder as `app-review-recording.mp4` (git-ignored by size — store
it outside git if it is large).
