---
name: samudera-api-security
description: "Gunakan saat mengerjakan integrasi API, autentikasi, sesi, OTP, upload, dan navigasi privat Flutter SAMUDERA; security first, kontrak endpoint aktual, dan urutan rencana upgrade."
---

# SAMUDERA API Security

## Baca kontrak sebelum implementasi

- Root Flutter: `C:/laragon/www/aquara_mobile`; backend Laravel 12/Sanctum terpisah, bukan target perubahan otomatis.
- Baca `C:/laragon/www/aquara_mobile/AGENTS.MD`, `C:/laragon/www/aquara_mobile/PRD.md`, `C:/laragon/www/aquara_mobile/docs/API_DOCUMENTATION.md`, `C:/laragon/www/aquara_mobile/docs/FLUTTER_UPGRADE_PLAN.md`, `C:/laragon/www/aquara_mobile/ARCHITECTURE.md`, dan `C:/laragon/www/aquara_mobile/workflow.md`.
- Catat method, path, akses publik/Sanctum, field wajib/terlarang, tipe/nullability, format sukses/error, pagination, batas upload, dan efek pencabutan sesi untuk endpoint yang dikerjakan. Jangan membuat kontrak dari nama tabel atau fitur aspiratif PRD.
- Jika dokumen hilang/bertentangan, laporkan bagian dan keputusan yang perlu diperjelas sebelum implementasi terkait. URL contoh dokumentasi bukan deployment. Konfirmasi origin staging/produksi; jangan menguji API produksi.
- Rencana bertanggal 30 September 2026 masih berupa audit pra-implementasi. Pengguna menyatakan Tahap 2 selesai dan service-nya tersedia: jangan mengulang pembangunan Tahap 1–2 berdasarkan checkbox lama. Verifikasi gate, lalu Tahap 3 migrasi fitur lama, 4 SOS, 5 grosir, 6 info mock, 7 asisten mock, 8 regresi/rebranding sesuai dependensi rencana. Pertahankan fitur lama.

## Gunakan arsitektur Tahap 2

- Transport/interception: `C:/laragon/www/aquara_mobile/lib/services/api_client.dart` (`ApiClient`, `ApiAccess`, package `http`), hasil/error terstruktur di `C:/laragon/www/aquara_mobile/lib/services/api_result.dart`.
- Auth/facade: `C:/laragon/www/aquara_mobile/lib/services/auth_service.dart` (`AuthService`) dan `C:/laragon/www/aquara_mobile/lib/services/api_service.dart` (`ApiService`). Migrasikan request lama bertahap; jangan request backend langsung dari widget.
- Sesi terpusat: `C:/laragon/www/aquara_mobile/lib/services/session_service.dart` (`SessionService`, snapshot/revision, changes, invalidate). Token: `C:/laragon/www/aquara_mobile/lib/services/token_store.dart` (`TokenStore`, `SecureTokenStore`, `flutter_secure_storage`). Jangan menambahkan store/token cache paralel atau fallback plaintext.
- Pertahankan StatefulWidget/setState/FutureBuilder, ValueNotifier tema, Navigator + MaterialPageRoute. Tidak migrasi Dio, Provider, BLoC, Riverpod, atau router baru.
- `ApiClient` menerima path relatif terhadap base API, bukan URL absolut atau prefix `/api` ganda. Pertahankan timeout termasuk stream, batas ukuran respons, larangan redirect token dan pemeriksaan revisi sesi.

## Security contract wajib

