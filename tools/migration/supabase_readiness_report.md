# Supabase Readiness Report

- Supabase tables: **66**
- Source SQL Server tables: **34**
- Expected (mapped) tables missing in Supabase: **0**
- DAO-detected table names: **11**
- DAO table names missing in Supabase: **10**
- View dependency unresolved items: **22**

## Missing expected tables (sample)

## DAO table names missing in Supabase
- assignment
- auditlog
- eksekusi
- kesehatan
- observasi_tambahan
- petugas
- pohon
- reposisi
- riwayat
- spr_log

## View missing dependencies
- apk.v_apk_assignment->apk.v_apk_assignment
  - dbo.v_assignment
- apk.v_apk_petugas->apk.v_apk_petugas
  - apk.v_petugas_lahan
- apk.v_n_baris->apk.v_n_baris
  - apk.v_apk_assignment
- apk.v_new_nbaris->apk.v_new_nbaris
  - apk.v_n_baris
- apk.v_petugas_lahan->apk.v_petugas_lahan
  - dbo.petugas_lahan
- apk.v_pohon_terkini->apk.v_pohon_terkini
  - apk.v_pohon_terkini_
- apk.v_pohon_terkini_->apk.v_pohon_terkini_
  - apk.v_spk_pohon
  - dbo.v_reposisi_terkini
- apk.v_ref_code->apk.v_ref_code
  - dbo.ref_code
- apk.v_simulasi_pohon->apk.v_simulasi_pohon
  - apk.v_spk_pohon
  - dbo.vsim_reposisi_terkini
- apk.v_spk_pohon->apk.v_spk_pohon
  - dbo.petugas_lahan
- apk.v_spk_pohon_i->apk.v_spk_pohon_i
  - apk.v_new_nbaris
- dbo.v_max_reposisi->dbo.v_max_reposisi
  - dbo.reposisi_pohon
- dbo.v_max_spr->dbo.v_max_spr
  - dbo.stand_per_row
- dbo.v_pohon_tambahan->dbo.v_pohon_tambahan
  - dbo.reposisi_pohon
- dbo.v_pohon_terkini->dbo.v_pohon_terkini
  - dbo.reposisi_pohon
- dbo.v_reposisi_terkini->dbo.v_reposisi_terkini
  - dbo.reposisi_pohon
  - dbo.v_max_reposisi
- dbo.v_spr_terkini->dbo.v_spr_terkini
  - dbo.v_spr_tgl_terkini
- dbo.v_spr_tgl_terkini->dbo.v_spr_tgl_terkini
  - dbo.stand_per_row
  - dbo.v_max_spr
- dbo.vsim_max_reposisi->dbo.vsim_max_reposisi
  - dbo.reposisi_pohon
- dbo.vsim_pohon_tambahan->dbo.vsim_pohon_tambahan
  - dbo.reposisi_pohon
- dbo.vsim_reposisi_terkini->dbo.vsim_reposisi_terkini
  - dbo.reposisi_pohon
  - dbo.vsim_max_reposisi
- web.vw_pohon_terkini->web.vw_pohon_terkini
  - dbo.v_pohon_terkini