# Changelog

Semua perubahan penting pada project ini dicatat di file ini.

## [Unreleased]

## [2026-02-13] - Smart Login, Sign Out, dan Stabilitas Sync Blok

### Added
- Menambahkan flow **smart login**: skip initial sync jika data lokal blok aktif sudah siap.
- Menambahkan **Sign Out** di menu utama dengan konfirmasi dan warning bila ada pending sync.
- Menambahkan dokumentasi handover lintas device di [`README.md`](README.md).

### Changed
- Kebijakan cleanup saat login diubah: cleanup penuh hanya saat **user switch**.
- Normalisasi kode blok (`trim + upper`) pada sync tanaman/SPR agar konsisten lintas API dan SQLite.
- Query DAO untuk baca/hapus per blok dibuat case-insensitive (`TRIM(UPPER(...))`).

### Fixed
- Memperbaiki issue integrity check: `Data pohon blok D001A kosong` (false-negative karena mismatch format blok).
- Menyamakan perhitungan jumlah item pada card sync agar tidak lagi menampilkan jumlah batch sebagai jumlah record.

### UI/UX
- Penyegaran UI header reposisi agar lebih soft dan selaras dengan menu utama.
- Penggantian ikon navigasi kiri/kanan menjadi lebih jelas.
- Perbaikan visibilitas tombol tengah `POSISI AWAL`.
- Perbaikan tampilan card `SPR` (`xx/xx`) dan label `Baris` agar lebih eye-catching namun tetap soft.

### Technical References
- Smart login: [`tombolLogin()`](lib/screens/widgets/w_login.dart:163)
- Sign out: [`_handleSignOut()`](lib/screens/scr_menu.dart:399)
- Sync tanaman: [`_syncTanaman()`](lib/screens/scr_initial_sync.dart:690)
- Sync SPR: [`_syncSPRBlok()`](lib/screens/scr_initial_sync.dart:746)
- Integrity check: [`_runPostSyncIntegrityCheck()`](lib/screens/scr_initial_sync.dart:340)
- DAO blok match: [`getAllPohonByBlok()`](lib/mvc_dao/dao_pohon.dart:51), [`getByBlok()`](lib/mvc_dao/dao_spr.dart:47)

---

Format ini mengacu pada prinsip Keep a Changelog (adaptasi internal project).