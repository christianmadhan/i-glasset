-- I Glasset — schema
-- Run in the Supabase SQL editor, or `supabase db push`.
--
-- Images: no bytes and no third-party URLs are stored here. A row holds a
-- storage object path plus a sha256 checksum; the bucket is transport only and
-- every client keeps its own copy on device. See 0002_storage.sql.

create extension if not exists "pgcrypto";

-- ---------------------------------------------------------------------------
-- profiles
-- ---------------------------------------------------------------------------
create table public.profiles (
  id           uuid primary key references auth.users (id) on delete cascade,
  display_name text not null check (char_length(display_name) between 1 and 60),
  -- Avatars are device-local; this seeds the monogram colour so every client
  -- draws the same fallback.
  avatar_seed  text not null default encode(gen_random_bytes(8), 'hex'),
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- groups ("grupper" — Torsdagsklubben and friends)
-- ---------------------------------------------------------------------------
create type public.group_access as enum ('open', 'approval', 'private');
create type public.member_role   as enum ('owner', 'admin', 'member');
create type public.member_status as enum ('active', 'pending');

create table public.groups (
  id          uuid primary key default gen_random_uuid(),
  name        text not null check (char_length(name) between 1 and 80),
  description text,
  -- Free-text focus tags: Vin, Øl, Whisky, Spiritus, Kaffe, Blandet.
  focus       text[] not null default '{}',
  access      public.group_access not null default 'approval',
  invite_code text not null unique
                default 'GRP-' || upper(substr(encode(gen_random_bytes(8), 'hex'), 1, 4)),
  created_by  uuid not null references public.profiles (id) on delete cascade,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

create table public.group_members (
  group_id  uuid not null references public.groups (id) on delete cascade,
  user_id   uuid not null references public.profiles (id) on delete cascade,
  role      public.member_role   not null default 'member',
  status    public.member_status not null default 'active',
  joined_at timestamptz not null default now(),
  primary key (group_id, user_id)
);

create index group_members_user_idx on public.group_members (user_id);

-- ---------------------------------------------------------------------------
-- tastings
-- ---------------------------------------------------------------------------
create type public.tasting_status as enum ('draft', 'lobby', 'live', 'finished');

create table public.tastings (
  id            uuid primary key default gen_random_uuid(),
  group_id      uuid references public.groups (id) on delete set null,
  host_id       uuid not null references public.profiles (id) on delete cascade,
  title         text not null check (char_length(title) between 1 and 120),
  theme         text,
  description   text,
  -- Vin, Øl, Whisky, Rom, Spiritus, Kaffe, Andet
  category      text not null default 'Vin',
  status        public.tasting_status not null default 'draft',
  join_code     text not null unique
                  default upper(substr(encode(gen_random_bytes(8), 'hex'), 1, 6))
                  check (join_code ~ '^[A-Z0-9]{4,8}$'),
  scheduled_for timestamptz,

  -- Which glass the room is on. 0 = still in the lobby.
  current_position int not null default 0,

  -- Format og regler, exactly the switches the host sets when creating the
  -- tasting. Kept as one document because the app reads and writes it whole.
  --   blind, reveal, order, scale, show_others, timer, code_mode, guests,
  --   require_notes, guess_on, cats { duft, smag, drue, pris, alkohol,
  --   argang, region, ekstra → { on, pts } }
  config        jsonb not null default jsonb_build_object(
                  'blind', 'Alt skjult',
                  'reveal', 'Efter hvert glas',
                  'order', 'Fast',
                  'scale', '1-10',
                  'show_others', 'Efter afsløring',
                  'timer', 'Ingen',
                  'code_mode', 'Automatisk',
                  'guests', 'Kun gruppen',
                  'require_notes', false,
                  'guess_on', true,
                  'cats', jsonb_build_object(
                    'duft',    jsonb_build_object('on', true, 'pts', 3),
                    'smag',    jsonb_build_object('on', true, 'pts', 3),
                    'drue',    jsonb_build_object('on', true, 'pts', 3),
                    'pris',    jsonb_build_object('on', true, 'pts', 3),
                    'alkohol', jsonb_build_object('on', true, 'pts', 3),
                    'argang',  jsonb_build_object('on', true, 'pts', 3),
                    'region',  jsonb_build_object('on', true, 'pts', 5),
                    'ekstra',  jsonb_build_object('on', true, 'pts', 3)
                  )
                ),
  finished_at   timestamptz,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);

create index tastings_group_idx on public.tastings (group_id);
create index tastings_host_idx  on public.tastings (host_id);
create index tastings_code_idx  on public.tastings (join_code);

-- ---------------------------------------------------------------------------
-- tasting_items — the glasses. Everything identifying stays server-side until
-- the host reveals *that glass*; reveal is per item, not per tasting.
-- ---------------------------------------------------------------------------
create table public.tasting_items (
  id           uuid primary key default gen_random_uuid(),
  tasting_id   uuid not null references public.tastings (id) on delete cascade,
  position     int  not null check (position > 0),

  -- secrets ----------------------------------------------------------------
  name         text,
  producer     text,
  grape        text,
  country      text,
  region       text,
  vintage      int     check (vintage is null or vintage between 1800 and 2200),
  abv          numeric(4,1) check (abv is null or abv between 0 and 100),
  price        numeric(10,2),
  currency     text not null default 'DKK',
  product_type text,
  -- The one thing the host marked as special about this glass ("Økologisk",
  -- "Tre år på store fade"). Guessable for points.
  extra        text,
  aromas       text[] not null default '{}',
  flavours     text[] not null default '{}',
  -- Never shown to participants, even after the reveal.
  host_notes   text,

  -- image: storage path only, never bytes
  image_path   text,
  image_sha256 text check (image_sha256 is null or image_sha256 ~ '^[a-f0-9]{64}$'),
  image_bytes  int,

  revealed_at  timestamptz,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),

  unique (tasting_id, position)
);

create index tasting_items_tasting_idx on public.tasting_items (tasting_id);

-- ---------------------------------------------------------------------------
-- participants
-- ---------------------------------------------------------------------------
create table public.participants (
  id         uuid primary key default gen_random_uuid(),
  tasting_id uuid not null references public.tastings (id) on delete cascade,
  user_id    uuid not null references public.profiles (id) on delete cascade,
  is_host    boolean not null default false,
  joined_at  timestamptz not null default now(),
  unique (tasting_id, user_id)
);

create index participants_user_idx    on public.participants (user_id);
create index participants_tasting_idx on public.participants (tasting_id);

-- ---------------------------------------------------------------------------
-- ratings — one row per participant per glass. Carries both the score and the
-- guess, because the app submits them together.
-- ---------------------------------------------------------------------------
create table public.ratings (
  id              uuid primary key default gen_random_uuid(),
  tasting_item_id uuid not null references public.tasting_items (id) on delete cascade,
  user_id         uuid not null references public.profiles (id) on delete cascade,

  -- Always stored on the 1–10 scale. A tasting configured for 1–100 divides on
  -- the way in and multiplies on the way out, so history stays comparable
  -- across tastings that used different scales.
  score           numeric(4,2) check (score is null or score between 1 and 10),
  notes           text,

  -- the guess
  guess_aromas    text[] not null default '{}',
  guess_flavours  text[] not null default '{}',
  guess_grape     text,
  guess_country   text,
  guess_region    text,
  guess_extra     text,
  guess_price     numeric(10,2),
  guess_abv       numeric(4,1),
  guess_vintage   int,

  -- Filled in by score_item() at reveal. Never written by a client.
  points          jsonb,
  points_total    int,

  submitted_at    timestamptz,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  unique (tasting_item_id, user_id)
);

create index ratings_item_idx on public.ratings (tasting_item_id);
create index ratings_user_idx on public.ratings (user_id);

-- ---------------------------------------------------------------------------
-- updated_at
-- ---------------------------------------------------------------------------
create or replace function public.touch_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger profiles_touch      before update on public.profiles      for each row execute function public.touch_updated_at();
create trigger groups_touch        before update on public.groups        for each row execute function public.touch_updated_at();
create trigger tastings_touch      before update on public.tastings      for each row execute function public.touch_updated_at();
create trigger tasting_items_touch before update on public.tasting_items for each row execute function public.touch_updated_at();
create trigger ratings_touch       before update on public.ratings       for each row execute function public.touch_updated_at();

-- ---------------------------------------------------------------------------
-- helper predicates (security definer, so RLS policies don't recurse)
-- ---------------------------------------------------------------------------
create or replace function public.is_group_member(p_group_id uuid)
returns boolean language sql security definer set search_path = public stable as $$
  select exists (
    select 1 from public.group_members m
    where m.group_id = p_group_id and m.user_id = auth.uid() and m.status = 'active'
  );
$$;

create or replace function public.is_group_admin(p_group_id uuid)
returns boolean language sql security definer set search_path = public stable as $$
  select exists (
    select 1 from public.group_members m
    where m.group_id = p_group_id and m.user_id = auth.uid()
      and m.status = 'active' and m.role in ('owner', 'admin')
  );
$$;

create or replace function public.is_participant(p_tasting_id uuid)
returns boolean language sql security definer set search_path = public stable as $$
  select exists (
    select 1 from public.participants p
    where p.tasting_id = p_tasting_id and p.user_id = auth.uid()
  );
$$;

create or replace function public.is_host(p_tasting_id uuid)
returns boolean language sql security definer set search_path = public stable as $$
  select exists (
    select 1 from public.tastings t
    where t.id = p_tasting_id and t.host_id = auth.uid()
  );
$$;

-- ---------------------------------------------------------------------------
-- joining
-- ---------------------------------------------------------------------------

-- Joining a tasting by code. Not an INSERT policy on participants, because the
-- code has to be checked before anyone is let in — and a policy can't do that
-- without also making every tasting row readable.
create or replace function public.join_tasting(p_join_code text)
returns uuid language plpgsql security definer set search_path = public as $$
declare
  v_tasting public.tastings;
begin
  if auth.uid() is null then
    raise exception 'not authenticated' using errcode = '28000';
  end if;

  select * into v_tasting from public.tastings
  where join_code = upper(trim(p_join_code));

  if not found then
    raise exception 'Koden findes ikke' using errcode = 'P0002';
  end if;

  if v_tasting.status = 'draft' then
    raise exception 'Smagningen er ikke åbnet endnu' using errcode = 'P0001';
  end if;

  if v_tasting.status = 'finished' then
    raise exception 'Smagningen er slut' using errcode = 'P0001';
  end if;

  -- "Kun gruppen": guests without a group membership are turned away.
  if v_tasting.config ->> 'guests' = 'Kun gruppen'
     and v_tasting.group_id is not null
     and not public.is_group_member(v_tasting.group_id)
     and v_tasting.host_id <> auth.uid() then
    raise exception 'Kun medlemmer af gruppen kan deltage' using errcode = '42501';
  end if;

  insert into public.participants (tasting_id, user_id, is_host)
  values (v_tasting.id, auth.uid(), v_tasting.host_id = auth.uid())
  on conflict (tasting_id, user_id) do nothing;

  return v_tasting.id;
end;
$$;

create or replace function public.join_group(p_invite_code text)
returns uuid language plpgsql security definer set search_path = public as $$
declare
  v_group public.groups;
begin
  if auth.uid() is null then
    raise exception 'not authenticated' using errcode = '28000';
  end if;

  select * into v_group from public.groups
  where upper(invite_code) = upper(trim(p_invite_code));

  if not found then
    raise exception 'Gruppekoden findes ikke' using errcode = 'P0002';
  end if;

  insert into public.group_members (group_id, user_id, role, status)
  values (
    v_group.id, auth.uid(), 'member',
    case when v_group.access = 'open' then 'active'::public.member_status
         else 'pending'::public.member_status end
  )
  on conflict (group_id, user_id) do nothing;

  return v_group.id;
end;
$$;

-- Requesting membership of a group found by search, without an invite code.
-- Private groups aren't listed, so they can't be requested this way.
create or replace function public.request_group_membership(p_group_id uuid)
returns public.member_status language plpgsql security definer set search_path = public as $$
declare
  v_access public.group_access;
  v_status public.member_status;
begin
  select access into v_access from public.groups where id = p_group_id;

  if not found or v_access = 'private' then
    raise exception 'Gruppen findes ikke' using errcode = 'P0002';
  end if;

  v_status := case when v_access = 'open' then 'active'::public.member_status
                   else 'pending'::public.member_status end;

  insert into public.group_members (group_id, user_id, role, status)
  values (p_group_id, auth.uid(), 'member', v_status)
  on conflict (group_id, user_id) do nothing;

  select status into v_status from public.group_members
  where group_id = p_group_id and user_id = auth.uid();

  return v_status;
end;
$$;

-- A group's creator becomes its owner.
create or replace function public.handle_new_group()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.group_members (group_id, user_id, role, status)
  values (new.id, new.created_by, 'owner', 'active')
  on conflict do nothing;
  return new;
end;
$$;

create trigger on_group_created
  after insert on public.groups
  for each row execute function public.handle_new_group();

-- ---------------------------------------------------------------------------
-- scoring — the guess game, resolved server-side at reveal so a client can
-- never award itself points. Mirrors the rules shown on the guess sheet:
--
--   duft/smag   1 pt per matched note, capped at the category's points
--   drue        all or nothing
--   pris        full / two-thirds / one-third by how close, then nothing
--   alkohol     exact = full, within 1 % = 1 pt
--   argang      exact = full, within 2 years = 1 pt
--   region      country is worth pts-2 (min 1), region the remainder
--   ekstra      all or nothing
-- ---------------------------------------------------------------------------
-- Loose string equality for free-text guesses: trimmed and case-folded, so
-- "nebbiolo " scores the same as "Nebbiolo". Mirrored by GuessScorer in Dart.
create or replace function public.same_guess(a text, b text)
returns boolean language sql immutable as $$
  select a is not null and b is not null
     and lower(btrim(a)) = lower(btrim(b));
$$;

create or replace function public.score_rating(
  p_item public.tasting_items,
  p_rating public.ratings,
  p_cats jsonb
)
returns jsonb language plpgsql immutable as $$
declare
  v_pts   jsonb := '{}'::jsonb;
  v_total int := 0;
  v_key   text;
  v_max   int;
  v_got   int;
  v_dist  numeric;
  v_land  int;
begin
  foreach v_key in array array['duft','smag','drue','pris','alkohol','argang','region','ekstra']
  loop
    continue when not coalesce((p_cats -> v_key ->> 'on')::boolean, false);
    v_max := coalesce((p_cats -> v_key ->> 'pts')::int, 0);
    v_got := 0;

    if v_key = 'duft' then
      select least(count(*), v_max) into v_got
      from unnest(p_rating.guess_aromas) a
      where a = any (p_item.aromas);

    elsif v_key = 'smag' then
      select least(count(*), v_max) into v_got
      from unnest(p_rating.guess_flavours) f
      where f = any (p_item.flavours);

    elsif v_key = 'drue' then
      -- Compared loosely: a guest may have typed their own answer rather than
      -- tapped a chip. The Dart scorer in lib/data/scoring/ does the same.
      v_got := case when public.same_guess(p_rating.guess_grape, p_item.grape)
                    then v_max else 0 end;

    elsif v_key = 'pris' then
      if p_rating.guess_price is not null and p_item.price is not null then
        v_dist := abs(p_rating.guess_price - p_item.price);
        v_got := case
          when v_dist <= 25  then v_max
          when v_dist <= 50  then ceil(v_max * 2.0 / 3)
          when v_dist <= 100 then ceil(v_max / 3.0)
          else 0
        end;
      end if;

    elsif v_key = 'alkohol' then
      if p_rating.guess_abv is not null and p_item.abv is not null then
        v_dist := abs(p_rating.guess_abv - p_item.abv);
        v_got := case when v_dist < 0.05 then v_max
                      when v_dist <= 1   then 1
                      else 0 end;
      end if;

    elsif v_key = 'argang' then
      if p_rating.guess_vintage is not null and p_item.vintage is not null then
        v_dist := abs(p_rating.guess_vintage - p_item.vintage);
        v_got := case when v_dist = 0 then v_max
                      when v_dist <= 2 then 1
                      else 0 end;
      end if;

    elsif v_key = 'region' then
      v_land := greatest(v_max - 2, 1);
      v_got :=
        case when public.same_guess(p_rating.guess_country, p_item.country)
             then v_land else 0 end
      + case when public.same_guess(p_rating.guess_region, p_item.region)
             then v_max - v_land else 0 end;

    elsif v_key = 'ekstra' then
      v_got := case when public.same_guess(p_rating.guess_extra, p_item.extra)
                    then v_max else 0 end;
    end if;

    v_pts := v_pts || jsonb_build_object(v_key, jsonb_build_object('got', v_got, 'max', v_max));
    v_total := v_total + v_got;
  end loop;

  return jsonb_build_object('rows', v_pts, 'total', v_total);
end;
$$;

-- ---------------------------------------------------------------------------
-- host actions
-- ---------------------------------------------------------------------------

-- Reveals one glass and settles everyone's points for it in the same
-- statement, so the reveal and the scores can never disagree.
create or replace function public.reveal_item(p_item_id uuid)
returns public.tasting_items language plpgsql security definer set search_path = public as $$
declare
  v_item    public.tasting_items;
  v_cats    jsonb;
  v_guess_on boolean;
  v_rating  public.ratings;
  v_scored  jsonb;
begin
  select i.* into v_item from public.tasting_items i where i.id = p_item_id;
  if not found then
    raise exception 'Glasset findes ikke' using errcode = 'P0002';
  end if;

  if not public.is_host(v_item.tasting_id) then
    raise exception 'Kun værten kan afsløre' using errcode = '42501';
  end if;

  select t.config -> 'cats', coalesce((t.config ->> 'guess_on')::boolean, false)
    into v_cats, v_guess_on
  from public.tastings t where t.id = v_item.tasting_id;

  update public.tasting_items
  set revealed_at = coalesce(revealed_at, now())
  where id = p_item_id
  returning * into v_item;

  if v_guess_on then
    for v_rating in select * from public.ratings where tasting_item_id = p_item_id
    loop
      v_scored := public.score_rating(v_item, v_rating, v_cats);
      update public.ratings
      set points = v_scored -> 'rows',
          points_total = (v_scored ->> 'total')::int
      where id = v_rating.id;
    end loop;
  end if;

  return v_item;
end;
$$;

create or replace function public.advance_tasting(p_tasting_id uuid, p_position int)
returns public.tastings language plpgsql security definer set search_path = public as $$
declare
  v_tasting public.tastings;
begin
  if not public.is_host(p_tasting_id) then
    raise exception 'Kun værten kan styre smagningen' using errcode = '42501';
  end if;

  update public.tastings
  set current_position = p_position,
      status = case when p_position > 0 then 'live'::public.tasting_status else status end
  where id = p_tasting_id
  returning * into v_tasting;

  return v_tasting;
end;
$$;

create or replace function public.finish_tasting(p_tasting_id uuid)
returns public.tastings language plpgsql security definer set search_path = public as $$
declare
  v_tasting public.tastings;
begin
  if not public.is_host(p_tasting_id) then
    raise exception 'Kun værten kan afslutte smagningen' using errcode = '42501';
  end if;

  update public.tastings
  set status = 'finished', finished_at = now()
  where id = p_tasting_id
  returning * into v_tasting;

  return v_tasting;
end;
$$;

do $$
declare fn text;
begin
  foreach fn in array array[
    'join_tasting(text)', 'join_group(text)', 'request_group_membership(uuid)',
    'reveal_item(uuid)', 'advance_tasting(uuid,int)', 'finish_tasting(uuid)'
  ] loop
    execute format('revoke all on function public.%s from public', fn);
    execute format('grant execute on function public.%s to authenticated', fn);
  end loop;
end $$;

-- ---------------------------------------------------------------------------
-- the blind-safe view — the only way a participant reads glasses.
-- Identifying columns come back null until that glass is revealed, so the
-- answer is not merely hidden in the UI: it never reaches the device.
--
-- This view is deliberately NOT security_invoker. RLS is row-level and cannot
-- withhold individual columns, so if participants could select the base table
-- the blind would be pointless — they would simply read tasting_items directly.
-- Instead the base table's select policy is host-only, and this view runs as
-- its owner with its own access test in the WHERE clause below. That test is
-- the whole security boundary for participants, so keep it in one piece.
-- ---------------------------------------------------------------------------
create or replace view public.tasting_items_visible
with (security_invoker = false)
as
select
  i.id,
  i.tasting_id,
  i.position,
  (i.revealed_at is not null) or t.host_id = auth.uid() as is_revealed,
  i.revealed_at,
  case when v.show then i.name         end as name,
  case when v.show then i.producer     end as producer,
  case when v.show then i.grape        end as grape,
  case when v.show then i.country      end as country,
  case when v.show then i.region       end as region,
  case when v.show then i.vintage      end as vintage,
  case when v.show then i.abv          end as abv,
  case when v.show then i.price        end as price,
  case when v.show then i.currency     end as currency,
  case when v.show then i.product_type end as product_type,
  case when v.show then i.extra        end as extra,
  case when v.show then i.aromas  else '{}'::text[] end as aromas,
  case when v.show then i.flavours else '{}'::text[] end as flavours,
  case when v.show then i.image_path   end as image_path,
  case when v.show then i.image_sha256 end as image_sha256,
  case when v.show then i.image_bytes  end as image_bytes,
  -- host_notes is deliberately absent: hosts read tasting_items directly.
  i.created_at,
  i.updated_at
from public.tasting_items i
join public.tastings t on t.id = i.tasting_id
cross join lateral (
  select (i.revealed_at is not null) or t.host_id = auth.uid() as show
) v
where t.host_id = auth.uid() or public.is_participant(t.id);

grant select on public.tasting_items_visible to authenticated;

-- ---------------------------------------------------------------------------
-- Row Level Security
-- ---------------------------------------------------------------------------
alter table public.profiles      enable row level security;
alter table public.groups        enable row level security;
alter table public.group_members enable row level security;
alter table public.tastings      enable row level security;
alter table public.tasting_items enable row level security;
alter table public.participants  enable row level security;
alter table public.ratings       enable row level security;

-- profiles ------------------------------------------------------------------
create policy "profiles readable when signed in"
  on public.profiles for select to authenticated using (true);

create policy "insert your own profile"
  on public.profiles for insert to authenticated with check (id = auth.uid());

create policy "update your own profile"
  on public.profiles for update to authenticated
  using (id = auth.uid()) with check (id = auth.uid());

-- groups --------------------------------------------------------------------
-- Open and approval groups are discoverable in search; private ones are only
-- visible to their members.
create policy "discoverable groups are readable"
  on public.groups for select to authenticated
  using (access in ('open', 'approval') or public.is_group_member(id));

create policy "create a group you own"
  on public.groups for insert to authenticated with check (created_by = auth.uid());

create policy "admins update their group"
  on public.groups for update to authenticated
  using (public.is_group_admin(id)) with check (public.is_group_admin(id));

create policy "admins delete their group"
  on public.groups for delete to authenticated using (public.is_group_admin(id));

-- group_members -------------------------------------------------------------
create policy "members see the roster"
  on public.group_members for select to authenticated
  using (user_id = auth.uid() or public.is_group_member(group_id));

create policy "admins manage members"
  on public.group_members for update to authenticated
  using (public.is_group_admin(group_id)) with check (public.is_group_admin(group_id));

create policy "leave a group, or be removed by an admin"
  on public.group_members for delete to authenticated
  using (user_id = auth.uid() or public.is_group_admin(group_id));

-- No INSERT policy: joining goes through join_group() /
-- request_group_membership(), which decide active vs pending.

-- tastings ------------------------------------------------------------------
create policy "read tastings you host, joined, or whose group you're in"
  on public.tastings for select to authenticated
  using (
    host_id = auth.uid()
    or public.is_participant(id)
    or (group_id is not null and public.is_group_member(group_id))
  );

create policy "create a tasting you host"
  on public.tastings for insert to authenticated
  with check (
    host_id = auth.uid()
    and (group_id is null or public.is_group_member(group_id))
  );

create policy "hosts update their tasting"
  on public.tastings for update to authenticated
  using (host_id = auth.uid()) with check (host_id = auth.uid());

create policy "hosts delete their tasting"
  on public.tastings for delete to authenticated using (host_id = auth.uid());

-- tasting_items -------------------------------------------------------------
-- Hosts only. Participants must go through tasting_items_visible, which blanks
-- the identifying columns until each glass is revealed. Granting participants
-- select here would hand them the answers, since RLS cannot hide columns.
create policy "hosts read their items"
  on public.tasting_items for select to authenticated
  using (public.is_host(tasting_id));

create policy "hosts manage items"
  on public.tasting_items for all to authenticated
  using (public.is_host(tasting_id)) with check (public.is_host(tasting_id));

-- participants --------------------------------------------------------------
create policy "participants see each other"
  on public.participants for select to authenticated
  using (public.is_participant(tasting_id) or public.is_host(tasting_id));

create policy "leave a tasting, or be removed by the host"
  on public.participants for delete to authenticated
  using (user_id = auth.uid() or public.is_host(tasting_id));

-- No INSERT policy: joining goes through join_tasting().

-- ratings -------------------------------------------------------------------
-- Your own rows are always yours. Other people's open up according to the
-- tasting's "Se andres karakterer" setting.
create policy "read own ratings, and others' per the tasting's setting"
  on public.ratings for select to authenticated
  using (
    user_id = auth.uid()
    or exists (
      select 1
      from public.tasting_items i
      join public.tastings t on t.id = i.tasting_id
      where i.id = ratings.tasting_item_id
        and (public.is_participant(t.id) or t.host_id = auth.uid())
        and (
          t.config ->> 'show_others' = 'Straks'
          or (t.config ->> 'show_others' = 'Efter afsløring' and i.revealed_at is not null)
        )
    )
  );

create policy "write your own rating"
  on public.ratings for insert to authenticated
  with check (
    user_id = auth.uid()
    and points is null and points_total is null
    and exists (
      select 1 from public.tasting_items i
      where i.id = tasting_item_id and public.is_participant(i.tasting_id)
    )
  );

-- Edits stop at the reveal: once a glass is settled, its scores are history.
create policy "edit your own rating until the glass is revealed"
  on public.ratings for update to authenticated
  using (
    user_id = auth.uid()
    and exists (
      select 1 from public.tasting_items i
      where i.id = ratings.tasting_item_id and i.revealed_at is null
    )
  )
  with check (user_id = auth.uid());

create policy "delete your own rating"
  on public.ratings for delete to authenticated using (user_id = auth.uid());

-- Clients must not be able to award themselves points, even in an UPDATE that
-- the policy above allows. reveal_item() is security definer and bypasses this.
create or replace function public.guard_rating_points()
returns trigger language plpgsql as $$
begin
  if tg_op = 'UPDATE' then
    new.points := old.points;
    new.points_total := old.points_total;
  else
    new.points := null;
    new.points_total := null;
  end if;
  return new;
end;
$$;

create trigger ratings_guard_points
  before insert or update on public.ratings
  for each row execute function public.guard_rating_points();

-- ---------------------------------------------------------------------------
-- new users get a profile
-- ---------------------------------------------------------------------------
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, display_name)
  values (
    new.id,
    coalesce(
      nullif(new.raw_user_meta_data ->> 'display_name', ''),
      split_part(coalesce(new.email, 'Gæst'), '@', 1)
    )
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ---------------------------------------------------------------------------
-- realtime — this is what flips every guest's screen the moment the host
-- reveals a glass or moves the room to the next one.
-- ---------------------------------------------------------------------------
alter publication supabase_realtime add table public.tastings;
alter publication supabase_realtime add table public.tasting_items;
alter publication supabase_realtime add table public.participants;
alter publication supabase_realtime add table public.ratings;
