# wfsnew-adapter (Supabase Edge Function)

Adapter ini meniru pola endpoint legacy `wfs.jsp` + `wfsnew.jsp` agar app Flutter lama tetap kompatibel saat backend dipindah ke Supabase.

## 1) Tujuan

- Menangani endpoint baca gaya lama:
  - `?r=autor&q=<username>,<password>`
  - `?r=apk.task&q=<mandor>`
  - `?r=blok.pohon&q=<mandor>`
  - `?r=sim.pohon&q=simulasi`
  - `?r=spr.blok&q=<blok>`
- Menangani endpoint kirim sync gaya lama:
  - `?j=[{TARGET,PARAMS}, ...]`

TARGET write yang didukung:
- `ITE`, `IKP`, `IRP`, `IOB`, `IAL`, `ISPR`

## 2) Deploy

Jalankan dari root project:

```bash
supabase functions deploy wfsnew-adapter --no-verify-jwt
```

Set secret (service role diperlukan karena operasi write):

```bash
supabase secrets set SUPABASE_URL=https://<project-ref>.supabase.co
supabase secrets set SUPABASE_SERVICE_ROLE_KEY=<service-role-key>
```

## 3) Runtime config di Flutter

Gunakan define berikut:

```bash
flutter run \
  --dart-define=SYNC_SOURCE=supabase \
  --dart-define=SUPABASE_API_BASE_URL=https://jofdimvnknmauvfeocyu.supabase.co/functions/v1/wfsnew-adapter \
  --dart-define=SUPABASE_SYNC_POST_URL=https://jofdimvnknmauvfeocyu.supabase.co/functions/v1/wfsnew-adapter
```

## 4) Catatan kompatibilitas

- Response sukses sync sengaja plaintext: `[Berhasil Sinkronisasi]` agar parser mobile existing tetap mengenali sukses.
- Response error sengaja diawali `ERROR:` untuk tetap terbaca oleh flow existing.

