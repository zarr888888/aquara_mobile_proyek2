# Security Contract

## Pesanan eceran — kandidat 24 November 2026

Seluruh rute berikut berawalan `/api`, membutuhkan Sanctum, dan tidak memakai `pre-order` atau tonase. Produk lama tetap memiliki `satuan_jual:null`: tidak bisa dipesan sampai pemilik secara eksplisit menetapkan satuan **dan** harga. Harga daftar produk adalah rupiah per satuan setelah penawaran ditetapkan.

| Method dan path | Request | Hasil |
|---|---|---|
| PUT `pasars/{id}/retail-offer` | `satuan_jual`: kg, ekor, atau kemasan; `harga`: integer 1–999999999 | 200 `success:true,data:produk`. Pemilik saja; nonpemilik 404; bukan eceran 422. |
| POST `retail-orders` | `pasar_id`, `jumlah` string desimal kanonik, `expected_unit`, `expected_price` | 201 `success:true,data:pesanan`. Dua field expected hanya prasyarat kecocokan; bukan sumber perhitungan. Produk hilang 404, milik sendiri 403, penawaran usang/belum lengkap/bukan eceran 409. |
| GET `retail-orders?page=N` | page integer positif, default 1 | 200 `success:true,data:paginator`, daftar di `data.data`, 20 per halaman, terbaru dahulu. Hanya pesanan sebagai pembeli/penjual. Jangan mengikuti URL absolut dari paginator. |
| PUT `retail-orders/{id}/confirmation` | Tidak ada body/query | 200 `success:true,data:pesanan`; idempoten, khusus penjual yang disimpan pada pesanan. Pembeli atau pihak lain 404. |

`jumlah` > 0, maksimal 6 digit sebelum titik; kg maksimal 3 angka desimal (contoh `1.250`), ekor/kemasan hanya digit bulat. Backend mengunci produk, mengambil harga saat itu, menghitung perkalian tanpa float, membulatkan sekali ke rupiah terdekat (setengah ke atas), menolak total di bawah Rp1. Mutasi menolak field tambahan dengan 422. POST dibatasi 20/menit, handle 429/Retry-After; tidak ada retry otomatis. Jika timeout, cek riwayat sebelum mengulang. Tidak ada reservasi stok atau pemrosesan pembayaran.

Pesanan mengandung `id,buyer_id,seller_id,pasar_id,nama_ikan,satuan_jual,harga_satuan,jumlah,total_harga,status_bayar,confirmed_at,created_at,updated_at`. `jumlah` dalam respons string tiga desimal; `harga_satuan,total_harga` integer rupiah. Nama, identitas penjual, satuan dan harga tersimpan sebagai snapshot meskipun produk diubah/dihapus. `confirmed_at:null` menunggu; timestamp berarti penjual sudah konfirmasi. `status_bayar` awal `Belum Bayar` dan tidak berubah oleh konfirmasi. Pembayaran langsung ke penjual, bukan gateway. Rute grosir tetap terpisah.


## Omni-Search Flutter — 18 November 2026

Beranda dan Semua Layanan berbagi satu input: filter layanan/kategori lokal bekerja saat mengetik, termasuk untuk guest. Tombol Cari konten atau aksi Cari pada keyboard mengirim `GET search` hanya untuk sesi login. App bar Pasar, Forum, dan Berita membuka versi khusus konten dari layar yang sama; navbar tidak berubah. Sumber yang dicari adalah produk, isi posting Forum, dan Berita, bukan judul Forum atau artikel bantuan statis.

`q` dikirim sebagai query parameter (1–100 code point setelah trim). `data.pasar`, `data.forum`, `data.berita` masing-masing memiliki `data` dan `meta`. Muat lagi mengirim hanya parameter halaman kelompok terkait, sampai halaman 1000, dan menggabungkan berdasarkan ID dalam kelompok itu. `title:null` pada Forum bukan kesalahan; `summary` dan `thumbnail` dapat null. Preview tidak dipakai sebagai detail.

Ketukan membaca satu objek `success:true,data:{...}` dari `pasars/{id}`, `forum/{id}`, atau `posts/{id}` dan memeriksa ID sebelum navigasi. Detail Forum memakai `comments_count`, bukan panjang `comments`; komentar/balasan dimuat melalui layar komentar existing. Semua pembacaan konten memakai expectedSession. 401 ditangani ApiClient; 404 tidak memutus sesi. Cooldown search terpisah dari cooldown detail bersama. Tidak ada cache disk atau retry otomatis. Kontrak server acuan: `C:/laragon/www/aquara_proyek2/docs/API_DOCUMENTATION.md`, bagian Omni-Search dan Detail konten berdasarkan ID.

**Verifikasi lokal:** 42 tes terarah dan 779 tes suite penuh lulus dengan transport pengujian; lihat TODO untuk baseline analyzer dan gate emulator. Bukan verifikasi API nyata, integrasi perangkat, performa backend, atau rilis.

Kontrak wajib untuk frontend SAMUDERA (Web/Flutter). Dokumentasi ini disusun pada **29 September 2026** dari route, controller, model, policy, dan service pada workspace, bukan dari rancangan fitur yang belum diimplementasikan.

## Autentikasi dan akses data

- Semua endpoint berlabel **Sanctum** wajib mengirim `Authorization: Bearer <token>` menggunakan token yang dikembalikan backend. Endpoint publik hanya autentikasi/OTP awal dan `/api/info/*`.
- Selalu kirim `Accept: application/json`. Untuk body JSON gunakan `Content-Type: application/json`; untuk upload gunakan `multipart/form-data` dengan boundary yang dibuat HTTP client.
- Simpan token secara aman; jangan taruh token/password/OTP dalam URL, log, atau pesan chatbot. Gunakan HTTPS pada deployment.
- Identitas pengguna diambil dari token, bukan `user_id` yang dikirim frontend. Token tidak memberikan hak membaca atau mengubah data milik orang lain.
- Login password membutuhkan akun yang sudah diverifikasi (`email_verified_at` terisi). Registrasi tidak langsung mengeluarkan token.
- Logout mencabut **token aktif saja**. Reset password lewat OTP dan perubahan kontak mencabut **semua token**; frontend harus menghapus token lokal dan meminta login kembali. Perubahan password dengan password lama tidak mencabut token pada implementasi sekarang.
- `GET /api/user/{id}` hanya untuk pengguna sendiri. Laporan darurat dan chat hanya terlihat oleh pemilik. Pre-order terlihat oleh pembeli atau pemilik produk terkait, termasuk ketika pengguna memiliki role admin. Update/hapus pasar, posting forum, dan komentar dibatasi kepada pemiliknya.
- Login Google menerima **`id_token` Google yang diverifikasi backend**, bukan pasangan email/nama/Google ID buatan frontend.

## Format OTP baru

```json
{
  "login_id": "nelayan@example.test",
  "otp": "123456"
}
```

