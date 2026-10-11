# Rencana Upgrade Flutter SAMUDERA — Proyek 2 → Proyek 3

**Tanggal audit:** 30 September 2026  
**Status:** Rencana integrasi; belum ada implementasi fitur/perubahan kode aplikasi.  
**Prioritas:** amankan transport dan sesi → benahi Auth/OTP → migrasikan fitur lama → integrasikan fitur baru → uji regresi.

## 1. Acuan, ruang lingkup, dan batas audit

- Kontrak integrasi utama: `c:\laragon\www\aquara_mobile\docs\API_DOCUMENTATION.md`, disusun backend pada 29 September 2026.
- Target produk: `c:\laragon\www\aquara_mobile\PRD.md` versi 3.0.
- Penjelasan tambahan: `c:\laragon\www\aquara_mobile\docs\Asisten_SAMUDERA.md` dan `c:\laragon\www\aquara_mobile\docs\Integrasi_Eksternal_Mock.md`.
- Aturan repositori: `c:\laragon\www\aquara_mobile\AGENTS.MD`.
- Audit dilakukan terhadap source Flutter lokal, dependensi, pemanggilan API, alur autentikasi, dan baseline analyzer/test. Backend produksi tidak dipanggil; ketersediaan deployment dan perilaku runtime backend belum diverifikasi langsung.
- Bila target PRD berbeda dengan kemampuan API, gunakan kontrak API aktual. Jangan menebak endpoint dari nama tabel/desain database atau menganggap fitur aspiratif sudah tersedia.
- Tidak menjalankan PHP, Composer, atau Artisan. Tidak mengubah direktori native Android/iOS, dependency, maupun state management.

## 2. Kondisi codebase saat ini

### 2.1 Stack dan pola arsitektur

| Area | Temuan aktual | Keputusan rencana |
| --- | --- | --- |
| Manifest | `c:\laragon\www\aquara_mobile\pubspec.yaml`: nama paket `aquara_mobile`, versi `1.0.0+1`, Dart `^3.9.0` | Rebranding UI dipisah dari rename package/native identity; tidak rename massal |
| HTTP | `http: ^1.2.0`; tidak ada Dio | Pertahankan `http`; bangun wrapper transport/interception, bukan migrasi ke Dio |
| State | `StatefulWidget`, `setState`, `FutureBuilder`; `ValueNotifier<ThemeMode>` di `c:\laragon\www\aquara_mobile\lib\main.dart` | Pertahankan pola ini; tidak menambahkan Provider/BLoC/Riverpod |
| Struktur | Layar di `c:\laragon\www\aquara_mobile\lib\screens`; satu service di `c:\laragon\www\aquara_mobile\lib\services\api_service.dart` | Tambahkan komponen kecil bertahap; facade service lama tetap menjadi jalur migrasi |
| Routing | `Navigator` + `MaterialPageRoute`; belum router declarative | Pertahankan navigasi existing, tambahkan pemeriksaan sesi pada layar privat |
| Persistensi | `shared_preferences: ^2.5.4`; token dan metadata user ditulis langsung oleh beberapa metode login | Pusatkan lifecycle sesi; penyimpanan token aman adalah gate implementasi tersendiri |
| Pendukung | `image_picker`, `intl`, `url_launcher`, `google_sign_in`, Firebase Messaging/local notifications sudah ada | Gunakan kembali untuk foto, tanggal, tautan, dan login; jangan menambahkan SDK peta/LLM untuk fase mock |
| Pengujian | `flutter_test` tersedia; satu test counter template | Ganti test tidak relevan pada fase implementasi, lalu tambah contract/widget tests |

Versi dependency di atas adalah constraint manifest, bukan klaim versi terbaru atau versi pasti yang terpasang. Tidak dilakukan upgrade package pada audit ini.

### 2.2 Temuan dan gap prioritas

