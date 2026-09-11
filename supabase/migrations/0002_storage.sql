-- I Glasset — storage bucket for image *transport only*.
--
-- Images are never stored in the database, and they are not meant to live in
-- the cloud long-term either. The host uploads a bottle photo while building a
-- tasting; when that glass is revealed, each participant's app downloads it
-- once into that device's own folder and renders from disk from then on.
-- Objects here can be swept away by the cleanup job below without the app
-- losing anything.

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'tasting-media',
  'tasting-media',
  false,                                   -- private: no public URLs
  8 * 1024 * 1024,                         -- 8 MB per image
  array['image/jpeg', 'image/png', 'image/webp', 'image/heic']
)
on conflict (id) do update
  set public             = excluded.public,
      file_size_limit    = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

-- Object paths are always: tastings/<tasting_id>/items/<item_id>.<ext>
create or replace function public.storage_tasting_id(p_name text)
returns uuid language sql immutable as $$
  select case
    when split_part(p_name, '/', 1) = 'tastings'
     and split_part(p_name, '/', 2) ~ '^[0-9a-f-]{36}$'
    then split_part(p_name, '/', 2)::uuid
  end;
$$;

create or replace function public.storage_item_id(p_name text)
returns uuid language sql immutable as $$
  select case
    when split_part(p_name, '/', 3) = 'items'
     and split_part(split_part(p_name, '/', 4), '.', 1) ~ '^[0-9a-f-]{36}$'
    then split_part(split_part(p_name, '/', 4), '.', 1)::uuid
  end;
$$;

-- The host uploads, replaces and removes their own tasting's media.
create policy "hosts write their tasting media"
  on storage.objects for all
  to authenticated
  using (
    bucket_id = 'tasting-media'
    and public.is_host(public.storage_tasting_id(name))
  )
  with check (
    bucket_id = 'tasting-media'
    and public.is_host(public.storage_tasting_id(name))
  );

-- Participants may download, but only the glasses that have been revealed.
-- Before that, a leaked object path is useless to them — and
-- tasting_items_visible doesn't hand out the path in the first place.
create policy "participants download revealed media"
  on storage.objects for select
  to authenticated
  using (
    bucket_id = 'tasting-media'
    and exists (
      select 1
      from public.tasting_items i
      join public.tastings t on t.id = i.tasting_id
      where i.id = public.storage_item_id(storage.objects.name)
        and i.tasting_id = public.storage_tasting_id(storage.objects.name)
        and i.revealed_at is not null
        and public.is_participant(t.id)
    )
  );

-- ---------------------------------------------------------------------------
-- Optional: purge cloud copies once everyone has had time to sync.
-- Requires pg_cron (Database → Extensions). 14 days is a comfortable grace
-- period; devices that already synced keep their copies regardless.
-- ---------------------------------------------------------------------------
create or replace function public.purge_synced_tasting_media()
returns int language plpgsql security definer set search_path = public as $$
declare
  v_deleted int;
begin
  with gone as (
    delete from storage.objects o
    where o.bucket_id = 'tasting-media'
      and exists (
        select 1 from public.tasting_items i
        where i.id = public.storage_item_id(o.name)
          and i.revealed_at < now() - interval '14 days'
      )
    returning 1
  )
  select count(*) into v_deleted from gone;

  return v_deleted;
end;
$$;

-- Enable with:
--   select cron.schedule('purge-tasting-media', '0 4 * * *',
--                        $$select public.purge_synced_tasting_media()$$);