- `otp` wajib **string tepat enam digit**, regex `^[0-9]{6}$`. Angka JSON seperti `123456` bukan format yang diterima.
- Pengiriman memakai `method: "email"` atau `method: "wa"`. Registrasi/reset mengenali akun melalui `login_id` (email atau nomor telepon); login WA memakai `phone`.
- OTP berlaku **5 menit**, sekali pakai, terikat akun dan tujuan (`register`, `login`, `reset`, `contact`, atau `delete`). OTP tujuan lain tidak dapat digunakan silang.
- Hanya satu challenge tersimpan per akun: pengiriman baru menggantikan challenge sebelumnya, termasuk lintas tujuan/kanal.
- Untuk perubahan kontak, kirim **`method`, `target_contact`, dan `otp`**. Kontak serta kanal harus sama dengan permintaan kirim OTP. Jangan mengirim field `email` atau `phone` pada endpoint konfirmasi perubahan kontak; keduanya ditolak walaupun bernilai `null`.
- OTP tidak dikembalikan dalam respons API; challenge disimpan sebagai hash. Field lama `otp` dan `otp_expired_at` disembunyikan dari JSON pengguna dan tidak dipakai sebagai kontrak verifikasi.
- Jeda kirim ulang minimal **60 detik**. Maksimal **3 pengiriman** dalam window **15 menit**, dan batas percobaan gagal **5 kali** per akun. Counter berlaku lintas tujuan. Pada kegagalan kelima respons sudah `429`; kegagalan sebelumnya umumnya `401`. Setelah window berakhir, minta kode baru sebelum verifikasi lagi.
- Target email harus email valid (maksimal 255 karakter); target WA berupa 10–15 digit dengan awalan `+` opsional. Nomor disimpan/dicari sebagaimana dikirim: gunakan format konsisten, jangan mengasumsikan normalisasi otomatis.

## Rate limiting dan HTTP 429

| Cakupan | Batas yang dikonfigurasi |
| --- | --- |
| Semua endpoint publik autentikasi/OTP pada bagian 2–3 | Middleware `throttle:10,1` (10 request/menit) |
| `POST /api/login` | Tambahan `throttle:5,1` (5 request/menit) |
| `POST /api/ai-analyze` | `throttle:5,1` (5 request/menit) |
| `POST /api/pre-order` | `throttle:20,1` (20 request/menit) |
| Ketiga route `/api/asisten/chat` dan detailnya | Bucket bersama **10 request/menit per user**, termasuk baca riwayat/detail |
| Ketiga route `/api/info/*` | Bucket bersama **30 request/menit per IP** |
| Operasi OTP | Batas per akun pada seksi OTP, di samping middleware route |

Batas numerik di atas adalah konfigurasi middleware, **bukan jaminan kuota terpisah per URL**; jangan mengasumsikan masing-masing route memiliki counter sendiri. Endpoint lain tidak memasang limiter khusus dalam `routes/api.php`.

Frontend wajib menangani `429`, menghentikan retry agresif, menonaktifkan tombol kirim sementara, dan mengikuti `Retry-After` jika header tersedia. Middleware throttle dapat menyertakan header rate-limit; `429` yang berasal dari service OTP atau provider AI tidak selalu menyertakan `Retry-After`.

Contoh `429` dari limiter Asisten:

```json
{"success":false,"message":"Batas request Asisten tercapai. Silakan coba kembali nanti.","data":null}
```

Contoh `429` dari limiter informasi eksternal:

```json
{"success":false,"message":"Terlalu banyak permintaan informasi. Silakan coba kembali nanti.","data":null}
```

Contoh `429` dari service OTP:

```json
{"message":"Batas OTP akun tercapai. Tunggu 15 menit."}
```

Pesan lain yang mungkin: `Tunggu sebelum meminta OTP lagi.` atau `OTP tidak valid, kedaluwarsa, atau batas percobaan tercapai.` Jangan mengandalkan keberadaan `success` pada seluruh error.

---

# Dokumentasi API SAMUDERA — Backend Fase 1

## 1. Konvensi integrasi

- **Base URL:** origin backend + `/api`, contoh `https://samudera.example/api` (domain ilustrasi, bukan URL deployment).
- Seluruh URL di bawah sudah menyertakan prefix `/api`.
- **Publik** = tidak memerlukan Bearer Token; **Sanctum** = memerlukan Bearer Token.
- Semua contoh JSON adalah ilustrasi bentuk respons, bukan hasil request produksi. ID, waktu, token dan isi data dapat berbeda. Contoh objek Eloquent tertentu menampilkan field relevan; field database/relasi lain yang tidak disembunyikan dapat ikut terserialisasi. Jangan menganggap contoh sebagai whitelist field.
- Token `1|contoh-token-sanctum` hanya ilustrasi, bukan token yang dapat digunakan.
- `Request: tidak ada` berarti tidak ada parameter Body/Query yang digunakan controller. Parameter path `{id}` tetap harus diisi ID resource yang dimaksud.
- Kecuali disebutkan berbeda, respons sukses adalah **HTTP 200**, pembuatan tertentu **201**. Route GET juga didaftarkan Laravel sebagai HEAD (tanpa body respons).
- Endpoint daftar tanpa pagination mengembalikan array, termasuk `[]` saat kosong. Hanya riwayat pre-order dan chat yang memakai pagination (20 item per halaman).
- Format respons **belum seragam**: misalnya `/fish-types` memakai `status`, `/user` mengembalikan objek langsung, dan hapus pasar hanya memakai `message`.
- File gambar dikirim sebagai file biner multipart, bukan string URL atau base64. Upload baru diproses backend melalui Cloudinary. Data lama tertentu masih dapat mengandung path relatif; jangan menambahkan `/storage/` pada URL Cloudinary.
- Field tanggal pengambilan memakai `YYYY-MM-DD`; timestamps mengikuti serialisasi server. `total_tonase` dalam respons merupakan **string desimal dua angka**. `harga` dan `stok` pasar di-cast menjadi integer. Beberapa model lama tidak memiliki cast numerik/boolean; toleransi tipe diperlukan pada parsing data lama.

### 1.1 Respons error umum

Error berikut berlaku pada endpoint terkait meskipun tidak diulang di setiap seksi. Teks error validasi/default framework dapat mengikuti konfigurasi bahasa dan environment.

| Status | Makna |
| --- | --- |
| `400` | Password lama salah pada ubah password |
| `401` | Token tidak valid/tidak ada, kredensial salah, Google token tidak valid, atau OTP tidak valid/kedaluwarsa/terpakai |
| `403` | Akun belum terverifikasi pada login password, atau bukan pemilik resource |
| `404` | Resource/akun tidak ditemukan; beberapa endpoint juga menyamarkan akses ke data orang lain sebagai 404 |
| `422` | Validasi input gagal; termasuk field beraturan `missing` yang tetap dikirim |
| `429` | Rate limit aplikasi, OTP, atau kuota provider analisis AI |
| `500` | Kegagalan internal/provider AI tertentu |
| `503` | Pengiriman OTP, upload pada endpoint tertentu, atau konfigurasi Google tidak tersedia |

Contoh `401` Sanctum:

```json
{"message":"Unauthenticated."}
```

Contoh `422` (teks ilustratif):

```json
{"message":"The otp field format is invalid.","errors":{"otp":["The otp field format is invalid."]}}
```

Contoh `403` framework:

```json
{"message":"This action is unauthorized."}
```

Contoh `404` model (pesan dapat berbeda per model/framework):

```json
{"message":"No query results for model [App\\Models\\AsistenChat] 99"}
```

Contoh `429` middleware generik:

```json
{"message":"Too Many Attempts."}
```

### 1.2 Bentuk User

Endpoint yang mengembalikan User tidak mengembalikan `password`, `remember_token`, `otp`, atau `otp_expired_at`. Field seperti `google_id`, `email_verified_at`, `foto_profil`, dan `fokus_budidaya` dapat muncul/null sesuai data. Relasi `user` pada pasar/forum memakai serialisasi model yang sama; perlakukan sebagai data pribadi.

```json
{
  "id":1,
  "name":"Budi",
  "email":"nelayan@example.test",
  "phone":"081234567890",
  "email_verified_at":"2026-09-29T08:00:00.000000Z",
  "google_id":null,
  "foto_profil":null,
  "fokus_budidaya":"Lele",
  "created_at":"2026-09-29T07:00:00.000000Z",
  "updated_at":"2026-09-29T08:00:00.000000Z"
}
```