| Prioritas | Bukti lokasi | Gap/dampak |
| --- | --- | --- |
| P0 | `c:\laragon\www\aquara_mobile\lib\services\api_service.dart`: `fetchFishTypes`, `fetchPosts`, `fetchStocks`, `fetchForumPosts`, `fetchPasar`, `getUserProfile` | Sejumlah GET belum mengirim Bearer; endpoint data lama sekarang privat |
| P0 | File service yang sama: `updateForumPost`, `toggleLikePost`, `deleteForumPost`, `storeComment`, `deleteComment` | Mutasi forum belum konsisten memakai Bearer; payload masih membawa identitas dari client |
| P0 | `c:\laragon\www\aquara_mobile\lib\screens\ai_fisho_screen.dart`: `_analyzeImage` | Request multipart langsung ke domain hardcoded, di luar service, tanpa Bearer |
| P0 | `c:\laragon\www\aquara_mobile\lib\services\api_service.dart`: `loginWithGoogle` | Mengirim `email/name/google_id`, bukan `id_token` terverifikasi |
| P0 | File service yang sama: `ubahKontak`; `c:\laragon\www\aquara_mobile\lib\screens\ubah_kontak_screen.dart` | Konfirmasi mengirim `email/phone/otp`; backend baru melarang kedua field kontak lama dan membutuhkan `method/target_contact/otp` |
| P0 | Metode login service; `c:\laragon\www\aquara_mobile\lib\screens\profil_screen.dart`: `_handleLogout` | Token disimpan di preferences; logout hanya menghapus sebagian metadata lokal, belum mencabut token backend |
| P0 | `c:\laragon\www\aquara_mobile\lib\screens\splash_screen.dart`: `_checkDestination` | Keputusan masuk Beranda hanya berdasarkan onboarding, bukan validasi sesi |
| P1 | `c:\laragon\www\aquara_mobile\lib\screens\otp_screen.dart` | OTP sudah dikirim sebagai string; belum cooldown/expiry bersama. Tujuan berbentuk beberapa boolean dan method kirim ulang ditebak dari adanya `@` pada identifier |
| P1 | `c:\laragon\www\aquara_mobile\lib\screens\lupa_password_screen.dart` | Password reset masih divalidasi minimal 6, kontrak reset OTP baru 12–128 karakter |
| P1 | `c:\laragon\www\aquara_mobile\lib\services\api_service.dart` | Belum timeout eksplisit; respons dipangkas menjadi bool/list kosong/map pesan sehingga status, field errors, dan Retry-After hilang |
| P1 | `c:\laragon\www\aquara_mobile\lib\screens\pasar_screen.dart` dan service create/update pasar | Belum integrasi stok, kategori, tipe penjualan, pre-order; ada prefix storage domain lama |
| P1 | `c:\laragon\www\aquara_mobile\lib\screens\catalog_screen.dart` | Katalog existing menggunakan referensi `fish-types/stocks`, bukan resource produk `pasars`; Bursa Grosir harus memakai ID produk pasar |
| P1 | Struktur layar/service lokal | Belum ada integrasi `/lapor-darurat`, `/pre-order`, `/info/*`, `/asisten/chat` |
| P2 | `c:\laragon\www\aquara_mobile\lib\main.dart` dan sejumlah layar | Branding AQUARA masih tampil; notifikasi dan akses guest perlu diselaraskan |

**Bagian yang dipertahankan:** registrasi sudah dilanjutkan ke kirim/verifikasi OTP; metode register/reset memakai `login_id`; login WA memakai `phone`; beberapa upload dan endpoint pengaturan sudah memakai Bearer. Upgrade memperbaiki konsistensi, bukan menganggap seluruh Auth harus dibangun ulang.

## 3. Fondasi Network/API dan sesi — wajib sebelum fitur baru

### 3.1 Transport terpusat dengan interception pada `http`

Rencana file baru: `c:\laragon\www\aquara_mobile\lib\services\api_client.dart`, `c:\laragon\www\aquara_mobile\lib\services\session_service.dart`, dan `c:\laragon\www\aquara_mobile\lib\services\api_result.dart`. Ini pemisahan tanggung jawab transport/sesi, bukan perubahan state management.

- Bungkus `http.Client` yang dapat diinjeksi untuk pengujian; semua request backend, termasuk multipart, melewati satu jalur.
- Endpoint ditandai eksplisit publik/privat. Endpoint autentikasi awal dan `/api/info/*` publik; data aplikasi lainnya mengikuti label Sanctum pada kontrak.
- Selalu `Accept: application/json`. Body JSON di-encode dengan `Content-Type: application/json`. Biarkan HTTP client membuat multipart boundary; jangan memasang header JSON pada multipart.
- Request privat mengambil token Sanctum dari pengelola sesi dan menambahkan `Authorization: Bearer <token>`. Jangan mengirim `Bearer null`, token kosong, Google ID token, atau metadata user sebagai pengganti token backend.
- Batasi pengiriman Bearer pada origin backend yang dikonfigurasi. Request RSS pihak ketiga di `fetchBeritaNasional` tetap terpisah dan tidak boleh menerima token.
- Pusatkan base URL HTTPS melalui konfigurasi environment; domain `https://aquara.app/api` saat ini belum dianggap deployment baru yang terkonfirmasi. Domain contoh dokumentasi bukan endpoint produksi.
- Tambahkan timeout terukur untuk semua GET/JSON/multipart, termasuk membaca stream respons; misalnya awal 30 detik untuk JSON dan 60 detik upload, lalu kalibrasi melalui staging. Angka ini usulan client, bukan kontrak server.
- Tangani offline, timeout, respons kosong/non-JSON, JSON rusak, dan kegagalan stream. Jangan tampilkan stack trace, token, password, OTP, atau raw response sensitif kepada pengguna/log.
- Hentikan pemakaian list kosong sebagai pengganti seluruh error. UI membedakan loading, sukses kosong, gagal, dan retry manual.
- Jangan auto-retry mutasi seperti kirim OTP, toggle like, SOS, chat, dan pre-order: timeout tidak memastikan transaksi gagal. Cegah double-submit dan cek riwayat sebelum pengguna mengulang mutasi berstatus tidak pasti.

