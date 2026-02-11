-- Priority SQL Patch to close missing tables and stabilize view dependency for SYNC_SOURCE=supabase
-- Generated from readiness assessment artifacts.

BEGIN;

CREATE SCHEMA IF NOT EXISTS dbo;
CREATE SCHEMA IF NOT EXISTS apk;
CREATE SCHEMA IF NOT EXISTS web;

-- 1) Close 15 missing source tables in dbo (bootstrap-first, refine constraints later)
CREATE TABLE IF NOT EXISTS dbo.pihak_peran (
  id_pihak_peran TEXT,
  payload JSONB,
  created_at TIMESTAMP,
  updated_at TIMESTAMP
);

CREATE TABLE IF NOT EXISTS dbo.pihak_posisi (
  id_pihak_posisi TEXT,
  payload JSONB,
  created_at TIMESTAMP,
  updated_at TIMESTAMP
);

CREATE TABLE IF NOT EXISTS dbo.pihak_relasi (
  id_pihak_relasi TEXT,
  payload JSONB,
  created_at TIMESTAMP,
  updated_at TIMESTAMP
);

CREATE TABLE IF NOT EXISTS dbo.pihak_tipe_peran (
  id_pihak_tipe_peran TEXT,
  payload JSONB,
  created_at TIMESTAMP,
  updated_at TIMESTAMP
);

CREATE TABLE IF NOT EXISTS dbo.pihak_tipe_posisi (
  id_pihak_tipe_posisi TEXT,
  payload JSONB,
  created_at TIMESTAMP,
  updated_at TIMESTAMP
);

CREATE TABLE IF NOT EXISTS dbo.posisi_histori (
  id_posisi_histori TEXT,
  payload JSONB,
  created_at TIMESTAMP,
  updated_at TIMESTAMP
);

CREATE TABLE IF NOT EXISTS dbo.posisi_struktur (
  id_posisi_struktur TEXT,
  payload JSONB,
  created_at TIMESTAMP,
  updated_at TIMESTAMP
);

CREATE TABLE IF NOT EXISTS dbo.posisi_tupoksi (
  id_posisi_tupoksi TEXT,
  payload JSONB,
  created_at TIMESTAMP,
  updated_at TIMESTAMP
);

CREATE TABLE IF NOT EXISTS dbo.sop_referensi (
  id_sop_referensi TEXT,
  payload JSONB,
  created_at TIMESTAMP,
  updated_at TIMESTAMP
);

CREATE TABLE IF NOT EXISTS dbo.sop_referensi_versi (
  id_sop_referensi_versi TEXT,
  payload JSONB,
  created_at TIMESTAMP,
  updated_at TIMESTAMP
);

CREATE TABLE IF NOT EXISTS dbo.sop_tipe (
  id_sop_tipe TEXT,
  payload JSONB,
  created_at TIMESTAMP,
  updated_at TIMESTAMP
);

CREATE TABLE IF NOT EXISTS dbo.sop_tipe_versi (
  id_sop_tipe_versi TEXT,
  payload JSONB,
  created_at TIMESTAMP,
  updated_at TIMESTAMP
);

CREATE TABLE IF NOT EXISTS dbo.task_execution (
  id_task_execution TEXT,
  payload JSONB,
  created_at TIMESTAMP,
  updated_at TIMESTAMP
);

CREATE TABLE IF NOT EXISTS dbo.tupoksi_tipe (
  id_tupoksi_tipe TEXT,
  payload JSONB,
  created_at TIMESTAMP,
  updated_at TIMESTAMP
);

CREATE TABLE IF NOT EXISTS dbo.tupoksi_valid (
  id_tupoksi_valid TEXT,
  payload JSONB,
  created_at TIMESTAMP,
  updated_at TIMESTAMP
);

-- 2) Ensure core missing dependencies for current view chain
CREATE TABLE IF NOT EXISTS dbo.petugas_lahan (
  id_penugasan TEXT,
  id_petugas TEXT,
  jenis_lahan TEXT,
  kode_lahan TEXT,
  tanggal_mulai TIMESTAMP,
  tanggal_selesai DATE
);

CREATE TABLE IF NOT EXISTS dbo.ref_code (
  kode NUMERIC(38,0),
  istilah TEXT,
  nama_error TEXT,
  keterangan TEXT,
  jenis TEXT
);

CREATE TABLE IF NOT EXISTS dbo.reposisi_pohon (
  id_reposisi TEXT,
  id_tanaman TEXT,
  pohon_awal INTEGER,
  baris_awal INTEGER,
  pohon_tujuan INTEGER,
  baris_tujuan INTEGER,
  keterangan TEXT,
  petugas TEXT,
  from_date TIMESTAMP,
  thru_date TIMESTAMP,
  tipe_riwayat TEXT,
  blok TEXT
);

CREATE TABLE IF NOT EXISTS dbo.stand_per_row (
  id_spr TEXT,
  blok TEXT,
  nbaris INTEGER,
  spr_awal INTEGER,
  spr_akhir INTEGER,
  keterangan TEXT,
  petugas TEXT,
  from_date TIMESTAMP,
  thru_date TIMESTAMP
);

-- Needed by dbo.v_assignment conversion
ALTER TABLE IF EXISTS dbo.ops_sub_tindakan
  ADD COLUMN IF NOT EXISTS nama_sub_tindakan TEXT;

COMMIT;

-- 3) Run view DDL in this order after this patch:
--    a) tools/migration/converted_views_postgres.sql
--    b) tools/migration/converted_views_apk_postgres.sql
--    c) tools/migration/converted_views_web_postgres.sql