## 2. Autentikasi publik

Seluruh endpoint bagian ini memakai limiter publik `10,1`; login juga `5,1`.

### POST /api/register

**Akses:** Publik. **Body:** JSON.

| Parameter | Ketentuan |
| --- | --- |
| `name` | Wajib, string, maksimal 255 karakter |
| `email` | Opsional/null, string email valid, unik di users |
| `phone` | Wajib, string 10–15 karakter, unik di users; controller registrasi belum membatasi hanya digit |
| `password` | Wajib, string, minimal 6 karakter |

Request:

```json
{"name":"Budi","email":"nelayan@example.test","phone":"081234567890","password":"contoh-password"}
```

**201:** Akun dibuat, belum terverifikasi, belum ada token. Controller tidak otomatis mengirim OTP.

```json
{"success":true,"message":"Berhasil mendaftar! Silakan lakukan verifikasi OTP.","data":{"id":1,"name":"Budi","email":"nelayan@example.test","phone":"081234567890","created_at":"2026-09-29T07:00:00.000000Z","updated_at":"2026-09-29T07:00:00.000000Z"}}
```

Lanjutkan ke kirim OTP registrasi, lalu verifikasi. Error input/duplikat: `422`.

### POST /api/login

**Akses:** Publik. **Body:** `login_id` wajib string (email atau phone), `password` wajib string.

```json
{"login_id":"nelayan@example.test","password":"contoh-password"}
```

**200:**

```json
{"success":true,"message":"Login Berhasil!","data":{"id":1,"name":"Budi","email":"nelayan@example.test","phone":"081234567890","email_verified_at":"2026-09-29T08:00:00.000000Z"},"token":"1|contoh-token-sanctum"}
```

**401:**

```json
{"success":false,"message":"Email/No HP atau Password salah!"}
```

**403:**

```json
{"success":false,"message":"Akun Anda belum diverifikasi OTP. Silakan verifikasi terlebih dahulu."}
```

### POST /api/google-login

**Akses:** Publik. **Body:** `id_token` wajib string, maksimal 10000 karakter. Dapatkan Google ID token dari alur login Google frontend; bukan access token Sanctum.

```json
{"id_token":"contoh-google-id-token"}
```

**200:**

```json
{"success":true,"message":"Login Google Berhasil!","data":{"id":2,"name":"Pengguna Google","email":"google-user@example.test","google_id":"contoh-google-subject","phone":"GL1790668800","email_verified_at":"2026-09-29T08:00:00.000000Z"},"token":"2|contoh-token-sanctum"}
```

Backend memvalidasi audience, issuer, email terverifikasi, dan subject token. Akun dicocokkan lewat email; akun baru diberi phone sementara berawalan `GL`, bukan nomor WA valid. Akun baru ditandai terverifikasi; untuk akun lama controller tidak otomatis mengubah `email_verified_at`.

Error: `401` token/claims gagal; `403` akun sudah memiliki Google ID yang berbeda; `503` konfigurasi Google belum tersedia. Salah satu bentuk `401`:

```json
{"success":false,"message":"Verifikasi Google gagal."}
```

## 3. OTP registrasi, login WA, dan reset password

**Akses semua endpoint bagian ini:** Publik. **Body:** JSON. Limiter publik `10,1` dan batas OTP per akun berlaku. Account lookup gagal menghasilkan `404`; pengiriman gagal menghasilkan `503` dengan `{"message":"Pengiriman OTP gagal. Silakan coba kembali nanti."}`. Verifikasi OTP mengikuti error `401`/`429` pada Security Contract.

### POST /api/register/send-otp

**Body:** `login_id` wajib string maksimal 255 karakter; `method` wajib `email` atau `wa`. Target diambil dari kontak akun yang sudah dibuat.

```json
{"login_id":"nelayan@example.test","method":"email"}
```

**200:**

```json
{"success":true,"message":"OTP dikirim. Berlaku 5 menit."}
```

### POST /api/register/verify-otp

**Body:** `login_id` wajib string maksimal 255 karakter; `otp` wajib string enam digit.

```json
{"login_id":"nelayan@example.test","otp":"123456"}
```

**200:** Menandai `email_verified_at`, termasuk bila verifikasi dilakukan melalui WA, lalu mengeluarkan token.

```json
{"success":true,"data":{"id":1,"name":"Budi","email":"nelayan@example.test","phone":"081234567890","email_verified_at":"2026-09-29T08:00:00.000000Z"},"token":"1|contoh-token-sanctum"}
```

### POST /api/send-otp-wa

**Body:** `phone` wajib string; regex `^\+?[0-9]{10,15}$`.

```json
{"phone":"081234567890"}
```

**200:**

```json
{"success":true,"message":"OTP login dikirim."}
```

Jika nomor belum terdaftar, backend membuat akun dengan nama `Pengguna SAMUDERA`, email sintetis `wa_<uuid>@samudera.invalid`, dan password acak. Ini alur OTP tujuan `login`, bukan `register`.

### POST /api/verify-otp-wa

**Body:** `phone` wajib string maksimal 16 karakter; `otp` wajib string enam digit. Gunakan nomor yang sama persis saat kirim OTP.

```json
{"phone":"081234567890","otp":"123456"}
```

**200:**

```json
{"success":true,"data":{"id":1,"name":"Budi","email":"nelayan@example.test","phone":"081234567890","email_verified_at":null},"token":"1|contoh-token-sanctum"}
```

Endpoint ini mengeluarkan token tanpa mengubah `email_verified_at`; jangan mengasumsikan login WA otomatis membuka login password untuk akun yang belum terverifikasi registrasi.

### POST /api/lupa-password/send-otp

**Body:** `login_id` wajib string maksimal 255 karakter; `method` wajib `email` atau `wa`.

```json
{"login_id":"081234567890","method":"wa"}
```

**200:**

```json
{"success":true,"message":"OTP dikirim. Berlaku 5 menit."}
```

### POST /api/lupa-password/verify

**Body:** `login_id` wajib string maksimal 255 karakter; `otp` wajib string enam digit; **`new_password`** wajib string 12–128 karakter. Tidak memerlukan field konfirmasi password.

```json
{"login_id":"081234567890","otp":"123456","new_password":"password-baru-contoh"}
```

**200:** Semua token dicabut; tidak ada token baru pada respons.

```json
{"success":true,"message":"Password diperbarui. Silakan login kembali."}
```

## 4. Pengguna, profil, kontak, dan penghapusan akun

**Akses semua endpoint bagian ini:** Sanctum.

### GET /api/user

**Request:** tidak ada. **200:** Objek User langsung, tanpa envelope `success`/`data`.

```json
{"id":1,"name":"Budi","email":"nelayan@example.test","phone":"081234567890","email_verified_at":"2026-09-29T08:00:00.000000Z","foto_profil":null,"fokus_budidaya":"Lele","created_at":"2026-09-29T07:00:00.000000Z","updated_at":"2026-09-29T08:00:00.000000Z"}
```

### GET /api/user/{id}

**Path:** `id` pengguna sendiri. **Body/Query:** tidak ada.

**200:**

```json
{"success":true,"data":{"id":1,"name":"Budi","email":"nelayan@example.test","phone":"081234567890","email_verified_at":"2026-09-29T08:00:00.000000Z"}}
```

**404** untuk ID tidak ada atau bukan pengguna token:

```json
{"success":false,"message":"User tidak ditemukan"}
```

### POST /api/logout