### 3.2 Penanganan status dan envelope

| Kondisi | Perilaku client yang direncanakan |
| --- | --- |
| 2xx | Decode sesuai endpoint: `/user` objek langsung; daftar umumnya `data`; pre-order/chat `data.data`; hapus pasar cukup `message` |
| 401 autentikasi Sanctum | Invalidasi sesi sekali, bersihkan data privat, arahkan login tanpa loop navigasi saat beberapa request gagal bersamaan |
| 401 kredensial/Google/OTP | Tampilkan error pada alur terkait, jangan otomatis menghapus sesi karena kode OTP salah. OTP kontak/hapus akun juga berada di endpoint privat: status 401 saja tidak cukup untuk menyimpulkan token invalid |
| 401 ambigu pada verifikasi privat | Bedakan respons `Unauthenticated.` dari kegagalan challenge dengan konteks endpoint; bila tidak dapat dipastikan, validasi sesi terkontrol melalui `/user`, bukan logout membabi buta |
| 403 login password | Arahkan ke verifikasi registrasi untuk identifier tersebut, bukan mencoba login berulang |
| 403 resource / 404 | Pesan akses tidak tersedia/tidak ditemukan; jangan bocorkan pemilik lain atau logout otomatis |
| 422 | Pertahankan `errors` per field dan pesan server; jangan menyimpulkan semua 422 registrasi berarti kontak duplikat |
| 429 | Simpan status dan header; ikuti `Retry-After` bila ada, nonaktifkan tombol dan tampilkan countdown; tanpa header gunakan backoff konservatif sesuai konteks dengan pesan jujur, bukan klaim waktu reset pasti |
| 400 / 500 / 503 | Pesan sesuai konteks: password lama salah, layanan/upload/OTP tidak tersedia; pertahankan input nonrahasia dan sediakan retry manual |

Cooldown harus mencerminkan bucket bersama: OTP lintas tujuan per akun, chat 10 request/menit per user untuk semua operasinya, info 30 request/menit per IP, POST pre-order 20/menit, login tambahan 5/menit, autentikasi publik 10/menit, AI analyze 5/menit. Jangan menganggap kuota selalu terpisah per URL. Pembatasan client hanya UX; server tetap otoritatif.

### 3.3 Lifecycle dan penyimpanan sesi

- Satu jalur menyimpan token dari login password, Google, verifikasi registrasi, dan verifikasi login WA. Validasi bentuk token/user sebelum menyatakan berhasil.
- `shared_preferences` tetap untuk preferensi nonrahasia; penyimpanan token aman belum tersedia dalam dependency existing. Tetapkan pilihan penyimpanan berbasis fasilitas aman OS dan evaluasi kompatibilitas package pada tahap implementasi terpisah. Jangan mengklaim preferences memenuhi security contract.
- Sampai pilihan storage aman tersedia, jangan merilis penyimpanan token permanen baru. Pilihan migrasi konservatif: hapus token preferences lama dan minta login ulang; migrasi langsung hanya setelah desain storage tervalidasi.
- Bootstrap sesi melalui `GET /api/user`, bukan hanya keberadaan key token. Kegagalan jaringan bukan bukti token dicabut: tampilkan retry tanpa membuka data privat atau menghapus sesi secara keliru.
- Logout: panggil `POST /api/logout`, lalu hapus sesi lokal dan data privat. Jika offline/gagal, tetap izinkan keluar lokal dengan keterangan pencabutan server belum terkonfirmasi.
- Reset OTP dan ubah kontak sukses: seluruh token dicabut backend → bersihkan sesi/cache privat dan minta login kembali. Hapus akun sukses: bersihkan sesi juga.
- Ubah password dengan password lama: token tetap berlaku sesuai implementasi backend, jangan menyamakan dengan reset OTP.
- Bersihkan metadata foto/profil dan riwayat privat saat berpindah akun, tanpa menghapus preferensi onboarding/tema secara tidak perlu. Respons request akun lama yang terlambat tidak boleh masuk ke sesi akun baru.
- Guest hanya boleh mengakses permukaan publik yang disepakati, terutama info simulasi. Menu forum/pasar/AI/SOS/chat/pre-order harus meminta login; jangan membiarkan Beranda memanggil seluruh API privat saat belum login.

