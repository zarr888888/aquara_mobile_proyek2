# Asisten SAMUDERA — Fase 1

## Pembaruan presentasi — 26 Oktober 2026

Lima screenshot pengguna dibaca langsung sebagai acuan komposisi, bukan aset atau kemampuan backend. Entry sekarang FAB hanya ketika Beranda aktif, bukan overlay global; tombol konten lama dihapus. Ikon chat existing, #009FE3, 56px, tooltip/semantics Asisten SAMUDERA, elevation 3 dan padding bawah konten 88px; navbar/kamera SOS tidak diubah.

Chat memakai identitas logo SAMUDERA dan “Balasan otomatis”, bubble pengguna kanan dan Asisten kiri (radius 20, 88% lebar tersedia, maksimum 520), permukaan netral tema dan biru dengan teks hitam kontras. Poppins diwarisi tema aplikasi existing. Timestamp tetap dari createdAt aktual melalui konversi existing, tanpa fallback tanggal. Menu titik tiga hanya refresh manual riwayat/detail dan Tutup layar; tombol pemeriksaan manual dalam daftar tetap tersedia untuk pemulihan hasil belum pasti. Pagination/detail tetap memakai handler existing.

Composer terpisah di bawah area scroll, mengikuti Scaffold keyboard/SafeArea, 1–4 baris atau maksimal 2 dalam ruang sempit/teks besar. Identitas pindah ke area scroll pada mode kompak; label SIMULASI lengkap tetap di luar scroll pada seluruh state, memakai bodySmall dan tetap mengikuti textScaler. Pengingat kredensial, privasi logout, risiko duplikasi dan pasangan independen tetap dalam daftar. Tidak menambah fetch saat menu/layout/timer/resume atau memaksa scroll ke bawah. Service/model/kontrak/sesi tidak diubah.

Validasi aktual pembaruan: 129 test terarah dan 755 suite penuh lulus, exit 0; analyzer 38 → 38, exit 1, delta isi 0; format empat Dart 0 berubah exit 0; diff check exit 0. Fake/mock tanpa jaringan nyata. Laporan pengguna Berita/Komoditas/Asisten berjalan di emulator adalah laporan manual umum; visual perubahan ini, keyboard perangkat dan TalkBack masih memerlukan review emulator. Angka pada implementasi awal di bawah adalah historis.

## Implementasi Flutter — 26 Oktober 2026

Implementasi lokal Tahap 7 tersedia, menggantikan status persiapan historis di bawah:

