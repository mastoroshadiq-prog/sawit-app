-- =============================================================
-- Supabase SQL: Geo-tagging Audit Schema (append-only)
-- Target table consumed by app: audit_geo_event
-- =============================================================

-- 1) Extension for UUID generation
create extension if not exists pgcrypto;

-- 2) Table
create table if not exists public.audit_geo_event (
  event_id uuid primary key default gen_random_uuid(),
  event_type text not null default 'koreksi_temuan',
  event_time_utc timestamptz not null,

  user_id text not null,
  device_id text not null,
  divisi text not null,
  blok text not null,

  spk_number text null,
  assignment_id text null,

  id_tanaman text not null,
  id_reposisi text null,
  action_label text not null,

  latitude double precision null,
  longitude double precision null,
  accuracy_m double precision null,

  geo_source text not null,
  geo_status text not null,
  geo_captured_at_utc timestamptz not null,

  app_version text not null,
  created_at timestamptz not null default now(),

  constraint audit_geo_event_event_type_chk
    check (event_type in ('koreksi_temuan')),
  constraint audit_geo_event_geo_source_chk
    check (geo_source in ('gps_live', 'last_known', 'none')),
  constraint audit_geo_event_geo_status_chk
    check (geo_status in ('valid', 'fallback_offline', 'unavailable')),
  constraint audit_geo_event_accuracy_chk
    check (accuracy_m is null or accuracy_m >= 0),
  constraint audit_geo_event_latitude_chk
    check (latitude is null or (latitude >= -90 and latitude <= 90)),
  constraint audit_geo_event_longitude_chk
    check (longitude is null or (longitude >= -180 and longitude <= 180))
);

-- 3) Helpful indexes
create index if not exists idx_audit_geo_event_time
  on public.audit_geo_event (event_time_utc desc);

create index if not exists idx_audit_geo_event_user_time
  on public.audit_geo_event (user_id, event_time_utc desc);

create index if not exists idx_audit_geo_event_blok_divisi
  on public.audit_geo_event (blok, divisi);

create index if not exists idx_audit_geo_event_idtanaman
  on public.audit_geo_event (id_tanaman);

create index if not exists idx_audit_geo_event_idreposisi
  on public.audit_geo_event (id_reposisi)
  where id_reposisi is not null;

create index if not exists idx_audit_geo_event_spk
  on public.audit_geo_event (spk_number)
  where spk_number is not null;

create index if not exists idx_audit_geo_event_assignment
  on public.audit_geo_event (assignment_id)
  where assignment_id is not null;

-- 4) Enable RLS
alter table public.audit_geo_event enable row level security;

-- 5) Grants (minimum for anon insert via REST)
grant usage on schema public to anon;
grant insert on public.audit_geo_event to anon;

-- Optional: service_role full access for internal ops
grant all on public.audit_geo_event to service_role;

-- 6) Policies: append-only for anon
drop policy if exists audit_geo_event_insert_anon on public.audit_geo_event;
create policy audit_geo_event_insert_anon
  on public.audit_geo_event
  for insert
  to anon
  with check (true);

-- Explicitly block write mutations other than insert for anon
drop policy if exists audit_geo_event_update_anon on public.audit_geo_event;
create policy audit_geo_event_update_anon
  on public.audit_geo_event
  for update
  to anon
  using (false)
  with check (false);

drop policy if exists audit_geo_event_delete_anon on public.audit_geo_event;
create policy audit_geo_event_delete_anon
  on public.audit_geo_event
  for delete
  to anon
  using (false);

-- Optional read policy for authenticated dashboard users only
-- (uncomment if needed)
-- drop policy if exists audit_geo_event_select_authenticated on public.audit_geo_event;
-- create policy audit_geo_event_select_authenticated
--   on public.audit_geo_event
--   for select
--   to authenticated
--   using (true);

-- 7) Notes for app compatibility
-- - App sends upsert style request with on_conflict=event_id
-- - event_id from app must be valid UUID string
-- - geo fields nullable to support offline unavailable case