## 4. Login dan OTP Challenge

### 4.1 Model alur yang konsisten

Refactor parameter layar OTP menjadi konteks eksplisit: tujuan `register/login/reset/contact/delete`, identifier, method, target kontak jika relevan, dan waktu tunggu. Pertahankan `StatefulWidget/setState`; tidak memerlukan framework baru. Backend tidak mengirim `challenge_id`, kode OTP, atau expiry metadata: jangan menciptakan field request/response tersebut.

| Alur | Request dan hasil yang harus diikuti |
| --- | --- |
| Registrasi | `POST /api/register` → 201 tanpa token dan tanpa pengiriman OTP otomatis → `/api/register/send-otp` dengan `login_id/method` → `/api/register/verify-otp` dengan `login_id/otp` → simpan token |
| Password | `/api/login` dengan `login_id/password`; 403 membuka verifikasi registrasi, 401 kredensial salah, 429 cooldown |
| Google | Ambil Google ID token dari `google_sign_in` existing; `/api/google-login` hanya mengirim `id_token`. Cocokkan audience/server client ID dengan backend; jangan log token |
| Login WA | `/api/send-otp-wa` dengan `phone` → `/api/verify-otp-wa` dengan nomor yang sama dan `otp`. Bisa membuat akun baru; tidak otomatis mengisi `email_verified_at` |
| Reset password | `/api/lupa-password/send-otp` dengan `login_id/method` → `/api/lupa-password/verify` dengan `login_id/otp/new_password`; password 12–128 karakter, respons tidak memberi token baru |
| Ubah kontak | `/api/ubah-kontak/send-otp` dengan `method/target_contact` → `/api/ubah-kontak` dengan kedua nilai yang sama + `otp`. Ubah satu kontak per challenge. Key `email/phone` harus benar-benar tidak ada, termasuk null |
| Hapus akun | `/api/hapus-akun/send-otp` dengan `method` → `DELETE /api/hapus-akun` dengan `otp`, tetap memakai Bearer |

### 4.2 Validasi, cooldown, dan lifecycle UI

- `otp` wajib string regex `^[0-9]{6}$`; pertahankan nol di depan, batasi input digit, dan dukung paste enam digit. Jangan mengubahnya menjadi integer.
- TTL challenge 5 menit; kirim ulang minimal 60 detik. Maksimal 3 pengiriman per 15 menit dan 5 kegagalan per akun; kegagalan kelima sudah 429, bukan 401.
- Satu challenge per akun: permintaan baru mengganti kode sebelumnya lintas tujuan/kanal. Jelaskan konsekuensinya dan hindari dua flow OTP aktif sekaligus.
- Timer lokal dihitung dari waktu absolut agar resume aplikasi tidak mereset cooldown; status server tetap penentu. Setelah window lock berakhir, minta OTP baru sebelum verifikasi ulang.
- Simpan pilihan kanal yang benar, jangan menebak kanal dari `login_id`: identifier email dapat dipakai mencari akun yang dipilih menerima OTP via WA, dan sebaliknya.
- Format target WA 10–15 digit dengan `+` opsional; gunakan format identik saat request dan verifikasi karena server tidak menjamin normalisasi nomor.
- Email maksimal 255 karakter dan valid; tangani akun Google dengan phone sementara `GL...` yang bukan nomor WA. Jangan menawarkan kanal yang kontaknya tidak dapat dipakai.
- Registrasi dan ubah password biasa masih minimal 6 karakter menurut kontrak; reset OTP berbeda (12–128). Jangan menerapkan asumsi satu aturan untuk semua endpoint.
- Pertahankan input yang perlu diperbaiki, jangan persist OTP/password; dispose controller/timer dan cek `mounted` sebelum `setState` setelah `await`.
- Widget harus aman pada layar kecil, keyboard terbuka, dan ukuran teks besar. Perbaiki risiko enam kotak OTP/row tombol overflow.

