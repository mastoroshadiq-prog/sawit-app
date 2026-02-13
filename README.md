# Sawit App (Flutter Mobile)

Aplikasi mobile untuk operasional lapangan kebun sawit dengan pendekatan **offline-first**: data dipakai dari lokal (SQLite) lalu disinkronkan ke server saat jaringan tersedia.

## Tujuan Aplikasi

- Mendukung aktivitas petugas lapangan secara cepat dan stabil.
- Menjaga data tetap aman saat offline, lalu sinkron saat online.
- Menyediakan alur kerja yang jelas dari login, initial sync, eksekusi tugas, hingga pelaporan perubahan data lapangan.

## Fitur yang Sudah Ada

- Login petugas dan pengenalan konteks kerja (akun/blok).
- Initial sync bertahap (SPK, tanaman, SPR, finalisasi) dengan indikator progres per-step.
- Mekanisme checkpoint untuk melanjutkan proses sinkronisasi yang terhenti.
- Eksekusi tugas lapangan dan pembaruan status pekerjaan.
- Pencatatan kesehatan tanaman.
- Reposisi tanaman dengan histori perubahan.
- Observasi tambahan.
- Outbound sync berbasis batch untuk data hasil kerja lapangan.
- Audit log aktivitas sinkronisasi/perubahan.

## Arsitektur Singkat

Struktur modul utama:

- [`lib/main.dart`](lib/main.dart): entry point aplikasi dan routing.
- [`lib/screens`](lib/screens): UI, flow login, sync, menu, reposisi, dan aksi lapangan.
- [`lib/mvc_models`](lib/mvc_models): model domain.
- [`lib/mvc_dao`](lib/mvc_dao): akses dan manipulasi data SQLite.
- [`lib/mvc_services`](lib/mvc_services): komunikasi API/backend.
- [`lib/plantdb`](lib/plantdb): setup database lokal.
- [`supabase/functions/wfsnew-adapter/index.ts`](supabase/functions/wfsnew-adapter/index.ts): adapter endpoint kompatibel format legacy sinkronisasi.

## Alur Sinkronisasi

### 1) Initial Sync

Implementasi utama di [`InitialSyncPage`](lib/screens/scr_initial_sync.dart:153):

1. Reset data lokal (dengan proteksi terhadap data belum tersinkron)
2. Ambil data SPK
3. Ambil riwayat kesehatan
4. Ambil data tanaman
5. Ambil data SPR
6. Finalisasi data lokal

### 2) Outbound Sync

Implementasi di [`_sendAllBatchesX()`](lib/screens/scr_sync_action.dart:187):

- Data dikirim per kategori dan per sub-batch.
- Setiap batch sukses akan menandai flag lokal agar idempotent.
- Jika batch gagal, proses kategori dihentikan dan pesan error ditampilkan.

## Stack Teknologi

- Flutter (Dart)
- SQLite (`sqflite`)
- HTTP API
- Shared Preferences
- Supabase Edge Function (adapter backend)

Referensi dependency: [`pubspec.yaml`](pubspec.yaml).

## Menjalankan Project

Prasyarat:

- Flutter SDK (stable)
- Android SDK / emulator / perangkat fisik

Perintah dasar:

```bash
flutter pub get
flutter analyze
flutter run
```

## Catatan Operasional

- Jalankan [`flutter analyze`](analysis_options.yaml) sebelum commit.
- Untuk deployment adapter Supabase, pastikan command dieksekusi dari root project.
- Gunakan konfigurasi environment yang konsisten antara app Flutter dan Edge Function.

## Login & Sync Policy (Current)

Kebijakan terbaru agar workflow lapangan lebih efisien:

- **Initial sync tidak wajib setiap login**.
- Setelah login sukses, aplikasi akan cek kesiapan data lokal blok aktif (Assignment + Pohon + SPR).
- Jika data lokal siap, user langsung masuk menu utama.
- Jika belum siap, user diarahkan ke initial sync.
- Sign out tersedia di menu utama, dengan warning bila ada data pending belum tersinkron.

Referensi implementasi:

- Smart login: [`tombolLogin()`](lib/screens/widgets/w_login.dart:163)
- Initial sync tanaman + integrity: [`_syncTanaman()`](lib/screens/scr_initial_sync.dart:690)
- Initial sync SPR: [`_syncSPRBlok()`](lib/screens/scr_initial_sync.dart:746)
- Sign out + pending warning: [`_handleSignOut()`](lib/screens/scr_menu.dart:399)

## Handover Cepat Antar Device (Wajib)

Saat pindah laptop/PC, gunakan checklist ini agar konteks langsung tersambung:

1. Pull branch terbaru dari remote.
2. Baca bagian ini di README + ringkasan perubahan di [`CHANGELOG.md`](CHANGELOG.md).
3. Jalankan baseline command:
   - `flutter pub get`
   - `flutter analyze`
4. Validasi flow kritikal:
   - Login user lama (tanpa initial sync berulang)
   - Initial sync user/blok baru
   - Outbound sync pending
   - Sign out

## Known Issues & Troubleshooting

### Kasus: Integrity check gagal "Data pohon blok D001A kosong"

Kemungkinan penyebab:

- Mismatch format kode blok (case/whitespace) antara API dan SQLite.
- Data lama blok bercampur dengan format blok berbeda.

Perbaikan yang sudah diterapkan:

- Normalisasi blok `trim + upper` pada proses sync.
- Query DAO blok dibuat case-insensitive (`TRIM(UPPER(...))`).
- Refresh data per blok dilakukan delete-by-blok sebelum insert ulang.

Referensi:

- [`PohonDao.getAllPohonByBlok()`](lib/mvc_dao/dao_pohon.dart:51)
- [`SPRDao.getByBlok()`](lib/mvc_dao/dao_spr.dart:47)
- [`_runPostSyncIntegrityCheck()`](lib/screens/scr_initial_sync.dart:340)

## Next Steps Teknis (Prioritas)

- Tambahkan marker versi schema lokal agar migrasi/compatibility lebih mudah dilacak.
- Tambahkan dokumentasi release note singkat di setiap merge utama.
- Tambahkan test skenario login ulang (same user), user switch, dan integrity post-sync.

## Roadmap Perbaikan (Disarankan)

- Penyempurnaan retry initial sync agar selalu melanjutkan dari step gagal secara deterministik.
- Penambahan observability log sinkronisasi (client + server) yang lebih terstruktur.
- Integrasi uji otomatis untuk skenario sinkronisasi gagal/lanjut.

## Repository

Target repository:

- [`sawit-app`](https://github.com/mastoroshadiq-prog/sawit-app.git)