- Entry **satu tombol Asisten SAMUDERA di Beranda**, bukan FAB global atau perubahan navbar. Composer/riwayat dan detail masing-masing dilindungi SessionBoundary; navigasi memakai Navigator/MaterialPageRoute existing.
- C:/laragon/www/aquara_mobile/lib/models/asisten_chat.dart menormalisasi POST dan GET secara terpisah. ID positif, teks nonkosong, timestamp UTC ISO kalender valid, dan is_mock true pada POST wajib; tidak membuat nilai pengganti. Panjang input dihitung Unicode code points (runes), bukan UTF-16/grapheme. Backend tetap otoritas sanitasi dan validasi ulang; Flutter tidak decode HTML atau meniru balasan.
- C:/laragon/www/aquara_mobile/lib/services/asisten_api.dart memakai facade/mixin ApiService dan ApiClient existing: hanya path relatif asisten/chat, body POST tepat message; status 201 wajib. History mengambil nomor halaman positif buatan client dan metadata data.data; tidak mengikuti URL paginator absolut.
- C:/laragon/www/aquara_mobile/lib/screens/asisten_samudera_screen.dart menampilkan pasangan kronologis created_at naik lalu id naik (kebalikan urutan server untuk presentasi). ID digabung/dedup termasuk hasil POST; refresh mengganti daftar dan mengabaikan respons GET lama. Next-page gagal mempertahankan daftar. Halaman kosong tetap dapat dilanjutkan bila current_page < last_page. Detail selalu GET endpoint detail.
- Label permanen: “SIMULASI — balasan otomatis berbasis aturan, bukan AI percakapan atau layanan tanggap darurat.” Label dan indikator loading berada di luar daftar scroll. Semua isi teks biasa; tidak ada HTML, streaming, upload, smart-router, thread, edit/hapus atau provider AI. Dr.Fisho/WhatsApp tetap terpisah.
- Draft/riwayat/detail hanya memori layar dalam sesi; logout/pergantian sesi/dispose membersihkannya dan callback lama tidak diterapkan. Logout membersihkan tampilan lokal, **bukan menghapus riwayat server**. Metadata cooldown/in-flight terpisah dari isi, memakai weak key SessionService dan revisi; bertahan ketika layar ditutup/dibuka dalam sesi sama, tidak berlaku lintas revisi login.
- Kuota server tetap 10 request/menit/user bersama POST/history/detail. 429 menghormati Retry-After dari ApiClient (detik/HTTP-date); header invalid/tidak ada memakai jeda aplikasi 60 detik dengan label bukan waktu reset server. Timer hanya memperbarui tampilan, tidak fetch saat deadline/resume. Tidak ada polling, auto GET setelah POST, atau retry POST.
- Timeout/network/5xx/malformed POST mempertahankan draft dan menyatakan hasil belum pasti. Pemeriksaan riwayat manual tersedia; tidak muncul pada satu halaman bukan bukti gagal, kecocokan teks/tanggal bukan bukti identitas request. Retry manual berisiko duplikat karena belum ada idempotency key. 401 melalui invalidasi sesi existing; 403/404 aman tanpa logout; 422 hanya field message yang dikenal dengan copy aman.

### Validasi lokal aktual

- 60 test Asisten + 2 test Beranda baru; gabungan terarah 134 PASS (exit 0). Suite penuh final **744 PASS (exit 0)**, dijalankan sekali setelah kode final; bukan angka historis 682.
- Baseline dan final analyzer 41 diagnostic (exit 1), isi severity/pesan/path/kode identik setelah normalisasi lokasi; delta 0. Fake/MockClient/clock/Completer, tanpa jaringan nyata. Widget 320px/teks 2x/light-dark/keyboard inset 240; pagination/stale response/session lifecycle, payload/schema/status/cooldown dan navigasi/banner/SOS diuji lokal.
- Format tujuh file Dart: 0 berubah, exit 0; git diff --check exit 0. Log final terarah/penuh tanpa missed-tap warning/exception. Hash baseline lib/test/docs membatasi perubahan existing pada sambungan Beranda/facade, test Beranda, dan dokumentasi Asisten/roadmap; fitur pengguna lainnya tetap.
- Log dan exit code berada di C:/Users/Fajar/AppData/Local/Temp/samudera-asisten-*. Dokumentasi hasil terbaru juga ada di C:/laragon/www/aquara_mobile/TODO.md.
- Belum ada pemeriksaan emulator/perangkat/integrasi deployment dua akun pada tugas ini. Migration aktif, konfigurasi deployment/shared limiter, retensi, provider AI, MySQL/PostgreSQL, load test dan UAT adalah gate terpisah. Backend hanya dibaca terarah; tidak dijalankan/diubah. Tidak menandai AI sungguhan atau kesiapan rilis selesai.

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

## Persiapan Flutter — 25 Oktober 2026 (baca source lokal, bukan verifikasi deployment)

### A. Posisi roadmap dan dukungan existing