Layar terdampak: `c:\laragon\www\aquara_mobile\lib\screens\login_screen.dart`, `c:\laragon\www\aquara_mobile\lib\screens\register_screen.dart`, `c:\laragon\www\aquara_mobile\lib\screens\otp_screen.dart`, `c:\laragon\www\aquara_mobile\lib\screens\lupa_password_screen.dart`, `c:\laragon\www\aquara_mobile\lib\screens\ubah_kontak_screen.dart`, `c:\laragon\www\aquara_mobile\lib\screens\pengaturan_screen.dart`, serta layar splash/profil dan service yang disebut sebelumnya.

## 5. Integrasi fitur baru

### 5.1 Lapor Darurat / SOS Bahari

- Tambahkan entry Beranda, form, riwayat milik sendiri, dan detail status. Usulan layar: `c:\laragon\www\aquara_mobile\lib\screens\lapor_darurat_screen.dart`, `c:\laragon\www\aquara_mobile\lib\screens\riwayat_lapor_darurat_screen.dart`, `c:\laragon\www\aquara_mobile\lib\screens\detail_lapor_darurat_screen.dart`.
- API: `POST /api/lapor-darurat` (201), `GET /api/lapor-darurat` (array tanpa pagination), `GET /api/lapor-darurat/{id}`; seluruhnya Sanctum.
- Form: `jenis_sos` tepat `Wabah Penyakit`, `Pencemaran Limbah`, atau `Cuaca Ekstrem`; `deskripsi` wajib maksimal 5000; foto opsional JPEG/JPG/PNG maksimal 2048 KB, menggunakan `image_picker` existing.
- Gunakan multipart jika ada foto. Jangan mengirim `user_id/status_laporan/admin_id`; backend menentukan pemilik dan status awal `Pending`.
- Detail menampilkan `Pending/Diproses/Selesai`, foto dan waktu, serta refresh manual. Tidak ada endpoint ubah status/hapus laporan dari mobile, koordinat GPS, atau kontrak realtime/push khusus SOS.
- 503 upload: tampilkan kegagalan dan pertahankan draft di memori; kontrak menyatakan laporan tidak dibuat. Pada timeout hasil tidak pasti, cek riwayat sebelum kirim ulang.
- Jangan menjanjikan laporan langsung ditindaklanjuti atau mengganti layanan tanggap darurat. Tampilkan hasil terkirim hanya setelah respons sukses, bukan saat request baru dimulai.
- **Selesai bila:** validasi dan upload berhasil, kepemilikan diisolasi, status dapat dibaca ulang, gagal kirim tidak ditampilkan sebagai sukses, UI responsif.

### 5.2 Bursa Grosir / Pre-order

- Integrasikan pada produk pasar existing, bukan memakai ID `fish-types/stocks`. Perbarui `c:\laragon\www\aquara_mobile\lib\screens\pasar_screen.dart`, `c:\laragon\www\aquara_mobile\lib\screens\tambah_jualan_screen.dart`, `c:\laragon\www\aquara_mobile\lib\screens\edit_jualan_screen.dart`, serta facade API.
- Tambahkan field `stok` integer 0–999999999, kategori `tawar/laut/olahan`, tipe `eceran/grosir`. Default backend hanya berlaku bila key dihilangkan, bukan null eksplisit.
- Filter kategori/tipe secara lokal dari `GET /api/pasars`; backend belum menyediakan query filter/pagination. Detail produk berasal dari item daftar, bukan endpoint detail pasar yang tidak tersedia.
- Usulan layar baru: `c:\laragon\www\aquara_mobile\lib\screens\pre_order_screen.dart`, `c:\laragon\www\aquara_mobile\lib\screens\riwayat_pre_order_screen.dart`, `c:\laragon\www\aquara_mobile\lib\screens\detail_pre_order_screen.dart`.
- `POST /api/pre-order`: hanya `pasar_id` integer produk grosir, `total_tonase` numeric >0 hingga 99999999.99 dengan maksimal dua desimal, dan `tgl_pengambilan` berformat `YYYY-MM-DD`, hari ini/berikutnya menurut tanggal server.
- Jangan mengirim `user_id/status_bayar`, bahkan null. Validasi input desimal Indonesia tanpa pembulatan diam-diam; tampilkan 422 tanggal jika zona waktu perangkat berbeda dari server.
- Respons 201 mengembalikan `total_tonase` string dua desimal dan status `Belum Bayar`. Pertahankan parsing desimal yang tepat; status berikutnya dapat `DP/Lunas`.
- Riwayat `GET /api/pre-order?page=N`: baca `data.data`, 20 item per halaman, gabungkan tanpa duplikasi ID. Detail `/api/pre-order/{id}` hanya pembeli atau pemilik produk; 404 juga berarti tidak berhak.
- Riwayat tidak eager-load relasi pasar/user; jangan mengasumsikan nama produk tersedia di respons pesanan. Bila perlu cocokkan dengan daftar pasar dan sediakan fallback ID.
- Belum ada pembayaran, pembatalan, update/delete pesanan, perhitungan total harga, reservasi/pengurangan stok, atau validasi tonase terhadap stok. Jangan tampilkan tombol/hasil transaksi yang seolah fitur tersebut sudah ada. Satuan stok/harga dan konversi ke ton harus dikonfirmasi sebelum membuat kalkulasi.
- **Selesai bila:** hanya produk grosir dapat dipesan, payload bersih, pagination dan role peserta benar, double-submit dicegah, keterbatasan transaksi terlihat jelas.

