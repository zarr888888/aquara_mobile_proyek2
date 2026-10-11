# Audit Final Fase 1 — 27 September 2026

## Status

Belum disetujui untuk produksi publik. PRD langkah 8 adalah regression check dan smoke test.
Migration chatbot berhasil dijalankan, batch 12. Tidak ada migration baru pada audit ini.
Baseline seluruh suite: 35 test / 442 assertion lulus sebelum perbaikan audit.
Hasil akhir seluruh suite setelah perbaikan: **40 test / 552 assertion lulus**, exit code 0.
Pemeriksaan syntax controller/config/model terkait dan git diff --check juga lulus.

## Perbaikan audit

- Semua route API selain daftar eksplisit registrasi/login/OTP/info mock memakai auth:sanctum.
- Endpoint auth/OTP publik memiliki throttle tambahan.
- Route duplikat GET posts dihapus (handler efektif PostController dipertahankan).
- Forum: mine berdasarkan token; update/delete post/comment berdasarkan pemilik;
  identitas pembuat komentar/post/like berasal dari token.
- Pasar: pembuat berasal dari token; update/delete wajib pemilik.
- User detail hanya diri sendiri; OTP dan waktu kadaluwarsa disembunyikan dari serialisasi.
- Notifikasi pribadi hanya dapat diubah pemilik; notifikasi global tidak lagi dimutasi
  oleh pengguna sebagai state read global. Read-per-user membutuhkan desain tambahan.
- Panel admin membatasi role Admin Dinas / super_admin.
- Kredensial WA dipindahkan ke services.fonnte.token / FONNTE_TOKEN; OTP memakai random_int.
- Google login wajib id_token yang diverifikasi oleh google/auth yang sudah terpasang;
  issuer/audience/email verified diperiksa. GOOGLE_CLIENT_ID wajib dikonfigurasi.
- Verifikasi TLS AI diaktifkan kembali. Upload profil/konsultasi baru menggunakan trait Cloudinary.
- CORS allowlist dari CORS_ALLOWED_ORIGINS, tanpa wildcard/pattern global atau cookie credentials.
- PHPUnit memakai SQLite in-memory secara eksplisit.
- Tidak ditemukan dd/dump/var_dump/print_r pada controller saat pemindaian.

## Perubahan kontrak bagi Frontend

Semua data API lama kini memerlukan Bearer token. Google login mengirim id_token,
bukan mempercayai email/name/google_id dari client. GET user/{id} hanya untuk diri sendiri.
Isi CORS_ALLOWED_ORIGINS dengan origin browser sah (scheme + host + port), dipisah koma,
tanpa slash penutup. Default kosong menolak akses lintas-origin browser.
Flutter native tidak bergantung CORS; CORS bukan otorisasi atau identifikasi aplikasi.

## Blocker sebelum go-live

1. ROTASI token Fonnte yang sebelumnya hardcoded; source/history mungkin sudah terekspos.
   Isi token baru melalui secret environment, jangan commit. Uji pengiriman WA/email sebenarnya.
2. OTP legacy memakai kolom yang sama untuk beberapa tujuan (login/reset/kontak/hapus akun).
   Perlu binding OTP terhadap tujuan dan target, batas percobaan per akun, serta pengujian
   replay/cross-purpose. Penggantian kontak juga perlu pengikatan ke target yang diverifikasi.
3. Uji Google sign-in nyata dengan audience client Flutter; test audit tidak menggantikan
   verifikasi interoperabilitas provider di staging.
4. Upload Filament legacy masih perlu audit/migrasi disk menyeluruh (misalnya FileUpload
   PasarResource belum eksplisit Cloudinary); verifikasi render foto profil setelah memakai URL.
5. APP_DEBUG=false, HTTPS, secure cookie, shared cache, domain CORS resmi, dan kredensial
   provider harus diverifikasi di deployment. trustProxies('*') saat ini perlu ditinjau sesuai
   ingress Heroku agar spoofing forwarded IP tidak menghindari rate limiting.
6. Seeder berisi password default; ganti akun/password produksi dan jangan menjalankan
   seeder contoh di produksi tanpa penyesuaian.
7. Smoke test Postgres/Heroku/Cloudinary persistensi redeploy/FCM/email/WA/Gemini belum dilakukan.
8. Audit dependency/CVE, penetration test, retensi chat/PII, backup-restore, dan beban belum dilakukan.
9. Penanganan kegagalan upload legacy dan pembersihan orphan media perlu diuji menyeluruh.

## Kesimpulan

Bisa dipakai tim Frontend untuk integrasi di lingkungan uji dengan kontrak terbaru.
Belum layak diberi label 100% aman atau diserahterimakan sebagai layanan publik produksi.
Automated tests memverifikasi kasus yang ditulis, bukan seluruh kemungkinan celah.