- Tahap 7 pada C:/laragon/www/aquara_mobile/docs/FLUTTER_UPGRADE_PLAN.md; status audit 30 September tidak menggantikan progres aktual C:/laragon/www/aquara_mobile/TODO.md. Tahap 2 dilaporkan selesai; SOS, pre-order, Info Mock dan pembaruan UI sudah memiliki implementasi/validasi lokal. Tidak mengulangnya atau menyatakan semua gate rilis selesai.
- Penelusuran C:/laragon/www/aquara_mobile/lib dan C:/laragon/www/aquara_mobile/test belum menemukan modul percakapan Asisten. C:/laragon/www/aquara_mobile/lib/screens/home_screen.dart hanya memiliki komentar reservasi; C:/laragon/www/aquara_mobile/test/home_2d_test.dart masih mengharapkan Asisten tidak tampil. Teks AI pada C:/laragon/www/aquara_mobile/lib/screens/onboarding_screen.dart bukan bukti integrasi chat AI.
- C:/laragon/www/aquara_mobile/lib/screens/consultation_screen.dart membuka Dr. Fisho (analisis foto, kontrak POST /api/ai-analyze) atau WhatsApp eksternal. Keduanya terpisah dari chat ini; jangan diganti/digabung atau mengklaim penyuluh menjawab chat mock.
- Fondasi tersedia di C:/laragon/www/aquara_mobile/lib/services/api_client.dart, C:/laragon/www/aquara_mobile/lib/services/api_result.dart, C:/laragon/www/aquara_mobile/lib/services/api_service.dart dan C:/laragon/www/aquara_mobile/lib/widgets/session_boundary.dart. Pola mixin API terarah tersedia di C:/laragon/www/aquara_mobile/lib/services/pre_order_api.dart. Gunakan SessionService, SecureTokenStore, StatefulWidget/setState dan Navigator/MaterialPageRoute existing, tanpa transport/token store/router paralel.

### B. Kontrak aktual dan bukti source

Dokumentasi acuan: C:/laragon/www/aquara_mobile/docs/API_DOCUMENTATION.md bagian 10 dan bagian endpoint/proteksi dokumen ini. Dicocokkan dengan source Laravel berikut, tidak menjalankan backend:

| Method/path | Request dan respons aktual | Sumber |
| --- | --- | --- |
| POST /api/asisten/chat | JSON hanya `message` string wajib, maksimal 2000 sebelum/sesudah sanitasi; 201 envelope `success/message/data`; data: `id`, pesan bersih `message`, `reply`, `is_mock: true`, `created_at` | C:/laragon/www/aquara_proyek2/app/Http/Controllers/Api/AsistenChatController.php, store |
| GET /api/asisten/chat | Tanpa body, query `page` positif menurut dokumentasi; 200 envelope, array di `data.data`, paginator 20 item; urut created_at desc lalu id desc. Item memakai `id/user_id/pertanyaan/jawaban/created_at/updated_at`, tanpa is_mock | Controller yang sama, index |
| GET /api/asisten/chat/{id} | ID numerik, tanpa body/query; 200 envelope dengan satu item schema GET; 404 untuk tidak ditemukan/milik orang lain/orphan, route nonnumerik tidak cocok | Controller yang sama, show; C:/laragon/www/aquara_proyek2/routes/api.php |

- Ketiganya `auth:sanctum` dan `throttle:asisten-chat` pada C:/laragon/www/aquara_proyek2/routes/api.php:66–70. Bearer hanya origin backend lewat ApiClient; path Flutter relatif `asisten/chat`, bukan URL absolut atau prefix api ganda. Tidak ada endpoint edit/hapus chat, upload chat, streaming, conversation/thread ID atau action smart-router dalam grup route ini.
- POST menolak kehadiran `user_id/response/reply/jawaban/pertanyaan`, termasuk null; field lain tidak diteruskan ke model. Sanitasi: decode entities sekali, strip tags, buang kontrol, rapikan whitespace dan validasi ulang; kosong menghasilkan 422. Jangan decode ulang atau render HTML pada Flutter.
- C:/laragon/www/aquara_proyek2/app/Models/AsistenChat.php guarded seluruh field; ownedBy membatasi user login tanpa bypass admin. FK user_id nullable pada C:/laragon/www/aquara_proyek2/database/migrations/2026_09_27_130815_create_asisten_chats_table.php; API tidak membuat chat guest. Semua respons sukses controller private, no-store.
- C:/laragon/www/aquara_proyek2/app/Support/AsistenReply.php memilih teks tetap berurutan SOS/darurat, grosir/pre-order, cuaca, lalu default. Ini **aturan lokal di backend/mock**, tanpa pemanggilan provider AI, konteks percakapan atau interpolasi input. Tidak ada bukti AI percakapan aktif; status provider Dr. Fisho tidak membuktikannya.
- C:/laragon/www/aquara_proyek2/app/Providers/AppServiceProvider.php:31–38 menetapkan 10 request/menit per user bersama POST/GET/detail, respons 429 `success:false/message/data:null` dengan header limiter. C:/laragon/www/aquara_proyek2/tests/Feature/AsistenChatTest.php memiliki assertion Retry-After, isolasi termasuk admin/orphan, kuota lintas token/IP dan balasan tetap; source test dibaca, **tidak dijalankan**.
- 401 melalui Sanctum; 422 validasi Laravel; 404 detail; 429 kuota bersama. Jangan bergantung pada envelope sukses untuk error. Timeout/network/non-JSON/5xx perlu ditangani sebagai kegagalan terstruktur existing, bukan jawaban chat.
- Batas kecocokan: dokumentasi meminta page integer positif, tetapi index tidak memvalidasi query secara eksplisit (langsung paginate). Flutter wajib membentuk page positif sendiri; jangan menjanjikan 422 untuk page invalid. Perilaku runtime query invalid tidak diuji dan perlu klarifikasi backend bila hendak dijadikan kontrak ketat.

