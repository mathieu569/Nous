-- =====================================================================
-- NOUS : base de données Supabase
-- À coller en entier dans Supabase > SQL Editor > New query > Run
-- (à lancer une seule fois)
-- =====================================================================

-- ---------- TABLES ----------
create table public.couples (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  start_date date,
  created_at timestamptz not null default now()
);

create table public.profiles (
  user_id uuid primary key references auth.users (id) on delete cascade,
  couple_id uuid not null references public.couples (id) on delete cascade,
  name text not null default '',
  status text not null default '',
  photo_path text,
  created_at timestamptz not null default now()
);

create table public.stories (
  id uuid primary key default gen_random_uuid(),
  couple_id uuid not null references public.couples (id) on delete cascade,
  author_id uuid not null references auth.users (id) on delete cascade,
  image_path text not null,
  created_at timestamptz not null default now()
);

create table public.events (
  id uuid primary key default gen_random_uuid(),
  couple_id uuid not null references public.couples (id) on delete cascade,
  title text not null,
  event_date date not null,
  created_at timestamptz not null default now()
);

-- ---------- SÉCURITÉ (RLS) : chacun ne voit que SON couple ----------
alter table public.couples enable row level security;
alter table public.profiles enable row level security;
alter table public.stories enable row level security;
alter table public.events enable row level security;

-- Renvoie le couple de la personne connectée
create or replace function public.my_couple_id()
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  select couple_id from public.profiles where user_id = auth.uid()
$$;

create policy "couples: lire le sien" on public.couples
  for select to authenticated
  using (id = public.my_couple_id());

create policy "couples: modifier le sien" on public.couples
  for update to authenticated
  using (id = public.my_couple_id())
  with check (id = public.my_couple_id());

create policy "profiles: lire ceux du couple" on public.profiles
  for select to authenticated
  using (couple_id = public.my_couple_id());

create policy "profiles: modifier le mien" on public.profiles
  for update to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid() and couple_id = public.my_couple_id());

create policy "stories: lire celles du couple" on public.stories
  for select to authenticated
  using (couple_id = public.my_couple_id());

create policy "stories: ajouter les miennes" on public.stories
  for insert to authenticated
  with check (couple_id = public.my_couple_id() and author_id = auth.uid());

create policy "stories: supprimer les miennes" on public.stories
  for delete to authenticated
  using (couple_id = public.my_couple_id() and author_id = auth.uid());

create policy "events: tout pour le couple" on public.events
  for all to authenticated
  using (couple_id = public.my_couple_id())
  with check (couple_id = public.my_couple_id());

-- ---------- APPAIRAGE (fonctions appelées par l'app) ----------
create or replace function public.create_couple(p_name text)
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  v_code text;
  v_id uuid;
begin
  if auth.uid() is null then
    raise exception 'Non connecté';
  end if;
  if exists (select 1 from public.profiles where user_id = auth.uid()) then
    raise exception 'Tu fais déjà partie d''un couple';
  end if;
  loop
    v_code := upper(substr(md5(random()::text || clock_timestamp()::text), 1, 6));
    exit when not exists (select 1 from public.couples where code = v_code);
  end loop;
  insert into public.couples (code) values (v_code) returning id into v_id;
  insert into public.profiles (user_id, couple_id, name)
    values (auth.uid(), v_id, coalesce(nullif(trim(p_name), ''), 'Moi'));
  return json_build_object('id', v_id, 'code', v_code);
end
$$;

create or replace function public.join_couple(p_code text, p_name text)
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  v_id uuid;
begin
  if auth.uid() is null then
    raise exception 'Non connecté';
  end if;
  if exists (select 1 from public.profiles where user_id = auth.uid()) then
    raise exception 'Tu fais déjà partie d''un couple';
  end if;
  select id into v_id from public.couples where code = upper(trim(p_code));
  if v_id is null then
    raise exception 'Code invalide';
  end if;
  if (select count(*) from public.profiles where couple_id = v_id) >= 2 then
    raise exception 'Ce couple est déjà complet';
  end if;
  insert into public.profiles (user_id, couple_id, name)
    values (auth.uid(), v_id, coalesce(nullif(trim(p_name), ''), 'Moi'));
  return json_build_object('id', v_id);
end
$$;

revoke all on function public.create_couple(text) from public, anon;
revoke all on function public.join_couple(text, text) from public, anon;
grant execute on function public.create_couple(text) to authenticated;
grant execute on function public.join_couple(text, text) to authenticated;

-- ---------- STOCKAGE DES PHOTOS ET DESSINS ----------
insert into storage.buckets (id, name, public, file_size_limit)
values ('nous', 'nous', false, 3145728)
on conflict (id) do nothing;

create policy "nous: lire" on storage.objects
  for select to authenticated
  using (bucket_id = 'nous'
         and (storage.foldername(name))[1] = public.my_couple_id()::text);

create policy "nous: ajouter" on storage.objects
  for insert to authenticated
  with check (bucket_id = 'nous'
              and (storage.foldername(name))[1] = public.my_couple_id()::text);

create policy "nous: supprimer" on storage.objects
  for delete to authenticated
  using (bucket_id = 'nous'
         and (storage.foldername(name))[1] = public.my_couple_id()::text);

-- ---------- TEMPS RÉEL (voir les changements de l'autre en direct) ----------
do $$ begin
  alter publication supabase_realtime add table public.profiles;
exception when duplicate_object then null; end $$;
do $$ begin
  alter publication supabase_realtime add table public.stories;
exception when duplicate_object then null; end $$;
do $$ begin
  alter publication supabase_realtime add table public.events;
exception when duplicate_object then null; end $$;
do $$ begin
  alter publication supabase_realtime add table public.couples;
exception when duplicate_object then null; end $$;
