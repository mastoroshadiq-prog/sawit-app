-- Login bootstrap for Supabase adapter (legacy-compatible)
-- Jalankan di Supabase SQL Editor

-- 1) Pastikan schema tersedia
create schema if not exists dbo;
create schema if not exists apk;

-- 2) Pastikan table master_pihak ada (minimal kolom untuk login/view)
create table if not exists dbo.master_pihak (
  id_pihak text primary key,
  tipe text,
  nama text,
  kode_unik text,
  id_induk text,
  alias text,
  id_unik text,
  jenis_id text
);

-- 3) Pastikan table petugas_lahan ada (sumber blok/divisi untuk v_apk_petugas)
create table if not exists dbo.petugas_lahan (
  id_penugasan text,
  id_petugas text,
  jenis_lahan text,
  kode_lahan text,
  from_date timestamp,
  thru_date timestamp
);

-- 4) Pastikan table master_lahan ada (sumber divisi)
create table if not exists dbo.master_lahan (
  id_lahan text primary key,
  nama_lahan text,
  kode_tipe text,
  kode_induk text,
  nilai numeric,
  satuan text,
  keterangan text
);

-- 5) Buat/refresh view v_petugas_lahan
create or replace view apk.v_petugas_lahan as
select a.*, b.kode_induk as divisi
from dbo.petugas_lahan a
left join dbo.master_lahan b
  on b.id_lahan = a.kode_lahan;

-- 6) Buat/refresh view v_apk_petugas (dipakai fallback login adapter)
create or replace view apk.v_apk_petugas as
select b.*, a.kode_lahan as blok, a.divisi
from apk.v_petugas_lahan a
left join dbo.master_pihak b
  on b.kode_unik = a.id_petugas
where b.jenis_id = 'PWD';

-- 7) Seed 1 akun login minimal (ubah nilainya sesuai kebutuhan)
--    Akun login = kode_unik
insert into dbo.master_pihak (id_pihak, tipe, nama, kode_unik, jenis_id)
values ('U-TEST-001', 'MANDOR', 'USER TEST', 'tester01', 'PWD')
on conflict (id_pihak) do update set
  tipe = excluded.tipe,
  nama = excluded.nama,
  kode_unik = excluded.kode_unik,
  jenis_id = excluded.jenis_id;

insert into dbo.master_lahan (id_lahan, nama_lahan, kode_tipe, kode_induk)
values ('BLK-A01', 'BLOK A01', 'BLK', 'DIV-A')
on conflict (id_lahan) do update set
  nama_lahan = excluded.nama_lahan,
  kode_tipe = excluded.kode_tipe,
  kode_induk = excluded.kode_induk;

update dbo.master_lahan
set keterangan = 'BLK-A01'
where id_lahan = 'BLK-A01';

do $$
begin
  -- Adaptif ke struktur tabel existing (karena skema bisa beda antar project)
  if exists (
    select 1
    from information_schema.columns
    where table_schema = 'dbo'
      and table_name = 'petugas_lahan'
      and column_name = 'from_date'
  ) then
    insert into dbo.petugas_lahan (id_penugasan, id_petugas, jenis_lahan, kode_lahan, from_date, thru_date)
    values ('ASG-TEST-001', 'tester01', 'BLOK', 'BLK-A01', now(), null);
  else
    insert into dbo.petugas_lahan (id_penugasan, id_petugas, jenis_lahan, kode_lahan)
    values ('ASG-TEST-001', 'tester01', 'BLOK', 'BLK-A01');
  end if;
exception when undefined_column then
  -- fallback terakhir jika struktur sangat minimal
  insert into dbo.petugas_lahan (id_petugas, kode_lahan)
  values ('tester01', 'BLK-A01');
end $$;

-- 8) Grant akses schema + objek untuk role API
grant usage on schema apk to anon, authenticated, service_role;
grant usage on schema dbo to anon, authenticated, service_role;

grant select on all tables in schema apk to anon, authenticated, service_role;
grant select on all tables in schema dbo to anon, authenticated, service_role;

grant select on all sequences in schema apk to anon, authenticated, service_role;
grant select on all sequences in schema dbo to anon, authenticated, service_role;

alter default privileges in schema apk grant select on tables to anon, authenticated, service_role;
alter default privileges in schema dbo grant select on tables to anon, authenticated, service_role;

-- 9) Verifikasi cepat
select count(*) as cnt_master_pihak from dbo.master_pihak;
select count(*) as cnt_v_apk_petugas from apk.v_apk_petugas;
select id_pihak, kode_unik, nama, tipe, blok, divisi from apk.v_apk_petugas limit 10;

-- 10) Seed minimal data untuk initial sync (apk.task + spr.blok)
-- v_assignment dependency (ops_* + kebun_n_pokok)
insert into dbo.kebun_n_pokok (
  id_npokok, id_tanaman, id_tipe, n_baris, n_pokok, tgl_tanam, petugas, from_date, thru_date, catatan, kode
)
values (
  'NPK-TEST-001', 'TNM-TEST-001', 'TP-01', 1, 1, current_date, 'tester01', now(), null, 'BLK-A01', 'S'
)
on conflict (id_npokok) do nothing;

insert into dbo.ops_sub_tindakan (
  id_sub_tindakan, id_fase_besar, nama_sub_tindakan, kode_sub_tindakan, deskripsi, created_at, updated_at
)
values (
  'SUB-TEST-001', null, 'PEMUPUKAN TEST', 'PMK-T', 'seed testing', now(), now()
)
on conflict (id_sub_tindakan) do nothing;

insert into dbo.ops_jadwal_tindakan (
  id_jadwal_tindakan, id_tanaman, id_sub_tindakan, frekuensi, interval_hari, tanggal_mulai, tanggal_selesai, created_at, updated_at
)
values (
  'JDL-TEST-001', 'TNM-TEST-001', 'SUB-TEST-001', 'HARIAN', 1, now(), null, now(), now()
)
on conflict (id_jadwal_tindakan) do nothing;

insert into dbo.ops_spk_tindakan (
  id_spk, id_jadwal_tindakan, nomor_spk, tanggal_terbit, tanggal_mulai, tanggal_selesai,
  status, penanggung_jawab, mandor, lokasi, uraian_pekerjaan, catatan, created_at, updated_at
)
values (
  'SPK-TEST-001', 'JDL-TEST-001', 'SPK/TEST/001', current_date, current_date, null,
  'DISETUJUI', null, 'tester01', 'BLK-A01', 'seed task', '-', now(), now()
)
on conflict (id_spk) do nothing;

-- stand_per_row untuk v_spr_terkini (opsional; fallback ke hitung pohon jika kosong)
insert into dbo.stand_per_row (
  id_spr, blok, nbaris, spr_awal, spr_akhir, keterangan, petugas, from_date, thru_date
)
select 'SPR-TEST-001', 'BLK-A01', 1, 1, 1, 'seed spr', 'tester01', now(), null
where exists (
  select 1 from information_schema.tables
  where table_schema = 'dbo' and table_name = 'stand_per_row'
);

-- 11) Verifikasi final untuk endpoint initial sync
select count(*) as cnt_apk_task_tester01 from apk.v_apk_assignment where mandor = 'tester01';
select count(*) as cnt_blok_pohon_tester01 from apk.v_pohon_terkini where mandor = 'tester01';
select count(*) as cnt_spr_blk_a01 from dbo.v_spr_terkini where blok = 'BLK-A01';

