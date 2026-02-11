# Sync Source Switching (SQL Server vs Supabase)

Project sekarang mendukung pemilihan sumber sync saat menjalankan app melalui dart-define.

## 1) Konsep

Konfigurasi ada di:
- `lib/config/sync_source_config.dart`

Source yang didukung:
- `sqlserver` (default)
- `supabase`

Service yang sudah membaca config source:
- `lib/mvc_services/api_auth.dart`
- `lib/mvc_services/api_spk.dart`
- `lib/mvc_services/api_pohon.dart`
- `lib/mvc_services/api_spr.dart`
- `lib/screens/sync/sync_service.dart`

## 2) Menjalankan mode SQL Server (default)

```bash
flutter run --dart-define=SYNC_SOURCE=sqlserver
```

Opsional override endpoint SQL Server:

```bash
flutter run \
  --dart-define=SYNC_SOURCE=sqlserver \
  --dart-define=SQLSERVER_BASE_URL=http://13.67.47.76/bbn \
  --dart-define=SQLSERVER_SYNC_POST_URL=http://13.67.47.76/kebun/wfsnew.jsp
```

## 3) Menjalankan mode Supabase

```bash
flutter run \
  --dart-define=SYNC_SOURCE=supabase \
  --dart-define=SUPABASE_API_BASE_URL=https://<your-project>.supabase.co/functions/v1 \
  --dart-define=SUPABASE_SYNC_POST_URL=https://<your-project>.supabase.co/functions/v1/sync
```

Catatan:
- `SUPABASE_API_BASE_URL` dipakai oleh API auth/spk/pohon/spr.
- `SUPABASE_SYNC_POST_URL` dipakai oleh service upload batch sync.

## 4) Nilai default saat tidak diisi

- `SYNC_SOURCE=sqlserver`
- `SQLSERVER_BASE_URL=http://13.67.47.76/bbn`
- `SQLSERVER_SYNC_POST_URL=http://13.67.47.76/kebun/wfsnew.jsp`

Sehingga tanpa define tambahan app tetap bekerja seperti perilaku lama.

