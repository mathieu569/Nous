-- Une date de fin par personne (v0.13). Relançable sans risque.
-- À lancer AVANT d'envoyer la nouvelle version de l'appli.

alter table public.media_ratings alter column rating drop not null;
alter table public.media_ratings add column if not exists finished_at timestamptz;

-- Reprise de l'existant : celui qui a terminé garde la date du titre.
insert into public.media_ratings (media_id, user_id, rating, finished_at)
select m.id, m.finished_by, null, m.finished_at
from public.media m
where m.status = 'done' and m.finished_by is not null and m.finished_at is not null
on conflict (media_id, user_id) do nothing;

-- Les notes déjà données sans date reçoivent la date du titre.
update public.media_ratings r
set finished_at = m.finished_at
from public.media m
where m.id = r.media_id and m.status = 'done'
  and r.finished_at is null and m.finished_at is not null;

-- Efface les dates des deux quand un titre est remis en cours / en envie.
create or replace function public.clear_finish_dates(p_media uuid)
returns void
language sql
security definer
set search_path = public
as $$
  update public.media_ratings
  set finished_at = null
  where media_id = p_media
    and exists (select 1 from public.media m
                where m.id = p_media and m.couple_id = public.my_couple_id());
$$;
grant execute on function public.clear_finish_dates(uuid) to authenticated;
