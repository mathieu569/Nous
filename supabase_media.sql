-- Suivi films / séries / livres. Relançable sans risque.
-- À lancer dans Supabase > SQL Editor AVANT de mettre à jour l'appli.

create table if not exists public.media (
  id uuid primary key default gen_random_uuid(),
  couple_id uuid not null references public.couples(id) on delete cascade,
  kind text not null check (kind in ('film', 'serie', 'livre')),
  ext_id text not null,
  title text not null,
  subtitle text,
  cover_url text,
  status text not null default 'wish' check (status in ('wish', 'current', 'done')),
  finished_by uuid,
  finished_at timestamptz,
  created_at timestamptz not null default now(),
  unique (couple_id, kind, ext_id)
);

-- Un seul titre "en cours" par catégorie et par couple.
create unique index if not exists media_one_current
  on public.media (couple_id, kind) where status = 'current';

create table if not exists public.media_wishes (
  media_id uuid not null references public.media(id) on delete cascade,
  user_id uuid not null,
  primary key (media_id, user_id)
);

create table if not exists public.media_ratings (
  media_id uuid not null references public.media(id) on delete cascade,
  user_id uuid not null,
  rating int not null check (rating between 1 and 5),
  primary key (media_id, user_id)
);

alter table public.media enable row level security;
alter table public.media_wishes enable row level security;
alter table public.media_ratings enable row level security;

drop policy if exists media_couple on public.media;
create policy media_couple on public.media for all to authenticated
  using (couple_id = public.my_couple_id())
  with check (couple_id = public.my_couple_id());

-- Envies : on voit celles du couple, on ne modifie que les siennes.
drop policy if exists wishes_select on public.media_wishes;
create policy wishes_select on public.media_wishes for select to authenticated
  using (exists (select 1 from public.media m
                 where m.id = media_id and m.couple_id = public.my_couple_id()));
drop policy if exists wishes_insert on public.media_wishes;
create policy wishes_insert on public.media_wishes for insert to authenticated
  with check (user_id = auth.uid() and exists (select 1 from public.media m
                 where m.id = media_id and m.couple_id = public.my_couple_id()));
drop policy if exists wishes_delete on public.media_wishes;
create policy wishes_delete on public.media_wishes for delete to authenticated
  using (user_id = auth.uid());

-- Notes : même principe.
drop policy if exists ratings_select on public.media_ratings;
create policy ratings_select on public.media_ratings for select to authenticated
  using (exists (select 1 from public.media m
                 where m.id = media_id and m.couple_id = public.my_couple_id()));
drop policy if exists ratings_insert on public.media_ratings;
create policy ratings_insert on public.media_ratings for insert to authenticated
  with check (user_id = auth.uid() and exists (select 1 from public.media m
                 where m.id = media_id and m.couple_id = public.my_couple_id()));
drop policy if exists ratings_update on public.media_ratings;
create policy ratings_update on public.media_ratings for update to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());
drop policy if exists ratings_delete on public.media_ratings;
create policy ratings_delete on public.media_ratings for delete to authenticated
  using (user_id = auth.uid());

-- Synchronisation en direct entre les deux téléphones.
do $$ begin alter publication supabase_realtime add table public.media;
exception when duplicate_object then null; end $$;
do $$ begin alter publication supabase_realtime add table public.media_wishes;
exception when duplicate_object then null; end $$;
do $$ begin alter publication supabase_realtime add table public.media_ratings;
exception when duplicate_object then null; end $$;
