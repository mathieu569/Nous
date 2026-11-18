-- =====================================================================
-- NOUS : notifications push
-- À coller dans Supabase > SQL Editor > New query > Run (une seule fois)
-- =====================================================================

create table public.push_tokens (
  token text primary key,
  user_id uuid not null references auth.users (id) on delete cascade,
  platform text not null,
  updated_at timestamptz not null default now()
);

-- RLS activée et AUCUNE règle : personne ne lit ni n'écrit directement cette table.
-- Les téléphones passent par register_push_token(), la fonction d'envoi utilise la clé service.
alter table public.push_tokens enable row level security;

create or replace function public.register_push_token(p_token text, p_platform text)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'Non connecté';
  end if;
  insert into public.push_tokens (token, user_id, platform)
    values (p_token, auth.uid(), p_platform)
  on conflict (token) do update
    set user_id = auth.uid(), platform = excluded.platform, updated_at = now();
end
$$;

revoke all on function public.register_push_token(text, text) from public, anon;
grant execute on function public.register_push_token(text, text) to authenticated;
