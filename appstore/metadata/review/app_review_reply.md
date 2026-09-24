# Reply to App Review — Guideline 2.1, Information Needed (1.0.0 build 2)

Paste the text below the line into the App Store Connect message thread
(limit 4000 characters), attach the screen recording, and paste the same text
into *App Review Information → Notes* before resubmitting.

---

Thank you for the review. Answers follow; the screen recording is attached.

1. SCREEN RECORDING
Attached, captured on an iPhone on the current iOS. It starts at launch and shows: entering a display name, creating a group and a tasting, adding bottles with a photo (Camera prompt), opening the room (Local Network prompt), a second phone joining with the code, scoring a blind glass, the guess sheet, the host revealing the glass, standings, finishing the evening, the archive, and signing out.
There is no account registration or login, hence no account deletion: the first screen asks only for a display name, stored on the device. Profil > "Slet alle mine data" erases everything the app holds (profile, groups, tastings, ratings, photos); the recording shows it. There is no paid content or in-app purchase.

2. PURPOSE AND AUDIENCE
I Glasset ("In the Glass") is a companion for blind tastings among friends, e.g. a wine club. Such evenings usually run on scraps of paper: one person knows the answers and nobody has a tally afterwards. In the app the host enters the bottles, the other phones in the room join with a six-character code, everyone scores each glass blind and guesses grape, region, vintage and price for points, and when the host reveals a glass the bottle photo and points appear on every phone. Groups keep standings between evenings. Audience: adults tasting wine and spirits socially (rated 17+). The interface is Danish, for the Danish market.

3. SETUP AND MAIN FEATURES
No credentials needed. On one device:
- Enter any name > Kom i gang.
- Grupper > Opret gruppe > name > save.
- Opret smagning i gruppen > title and number of glasses > save. Tap each glass to enter name, grape, country, region, vintage, alcohol, price and optionally a photo.
- Åbn venteværelset opens the room (Local Network prompt; the app works if denied).
- Start glas 1 > score with the slider > Gæt vinen (guess sheet) > Send bedømmelse > Afslør produkt > Se stillingen > Videre til glas 2 ... > Afslut smagningen.
- Finished tastings appear on Home and in the group; every glass is under Top with your score and notes.
Second device on the same Wi-Fi: Deltag med kode uden konto > type the code shown in the host's lobby. The guest sees only "Glas #1" until the host reveals it.

4. EXTERNAL SERVICES
None. No backend, authentication, analytics, advertising, payment or AI service. The only network activity is device-to-device on the local network: the host phone advertises a Bonjour service (_iglasset._tcp) and guests connect over a TCP socket; nothing is sent to the internet. Fonts are bundled in the app; nothing is downloaded at runtime. Photos come from the device camera or photo library. Built with Flutter.

5. REGIONAL DIFFERENCES
None. Identical functionality and content in all regions; Danish UI everywhere.

6. REGULATED INDUSTRY / PROTECTED MATERIAL
Not applicable. The app does not sell or serve alcohol and contains no third-party protected material. The only content is what users type or photograph, shared solely with the phones that joined that tasting with the host's code, over the local network. No public feed, no user discovery, nothing stored or transmitted by us. Moderation: the host can remove a participant from the room (lobby > "Fjern", or hold a name in the roster), which deletes that person's contributions and bars the code for them; any participant can leave at any time; Profil > "Rapportér indhold" reports content to us by e-mail.

Contact: Christian Witt, christian@huce.dk