### 5.3 Info Eksternal — Mock

- Tambahkan kartu Beranda dan halaman sederhana untuk KKP, cuaca, serta daftar TPI. Usulan: `c:\laragon\www\aquara_mobile\lib\screens\info_eksternal_screen.dart` dengan jenis informasi eksplisit.
- API publik: `GET /api/info/kkp`, `/api/info/cuaca`, `/api/info/tpi`; tidak perlu token/koordinat/query lokasi.
- Parse `data.is_mock/source/generated_at/items` dan `message`. KKP: judul/ringkasan/tanggal nullable; cuaca: wilayah/kondisi/suhu/angin/gelombang dan validitas nullable; TPI: nama/alamat/lat/lng ilustrasi.
- Label permanen **DATA SIMULASI — bukan informasi resmi atau panduan keselamatan pelayaran**. `generated_at` adalah waktu pembuatan cache, bukan waktu observasi. Jangan mengganti tanggal nullable dengan waktu sekarang.
- Backend cache 300 detik per jenis; client dapat memakai cache nonrahasia dengan penanda waktu/stale, deduplikasi request, dan refresh manual tanpa polling agresif. Cache hit tetap memakan kuota bersama 30/menit/IP.
- Fase ini berupa daftar TPI, bukan peta navigasi operasional. Tidak perlu izin GPS/package peta, tidak mengklaim harga realtime/pasang surut tersedia.
- **Selesai bila:** tiga jenis info dapat dibuka sebagai guest, label simulasi selalu terlihat, data kosong/error/429/stale ditangani, tidak ada klaim feed resmi.

### 5.4 Asisten SAMUDERA — Chatbot Mock

- Tambahkan tombol mengambang yang tidak menutupi navigasi/form dan layar `c:\laragon\www\aquara_mobile\lib\screens\asisten_samudera_screen.dart`; wajib login.
- `POST /api/asisten/chat` hanya `message` string tidak kosong maksimal 2000; dilarang menyertakan `user_id/response/reply/jawaban/pertanyaan`, termasuk null.
- Normalisasikan model UI: respons POST 201 memakai `message/reply/is_mock`; GET riwayat/detail memakai `pertanyaan/jawaban` dan tidak menambahkan `is_mock`.
- Riwayat `GET /api/asisten/chat?page=N`: `data.data`, 20 item, terbaru dahulu; detail `/api/asisten/chat/{id}` milik sendiri. Atur urutan bubble secara eksplisit dan deduplikasi pesan yang baru dikirim dengan riwayat.
- Render plain text, bukan HTML/skrip; jangan decode berulang. Tampilkan label simulasi walau GET tidak membawa `is_mock`.
- Kuota 10 request/menit per user dibagi kirim/riwayat/detail: hindari polling dan GET ulang otomatis setiap kirim. Hormati `private, no-store`; jangan persist riwayat chat ke disk/cache bersama, bersihkan state saat logout.
- Jangan meminta OTP/password/token melalui chat; bukan LLM atau layanan tanggap darurat. Analisis gambar AI existing tetap fitur terpisah.
- Smart router belum memiliki action/schema navigasi dari backend. Jika diperlukan, gunakan shortcut UI statis yang diizinkan menuju SOS/Bursa/Info, bukan mengeksekusi URL/instruksi dari isi jawaban.
- **Selesai bila:** kedua bentuk respons terbaca, riwayat terisolasi, status simulasi jelas, 422/429 ditangani, dan data chat tidak bocor lintas sesi.

## 6. Regresi fitur lama dan gap PRD lain

