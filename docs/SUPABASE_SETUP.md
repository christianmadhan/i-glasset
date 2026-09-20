# Supabase setup for I Glasset

Two SQL files do the real work; the rest is dashboard clicking.

- `supabase/migrations/0001_init.sql` — tables, the blind-safe view, RPCs, scoring, RLS, realtime
- `supabase/migrations/0002_storage.sql` — the `tasting-media` bucket and its policies
- `supabase/migrations/0003_optional_extra.sql` — "Det ekstraordinære" only counts on glasses that have one; the view tells guests whether a blind glass does

---

## 1. Create the project

1. <https://supabase.com/dashboard> → **New project**.
2. Name it `i-glasset`, region **EU (Frankfurt)** — closest to DK and keeps personal
   data in the EU. Store the database password somewhere safe.
3. Wait for provisioning (~2 minutes).

## 2. Run the schema

**Dashboard route:**

1. **SQL Editor** → **New query** → paste all of `0001_init.sql` → **Run**.
2. New query → paste `0002_storage.sql` → **Run**.
3. New query → paste `0003_optional_extra.sql` → **Run**.

**CLI route** (preferred once you have more than one environment):

```bash
brew install supabase/tap/supabase
supabase login
supabase link --project-ref YOUR-PROJECT-REF
supabase db push
```

### What the schema gives you

| Object | Purpose |
| --- | --- |
| `profiles` | One row per auth user, created by the `on_auth_user_created` trigger. |
| `groups`, `group_members` | The clubs. `access` is `open` / `approval` / `private`; the creator becomes owner via trigger. |
| `tastings` | An evening. Holds the join code, the current glass, and a `config` document with every "Format og regler" switch. |
| `tasting_items` | The glasses, with the answers: name, producer, grape, region, vintage, ABV, price, the correct aroma/flavour notes, and the one "extraordinary" fact. Each has its own `revealed_at`. |
| `tasting_items_visible` | **The view participants read.** Returns `null` for every identifying column until *that glass* is revealed. |
| `participants` | Who is in the room. No INSERT policy — you join only via `join_tasting()`. |
| `ratings` | One row per person per glass: the score, the notes, and the guess. `points` / `points_total` are written only by the server. |

### The functions

| Function | Who | What it does |
| --- | --- | --- |
| `join_tasting(code)` | anyone signed in | Validates the code and the "Kun gruppen" rule, then enrols the caller. |
| `join_group(code)` / `request_group_membership(id)` | anyone signed in | Joins outright or records a pending request, depending on the group's access. |
| `advance_tasting(id, position)` | host | Moves the room to a glass. |
| `reveal_item(id)` | host | Reveals one glass **and settles everyone's guess points in the same statement**. |
| `finish_tasting(id)` | host | Closes the evening. |

## 3. Two things worth understanding

**The blind is enforced by the database, not the app.** RLS is row-level and
cannot hide individual columns, so if participants could select `tasting_items`
they would simply read the answers. Instead the base table's select policy is
**host-only**, and `tasting_items_visible` runs as its owner with its own access
test in the WHERE clause. A guest's device never receives the name of a wine it
hasn't been shown.

**Points can't be self-awarded.** `reveal_item()` computes each rating's score
server-side from the host's answer key, and a trigger (`ratings_guard_points`)
strips `points` and `points_total` from any client write. The rules it applies
are the ones printed on the guess sheet — 1 pt per matched note up to the cap,
all-or-nothing on the grape, tiered by closeness on price, and so on.

## 4. Verify RLS

**Database → Tables** — every table in `public` should show *RLS enabled*. This
should return zero rows:

```sql
select tablename
from pg_tables
where schemaname = 'public' and rowsecurity = false;
```

## 5. Storage

`0002_storage.sql` created the bucket. Confirm under **Storage**: `tasting-media`,
**not public**, 8 MB limit, image MIME types only.

Optional, recommended — enable **pg_cron** (Database → Extensions) and schedule
the cleanup so cloud copies don't linger after everyone has synced:

```sql
select cron.schedule(
  'purge-tasting-media',
  '0 4 * * *',
  $$select public.purge_synced_tasting_media()$$
);
```

## 6. Auth

**Authentication → Providers**:

- Leave **Email** enabled; turn on **Confirm email** for production.
- Turn on **Anonymous sign-ins** if you want "Deltag med kode uden konto" to
  work — that button creates an anonymous session so a guest can be in the room
  in seconds. Without it, the button will fail.

**Authentication → URL Configuration** → add the redirect:

```
dk.huce.iglasset://login-callback/
```

## 7. Realtime

`0001_init.sql` adds `tastings`, `tasting_items`, `participants` and `ratings`
to the `supabase_realtime` publication. That's what flips every guest's screen
the moment the host reveals a glass. Confirm under **Database → Replication**.

## 8. Wire the app up

**Project Settings → API**, copy the **Project URL** and the **publishable**
(formerly *anon*) key:

```bash
cp dart_define.example.json dart_define.json
```

Fill in the two values, then:

```bash
flutter run --dart-define-from-file=dart_define.json
```

`dart_define.json` is gitignored. Nothing secret ships in the bundle — the
publishable key is designed to be public, and RLS is what actually protects the
data.

---

## How images are handled

You asked for images not to live in the database, and for each device to keep
its own copy. That is exactly what this does:

1. **Host adds a bottle photo.** The app copies it into the app's own folder on
   the host's device, uploads it to
   `tasting-media/tastings/<tastingId>/items/<itemId>.jpg`, and writes **only**
   the object path, a sha256 checksum and the byte size to the row. No bytes, no
   base64, no URL in Postgres.

2. **Before that glass is revealed**, the storage policy refuses the download to
   everyone but the host — and `tasting_items_visible` doesn't hand out the path
   in the first place.

3. **The host reveals.** Realtime pushes it; each guest's app downloads the image
   once, checks it against the checksum, and writes it into that device's own
   folder:

   ```
   <app documents>/I Glasset/tastings/<tastingId>/items/<itemId>.jpg
   ```

   On iOS that folder is exposed in the Files app (`UIFileSharingEnabled` +
   `LSSupportsOpeningDocumentsInPlace`), so it really is the user's folder.

4. **From then on the UI renders from disk.** Old tastings work with no
   connection at all.

5. **The cloud copy is disposable.** `purge_synced_tasting_media()` deletes
   objects 14 days after reveal; devices that already synced are unaffected.
   Anyone who missed one can re-pull it from **Profil → Billeder på enheden**.

Relevant code: [`local_media_store.dart`](../lib/data/local/local_media_store.dart),
[`media_sync_service.dart`](../lib/data/repositories/media_sync_service.dart),
and [`media_sync_controller.dart`](../lib/features/live/media_sync_controller.dart).
