-- =============================================================
-- Supabase SQL: Geo Photo Evidence Schema
-- Table metadata for uploaded photos in Storage bucket
-- =============================================================

create extension if not exists pgcrypto;

create table if not exists public.audit_geo_photo (
  photo_id uuid primary key default gen_random_uuid(),
  event_time_utc timestamptz not null,

  user_id text not null,
  device_id text not null,
  divisi text not null,
  blok text not null,

  spk_number text null,
  assignment_id text null,

  id_tanaman text not null,
  id_reposisi text not null,
  action_label text not null,

  local_path text not null,
  mime_type text not null default 'image/jpeg',
  file_size bigint not null default 0,

  upload_status text not null default 'uploaded',
  storage_path text not null,
  public_url text not null,

  app_version text not null,
  created_at timestamptz not null default now(),

  constraint audit_geo_photo_upload_status_chk
    check (upload_status in ('queued', 'uploaded', 'failed')),
  constraint audit_geo_photo_file_size_chk
    check (file_size >= 0)
);

create unique index if not exists idx_audit_geo_photo_storage_path
  on public.audit_geo_photo (storage_path);

create index if not exists idx_audit_geo_photo_time
  on public.audit_geo_photo (event_time_utc desc);

create index if not exists idx_audit_geo_photo_user
  on public.audit_geo_photo (user_id, event_time_utc desc);

create index if not exists idx_audit_geo_photo_relasi
  on public.audit_geo_photo (id_tanaman, id_reposisi);

-- RLS
alter table public.audit_geo_photo enable row level security;

grant usage on schema public to anon;
grant insert on public.audit_geo_photo to anon;

grant all on public.audit_geo_photo to service_role;

drop policy if exists audit_geo_photo_insert_anon on public.audit_geo_photo;
create policy audit_geo_photo_insert_anon
  on public.audit_geo_photo
  for insert
  to anon
  with check (true);

drop policy if exists audit_geo_photo_update_anon on public.audit_geo_photo;
create policy audit_geo_photo_update_anon
  on public.audit_geo_photo
  for update
  to anon
  using (false)
  with check (false);

drop policy if exists audit_geo_photo_delete_anon on public.audit_geo_photo;
create policy audit_geo_photo_delete_anon
  on public.audit_geo_photo
  for delete
  to anon
  using (false);

-- =============================================================
-- Storage bucket setup (run once, edit bucket name if needed)
-- =============================================================
insert into storage.buckets (id, name, public)
values ('audit-photo', 'audit-photo', true)
on conflict (id) do nothing;

-- Allow anon upload into bucket audit-photo
drop policy if exists storage_audit_photo_insert_anon on storage.objects;
create policy storage_audit_photo_insert_anon
  on storage.objects
  for insert
  to anon
  with check (bucket_id = 'audit-photo');

-- Allow anon read public objects in bucket audit-photo
drop policy if exists storage_audit_photo_select_anon on storage.objects;
create policy storage_audit_photo_select_anon
  on storage.objects
  for select
  to anon
  using (bucket_id = 'audit-photo');

-- Block anon delete
drop policy if exists storage_audit_photo_delete_anon on storage.objects;
create policy storage_audit_photo_delete_anon
  on storage.objects
  for delete
  to anon
  using (false);