- Migrasikan semua request lama ke transport yang sama sebelum menganggap upgrade selesai: referensi ikan/stok/berita, profil, pasar, forum/like/comment, notifikasi, dan analisis gambar AI.
- Hilangkan pengiriman identitas client (`user_id/author_name`) untuk mengklaim kepemilikan. ID user lokal boleh dipakai untuk presentasi/filter, tetapi otorisasi tetap backend.
- Perbaiki resolusi gambar: URL HTTPS Cloudinary dipakai utuh; prefix storage hanya untuk path relatif legacy yang sesuai konfigurasi. Jangan mengirim secret Cloudinary atau upload langsung dengan credential backend dari aplikasi.
- Validasi ukuran/jenis gambar per endpoint; jangan menyamaratakan batas seluruh fitur. Forum dan AI memiliki batas sendiri pada dokumentasi API.
- Forum Saya dapat difilter di client dari daftar forum berdasarkan user sesi karena tidak ada endpoint khusus yang terdokumentasi. UI tombol edit/hapus mengikuti kepemilikan, tetap tangani 403/404 dari server.
- Notifikasi: integrasikan mark-read sesuai kontrak; notifikasi global tidak menyimpan status baca per pengguna di backend. Jangan menganggap semua notifikasi terkait fitur baru atau seluruh status read persisten.
- Rebranding UI/teks/logo ke SAMUDERA dengan warna laut/putih, termasuk onboarding, judul aplikasi, dan label notifikasi. Nama package/native identifiers dan migrasi channel notifikasi tidak diubah diam-diam.
- Global Search, panduan E-KUSUKA/SIPI/SIKPI/asuransi, feed resmi BMKG/KKP, peta operasional, dan realtime adalah backlog PRD lanjutan. Tidak ada endpoint omni-search/perizinan dalam kontrak ini. Jangan mengarang `/search`, endpoint bantuan, atau route realtime; sepakati sumber konten dan strategi pencarian lokal/backend lebih dahulu.
- Klaim dialog hapus akun bahwa semua konten pasti hilang perlu direview: dokumentasi Asisten menyebut konten chat dapat tetap tersimpan tanpa pemilik. Copy dan kebijakan retensi harus dikonfirmasi, bukan dijanjikan oleh Flutter.

## 7. Urutan eksekusi dan gate penerimaan

Semua checkbox berikut adalah pekerjaan mendatang, bukan implementasi yang sudah selesai.

| Tahap | Pekerjaan | Dependensi/gate selesai |
| --- | --- | --- |
| 0 | [ ] Konfirmasi base URL staging, akun uji, audience Google, storage aman, zona waktu server dan satuan stok/harga; simpan baseline | Tidak memakai domain contoh/akun produksi; keputusan yang belum jelas dicatat |
| 1 | [ ] Transport/interception, typed result, timeout, normalisasi error, isolasi token dan sesi | Test header JSON/multipart, 401 kontekstual, 429 dan non-JSON lulus |
| 2 | [ ] Login Google/password/WA, bootstrap/logout, seluruh flow OTP dan pencabutan token | Tidak masuk layar privat tanpa sesi; OTP leading zero, cooldown, kontak baru, reset tervalidasi |
| 3 | [ ] Migrasi seluruh API lama, owner-only UI, Cloudinary, field pasar baru | Tidak ada request backend langsung dari widget; smoke test fungsi lama lulus |
| 4 | [ ] SOS: form, riwayat, detail | Membutuhkan tahap 1–3; upload, isolasi pemilik, dan status baca teruji |
| 5 | [ ] Bursa Grosir + riwayat/detail pre-order | Membutuhkan field pasar tahap 3; presisi/tanggal/pagination/peserta teruji |
| 6 | [ ] Info Eksternal Mock | Dapat paralel dengan 4–5 setelah transport siap; guest dan label simulasi teruji |
| 7 | [ ] Asisten Mock | Sesi stabil; kedua schema chat, pagination, no-store dan kuota bersama teruji |
| 8 | [ ] Rebranding final, aksesibilitas, regresi lintas akun/perangkat, UAT Dinas | Tidak ada klaim layanan resmi/realtime yang belum tersedia; temuan rilis diselesaikan |

Setiap tahap dibuat sebagai perubahan kecil yang dapat direview/dirollback; jangan mencampur refactor state management atau upgrade massal dependency. Perubahan native hanya setelah permintaan eksplisit sesuai aturan workspace.

## 8. Strategi pengujian

### 8.1 Contract/unit tests (client yang diinjeksi, tanpa API produksi)

