-- =============================================================
-- Dynamic Block Workflow (Koreksi & Temuan)
-- Idempotent SQL for Supabase Postgres
-- =============================================================

create schema if not exists dbo;
create schema if not exists apk;

-- 1) Master blok
create table if not exists dbo.mst_blok (
  blok_code text primary key,
  nama_blok text,
  estate_code text,
  divisi_code text,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_mst_blok_active
  on dbo.mst_blok(is_active, blok_code);

-- 2) Mapping user -> blok yang boleh diinspeksi
create table if not exists dbo.map_petugas_blok (
  kode_unik text not null,
  blok_code text not null,
  can_inspect boolean not null default true,
  from_date date,
  thru_date date,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (kode_unik, blok_code)
);

create index if not exists idx_map_petugas_blok_user
  on dbo.map_petugas_blok(kode_unik, can_inspect);

create index if not exists idx_map_petugas_blok_blok
  on dbo.map_petugas_blok(blok_code);

-- 3) View untuk dropdown blok selectable
create or replace view apk.v_apk_blok_selectable as
select
  b.blok_code,
  coalesce(b.nama_blok, b.blok_code) as nama_blok,
  coalesce(b.estate_code, '-') as estate,
  coalesce(b.divisi_code, '-') as divisi,
  b.is_active
from dbo.mst_blok b
where b.is_active = true;

-- 4) View user + blok mapping
create or replace view apk.v_apk_petugas_blok as
select
  m.kode_unik,
  m.blok_code,
  coalesce(b.nama_blok, b.blok_code) as nama_blok,
  coalesce(b.estate_code, '-') as estate,
  coalesce(b.divisi_code, '-') as divisi,
  m.can_inspect,
  m.from_date,
  m.thru_date
from dbo.map_petugas_blok m
left join dbo.mst_blok b on b.blok_code = m.blok_code
where m.can_inspect = true
  and (m.from_date is null or m.from_date <= current_date)
  and (m.thru_date is null or m.thru_date >= current_date)
  and coalesce(b.is_active, true) = true;

-- 5) Grant select untuk adapter/service role dan klien baca
grant usage on schema dbo to anon, authenticated, service_role;
grant usage on schema apk to anon, authenticated, service_role;

grant select on dbo.mst_blok to anon, authenticated, service_role;
grant select on dbo.map_petugas_blok to anon, authenticated, service_role;

grant select on apk.v_apk_blok_selectable to anon, authenticated, service_role;
grant select on apk.v_apk_petugas_blok to anon, authenticated, service_role;

-- 6) Optional helper indexes untuk data operasional per blok
--    Guard kolom timestamp karena ada environment yang memakai createdAt (quoted)
--    dan ada yang createdat (lowercase).
do $$
begin
  -- reposisi
  if exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'reposisi'
      and column_name = 'createdat'
  ) then
    execute 'create index if not exists idx_reposisi_blok_createdat on public.reposisi(blok, createdat)';
  elsif exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'reposisi'
      and column_name = 'createdAt'
  ) then
    execute 'create index if not exists idx_reposisi_blok_createdat on public.reposisi(blok, "createdAt")';
  else
    execute 'create index if not exists idx_reposisi_blok_only on public.reposisi(blok)';
  end if;

  -- observasi_tambahan
  if exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'observasi_tambahan'
      and column_name = 'createdat'
  ) then
    execute 'create index if not exists idx_observasi_tambahan_blok_createdat on public.observasi_tambahan(blok, createdat)';
  elsif exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'observasi_tambahan'
      and column_name = 'createdAt'
  ) then
    execute 'create index if not exists idx_observasi_tambahan_blok_createdat on public.observasi_tambahan(blok, "createdAt")';
  else
    execute 'create index if not exists idx_observasi_tambahan_blok_only on public.observasi_tambahan(blok)';
  end if;
end $$;

