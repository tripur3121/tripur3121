-- Contact Directory: initial schema.
-- Run this once in the Supabase SQL editor (or with the Supabase CLI).
-- Every table has Row Level Security: a row is visible and writable only to its owner.

create extension if not exists pg_trgm;

-- ---------------------------------------------------------------------------
-- Tables
-- ---------------------------------------------------------------------------

create table public.contacts (
  id                uuid primary key default gen_random_uuid(),
  user_id           uuid not null default auth.uid() references auth.users (id) on delete cascade,
  full_name         text not null check (char_length(btrim(full_name)) between 1 and 200),
  met_at            text check (char_length(met_at) <= 100),
  meeting_detail    text check (char_length(meeting_detail) <= 1000),
  relationship_type text check (char_length(relationship_type) <= 100),
  phone             text check (char_length(phone) <= 50),
  email             text check (char_length(email) <= 320),
  linkedin_url      text check (
                      linkedin_url is null
                      or (char_length(linkedin_url) <= 500 and linkedin_url ~* '^https://')
                    ),
  company           text check (char_length(company) <= 200),
  role              text check (char_length(role) <= 200),
  next_follow_up    date,
  notes             text check (char_length(notes) <= 10000),
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now(),
  -- Lets interactions reference (id, user_id) so ownership can never diverge.
  unique (id, user_id)
);

create table public.interactions (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null default auth.uid() references auth.users (id) on delete cascade,
  contact_id  uuid not null,
  occurred_on date not null default current_date,
  medium      text not null check (medium in ('call', 'text', 'email', 'in_person', 'other')),
  key_points  text check (char_length(key_points) <= 10000),
  created_at  timestamptz not null default now(),
  -- An interaction must belong to a contact owned by the same user.
  constraint interactions_contact_owner_fk
    foreign key (contact_id, user_id)
    references public.contacts (id, user_id)
    on delete cascade
);

-- ---------------------------------------------------------------------------
-- Indexes
-- ---------------------------------------------------------------------------

create index contacts_user_idx           on public.contacts (user_id);
create index contacts_follow_up_idx      on public.contacts (user_id, next_follow_up) where next_follow_up is not null;
create index contacts_name_trgm_idx      on public.contacts using gin (full_name gin_trgm_ops);
create index contacts_company_trgm_idx   on public.contacts using gin (company gin_trgm_ops);
create index contacts_notes_trgm_idx     on public.contacts using gin (notes gin_trgm_ops);

create index interactions_user_idx       on public.interactions (user_id);
create index interactions_contact_idx    on public.interactions (contact_id, occurred_on desc);
create index interactions_points_trgm_idx on public.interactions using gin (key_points gin_trgm_ops);

-- ---------------------------------------------------------------------------
-- updated_at trigger
-- ---------------------------------------------------------------------------

create function public.set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger contacts_set_updated_at
  before update on public.contacts
  for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------------------
-- "Last talked" is always derived from interactions, never stored by hand.
-- security_invoker makes the view run with the caller's rights, so RLS applies.
-- ---------------------------------------------------------------------------

create view public.contacts_with_last_talked
with (security_invoker = true) as
select
  c.*,
  (select max(i.occurred_on) from public.interactions i where i.contact_id = c.id) as last_talked
from public.contacts c;

-- ---------------------------------------------------------------------------
-- Search across name, company, notes and interaction text.
-- Returns matching contact ids; security invoker, so RLS still applies.
-- ---------------------------------------------------------------------------

create function public.search_contact_ids(q text)
returns setof uuid
language sql
stable
security invoker
set search_path = ''
as $$
  with pattern as (
    select '%' || replace(replace(replace(btrim(q), '\', '\\'), '%', '\%'), '_', '\_') || '%' as p
  )
  select c.id
  from public.contacts c, pattern
  where c.full_name ilike pattern.p
     or c.company   ilike pattern.p
     or c.notes     ilike pattern.p
  union
  select i.contact_id
  from public.interactions i, pattern
  where i.key_points ilike pattern.p;
$$;

-- ---------------------------------------------------------------------------
-- Row Level Security
-- ---------------------------------------------------------------------------

alter table public.contacts     enable row level security;
alter table public.interactions enable row level security;
alter table public.contacts     force row level security;
alter table public.interactions force row level security;

create policy contacts_select on public.contacts
  for select to authenticated using (user_id = (select auth.uid()));
create policy contacts_insert on public.contacts
  for insert to authenticated with check (user_id = (select auth.uid()));
create policy contacts_update on public.contacts
  for update to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));
create policy contacts_delete on public.contacts
  for delete to authenticated using (user_id = (select auth.uid()));

create policy interactions_select on public.interactions
  for select to authenticated using (user_id = (select auth.uid()));
create policy interactions_insert on public.interactions
  for insert to authenticated with check (user_id = (select auth.uid()));
create policy interactions_update on public.interactions
  for update to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));
create policy interactions_delete on public.interactions
  for delete to authenticated using (user_id = (select auth.uid()));

-- ---------------------------------------------------------------------------
-- Privileges: nothing for the anonymous role, only what the app needs for
-- logged-in users.
-- ---------------------------------------------------------------------------

revoke all on public.contacts, public.interactions, public.contacts_with_last_talked from anon, public;
grant select, insert, update, delete on public.contacts, public.interactions to authenticated;
grant select on public.contacts_with_last_talked to authenticated;
revoke all on function public.search_contact_ids(text) from anon, public;
grant execute on function public.search_contact_ids(text) to authenticated;
