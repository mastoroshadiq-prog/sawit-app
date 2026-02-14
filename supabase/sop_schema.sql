-- =============================================================
-- Supabase SQL: SOP Master + Checklist Execution (Tahap 2)
-- =============================================================

create extension if not exists pgcrypto;

-- 1) SOP master
create table if not exists public.sop_master (
  sop_id text primary key,
  sop_code text not null,
  sop_name text not null,
  sop_version text not null default '1.0',
  task_keyword text not null default '',
  is_active boolean not null default true,
  updated_at timestamptz not null default now()
);

-- 2) SOP step detail
create table if not exists public.sop_step (
  step_id text primary key,
  sop_id text not null references public.sop_master(sop_id) on delete cascade,
  step_order integer not null,
  step_title text not null,
  is_required boolean not null default true,
  evidence_type text not null default 'none',
  is_active boolean not null default true,
  updated_at timestamptz not null default now()
);

-- 3) Mapping task/SPK ke SOP
create table if not exists public.task_sop_map (
  map_id text primary key,
  sop_id text not null references public.sop_master(sop_id) on delete cascade,
  assignment_id text null,
  spk_number text null,
  source_type text not null default 'server',
  is_active boolean not null default true,
  updated_at timestamptz not null default now()
);

-- 4) Checklist execution (hasil centang dari device)
create table if not exists public.task_sop_check (
  check_id text primary key,
  execution_id text null,
  assignment_id text not null,
  spk_number text null,
  sop_id text not null references public.sop_master(sop_id),
  step_id text not null references public.sop_step(step_id),
  is_checked integer not null default 0 check (is_checked in (0, 1)),
  note text null,
  evidence_path text null,
  checked_at timestamptz not null,
  flag integer not null default 1,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- 5) Indexes
create index if not exists idx_sop_master_active
  on public.sop_master (is_active, sop_code);

create index if not exists idx_sop_step_sop_order
  on public.sop_step (sop_id, step_order)
  where is_active = true;

create index if not exists idx_task_sop_map_spk
  on public.task_sop_map (spk_number)
  where is_active = true;

create index if not exists idx_task_sop_check_assign
  on public.task_sop_check (assignment_id, checked_at desc);

create index if not exists idx_task_sop_check_spk
  on public.task_sop_check (spk_number, checked_at desc)
  where spk_number is not null;

-- 6) Seed default SOP fallback
insert into public.sop_master (
  sop_id,
  sop_code,
  sop_name,
  sop_version,
  task_keyword,
  is_active
) values (
  'SOP-GENERAL-TASK',
  'SOP-GEN-001',
  'SOP Umum Pengerjaan Task Lapangan',
  '1.0',
  'TASK',
  true
)
on conflict (sop_id) do update set
  sop_code = excluded.sop_code,
  sop_name = excluded.sop_name,
  sop_version = excluded.sop_version,
  task_keyword = excluded.task_keyword,
  is_active = excluded.is_active,
  updated_at = now();

insert into public.sop_master (
  sop_id,
  sop_code,
  sop_name,
  sop_version,
  task_keyword,
  is_active
) values (
  'SOP-PEMUPUKAN',
  'SOP-FERT-001',
  'SOP Pemupukan Kelapa Sawit',
  '1.0',
  'pemupukan|pupuk|fertilizer',
  true
)
on conflict (sop_id) do update set
  sop_code = excluded.sop_code,
  sop_name = excluded.sop_name,
  sop_version = excluded.sop_version,
  task_keyword = excluded.task_keyword,
  is_active = excluded.is_active,
  updated_at = now();

insert into public.sop_master (
  sop_id,
  sop_code,
  sop_name,
  sop_version,
  task_keyword,
  is_active
) values (
  'SOP-SURVEY-POHON',
  'SOP-SRV-001',
  'SOP Survey / Inspeksi Pohon',
  '1.0',
  'survey|inspeksi|observasi|monitoring|cek pohon',
  true
)
on conflict (sop_id) do update set
  sop_code = excluded.sop_code,
  sop_name = excluded.sop_name,
  sop_version = excluded.sop_version,
  task_keyword = excluded.task_keyword,
  is_active = excluded.is_active,
  updated_at = now();

insert into public.sop_master (
  sop_id,
  sop_code,
  sop_name,
  sop_version,
  task_keyword,
  is_active
) values (
  'SOP-KOREKSI-TEMUAN',
  'SOP-KOR-001',
  'SOP Koreksi & Temuan Lapangan',
  '1.0',
  'koreksi|temuan|reposisi|ganoderma',
  true
)
on conflict (sop_id) do update set
  sop_code = excluded.sop_code,
  sop_name = excluded.sop_name,
  sop_version = excluded.sop_version,
  task_keyword = excluded.task_keyword,
  is_active = excluded.is_active,
  updated_at = now();

insert into public.sop_step (
  step_id,
  sop_id,
  step_order,
  step_title,
  is_required,
  evidence_type,
  is_active
) values
  ('SOP-GEN-STEP-01', 'SOP-GENERAL-TASK', 1, 'Verifikasi lokasi kerja (blok/baris/pohon)', true,  'none',  true),
  ('SOP-GEN-STEP-02', 'SOP-GENERAL-TASK', 2, 'Pastikan APD dan keselamatan kerja terpenuhi', true,  'none',  true),
  ('SOP-GEN-STEP-03', 'SOP-GENERAL-TASK', 3, 'Laksanakan tindakan sesuai instruksi SPK', true,  'none',  true),
  ('SOP-GEN-STEP-04', 'SOP-GENERAL-TASK', 4, 'Ambil dokumentasi hasil pekerjaan', true,  'photo', true),
  ('SOP-GEN-STEP-05', 'SOP-GENERAL-TASK', 5, 'Catat temuan penting jika ada', false, 'note',  true)