1. Kirim Bearer hanya ke origin backend SAMUDERA yang dikonfigurasi (scheme, host, port), pada endpoint privat; jangan ke Cloudinary, URL gambar, tautan eksternal atau redirect. Gunakan HTTPS produksi dan jangan menonaktifkan validasi TLS.
2. Ikuti HTTP status sebelum parsing. Jangan mengharuskan semua envelope punya `success`/`data`: `/user` objek langsung, fish-types memakai `status`, beberapa hapus hanya `message`. Gunakan `Accept: application/json`; boundary multipart dibuat client.
3. **401 kontekstual:** login/kredensial/OTP gagal tidak otomatis berarti sesi kedaluwarsa. OTP privat perubahan kontak/hapus akun juga bisa 401 bisnis; pertahankan pemeriksaan sesi existing di ApiClient (probe user pada konteks tersebut), bukan logout membabi buta. Sesi tidak valid endpoint privat ditangani lewat SessionService; respons lama tidak boleh menghapus sesi login baru dan 401 paralel tidak boleh membuat transisi berulang.
4. **Logout/sesi berakhir:** hapus token melalui mekanisme terpusat, kosongkan data privat di memori/cache/controller, abaikan respons request dari revisi sesi lama. Lindungi tiap entry point privat termasuk navigasi langsung, notifikasi, dan tombol kembali; bersihkan stack memakai pola Navigator existing. Jangan hanya menyembunyikan tombol. Jangan mengklaim guard global sudah tersedia tanpa memeriksa subscriber dan setiap layar. Otorisasi data/pemilik tetap di backend.
5. **429:** hormati Retry-After valid (detik atau HTTP-date) melalui hasil ApiClient. Gunakan `C:/laragon/www/aquara_mobile/lib/services/auth_cooldown.dart` untuk flow auth/OTP yang sudah ada; tampilkan waktu tunggu jelas dan disable submit/resend. Bila header tidak tersedia, ikuti cooldown kontrak/UX existing, jangan mengarang waktu reset pasti. Cegah double-submit dengan guard in-flight juga di handler, bukan tampilan tombol saja.
6. Jangan otomatis retry POST/PUT/PATCH/DELETE/upload atau permintaan pembuat/pengubah data tanpa jaminan idempotensi backend yang terdokumentasi. Timeout bisa berarti server sudah memproses; tampilkan keadaan tidak pasti dan pemulihan aman, bukan kirim ulang otomatis.
7. OTP berupa string enam digit (leading zero dipertahankan), terikat tujuan/kanal/challenge. Ikuti field sebenarnya; ubah kontak memakai method/target_contact/otp, bukan email/phone termasuk null. Google login mengirim id_token, bukan identitas buatan client.
8. Logout mencabut token aktif; reset OTP/perubahan kontak mencabut semua token dan membutuhkan login ulang; perubahan password biasa tidak otomatis mencabut sesi sesuai kontrak. Jangan menebak efek endpoint lain.
9. Jangan menaruh token, OTP, password, atau data privat pada log, query URL, error server mentah, chatbot, shared_preferences, atau file biasa. Metadata profil legacy yang masih tersimpan bukan pola untuk diperluas: laporkan kebutuhan minimisasi/migrasinya sebagai pekerjaan terpisah. Error UI harus tersanitasi. Jangan membawa data nyata ke query skill.
10. Upload memakai batas MIME/ukuran/field per endpoint. Jangan mengirim credential Cloudinary atau melewati backend tanpa kontrak. URL gambar HTTPS absolut tidak diberi prefix storage. Cache privat harus terisolasi per akun, mematuhi no-store, dan dibersihkan saat sesi berubah.

## Pengujian bermakna dan pelaporan

- Ikuti `C:/laragon/www/aquara_mobile/test/services/api_client_test.dart`, `C:/laragon/www/aquara_mobile/test/services/auth_service_test.dart`, `C:/laragon/www/aquara_mobile/test/services/session_service_test.dart`, serta `C:/laragon/www/aquara_mobile/test/widget_test.dart`.
- Gunakan flutter_test, client http yang diinjeksi, fake TokenStore, clock terkendali; tidak perlu dependency baru atau jaringan produksi.
- Uji parsing envelope berbeda/non-JSON, private/public Bearer dan origin/redirect, timeout, 401 login/OTP vs sesi termasuk paralel/stale response, 429 dengan/tanpa Retry-After, cooldown dan double-tap, kegagalan storage, logout offline, cache lintas akun, akses langsung/back ke halaman privat.
- Pilih test berdasarkan perubahan; untuk UI uji loading/empty/error, layar 320 logical pixels, keyboard, teks besar, dark/light, dan dispose saat request berjalan. Jalankan analyzer/test sesuai scope dan laporkan hasil nyata, bukan klaim UAT.
- Aturan setup skill tidak memberi izin mengubah aplikasi. Pada pekerjaan implementasi terpisah, ikuti gate upgrade dan aturan pengguna. Jangan menjalankan PHP/Composer/Artisan, mengubah native tanpa izin, memasang dependency tanpa persetujuan, commit/push, atau memperbarui dokumen di luar scope.