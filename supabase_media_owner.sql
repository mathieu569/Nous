-- Du moment : un créneau par personne et "ensemble". Relançable sans risque.
-- À lancer dans Supabase > SQL Editor AVANT de mettre à jour l'appli.
-- owner_id = la personne concernée, ou null = ensemble.

alter table public.media add column if not exists owner_id uuid;

drop index if exists public.media_one_current;
create unique index media_one_current
  on public.media (couple_id, kind,
                   coalesce(owner_id, '00000000-0000-0000-0000-000000000000'::uuid))
  where status = 'current';