on conflict (step_id) do update set
  sop_id = excluded.sop_id,
  step_order = excluded.step_order,
  step_title = excluded.step_title,
  is_required = excluded.is_required,
  evidence_type = excluded.evidence_type,
  is_active = excluded.is_active,
  updated_at = now();

insert into public.sop_step (
  step_id,
  sop_id,
  step_order,
  step_title,
  is_required,
  evidence_type,
  is_active
) values
  ('SOP-FERT-STEP-01', 'SOP-PEMUPUKAN', 1, 'Validasi SPK dan area target pemupukan', true,  'none',  true),
  ('SOP-FERT-STEP-02', 'SOP-PEMUPUKAN', 2, 'Cek dosis pupuk sesuai rekomendasi agronomi', true,  'note',  true),
  ('SOP-FERT-STEP-03', 'SOP-PEMUPUKAN', 3, 'Pastikan APD lengkap sebelum aplikasi pupuk', true,  'none',  true),
  ('SOP-FERT-STEP-04', 'SOP-PEMUPUKAN', 4, 'Aplikasikan pupuk sesuai pola sebar standar', true,  'none',  true),
  ('SOP-FERT-STEP-05', 'SOP-PEMUPUKAN', 5, 'Dokumentasi sebelum/sesudah pemupukan', true,  'photo', true),
  ('SOP-FERT-STEP-06', 'SOP-PEMUPUKAN', 6, 'Catat deviasi dosis atau kendala lapangan', false, 'note',  true)
on conflict (step_id) do update set
  sop_id = excluded.sop_id,
  step_order = excluded.step_order,
  step_title = excluded.step_title,
  is_required = excluded.is_required,
  evidence_type = excluded.evidence_type,
  is_active = excluded.is_active,
  updated_at = now();

insert into public.sop_step (
  step_id,
  sop_id,
  step_order,
  step_title,
  is_required,
  evidence_type,
  is_active
) values
  ('SOP-SRV-STEP-01', 'SOP-SURVEY-POHON', 1, 'Validasi blok/baris/pohon sesuai rute survey', true,  'none',  true),
  ('SOP-SRV-STEP-02', 'SOP-SURVEY-POHON', 2, 'Lakukan observasi visual kondisi tanaman', true,  'none',  true),
  ('SOP-SRV-STEP-03', 'SOP-SURVEY-POHON', 3, 'Catat status/kategori temuan secara konsisten', true,  'note',  true),
  ('SOP-SRV-STEP-04', 'SOP-SURVEY-POHON', 4, 'Ambil foto bukti untuk pohon/area temuan', true,  'photo', true),
  ('SOP-SRV-STEP-05', 'SOP-SURVEY-POHON', 5, 'Tambahkan catatan tindak lanjut awal', false, 'note',  true)
on conflict (step_id) do update set
  sop_id = excluded.sop_id,
  step_order = excluded.step_order,
  step_title = excluded.step_title,
  is_required = excluded.is_required,
  evidence_type = excluded.evidence_type,
  is_active = excluded.is_active,
  updated_at = now();

insert into public.sop_step (
  step_id,
  sop_id,
  step_order,
  step_title,
  is_required,
  evidence_type,
  is_active
) values
  ('SOP-KOR-STEP-01', 'SOP-KOREKSI-TEMUAN', 1, 'Validasi titik koreksi (blok/baris/pohon) sebelum aksi', true,  'none',  true),
  ('SOP-KOR-STEP-02', 'SOP-KOREKSI-TEMUAN', 2, 'Konfirmasi jenis temuan dan opsi tindakan', true,  'note',  true),
  ('SOP-KOR-STEP-03', 'SOP-KOREKSI-TEMUAN', 3, 'Eksekusi reposisi/koreksi sesuai aturan operasional', true,  'none',  true),
  ('SOP-KOR-STEP-04', 'SOP-KOREKSI-TEMUAN', 4, 'Dokumentasi hasil koreksi/temuan', true,  'photo', true),
  ('SOP-KOR-STEP-05', 'SOP-KOREKSI-TEMUAN', 5, 'Catat rekomendasi tindak lanjut bila diperlukan', false, 'note',  true)
on conflict (step_id) do update set
  sop_id = excluded.sop_id,
  step_order = excluded.step_order,
  step_title = excluded.step_title,
  is_required = excluded.is_required,
  evidence_type = excluded.evidence_type,
  is_active = excluded.is_active,
  updated_at = now();

insert into public.task_sop_map (
  map_id,
  sop_id,
  assignment_id,
  spk_number,
  source_type,
  is_active
) values (
  'MAP-SOP-GEN-DEFAULT',
  'SOP-GENERAL-TASK',
  null,
  null,
  'seed',
  true
)
on conflict (map_id) do update set
  sop_id = excluded.sop_id,
  assignment_id = excluded.assignment_id,
  spk_number = excluded.spk_number,
  source_type = excluded.source_type,
  is_active = excluded.is_active,
  updated_at = now();

insert into public.task_sop_map (
  map_id,
  sop_id,
  assignment_id,
  spk_number,
  source_type,
  is_active
) values
  ('MAP-SOP-PEMUPUKAN-KEY', 'SOP-PEMUPUKAN', null, null, 'seed', true),
  ('MAP-SOP-SURVEY-KEY', 'SOP-SURVEY-POHON', null, null, 'seed', true),
  ('MAP-SOP-KOREKSI-KEY', 'SOP-KOREKSI-TEMUAN', null, null, 'seed', true)
on conflict (map_id) do update set
  sop_id = excluded.sop_id,
  assignment_id = excluded.assignment_id,
  spk_number = excluded.spk_number,
  source_type = excluded.source_type,
  is_active = excluded.is_active,
  updated_at = now();

