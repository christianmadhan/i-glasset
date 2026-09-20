-- ---------------------------------------------------------------------------
-- "Det ekstraordinære" is not a fixed part of the guess game. It only counts
-- on a glass the host marked something special about; on every other glass
-- the category is simply not in play. Two things follow:
--
--   1. score_rating() skips 'ekstra' when the glass has no `extra`, so the
--      total in play shrinks accordingly — mirrored by GuessScorer in Dart.
--   2. tasting_items_visible tells participants *whether* a blind glass has
--      one (a plain boolean, never the value), so the guess sheet knows to ask.
-- ---------------------------------------------------------------------------

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
    -- Only in play where the host marked something.
    continue when v_key = 'ekstra' and nullif(btrim(p_item.extra), '') is null;
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

-- The view gains one column; everything else is as in 0001.
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
  nullif(btrim(i.extra), '') is not null  as has_extra,
  case when v.show then i.aromas  else '{}'::text[] end as aromas,
  case when v.show then i.flavours else '{}'::text[] end as flavours,
  case when v.show then i.image_path   end as image_path,
  case when v.show then i.image_sha256 end as image_sha256,
  case when v.show then i.image_bytes  end as image_bytes,
  i.created_at,
  i.updated_at
from public.tasting_items i
join public.tastings t on t.id = i.tasting_id
cross join lateral (
  select (i.revealed_at is not null) or t.host_id = auth.uid() as show
) v
where t.host_id = auth.uid() or public.is_participant(t.id);

grant select on public.tasting_items_visible to authenticated;
