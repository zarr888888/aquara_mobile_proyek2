# Asisten SAMUDERA — Fase 1

## Cakupan dan autentikasi

Chatbot rule-based/mock, bukan LLM atau layanan tanggap darurat.
Tidak ada API key, HTTP request eksternal, eksekusi kode, atau interpolasi input ke balasan.
Seluruh endpoint wajib `auth:sanctum`, menggantikan opsi guest dalam PRD sesuai instruksi keamanan terbaru.

## Endpoint

- POST `/api/asisten/chat`: body JSON `{"message":"Bagaimana menggunakan SOS?"}`.
  Respons HTTP 201: `success`, `message`, `data` berisi `id`, `message` (teks bersih),
  `reply`, `is_mock: true`, dan `created_at`.
- GET `/api/asisten/chat`: riwayat milik user, 20 data per halaman (`?page=2`).
  Daftar berada pada `data.data`, beserta metadata pagination pada `data`.
- GET `/api/asisten/chat/{id}`: detail milik user; data tidak ada atau bukan miliknya menghasilkan 404.
  Riwayat/detail menggunakan kolom model: `id`, `user_id`, `pertanyaan`, `jawaban`, timestamps.

Status lain: 401 untuk tanpa autentikasi/token tidak valid, 422 untuk validasi gagal,
429 jika kuota habis (header `Retry-After` tersedia).

## Proteksi

- Maksimal 10 request/menit per user, dibagi bersama antara POST, riwayat, dan detail.
  Mengganti IP/token/query string tidak mereset kuota user. Request tidak valid juga memakan kuota.
- `message` wajib string maksimal 2000 karakter sebelum maupun sesudah sanitasi.
- Controller mendekode HTML entities satu kali, menjalankan `strip_tags`, membuang karakter kontrol,
  merapikan whitespace, lalu menolak hasil kosong sebelum memproses/menyimpan.
- `user_id`, `response`, `reply`, `jawaban`, dan `pertanyaan` dilarang pada body POST,
  termasuk nilai null. Field lain tidak diteruskan ke model.
- Model guarded seluruhnya. Controller mengisi kolom secara eksplisit dan mengasosiasikan user login.
- Query riwayat/detail selalu dibatasi user login, tanpa pengecualian role admin.
- Respons sukses memakai `Cache-Control: private, no-store`.
- Render teks sebagai plain text pada Flutter/web; jangan gunakan raw HTML atau decode berulang.
  Sanitasi bukan pengganti contextual output escaping.
- Balasan hanya dipilih dari teks tetap. Jika kelak memakai LLM, perlindungan prompt injection
  harus dirancang terpisah; `strip_tags` tidak menyelesaikan masalah tersebut.

## Database dan deployment

Migration `2026_09_27_130815_create_asisten_chats_table` mengikuti PRD:
`id`, nullable FK `user_id` dengan null-on-delete, `pertanyaan` text, `jawaban` text, timestamps.
Kolom nullable dipertahankan sesuai skema, tetapi API tidak membuat chat guest.
Chat tanpa pemilik tidak dapat diakses melalui endpoint ini.
Penghapusan akun membuat user_id null; konten chat tetap tersimpan sesuai skema PRD.
Kebijakan retensi/penghapusan konten pribadi perlu ditetapkan sebelum peluncuran publik.

Migration aplikasi menunggu izin pengguna. Test menjalankan skema hanya di SQLite in-memory.
Produksi multi-dyno harus memakai shared cache persisten untuk rate limiter, bukan cache array/file lokal.
Throttle aplikasi bukan perlindungan DDoS jaringan yang menyeluruh.

## Pengujian

`php artisan test --compact --filter=AsistenChatTest`

Cakupan: autentikasi, sanitasi sebelum pemrosesan/penyimpanan, validasi input, injeksi field,
mass assignment, isolasi data termasuk admin/chat orphan, batas kuota dan reset,
pergantian IP, token Sanctum berbeda untuk user yang sama, serta balasan tetap.