**Request:** tidak ada. **200:** Token aktif dicabut.

```json
{"success":true,"message":"Berhasil Logout"}
```

### POST /api/profil/update

**Body:** JSON tanpa foto, atau multipart dengan foto.

| Parameter | Ketentuan |
| --- | --- |
| `name` | Wajib, string maksimal 255 karakter |
| `fokus_budidaya` | Opsional/null, string; hanya diperbarui bila terisi |
| `foto_profil` | Opsional/null, file gambar JPEG/JPG/PNG, maksimal 2048 KB |

Contoh body tanpa foto:

```json
{"name":"Budi Santoso","fokus_budidaya":"Lele"}
```

**200:**

```json
{"success":true,"message":"Profil berhasil diperbarui!","data":{"id":1,"name":"Budi Santoso","email":"nelayan@example.test","phone":"081234567890","fokus_budidaya":"Lele","foto_profil":"https://res.cloudinary.com/demo/image/upload/samudera/profil-fotos/contoh.jpg"}}
```

`503` bila upload gagal (`message: "Upload foto gagal."`). Mengirim fokus kosong/null tidak menghapus fokus lama. Email/phone diubah melalui OTP kontak, bukan endpoint ini.

### POST /api/ubah-password

**Body:** `old_password` wajib; `password` wajib minimal 6 karakter; `password_confirmation` wajib sama dengan `password` melalui aturan `confirmed`. Kirim semuanya sebagai string.

```json
{"old_password":"contoh-password","password":"password-baru-contoh","password_confirmation":"password-baru-contoh"}
```

**200:**

```json
{"success":true,"message":"Kata sandi berhasil diperbarui!"}
```

**400:**

```json
{"success":false,"message":"Kata sandi lama yang Anda masukkan salah."}
```

Batas minimal di endpoint ini berbeda dari reset OTP (12 karakter). Token tetap aktif setelah sukses.

### POST /api/ubah-kontak/send-otp

**Body:** `method` wajib `email`/`wa`; `target_contact` wajib string maksimal 255 karakter, unik terhadap kolom email/phone pengguna lain. Service memvalidasi format email atau nomor WA sebelum pengiriman.

```json
{"method":"email","target_contact":"budi-baru@example.test"}
```

**200:**

```json
{"success":true,"message":"OTP dikirim ke kontak baru."}
```

OTP dikirim **ke kontak baru**, bukan kontak lama. Error format service dapat memakai key `target` dalam `errors`; konflik kontak memakai `target_contact`.

### POST /api/ubah-kontak

**Body:** `method` wajib `email`/`wa`; `target_contact` wajib string maksimal 255 karakter dan unik terhadap pengguna lain; `otp` wajib string enam digit. Field `email` dan `phone` **harus tidak ada**.

```json
{"method":"email","target_contact":"budi-baru@example.test","otp":"123456"}
```

**200:** Kontak diperbarui dan semua token dicabut.

```json
{"success":true,"message":"Kontak terverifikasi diperbarui. Silakan login kembali."}
```

Gunakan kontak/kanal yang sama dengan challenge; perubahan keduanya saat konfirmasi menyebabkan OTP gagal.

### POST /api/hapus-akun/send-otp

**Body:** `method` wajib `email`/`wa`. Kontak tujuan diambil dari akun pemilik token.

```json
{"method":"wa"}
```

**200:**

```json
{"success":true,"message":"OTP dikirim. Berlaku 5 menit."}
```

### DELETE /api/hapus-akun

**Body JSON:** `otp` wajib string enam digit. HTTP client harus mendukung body pada DELETE.

```json
{"otp":"123456"}
```

**200:** Akun dan tokennya dihapus.

```json
{"success":true,"message":"Akun dihapus."}
```

Seluruh operasi OTP kontak/hapus akun tetap mengikuti batas per akun, error `401`/`429`, dan pengiriman `503` pada Security Contract.

## 5. Referensi ikan, stok, dan berita

**Akses semua endpoint bagian ini:** Sanctum. Tidak ada parameter Body/Query, filter, atau pagination yang digunakan controller.

### GET /api/fish-types

**200:** Semua jenis ikan. Perhatikan `status`, bukan `success`.

```json
{"status":"success","data":[{"id":1,"name":"Lele","image":null,"fcr_ratio":"1.20","harvest_duration_days":90,"market_price_per_kg":"25000.00","standard_density_per_m2":100,"survival_rate":"90.00","feed_price_per_kg":"12000.00","image_url":null,"created_at":"2026-09-29T07:00:00.000000Z","updated_at":"2026-09-29T07:00:00.000000Z"}]}
```

Model menambahkan `image_url`. **Catatan kompatibilitas implementasi:** accessor saat ini membentuk `url('storage/' . image)` ketika `image` terisi, termasuk jika `image` sudah URL absolut. Jangan mengasumsikan `image_url` selalu benar untuk gambar Cloudinary; bila `image` sudah URL absolut, frontend dapat memakainya langsung. Dokumentasi tidak mengubah accessor ini.

### GET /api/stocks

**200:** Stok terbaru dahulu; relasi Eloquent `fishType` terserialisasi sebagai `fish_type`.

```json
{"success":true,"data":[{"id":1,"fish_type_id":1,"pengepul_name":"Pengepul Bahari","location":"Indramayu","amount_kg":500,"phone_number":"081234567891","created_at":"2026-09-29T07:00:00.000000Z","updated_at":"2026-09-29T07:00:00.000000Z","fish_type":{"id":1,"name":"Lele","image":null,"image_url":null}}]}
```

### GET /api/posts

**200:** Berita terbaru dahulu, berbeda dari posting komunitas `/forum`.

```json
{"success":true,"message":"Daftar Berita Berhasil Diambil","data":[{"id":1,"title":"Informasi Budidaya","content":"Materi pembinaan budidaya.","image":null,"category":"Edukasi","author":"Dinas","created_at":"2026-09-29T07:00:00.000000Z","updated_at":"2026-09-29T07:00:00.000000Z"}]}
```

## 6. Forum komunitas

**Akses semua endpoint bagian ini:** Sanctum. `{id}` adalah ID posting, kecuali `/forum/comment/{id}` dan turunannya yang memakai ID komentar. Identitas penulis ditentukan backend. Bagian forum dicocokkan dengan controller Laravel lokal pada 24 Oktober 2026; ini bukan verifikasi deployment. Migration thread/like komentar belum diterapkan pada database pengembangan.

### GET /api/forum

**Query:** `mine=1` untuk Forum Saya (filter server), `page >= 1`, `per_page` 1–50, default 20. **Body:** tidak ada. Flutter membentuk nomor halaman sendiri, menggabungkan ID unik, mempertahankan daftar saat halaman berikut gagal, dan refresh dari halaman pertama.

**200:** Terbaru dahulu (created_at dan id descending). `data` array posting, `meta` memuat current_page/per_page/total/last_page. `comments` hanya preview maksimal tiga komentar utama, bukan seluruh komentar. Array `likes` tidak dikirim; gunakan likes_count/is_liked_by_me. comments_count mencakup balasan; root_comments_count hanya induk.

```json
{"success":true,"data":[{"id":1,"user_id":1,"author_name":"Budi","content":"Bagaimana merawat kolam?","image":null,"likes_count":0,"comments_count":0,"root_comments_count":0,"is_liked_by_me":false,"created_at":"2026-09-29T07:00:00.000000Z","updated_at":"2026-09-29T07:00:00.000000Z","comments":[],"user":{"id":1,"name":"Budi"}}],"meta":{"current_page":1,"per_page":20,"total":1,"last_page":1}}
```

