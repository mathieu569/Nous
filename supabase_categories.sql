-- Catégories du journal d'événements (v0.14). Relançable sans risque.
-- À lancer AVANT d'envoyer la nouvelle version de l'appli.

create table if not exists public.event_categories (
  id uuid primary key default gen_random_uuid(),
  couple_id uuid not null references public.couples(id) on delete cascade,
  name text not null check (char_length(name) between 1 and 30),
  created_at timestamptz not null default now()
);

create unique index if not exists event_categories_name_uq
  on public.event_categories (couple_id, lower(name));

alter table public.event_categories enable row level security;

drop policy if exists event_categories_couple on public.event_categories;
create policy event_categories_couple on public.event_categories
  for all to authenticated
  using (couple_id = public.my_couple_id())
  with check (couple_id = public.my_couple_id());

-- Un événement a au plus une catégorie. Supprimer la catégorie ne supprime pas l'événement.
alter table public.events
  add column if not exists category_id uuid
  references public.event_categories(id) on delete set null;

do $$ begin alter publication supabase_realtime add table public.event_categories;
exception when duplicate_object then null; end $$;
