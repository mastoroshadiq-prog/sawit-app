# Kebun Sawit Mobile App

Aplikasi Flutter untuk mendukung operasional lapangan perkebunan sawit: mulai dari otentikasi petugas, sinkronisasi data awal, eksekusi tugas, pencatatan kesehatan tanaman, reposisi, hingga sinkronisasi data kembali ke server.

## Ringkasan Singkat

Project ini berfokus pada **workflow offline-first** dengan penyimpanan lokal SQLite, lalu sinkronisasi bertahap ke backend ketika koneksi tersedia. Aplikasi dirancang untuk kebutuhan petugas lapangan dengan antarmuka yang sederhana namun informatif.

## Fitur Utama

- Login petugas dan pengaturan konteks kerja (akun/blok).
- Initial sync data operasional (SPK, tanaman, SPR, dll).
- Progress sinkronisasi bertahap per-step dengan status detail:
  - `running`, `success`, `failed`
  - indikator item count per step
  - resume step gagal / pilih step awal / ulang semua
- Eksekusi tugas lapangan.
- Pencatatan kesehatan tanaman.
- Reposisi tanaman.
- Sinkronisasi outbound berbasis batch.
- Dasar pelaporan PDF.

## Arsitektur & Struktur Modul

Struktur utama di folder [`lib/`](lib):

- [`main.dart`](lib/main.dart): entrypoint aplikasi dan konfigurasi route.
- [`screens/`](lib/screens): layer UI/flow per halaman.
- [`mvc_models/`](lib/mvc_models): model data/domain.
- [`mvc_dao/`](lib/mvc_dao): akses data SQLite (DAO).
- [`plantdb/`](lib/plantdb): inisialisasi skema database lokal.
- [`mvc_services/`](lib/mvc_services): service API/network.
- [`mvc_libs/`](lib/mvc_libs): utilitas umum (PDF, koneksi, dsb).

## Alur Sinkronisasi

### 1) Initial Sync (setelah login)

Implementasi utama di [`InitialSyncPage`](lib/screens/scr_initial_sync.dart:131).

Step yang dijalankan berurutan:
1. Reset data lokal
2. Ambil data SPK
3. Ambil data riwayat kesehatan
4. Ambil data tanaman
5. Ambil data Stand Per Row (SPR)
6. Finalisasi simpan data

Dengan checkpoint lokal, jika ada step gagal user bisa:
- ulang dari step gagal,
- pilih step awal tertentu,
- atau ulang semua proses.

### 2) Outbound Sync (kirim data ke server)

Implementasi di [`scr_sync_action.dart`](lib/screens/scr_sync_action.dart:172) menggunakan batch per jenis data (tugas, kesehatan, reposisi, SPR log, audit log) agar proses lebih stabil dan terukur.

## Teknologi yang Digunakan

- Flutter + Dart
- SQLite via `sqflite`
- HTTP client
- Shared Preferences
- Image Picker + Permission Handler
- PDF/Printing

Lihat dependency aktif pada [`pubspec.yaml`](pubspec.yaml:30).

## Menjalankan Project

### Prasyarat
- Flutter SDK (sesuai channel stable)
- Android SDK / emulator atau device fisik

### Perintah dasar

```bash
flutter pub get
flutter analyze
flutter run
```

Untuk target device spesifik:

```bash
flutter run -d emulator-5554
```

## Kualitas Kode

Project ini menggunakan static analysis Flutter/Dart melalui [`analysis_options.yaml`](analysis_options.yaml). Selalu jalankan:

```bash
flutter analyze
```

sebelum commit/push agar kualitas kode tetap konsisten.

## Catatan Pengembangan

- Fokus utama saat ini adalah stabilitas sinkronisasi lapangan dan observabilitas proses sync.
- Untuk perubahan besar alur sync, prioritaskan backward compatibility terhadap data lokal/checkpoint.
- Jika ada kendala build path/gradle di Windows, lakukan stop daemon + clean build sebelum diagnosis lanjut.

## Repository

Remote repository:
- [`kebun-sawit`](https://github.com/mastoroshadiq-prog/kebun-sawit.git)