Objek komentar memuat id, community_post_id, user_id (string legacy), author_name, content, parent_id nullable, created_at/updated_at, likes_count/replies_count integer, is_liked_by_me boolean, dan user nullable (id/name/foto_profil). Flutter menormalisasi user_id numerik untuk ownership; nama bukan bukti kepemilikan. Payload malformed ditolak, bukan diubah menjadi daftar/count kosong.

### POST /api/forum

**Body:** `content` wajib string maksimal 5000 karakter; `image` opsional/null, file gambar maksimal 5120 KB. JSON tanpa gambar atau multipart dengan gambar.

```json
{"content":"Bagaimana merawat kolam?"}
```

**200** (bukan 201; tidak mengembalikan objek posting):

```json
{"success":true}
```

### POST /api/forum/{id}/update

**Path:** ID posting milik sendiri. **Body:** `content` wajib; controller saat ini hanya memakai aturan `required` (tidak memasang `string`/maksimal panjang seperti create). Kirim teks. `image` opsional/null, file gambar maksimal **10240 KB**. JSON tanpa gambar atau multipart dengan gambar. Tidak mengirim gambar mempertahankan gambar lama.

```json
{"content":"Pertanyaan kolam diperbarui."}
```

**200:**

```json
{"success":true}
```

`403` bukan pemilik. **404:**

```json
{"success":false,"message":"Not found"}
```

### DELETE /api/forum/{id}

**Path:** ID posting milik sendiri. **Body/Query:** tidak ada.

**200:**

```json
{"success":true}
```

`403` bukan pemilik. **404:**

```json
{"success":false}
```

### POST /api/forum/{id}/toggle-like

**Path:** ID posting. **Body/Query:** tidak ada. Toggle berdasarkan pengguna token; pemanggilan ulang dapat membatalkan like, sehingga bukan operasi idempoten.

**200:**

```json
{"success":true,"status":"liked"}
```

Jika like dibatalkan:

```json
{"success":true,"status":"unliked"}
```

`404` bila posting tidak ada: `{"success":false}`.

### POST /api/forum/{id}/comment

**Path:** ID posting. **Body JSON:** `content` wajib string tidak kosong maksimal 5000 karakter; `parent_id` opsional untuk balasan ke komentar utama pada posting sama. Satu tingkat saja; membalas balasan memakai ID induk utamanya. Tidak menginferensikan thread dari mention.

```json
{"content":"Saya juga ingin mengetahui jawabannya."}
```

**200** (bukan 201), wajib objek komentar valid:

```json
{"success":true,"data":{"id":10,"community_post_id":1,"user_id":"1","author_name":"Budi","content":"Saya juga ingin mengetahui jawabannya.","parent_id":null,"created_at":"2026-10-24T01:00:00Z","updated_at":"2026-10-24T01:00:00Z","likes_count":0,"replies_count":0,"is_liked_by_me":false,"user":null}}
```

`404` bila posting tidak ada; `422` untuk komentar tidak valid.

### Edit, suka, dan pagination komentar (24 Oktober 2026)

- `PATCH /api/forum/comment/{id}`: hanya `content`, pemilik saja. Jangan kirim user_id/author_name/community_post_id/parent_id, termasuk null. Respons 200 success/data objek komentar; UI memakai objek server dan mempertahankan draft saat gagal.
- `PUT /api/forum/comment/{id}/like` memastikan suka; `DELETE` path sama memastikan batal suka. Tanpa body, bukan toggle. Respons 200 `{"success":true,"data":{"id":10,"likes_count":2,"is_liked_by_me":true}}` (false untuk unlike). Count/flag berasal dari server; aksi ganda per komentar diblokir.
- `GET /api/forum/{id}/comments`: hanya induk. `GET /api/forum/comment/{id}/replies`: balasan langsung. Pagination 20 default/50 maksimum, ID ascending, array `data.data`, metadata paginator di `data`. Halaman di luar akhir kosong. Flutter tidak mengikuti URL absolut paginator dan tidak mengirim Bearer ke origin lain.
- Semua request melalui ApiClient/expectedSession existing. 401 terpusat; 403/404 bukan logout; 422 hanya field dikenal ditampilkan secara aman; 429 memakai Retry-After atau jeda lokal berlabel. Timeout/network/malformed mutation tidak diulang otomatis; UI menyediakan muat ulang untuk memeriksa hasil yang belum pasti.
- Layar komentar memakai SessionBoundary/Navigator existing. Draft, daftar dan thread hanya memori, dibersihkan pada pergantian sesi; respons lama diabaikan. Refresh/mutasi membatalkan penerapan hasil GET lama.

### DELETE /api/forum/comment/{id}

**Path:** ID **komentar** milik sendiri, bukan ID posting. **Body/Query:** tidak ada.

Hapus induk menghapus permanen seluruh balasan (termasuk milik pengguna lain) serta like terkait; UI meminta konfirmasi eksplisit. Hapus balasan mempertahankan induk. Muat ulang halaman/count setelah mutasi karena pagination offset dapat bergeser. 404 legacy tetap `{"success":false}`; replies dari induk yang hilang juga 404.

**200:**

```json
{"success":true}
```

`403` bukan pemilik komentar. `404` bila komentar tidak ada: `{"success":false}`.

## 7. Pasar / katalog penambak

**Akses semua endpoint bagian ini:** Sanctum. Nama resource aktual adalah `pasars`, bukan `katalog_penambak`.

### GET /api/pasars

**Request:** tidak ada. Tidak ada filter kategori/tipe penjualan atau pagination di controller; frontend dapat memfilter array yang diterima.

**200:** Semua jualan terbaru dahulu, dengan relasi `user`.

```json
{"success":true,"message":"Daftar Jualan Pasar Berhasil Diambil","data":[{"id":10,"user_id":2,"nama_ikan":"Lele","harga":25000,"deskripsi":"Lele hasil panen","nomor_wa":"081234567891","lokasi":"Indramayu","stok":1000,"kategori":"tawar","tipe_penjualan":"grosir","foto":null,"created_at":"2026-09-29T07:00:00.000000Z","updated_at":"2026-09-29T07:00:00.000000Z","user":{"id":2,"name":"Penjual","email":"penjual@example.test","phone":"081234567891"}}]}
```

### POST /api/pasars

**Body:** JSON atau multipart bila mengunggah `foto`.

| Parameter | Ketentuan |
| --- | --- |
| `nama_ikan` | Wajib, string maksimal 255 karakter |
| `harga` | Wajib, numeric 0–999999999; model menyerialisasikan integer |
| `deskripsi` | Wajib, string maksimal 2000 karakter |
| `nomor_wa` | Wajib, string maksimal 20 karakter |
| `lokasi` | Wajib, string maksimal 255 karakter |
| `stok` | Opsional/null, integer 0–999999999; default 0 bila tidak dikirim |
| `kategori` | Opsional/null, `tawar`, `laut`, atau `olahan`; default `tawar` bila tidak dikirim |
| `tipe_penjualan` | Opsional/null, `eceran` atau `grosir`; default `eceran` bila tidak dikirim |
| `foto` | Opsional/null, file JPEG/JPG/PNG maksimal 2048 KB |

Untuk memakai default, **hilangkan key**, bukan mengirim `null`; controller memakai `input(key, default)` dan tidak mengganti nilai null eksplisit dengan default.

```json
{"nama_ikan":"Lele","harga":25000,"deskripsi":"Lele hasil panen","nomor_wa":"081234567891","lokasi":"Indramayu","stok":1000,"kategori":"tawar","tipe_penjualan":"grosir"}
```

**201:**