### C. Usulan implementasi minimum dan kriteria penerimaan (belum dikerjakan)

1. Entry awal satu tombol Asisten pada Beranda, menuju layar privat melalui Navigator/MaterialPageRoute existing; FAB tidak menutupi tab/SOS/banner atau kontrol aksesibilitas. Usulan ini membatasi tahap awal pada Beranda; FAB semua layar utama tetap perlu keputusan scope, bukan diam-diam dianggap selesai.
2. Usulan file C:/laragon/www/aquara_mobile/lib/screens/asisten_samudera_screen.dart: satu layar percakapan + riwayat dengan loading/kosong/error, composer dan muat lebih lama/refresh manual. Label permanen **SIMULASI — bukan AI percakapan atau layanan tanggap darurat**, serta larangan mengirim password/OTP/token. Tidak membuat balasan lokal Flutter saat API gagal. Detail GET dapat tampil sebagai view pada layar yang sama, tanpa router baru.
3. Usulan C:/laragon/www/aquara_mobile/lib/models/asisten_chat.dart: model pasangan tanya/jawab dan paginator; parser POST/GET terpisah menuju model sama. Validasi id/teks/timestamp/envelope secara ketat; POST harus 201 dan is_mock true, GET tetap berlabel simulasi meski field itu absen. Empty sah bukan malformed. Gunakan pesan bersih server setelah sukses, bukan menganggap input mentah tersimpan.
4. Usulan C:/laragon/www/aquara_mobile/lib/services/asisten_api.dart: mixin pada ApiService/AuthService existing, tiga method create/history/detail dengan expectedSession. GET memakai page buatan client, tidak mengikuti URL paginator absolut. Normalisasi error field message yang aman, tanpa membocorkan body/exception/log chat. Tidak menambah dependency atau mengubah fondasi auth/config.
5. SessionBoundary pada seluruh entry termasuk direct/detail; state/controller/draft/riwayat hanya memori instance sesi, dibersihkan saat logout/pergantian sesi/dispose. Semua callback memeriksa mounted, revisi sesi dan generation operasi. Tidak menyimpan chat di preferences/file atau cache bersama; respons akun A terlambat tidak boleh muncul pada B.
6. Riwayat terbaru dahulu dari server dinormalisasi ke bubble kronologis eksplisit; halaman lama dimuat manual, dedup ID termasuk hasil POST. Refresh membatalkan hasil pagination lama; hindari polling/GET otomatis setiap kirim. Offset pagination dapat bergeser bila ada pesan baru, sehingga dedup dan refresh manual tetap diperlukan.
7. In-flight guard di handler/tombol untuk kirim, pagination dan route. 401 melalui sesi terpusat; 403/404 tampil aman, 422 mempertahankan draft. Cooldown 429 dibagi kirim/riwayat/detail dan tetap berlaku saat tutup/buka dalam sesi yang sama; metadata deadline saja, bukan cache chat. Hormati Retry-After detik/HTTP-date; bila tidak valid gunakan usulan jeda lokal 60 detik dengan label jelas, bukan klaim waktu reset server. Tidak fetch otomatis saat cooldown habis/resume.
8. Timeout/network/5xx/malformed setelah POST berarti hasil belum pasti: jangan retry otomatis atau mengarang jawaban; tawarkan periksa riwayat sebelum kirim ulang manual, dengan peringatan duplikasi. Backend belum menyediakan idempotency key; isi teks/timestamp bukan bukti pasti identitas request.
9. Uji terarah dengan flutter_test/http MockClient/fake token store/clock existing: kedua schema, pagination 20+/empty/malformed/dedup, payload bersih dan 200 vs 201, batas 0/2000/2001/whitespace/Unicode, 401/403/404/422/429 dengan/tanpa header, timeout/non-JSON, double-tap, cooldown bersama/reopen, guest/direct/back, logout/akun A terlambat setelah B, stale refresh/dispose. Widget: label simulasi, loading/error/draft, 320px, teks besar, keyboard, light/dark dan FAB tidak menutup kontrol. Sesuaikan assertion placeholder C:/laragon/www/aquara_mobile/test/home_2d_test.dart hanya ketika modul benar-benar diimplementasikan; jangan menghapus regresi unrelated.

