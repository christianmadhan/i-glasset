# App Privacy ("nutrition label")

Select **Data Not Collected**.

Why this is true for the shipping (local) build:

- No server. Tastings are exchanged phone-to-phone on the local network.
- No account. The display name lives only on the device and on the other
  phones in the room for the duration of a tasting.
- No analytics, crash reporting or advertising SDK.
- Photos and tasting history are stored in the app's own documents folder,
  which the user can see in the Files app and delete with the app.

If the app is ever switched to the hosted backend (`--dart-define=BACKEND=supabase`),
this answer changes (email address, user content, identifiers) and the label
must be updated before that build is submitted.

Privacy policy URL: https://huce.dk/privacy/iglasset