```json
{"success":true,"message":"Jualan berhasil ditambahkan","data":{"id":10,"user_id":2,"nama_ikan":"Lele","harga":25000,"deskripsi":"Lele hasil panen","nomor_wa":"081234567891","lokasi":"Indramayu","stok":1000,"kategori":"tawar","tipe_penjualan":"grosir","foto":null,"created_at":"2026-09-29T07:00:00.000000Z","updated_at":"2026-09-29T07:00:00.000000Z"}}
```

### POST /api/pasars/{id}/update

**Path:** ID jualan milik sendiri. **Body:** aturan parameter sama dengan create di atas; lima field utama (`nama_ikan`, `harga`, `deskripsi`, `nomor_wa`, `lokasi`) tetap wajib. Ini **POST**, bukan PUT/PATCH.

`stok`, `kategori`, dan `tipe_penjualan` hanya diubah jika terisi; `0` pada stok dapat digunakan. Bila foto tidak dikirim, foto lama tetap dipakai. Null/kosong pada field opsional bukan instruksi menghapus nilai lama.

```json
{"nama_ikan":"Lele","harga":26000,"deskripsi":"Lele siap panen","nomor_wa":"081234567891","lokasi":"Indramayu","stok":900}
```

**200:**

```json
{"success":true,"message":"Jualan berhasil diperbarui","data":{"id":10,"user_id":2,"nama_ikan":"Lele","harga":26000,"deskripsi":"Lele siap panen","nomor_wa":"081234567891","lokasi":"Indramayu","stok":900,"kategori":"tawar","tipe_penjualan":"grosir","foto":null}}
```

`403` bukan pemilik. **404:**

```json
{"success":false,"message":"Data tidak ditemukan"}
```

### DELETE /api/pasars/{id}

**Path:** ID jualan milik sendiri. **Body/Query:** tidak ada.

**200** (tanpa `success`):

```json
{"message":"Data jualan berhasil dihapus"}
```

`403` bukan pemilik. **404:**

```json
{"message":"Data tidak ditemukan"}
```

## 8. Lapor darurat / SOS Bahari

**Akses semua endpoint bagian ini:** Sanctum. Daftar/detail selalu dibatasi kepada pemilik token. Tidak tersedia endpoint API mobile untuk mengubah status atau menghapus laporan.

### GET /api/lapor-darurat

**Request:** tidak ada. Tanpa pagination; terbaru dahulu.

**200:**

```json
{"success":true,"message":"Riwayat laporan darurat berhasil diambil","data":[{"id":1,"user_id":1,"jenis_sos":"Wabah Penyakit","deskripsi":"Ikan tampak sakit sejak pagi.","foto":null,"status_laporan":"Pending","admin_id":null,"created_at":"2026-09-29T08:00:00.000000Z","updated_at":"2026-09-29T08:00:00.000000Z"}]}
```

### POST /api/lapor-darurat

**Body:** JSON atau multipart bila ada foto.

| Parameter | Ketentuan |
| --- | --- |
| `jenis_sos` | Wajib, salah satu `Wabah Penyakit`, `Pencemaran Limbah`, `Cuaca Ekstrem` (kapitalisasi sesuai contoh) |
| `deskripsi` | Wajib, string maksimal 5000 karakter |
| `foto` | Opsional/null, file JPEG/JPG/PNG maksimal 2048 KB |

```json
{"jenis_sos":"Wabah Penyakit","deskripsi":"Ikan tampak sakit sejak pagi."}
```

**201:** Backend menetapkan `user_id` dari token, `status_laporan: "Pending"`, dan `admin_id: null`. Jangan mengirim field tersebut untuk mengubah kepemilikan/status; controller mengabaikannya.

```json
{"success":true,"message":"Laporan darurat berhasil dikirim","data":{"id":1,"user_id":1,"jenis_sos":"Wabah Penyakit","deskripsi":"Ikan tampak sakit sejak pagi.","foto":null,"status_laporan":"Pending","admin_id":null,"created_at":"2026-09-29T08:00:00.000000Z","updated_at":"2026-09-29T08:00:00.000000Z"}}
```

**503** bila foto gagal diunggah; laporan tidak dibuat:

```json
{"success":false,"message":"Foto gagal diunggah. Silakan kirim ulang laporan."}
```

### GET /api/lapor-darurat/{id}

**Path:** ID numerik laporan sendiri. **Body/Query:** tidak ada.

**200:**

```json
{"success":true,"message":"Detail laporan darurat berhasil diambil","data":{"id":1,"user_id":1,"jenis_sos":"Wabah Penyakit","deskripsi":"Ikan tampak sakit sejak pagi.","foto":null,"status_laporan":"Diproses","admin_id":3,"created_at":"2026-09-29T08:00:00.000000Z","updated_at":"2026-09-29T09:00:00.000000Z"}}
```

Status yang dapat dibaca: `Pending`, `Diproses`, `Selesai`. `404` jika ID bukan numerik, tidak ditemukan, atau milik pengguna lain.

## 9. Pre-order / Bursa Grosir

**Akses semua endpoint bagian ini:** Sanctum. Kontrak aktual menggunakan **`pasar_id`**, bukan `katalog_id`. Semua pengguna terautentikasi dapat membuat pesanan; pembeli dan pemilik produk terkait dapat membaca riwayat/detail. Tidak ada API pembayaran, ubah status, pembatalan, update atau delete pre-order pada route saat ini.

### POST /api/pre-order

**Rate limit:** `20,1`. **Body JSON:**

| Parameter | Ketentuan |
| --- | --- |
| `pasar_id` | Wajib, integer ID pada `pasars` dengan `tipe_penjualan = grosir` |
| `total_tonase` | Wajib, numeric lebih dari 0, maksimal 99999999.99, 0–2 angka desimal |
| `tgl_pengambilan` | Wajib, format `YYYY-MM-DD`, hari ini atau sesudahnya berdasarkan tanggal server |
| `status_bayar` | Dilarang dikirim, termasuk null (`missing`) |
| `user_id` | Dilarang dikirim, termasuk null (`missing`) |

```json
{"pasar_id":10,"total_tonase":2.5,"tgl_pengambilan":"2026-10-01"}
```

Ganti tanggal contoh bila sudah lewat. Backend belum memvalidasi tonase terhadap stok, mengurangi stok, atau menghitung total harga pada endpoint ini; jangan mengasumsikan pesanan sebagai reservasi stok otomatis.

**201:**

```json
{"success":true,"message":"Pre-order berhasil dibuat","data":{"id":1,"user_id":1,"pasar_id":10,"total_tonase":"2.50","tgl_pengambilan":"2026-10-01","status_bayar":"Belum Bayar","created_at":"2026-09-29T08:00:00.000000Z","updated_at":"2026-09-29T08:00:00.000000Z"}}
```

`422` bila produk tidak ada/bukan grosir, tanggal lampau, presisi tonase salah, atau field terlarang dikirim. Status yang mungkin dibaca kemudian: `Belum Bayar`, `DP`, `Lunas`.

### GET /api/pre-order

**Query:** `page` opsional, nomor halaman (gunakan integer positif, default 1). **Body:** tidak ada. Ukuran halaman tetap 20; tidak ada `per_page` yang dipakai controller.

**200:** Data pesanan ada di **`data.data`**, bukan array pada `data` langsung.