- Bearer hanya untuk origin/endpoint yang benar; token kosong ditolak; `Accept` selalu ada; JSON dan multipart boundary benar.
- Bentuk respons objek langsung, envelope `data`, nested paginator, sukses tanpa `success`, dan error non-JSON.
- 401 token vs OTP/kredensial; 401 kontak/delete tidak memicu logout keliru; beberapa 401 paralel hanya satu transisi sesi.
- 429 dengan/tanpa Retry-After; cooldown lintas endpoint; tidak ada retry mutasi otomatis; timeout pada request maupun stream.
- OTP `012345`, panjang salah, karakter nondigit, expiry, resend, challenge diganti lintas tujuan, gagal kelima 429, dan kirim ulang setelah window.
- Google mengirim ID token; body kontak/pre-order/chat tidak mengandung field terlarang walaupun null.
- Paginasi pre-order/chat, normalisasi POST vs GET chat, string desimal tonase, tanggal/null, gambar absolute/relative, isolasi cache per akun.

### 8.2 Widget dan integrasi staging

- Perbaiki `c:\laragon\www\aquara_mobile\test\widget_test.dart` agar menguji alur nyata dengan dependency Firebase/network/storage yang dikendalikan, bukan counter template.
- Tambahkan unit tests di `c:\laragon\www\aquara_mobile\test\services` dan widget tests di `c:\laragon\www\aquara_mobile\test\screens`; gunakan `flutter_test` dan fasilitas test `http` existing sebelum menambah library lain.
- Uji loading/empty/error/retry, keyboard, teks besar, layar lebar 320 px, dark/light theme, disposal layar saat request berjalan, serta navigasi ulang setelah login.
- Staging dengan minimal dua akun: SOS/chat user lain tidak terlihat; pre-order bisa dibaca pembeli dan penjual terkait saja; forum/pasar hanya dapat dimutasi pemilik.
- Uji reset/kontak mencabut sesi perangkat lain, logout hanya token aktif, perubahan password biasa tetap aktif, serta login WA tidak otomatis membuka login password akun belum terverifikasi.
- Uji kegagalan upload, offline saat submit, respons timeout tak pasti, double tap, perpindahan akun, dan refresh saat terkena rate limit. Jangan melakukan load test/OTP spam pada produksi.

### 8.3 Baseline yang benar-benar dijalankan saat audit

Dari workspace `c:\laragon\www\aquara_mobile`:

| Perintah | Hasil audit |
| --- | --- |
| `flutter --version` | SDK tersedia; Dart 3.9.0 terdeteksi |
| `flutter analyze --no-pub` | 80 isu: 3 warning dan 77 info, tidak ada diagnostic error. Warning: `_isDarkMode`/`_showDevSnackBar` tidak digunakan pada pengaturan, `_isLoading` tidak digunakan pada ubah kontak |
| `flutter test --no-pub` | Gagal: satu test `Counter increments smoke test` mengharapkan teks `0` yang tidak ada; assertion pada `c:\laragon\www\aquara_mobile\test\widget_test.dart:19` |

Hasil tersebut adalah masalah baseline existing, bukan dampak implementasi upgrade. Belum ada pengujian perangkat fisik atau end-to-end ke backend baru. Pada tiap tahap implementasi, jalankan kembali analyzer/test, tambah pengujian relevan, dan jangan menutupi warning atau menghapus test hanya untuk membuat hasil terlihat hijau.

## 9. Keputusan yang perlu disepakati sebelum rilis

1. URL backend staging/produksi yang benar dan apakah domain/resource legacy dipertahankan.
2. Implementasi storage token aman dan kebijakan login ulang pengguna Proyek 2.
3. Google audience/client configuration yang sesuai backend, tanpa membuka secret di aplikasi.
4. UX guest: tetap dapat melihat Info Mock, sedangkan data utama membutuhkan login.
5. Zona waktu tanggal server, satuan stok/harga, dan ekspektasi bisnis pre-order tanpa reservasi stok/pembayaran.
6. Kebijakan retensi chat/penghapusan akun, kontak bantuan resmi, dan copy peringatan SOS/mock yang disetujui Dinas.
7. Persetujuan terpisah untuk fitur di luar kontrak: feed resmi, peta interaktif, realtime, omni-search backend, pembayaran, dan perubahan native.

**Rekomendasi langkah pertama:** eksekusi tahap 0–1 dahulu. Menambahkan layar baru sebelum transport, sesi, dan OTP dibenahi akan memperbanyak request yang tidak memenuhi Security Contract.