**Gate penerimaan minimum:** semua alur di atas terbukti lewat test terarah tanpa jaringan nyata; lint tidak menambah diagnostic; fitur UI/profil/banner/Dr. Fisho/WhatsApp existing tetap. Tidak ada kebocoran chat lintas sesi, retry POST otomatis, persistensi chat atau klaim AI/dinas aktif. Suite penuh/UAT/rilis bukan hasil dari tugas persiapan ini.

### D. Penghalang dan kebutuhan backend/keputusan

- Tidak ditemukan endpoint yang hilang untuk MVP mock; implementasi lokal Flutter dengan fake/mock dapat dilanjutkan pada tugas terpisah. Deployment route/migration aktif, akun staging dan origin pengujian belum dibuktikan; itu gate integrasi nyata, bukan alasan membangun ulang backend.
- Retensi belum diputuskan: migration memakai nullOnDelete, sehingga penghapusan user tidak otomatis menghapus isi chat. Perlu keputusan retensi/penghapusan konten dan copy privasi sebelum publik; jangan menjanjikan semua chat terhapus atau menambahkan tombol hapus tanpa endpoint.
- Rate limiter multi-dyno membutuhkan shared cache persisten sesuai dokumentasi, tetapi konfigurasi deployment/secret tidak dibaca. Scalability dan efektivitas limiter produksi belum diverifikasi.
- Perlu persetujuan titik masuk Beranda saja vs FAB semua layar, serta copy publik/retensi. Smart-router dinamis memerlukan action schema/allowlist yang belum ada; minimum tidak mengeksekusi URL/instruksi balasan. Informasi birokrasi/jawaban resmi Dinas belum tersedia; jangan dibuat-buat.
- Provider AI percakapan bukan prasyarat mock. Jika yang diminta kelak AI sungguhan, perlu scope backend baru: provider, kebijakan data, keamanan prompt, biaya/kuota, timeout dan kontrak respons; tidak memilih provider atau menyatakan integrasi aktif sekarang. Idempotensi perlu kontrak backend bila retry aman ingin ditambahkan.
- Pekerjaan ini hanya dokumentasi dan pembacaan source terkait. Tidak mengulang audit/test seluruh aplikasi, menjalankan perintah PHP, membaca secret, memanggil API nyata atau mengubah repository Laravel. Angka otomatis terakhir dan laporan manual emulator dicatat terpisah di C:/laragon/www/aquara_mobile/TODO.md; keamanan menyeluruh, scalability, UAT Dinas dan kesiapan rilis tetap terbuka.