```json
{
  "success":true,
  "message":"Riwayat pre-order berhasil diambil",
  "data":{
    "current_page":1,
    "data":[{"id":1,"user_id":1,"pasar_id":10,"total_tonase":"2.50","tgl_pengambilan":"2026-10-01","status_bayar":"Belum Bayar","created_at":"2026-09-29T08:00:00.000000Z","updated_at":"2026-09-29T08:00:00.000000Z"}],
    "first_page_url":"https://samudera.example/api/pre-order?page=1",
    "from":1,
    "last_page":1,
    "last_page_url":"https://samudera.example/api/pre-order?page=1",
    "links":[{"url":null,"label":"&laquo; Previous","active":false},{"url":"https://samudera.example/api/pre-order?page=1","label":"1","active":true},{"url":null,"label":"Next &raquo;","active":false}],
    "next_page_url":null,
    "path":"https://samudera.example/api/pre-order",
    "per_page":20,
    "prev_page_url":null,
    "to":1,
    "total":1
  }
}
```

URL pagination mengikuti host deployment dan label dapat mengikuti bahasa framework. Saat kosong, `data.data` adalah `[]`, `from`/`to` null, `total` 0. Tidak ada relasi `pasar`/`user` yang di-eager-load oleh endpoint ini.

### GET /api/pre-order/{id}

**Path:** ID numerik pesanan yang melibatkan pengguna. **Body/Query:** tidak ada.

**200:**

```json
{"success":true,"message":"Detail pre-order berhasil diambil","data":{"id":1,"user_id":1,"pasar_id":10,"total_tonase":"2.50","tgl_pengambilan":"2026-10-01","status_bayar":"Belum Bayar","created_at":"2026-09-29T08:00:00.000000Z","updated_at":"2026-09-29T08:00:00.000000Z"}}
```

`404` jika tidak ditemukan, ID bukan numerik, atau bukan peserta pesanan. Scope peserta diterapkan sebelum policy, sehingga role admin tidak membuka detail pesanan orang lain melalui API mobile.

## 10. Chatbot / Asisten SAMUDERA

**Akses semua endpoint bagian ini:** Sanctum. **Rate limit:** total 10 request/menit per user untuk kirim, riwayat, dan detail bersama-sama. Respons sukses memakai `Cache-Control: private, no-store`.

Backend menggunakan OpenAI Responses API (`gpt-5.4-mini`, `store:false`) jika `OPENAI_API_KEY` tersedia. Tanpa kunci, jawaban berbasis aturan berlabel Simulasi. Jika provider gagal atau teks tidak lengkap, POST mengembalikan 503 tanpa menyimpan pasangan chat. Hanya hasil AI sukses memiliki `is_mock:false`. Field `is_mock` dilarang pada input; jangan menjadikannya layanan tanggap darurat atau meminta pengguna mengirim rahasia.

### POST /api/asisten/chat

**Body JSON:** `message` wajib string maksimal 2000 karakter. Field **`user_id`, `response`, `reply`, `jawaban`, `pertanyaan` harus tidak ada** (`missing`), termasuk tidak boleh null.

```json
{"message":"Bagaimana membuat pre-order grosir?"}
```

Backend mendekode HTML entities, menghapus tag HTML/karakter kontrol, merapikan spasi, lalu memvalidasi kembali pesan. Pesan kosong setelah sanitasi menghasilkan `422`.

**201:**

```json
{"success":true,"message":"Pesan berhasil diproses","data":{"id":1,"message":"Bagaimana membuat pre-order grosir?","reply":"[Asisten SAMUDERA — simulasi] Pilih komoditas grosir, isi tonase dan tanggal pengambilan melalui fitur Bursa Grosir.","is_mock":true,"created_at":"2026-09-29T08:00:00.000000Z"}}
```

Pada mode simulasi, jawaban dipilih dari kata kunci SOS/darurat, grosir/pre-order, cuaca, atau jawaban default. Jangan mengasumsikan format respons POST sama dengan GET: POST memetakan `pertanyaan`/`jawaban` menjadi `message`/`reply`.

### GET /api/asisten/chat

**Query:** `page` opsional integer positif (default 1). **Body:** tidak ada. Pagination tetap 20 item; hanya chat sendiri, terbaru dahulu.

**200:**

```json
{
  "success":true,
  "message":"Riwayat chat berhasil diambil",
  "data":{
    "current_page":1,
    "data":[{"id":1,"user_id":1,"pertanyaan":"Bagaimana membuat pre-order grosir?","jawaban":"[Asisten SAMUDERA — simulasi] Pilih komoditas grosir, isi tonase dan tanggal pengambilan melalui fitur Bursa Grosir.","created_at":"2026-09-29T08:00:00.000000Z","updated_at":"2026-09-29T08:00:00.000000Z"}],
    "first_page_url":"https://samudera.example/api/asisten/chat?page=1",
    "from":1,
    "last_page":1,
    "last_page_url":"https://samudera.example/api/asisten/chat?page=1",
    "links":[{"url":null,"label":"&laquo; Previous","active":false},{"url":"https://samudera.example/api/asisten/chat?page=1","label":"1","active":true},{"url":null,"label":"Next &raquo;","active":false}],
    "next_page_url":null,
    "path":"https://samudera.example/api/asisten/chat",
    "per_page":20,
    "prev_page_url":null,
    "to":1,
    "total":1
  }
}
```

GET mengembalikan `pertanyaan`, `jawaban`, dan boolean `is_mock` per balasan (baris lama: true). Jika respons riwayat backend lama tidak memiliki field tersebut, Flutter menampilkan Simulasi. Metadata pagination mengikuti ketentuan yang sama dengan riwayat pre-order.

### GET /api/asisten/chat/{id}

**Path:** ID numerik chat sendiri. **Body/Query:** tidak ada.

**200:**

```json
{"success":true,"message":"Detail chat berhasil diambil","data":{"id":1,"user_id":1,"pertanyaan":"Bagaimana membuat pre-order grosir?","jawaban":"[Asisten SAMUDERA — simulasi] Pilih komoditas grosir, isi tonase dan tanggal pengambilan melalui fitur Bursa Grosir.","created_at":"2026-09-29T08:00:00.000000Z","updated_at":"2026-09-29T08:00:00.000000Z"}}
```

`404` jika ID bukan numerik, tidak ditemukan, atau milik orang lain (termasuk akses oleh admin).

## 11. Analisis gambar AI

### POST /api/ai-analyze

**Akses:** Sanctum. **Rate limit:** `5,1`. **Body:** wajib multipart dengan field `image`, file gambar JPEG/JPG/PNG maksimal **15360 KB** (15 MB). Tidak ada query parameter yang digunakan.

Contoh bagian form: `image = <file foto ikan atau air kolam>`. Tidak menerima URL/base64 sebagai pengganti file.

Berbeda dari chatbot simulasi, endpoint ini memanggil provider Gemini setelah upload Cloudinary. HTTP request ke provider dikonfigurasi timeout 120 detik; sesuaikan loading/timeout frontend dan hindari retry otomatis yang membuat analisis ganda.

**200:** Contoh hasil ilustratif; teks analisis berasal dari provider, bukan nilai tetap.

```json
{"success":true,"message":"Analisa AI berhasil!","data":{"id":1,"user_id":1,"image_path":"https://res.cloudinary.com/demo/image/upload/samudera/consultations/contoh.jpg","disease_detected":"Tidak Terdeteksi","water_quality_status":"Tidak Terdeteksi","solution":"Maaf, gambar tidak valid. Harap unggah foto ikan atau air kolam yang jelas.","raw_ai_response":"{\"disease_detected\":\"Tidak Terdeteksi\",\"water_quality_status\":\"Tidak Terdeteksi\",\"solution\":\"Maaf, gambar tidak valid. Harap unggah foto ikan atau air kolam yang jelas.\"}","created_at":"2026-09-29T08:00:00.000000Z","updated_at":"2026-09-29T08:00:00.000000Z"}}
```

