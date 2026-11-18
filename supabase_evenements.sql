-- =====================================================================
-- NOUS : journal d'événements (heure, récurrence, note, photo)
-- À coller dans Supabase > SQL Editor > New query > Run
-- À lancer AVANT de mettre à jour l'appli. Relançable sans erreur.
-- =====================================================================

alter table public.events
  add column if not exists event_at timestamptz,
  add column if not exists note text,
  add column if not exists photo_path text,
  add column if not exists repeat text not null default 'none';

-- Tes événements existants (date seulement) passent à minuit, heure de Paris.
update public.events
  set event_at = (event_date::timestamp at time zone 'Europe/Paris')
  where event_at is null;

alter table public.events alter column event_at set not null;
-- Ancienne colonne : on ne l'utilise plus.
alter table public.events alter column event_date drop not null;

alter table public.events drop constraint if exists events_repeat_check;
alter table public.events add constraint events_repeat_check
  check (repeat in ('none', 'weekly', 'monthly', 'yearly'));

alter table public.events drop constraint if exists events_note_len;
alter table public.events add constraint events_note_len
  check (note is null or char_length(note) <= 500);