`422` file tidak valid. `503` bila upload gagal:

```json
{"message":"Upload foto gagal."}
```

**429** bila provider mengembalikan 429 (berbeda dari pesan throttle middleware):

```json
{"success":false,"message":"Sistem SAMUDERA sedang sibuk melayani banyak petani. Antrean sistem sedang penuh, silakan coba lagi dalam 1 menit ya!"}
```

**500** bila provider mengembalikan status non-sukses selain 429, contoh status provider 503:

```json
{"success":false,"message":"Maaf, Sistem SAMUDERA sedang mengalami gangguan jaringan. Silakan periksa koneksi internet Anda dan coba lagi. (Kode: 503)"}
```

Exception koneksi/timeout dapat mengikuti error framework, bukan envelope khusus di atas. Tidak ada endpoint riwayat/detail konsultasi AI pada `routes/api.php` saat ini.

## 12. Informasi eksternal (mock)

**Akses semua endpoint bagian ini:** Publik, tanpa Bearer Token. **Request:** tidak ada Body/Query yang dipakai. Query lokasi/koordinat tidak memengaruhi hasil. **Rate limit:** total 30 request/menit per IP untuk ketiga endpoint. Hasil di-cache selama **300 detik per jenis informasi**; `generated_at` adalah waktu pembuatan data cache, bukan waktu observasi resmi.

Seluruh data adalah **simulasi**, belum feed resmi KKP/BMKG atau lokasi TPI operasional. Frontend wajib menampilkan `is_mock`/pesan simulasi secara jelas. Jangan memakai data ini sebagai panduan keselamatan pelayaran.

### GET /api/info/kkp

**200:**

```json
{
  "success":true,
  "message":"DATA SIMULASI — bukan informasi resmi atau panduan keselamatan pelayaran.",
  "data":{
    "is_mock":true,
    "source":"Simulasi SAMUDERA",
    "generated_at":"2026-09-29T08:00:00+00:00",
    "items":[{"id":"kkp-demo-1","judul":"Contoh informasi pembinaan budidaya","ringkasan":"Simulasi pengumuman pendampingan pembudidaya Indramayu. Jadwal resmi belum tersedia.","published_at":null}]
  }
}
```

### GET /api/info/cuaca

**200:**

```json
{
  "success":true,
  "message":"DATA SIMULASI — bukan informasi resmi atau panduan keselamatan pelayaran.",
  "data":{
    "is_mock":true,
    "source":"Simulasi SAMUDERA",
    "generated_at":"2026-09-29T08:00:00+00:00",
    "items":[{"id":"cuaca-demo-1","wilayah":"Indramayu (simulasi)","kondisi":"Berawan (contoh)","suhu_c":29,"kecepatan_angin_kmh":12,"tinggi_gelombang_m":0.5,"valid_at":null}]
  }
}
```

### GET /api/info/tpi

**200:**

```json
{
  "success":true,
  "message":"DATA SIMULASI — bukan informasi resmi atau panduan keselamatan pelayaran.",
  "data":{
    "is_mock":true,
    "source":"Simulasi SAMUDERA",
    "generated_at":"2026-09-29T08:00:00+00:00",
    "items":[{"id":"tpi-demo-1","nama":"TPI Contoh — bukan lokasi operasional","alamat":"Kabupaten Indramayu (data ilustrasi)","lat":-6.33,"lng":108.32}]
  }
}
```

## 13. Notifikasi

**Akses semua endpoint bagian ini:** Sanctum.

### GET /api/notifications

**Request:** tidak ada. Mengambil notifikasi milik pengguna dan notifikasi global (`user_id: null`), terbaru dahulu, tanpa pagination.

**200:**

```json
{"success":true,"data":[{"id":1,"user_id":null,"title":"Info Pasar SAMUDERA Terbaru!","message":"Ada Lele nih!","type":"pasar","reference_id":10,"is_read":false,"created_at":"2026-09-29T08:00:00.000000Z","updated_at":"2026-09-29T08:00:00.000000Z"}]}
```

Nilai `type` yang dibuat controller mencakup `pasar`, `forum`, dan `ai`; `reference_id` dapat null. Model belum memiliki cast `is_read` eksplisit, sehingga representasi bool/0/1 dapat mengikuti driver database.

### POST /api/notifications/{id}/read

**Path:** ID notifikasi pengguna atau notifikasi global. **Body/Query:** tidak ada.

**200:**

```json
{"success":true}
```

Notifikasi pribadi diubah menjadi `is_read = true`. Untuk notifikasi global, backend hanya mengembalikan sukses **tanpa menyimpan status baca per pengguna**. Jangan mengasumsikan bahwa GET berikutnya akan menandai notifikasi global sebagai terbaca.

**404** jika tidak ada atau milik pengguna lain:

```json
{"success":false}
```

## 14. Checklist integrasi frontend

1. Registrasi → kirim OTP registrasi → verifikasi OTP → simpan token. Alur alternatif: login password, Google ID token, atau kirim/verifikasi OTP WA.
2. Gunakan `Accept: application/json` pada setiap request dan Bearer Token hanya dari backend pada endpoint Sanctum.
3. Tangani HTTP status sebelum parsing envelope; jangan mengharuskan semua respons mempunyai `success`, `message`, dan `data`.
4. Tampilkan `errors` untuk 422, bedakan 401 OTP dari 401 token, dan gunakan backoff/countdown untuk 429.
5. Hapus token lokal setelah logout, reset password OTP, perubahan kontak, atau penghapusan akun sesuai alur yang selesai.
6. Gunakan multipart untuk gambar; batas file berbeda antara forum create/update, profil/pasar/SOS, dan analisis AI.
7. Untuk pre-order/chat, baca array dari `data.data`; endpoint daftar lain umumnya memakai `data` langsung.
8. Normalisasi model chat frontend: POST memakai `message`/`reply`, sedangkan GET memakai `pertanyaan`/`jawaban`.
9. Bedakan data simulasi dari data resmi dan jangan menyajikan chatbot sebagai layanan tanggap darurat.
10. Jangan membuat pemanggilan endpoint yang tidak terdaftar, misalnya detail pasar, update pembayaran pre-order, atau update status SOS lewat API mobile.

### Cakupan dan sumber implementasi

Dokumen mencakup seluruh pasangan method/URL aplikasi yang terdaftar pada file berikut (HEAD implisit tidak dihitung sebagai endpoint terpisah):

- `c:\laragon\www\aquara_proyek2\routes\api.php`
- `c:\laragon\www\aquara_proyek2\app\Http\Controllers\Api\` (seluruh controller yang dirujuk route)
- `c:\laragon\www\aquara_proyek2\app\Support\OtpService.php`
- `c:\laragon\www\aquara_proyek2\app\Support\AsistenReply.php`
- `c:\laragon\www\aquara_proyek2\app\Support\ExternalInfo.php`
- `c:\laragon\www\aquara_proyek2\app\Providers\AppServiceProvider.php`
- `c:\laragon\www\aquara_proyek2\app\Models\` dan `c:\laragon\www\aquara_proyek2\app\Policies\PreOrderPolicy.php`
- `c:\laragon\www\aquara_proyek2\bootstrap\app.php`

Skema rancangan di `c:\laragon\www\aquara_proyek2\docs\database_schema.md` memakai beberapa nama konseptual lama. Untuk integrasi API, nama payload/route aktual pada dokumen ini yang digunakan (`pasars`, `pasar_id`, `/lapor-darurat`, `/pre-order`). Tidak ada perubahan kode backend atau database yang dilakukan untuk menyesuaikan dokumentasi.