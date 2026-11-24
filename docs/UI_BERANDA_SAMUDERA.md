# Beranda SAMUDERA — acuan presentasi 2D

## Palet warna fitur

Fitur baru SAMUDERA menggunakan palet tema aplikasi. Biru merek #009FE3 diambil dari konstanta bersama; warna peringatan, error, dan sukses mengikuti tema masing-masing.

## Sumber logo final pengguna — SAMUDERA_FIX_LOGO.png

Pengguna sengaja menghapus logo lama; sumber final adalah
C:/laragon/www/aquara_mobile/assets/images/branding/SAMUDERA_FIX_LOGO.png.
PNG signature valid, decode System.Drawing dan Flutter berhasil, 500×500 (1:1),
RGBA dengan piksel transparan serta terlihat, 121.329 byte. Visual ikan emas dan
gelombang biru, tanpa wordmark. SHA256:
30A4751BCFC0ACB1F4FF1A0457C86CBAEF7950D165165624FC5E56C8CD919B63.
File tidak diedit/crop/recolor dan logo lama tidak dipulihkan.

Konstanta C:/laragon/www/aquara_mobile/lib/widgets/samudera_branding.dart
menjadi satu referensi sumber untuk Beranda, auth, splash, Tentang dan Asisten.
Ukuran widget, BoxFit, warna dan layout tetap; spacing Perizinan tidak diubah.
Deklarasi assets pada pubspec milik pengguna sudah cocok termasuk kapitalisasi.
Test menjaga PNG/decode/500×500/alpha/contain/layout serta menambah pemeriksaan
path final dan deklarasi aset persis. Dua kegagalan logo pada test Perizinan
teratasi: seluruh 19 test lulus exit 0, tanpa overflow tersisa pada run tersebut.
Regresi branding/Beranda/Asisten terkait 161 lulus exit 0.

Suite penuh final dijalankan sekali: 774 lulus exit 0. Analyzer baseline/final
38 diagnostic exit 1, delta isi 0; format tiga Dart 0 berubah exit 0 dan diff
check bersih termasuk PNG/untracked terkait. Hash PNG final, pubspec, resource
Android dan layar Perizinan tidak berubah. Tidak ada kegagalan test tersisa.

### Generator (hanya diperiksa)

image_path dan adaptive_icon_foreground pada pubspec pengguna sudah menunjuk
SAMUDERA_FIX_LOGO.png, bukan sumber lama. Konfigurasi tidak diubah dan generator
tidak dijalankan; resource native tidak disentuh. Test resource existing tetap
dipertahankan, bukan bukti resource sudah dihasilkan dari PNG baru. Padding
visual sumber baru berbeda dari sumber historis; klaim safe-zone/padding logo
lama di bagian historis berikut tidak berlaku otomatis pada PNG baru. Sebelum
regenerasi native diperlukan review safe-zone terpisah. Pemeriksaan emulator
untuk ukuran optik logo baru juga masih diperlukan.

## Perizinan publik — 27 Oktober 2026

Pembaruan UI berikut menggantikan presentasi awal di bawah: halaman pilihan ringkas
dengan tiga kartu full-tap/adaptif, satu Bantuan Diskanla, dan catatan pengajuan.
Detail bersama berisi ringkasan, kartu langkah bernomor, Perlu diketahui, CTA resmi,
bantuan dan Sumber & pembaruan expandable (tertutup awal). Domain ditampilkan,
bukan URL mentah; tanggal publikasi kosong tidak diulang. Header/tema/guard existing
tetap, Back menjaga posisi daftar. Registry memakai assets/icons/services/perizinan.png
(Certificate/Magnific), contain/warna asli/wadah 64×64 tetap. Kredit existing
ditambah tanpa menghapus kredit lain. Katalog fakta/URL/tanggal tidak berubah.
Validasi dan batas: C:/laragon/www/aquara_mobile/docs/PERIZINAN_SAMUDERA.md.

### Riwayat presentasi awal (sebelum penyederhanaan)

Registry existing menambah Perizinan pada Semua Layanan/kategori Nelayan & Kelautan dan Cari Layanan (KUSUKA/SIPI/SIKPI/asuransi/BPJS). Tujuan tunggal PerizinanScreen dengan guard _openPage existing; tidak menambah navbar/FAB atau mengubah fitur privat. Ikon sementara dokumen Material SDK, wadah 64×64/padding 8 tetap; tidak memakai ulang gambar fitur lain.

Tiga kartu panduan lokal memisahkan identitas KUSUKA, izin kapal, dan perlindungan. Setiap topik menampilkan ringkasan, langkah, batas informasi, sumber/URL/tanggal pemeriksaan tetap, tanggal publikasi bila tersedia, dan kontak Diskanla. AppBar mengikuti tema #009FE3/Poppins/back, Card/surface light-dark, SingleChildScrollView/SafeArea/maxWidth 760. Browser eksternal hanya setelah tap; tombol dinonaktifkan selama launch. Tidak ada form atau pengumpulan data pribadi. Status belum ditinjau dinas terlihat di layar.

Catatan sumber, batas, dan gate penerimaan: C:/laragon/www/aquara_mobile/docs/PERIZINAN_SAMUDERA.md. Pemeriksaan emulator/TalkBack/browser perangkat dan penerimaan dinas masih terbuka; implementasi lokal tidak menutup Cuaca resmi/Peta TPI/smart router/Omni-Search/rilis.

## Titik masuk Asisten mengambang — 26 Oktober 2026

Mengikuti posisi gambar 3–4 dari lima screenshot pengguna (diperiksa langsung), tombol Asisten konten dipindah ke FloatingActionButton kanan bawah Scaffold, hanya selectedIndex Beranda. Ikon chat existing menggantikan ilustrasi sirene referensi; #009FE3, 56×56, elevation 3, tooltip/semantics Asisten SAMUDERA. Tambahan padding bawah scroll 88px membuat akhir konten bisa digulir melewati FAB. Navbar, kamera SOS, carousel, layanan dan guard _openPage dengan ApiService injeksi tetap. Tidak membuat overlay global atau tombol kedua.

Pengujian geometry/touch target/tab/back/guest, regresi carousel/SOS dan sesi lulus dalam 129 test terarah; suite penuh final 755 PASS exit 0. Analyzer baseline/final 38 diagnostic exit 1 tanpa delta isi. Pemeriksaan visual posisi relatif carousel pada berbagai posisi scroll, keyboard dan TalkBack di emulator tetap diperlukan; tidak mengklaim identik piksel. Rincian chat dicatat di C:/laragon/www/aquara_mobile/docs/Asisten_SAMUDERA.md.

## Penutupan wiring Analisa — 26 Oktober 2026

Temuan wiring pada laporan kartu di bawah telah ditelusuri dan ditutup, tanpa perubahan presentasi. Pada konstruksi default, C:/laragon/www/aquara_mobile/lib/services/auth_service.dart memilih AuthService.apiBaseUrl dari SAMUDERA_API_URL compile-time/default existing dan SessionService.instance; membuat ApiService() baru tidak otomatis mengubah origin atau konteks sesi default. Namun, C:/laragon/www/aquara_mobile/lib/screens/home_screen.dart meneruskan instance injeksi ke Semua Komoditas, sedangkan callback kartu di C:/laragon/www/aquara_mobile/lib/screens/semua_komoditas_screen.dart sebelumnya tidak meneruskannya ke Analisa. C:/laragon/www/aquara_mobile/lib/screens/analysis_screen.dart dan C:/laragon/www/aquara_mobile/lib/widgets/session_boundary.dart memakai fallback ApiService() jika api null, sehingga client/target/sesi injeksi tidak dijamin sama.

Perbaikan minimum: tambahkan `api: _apiService` pada konstruktor AnalysisScreen dalam callback Semua Komoditas. Parameter nama/harga/FCR/periode dan guard existing tetap. Tidak mengubah URL/config, transport, autentikasi, token store, rumus atau UI. Test kedua jalur kini memverifikasi identitas instance/client/sesi sebelum mounting, kemudian memuat Analisa lewat mock yang sama dan menguji invalidasi sesi serta stack kembali Login. Regresi terarah aktual 168 PASS exit 0; analyzer 38 → 38 exit 1, delta isi 0; format dua Dart 0 berubah exit 0; git diff --check exit 0 dan untracked --no-index --check tanpa temuan whitespace (exit 1 menandakan beda file). Tidak menjalankan aplikasi/API nyata atau suite penuh ulang. Angka suite penuh pada riwayat berikut bukan hasil tugas wiring ini.

## Preview berita dan kartu komoditas bersama — 26 Oktober 2026

Acuan langsung: empat screenshot pengguna; gambar 2 hanya susunan kartu Berita Terkini dan gambar 4 hanya kartu Semua Komoditas. Tidak menyalin judul/CTA, konten berita referensi atau ruang kosong layar.

- C:/laragon/www/aquara_mobile/lib/widgets/home_news_preview.dart mempertahankan request satu future, retry manual, isolasi sesi, guest tanpa endpoint privat dan urutan/dedup maksimum tiga berita aktual. Kartu horizontal radius 16/elevation 1, padding 16/gap antarkartu 12, thumbnail kiri 80x80 radius 12/BoxFit.cover; null/error tetap mengisi bidang tersebut. Kanan judul tebal maksimal dua baris ellipsis, gap 8 lalu tanggal bodySmall dd MMM yyyy dari timestamp sebenarnya; tanggal kosong/rusak `-`. Tinggi mengikuti teks, bukan fixed height. Penulis hanya tidak dirender pada preview; field/model/detail tidak dihapus. Detail existing berbasis snapshot diberi key ID sumber, tanpa endpoint tambahan. CTA biru dan akses daftar tidak diduplikasi.
- Route aktif ditelusuri dari Beranda ke SemuaKomoditasScreen. Renderer inline pada C:/laragon/www/aquara_mobile/lib/screens/semua_komoditas_screen.dart diekstrak menjadi C:/laragon/www/aquara_mobile/lib/widgets/commodity_card.dart; kedua layar memakai satu implementasi. Thumbnail 54x54/radius 12, padding 16, gap foto 16, radius kartu 16, bayangan biru alpha .05/blur 15/offset 0,5; Poppins nama 15 bold, metadata 11, label harga 9, nominal 13 bold. Harga rata kanan; margin luar milik layar tetap terpisah dari struktur kartu.
- Varian Semua Komoditas putih pada light dan surface tema pada dark; foreground mengikuti tema, harga tetap biru. Beranda memakai #009FE3 persis dengan tint transparan dan teks/ikon netral gelap. Aturan responsif identik: ukur lebar harga dengan TextPainter/textScaler aktual; bila sisa ruang nama kurang dari 120 scaled pixels, tempatkan harga pada baris bawah rata kanan di sisi kanan thumbnail. Tidak memotong metadata, tidak mengecilkan teks, tinggi boleh bertambah. Sumber/formatter/nilai/FCR/hari/harga, batas dua preview dan callback/parameter Analisa tidak berubah.
- Test aktual: 10 test baru, terarah final 195 PASS exit 0, suite penuh final satu kali 754 PASS exit 0. Geometry dua varian pada 320px/1x/2x/light-dark sama; null/error image, judul panjang, tanggal, detail sesuai ID dan regresi guest/loading/retry/sesi/navigasi diuji dengan fake/mock. Analyzer 41 → 38 exit 1, tiga lint withOpacity hilang saat ekstraksi, tidak ada diagnostic baru. Format enam Dart 0 berubah exit 0, git diff --check exit 0; file baru --no-index --check tanpa temuan whitespace (exit 1 karena berbeda dari /dev/null). Log C:/Users/Fajar/AppData/Local/Temp/samudera-cards-*.
- Tidak ada pipeline golden/render existing yang ditemukan. Pemeriksaan visual emulator/font asli/crop foto dan pembandingan referensi pada constraint sama masih diperlukan; tidak mengklaim pixel-identical. Asisten tidak diubah dan emulator/integrasinya tetap tertunda. Temuan wiring existing di luar scope: Semua Komoditas tidak meneruskan instance ApiService ke Analisa; detail berita memakai snapshot konten, bukan fetch berdasarkan ID. Tidak menambah request atau mengubah service untuk kedua hal tersebut.

## Autoplay Mendukung Pembudidaya — 25 Oktober 2026

Permintaan eksplisit terbaru menggantikan ketentuan **tanpa autoplay** pada bagian riwayat di bawah hanya untuk Mendukung Pembudidaya. Panduan Aplikasi tetap manual dan tidak diubah.

- Acuan git show/log e88bf1e pada C:/laragon/www/aquara_mobile/lib/screens/home_screen.dart: Timer.periodic 3 detik, animateToPage 500ms easeInOut. Tidak ditemukan kontrol Jeda/Lanjut pada versi tersebut. Implementasi baru menggunakan interval diam 3 detik, transisi 500ms, kemudian interval baru setelah transisi selesai (bukan periodic tumpang tindih).
- C:/laragon/www/aquara_mobile/lib/widgets/support_banners.dart memakai PageView, empat konten/tujuan lama tetap. Salinan pertama setelah slide keempat memungkinkan satu langkah maju saat wrap; posisi dinormalisasi tanpa animasi kedua. Tinggi gambar, overlay, rounded 20, tema/Poppins/aset/kredit dipertahankan; indikator dan tombol terpisah di bawah gambar.
- Jeda menghentikan timer dan animasi pada slide terpilih. Lanjut mulai interval baru, tidak langsung meloncat. Geser manual otomatis menjeda. Kontrol Material minimum 48px, label jelas dan tooltip, tidak meneruskan tap ke gambar. Pilihan jeda berada pada state Beranda dan bertahan lintas tab selama instance hidup; tidak disimpan lintas peluncuran aplikasi.
- ModalRoute.isCurrentOf menangguhkan saat route lain menutupi Beranda, WidgetsBindingObserver saat inactive/background. Dispose membatalkan timer/controller; generation guard menolak completion lama. Tab nonaktif membuang widget sesuai mekanisme Beranda existing. Kembali/resume tidak menimpa pilihan jeda. disableAnimations atau accessibleNavigation menonaktifkan gerak otomatis dengan keterangan UI; manual/control masih tersedia. Tidak ada polling/fetch/dependency tambahan; callback dan guard navigasi existing tetap.

Hasil aktual: 74 test terarah (banner/Beranda/discovery/session navigation) PASS exit 0; suite penuh final sekali 682 PASS exit 0. Analyzer baseline/final 41 diagnostic exit 1 (isi sama setelah normalisasi lokasi); format 5 Dart 0 berubah exit 0, diff check exit 0. Log C:/Users/Fajar/AppData/Local/Temp/samudera-autoplay-target-final.txt, samudera-autoplay-full-final.txt, samudera-autoplay-baseline.txt dan samudera-autoplay-analyze-final.txt. Final log tanpa missed-tap/overflow/pending timer.

Test timer memakai pump interval/frame eksplisit: loop, pause/resume interval baru, swipe, route cover/return, inactive/resume, jeda pengguna, penghentian transisi/dispose, tab Beranda, 320px/2x/light-dark/reduced motion. Empat tujuan banner dan guest/double-open tetap diuji regresi existing. Tidak memperpanjang timeout; kegagalan awal harness diperbaiki dengan pumping frame awal/akhir animasi.

Emulator masih perlu: tinjau timing/crop/wrap, kontrol dan swipe, buka tujuan/Back, tab, background/resume, pengaturan reduced motion/TalkBack dan teks 2x nyata. Tidak ada klaim UAT baru. Hash lib/test sebelum/sesudah membuktikan hanya file existing Beranda/support banner dan dua test terkait berubah, ditambah test banner baru. Profil/komentar/produk/backend/auth/token/config/dependency/native tidak diubah.

## Tindak lanjut pemeriksaan emulator — 25 Oktober 2026

Bagian ini menggantikan batas implementasi Task 03 lama di bawah, bukan menghapus riwayat hasilnya.

### Profil dan produk

- Profil anggota mengikuti komposisi profil sendiri: panel #009FE3, avatar besar 100, nama, Fokus Usaha, produk. Fokus diambil dari GET profiles/{id}, nullable string; null/kosong memakai fallback, legacy Lele tidak dipetakan ulang. Identitas nested author tidak memerlukan fokus. Profil sendiri tetap memakai endpoint akun sendiri, dengan seluruh aksi existing.
- Form berlabel Fokus Usaha, maksimal 255 karakter; petunjuk eksplisit bahwa kosong mempertahankan nilai tersimpan. Service menolak >255 sebelum request. Setelah simpan profil membaca server, bukan menganggap input kosong menghapus fokus.
- C:/laragon/www/aquara_mobile/lib/widgets/profile_products.dart dipakai kedua profil: GET profiles/{id}/pasars?page=N&per_page=20, kategori lokal tawar/laut (Stok Panen) dan olahan (Stok Olahan). Halaman tanpa kategori belum berarti habis; tombol pagination berdasarkan last_page, tidak memakai total sebagai total kategori. Tidak memakai stocks/fish-type ID; fetchStocks tetap alur katalog.
- Kartu membuka PasarScreen existing dengan targetItemId dan targetOwnerId. GET pasars existing memvalidasi ketersediaan melalui daftar tanpa endpoint detail buatan. Tampilan target hanya produk yang cocok ID/owner, termasuk keadaan hilang; guard CRUD/WA/pre-order existing tetap. Tidak menambahkan /Kg. Back anggota mempertahankan daftar lintas halaman; self refresh agar CRUD tampil.

### Komentar: hasil diagnosis dan batas bukti

Alur yang diperiksa: ForumScreen -> ForumCommentsScreen -> fetchForumPage -> parseForumItem -> profileRelation -> ProfileIdentity -> ProfileNavigation/SessionBoundary. Root dan replies memakai callback yang sama. Nama/ikon fallback dapat tampil walau nested user null; kondisi ini sengaja tidak memiliki onTap profil. Validitas identitas tidak direkonstruksi dari nama/ID legacy. Tooltip kini membedakan Buka profil dan Profil penulis tidak tersedia.

Tap fisik root/reply nama/avatar dari Forum aktual dengan fake kontrak valid lulus, draft dan Back terjaga. Tidak ditemukan blocker hit-test lokal. Screenshot tidak memuat payload ataupun versi build, sehingga penyebab spesifik kegagalan emulator belum dapat dinyatakan pasti atau telah diperbaiki. Perlu verifikasi build dan nested user.id aktual tanpa mencatat token/data pribadi. Test tidak mengakali tap dengan memanggil callback untuk membuktikan navigasi ini.

### Sumber pemulihan banner

Git log/show C:/laragon/www/aquara_mobile/lib/screens/home_screen.dart pada commit e88bf1e membuktikan empat slide berikut:

| Judul | Aset existing | Tujuan existing |
| --- | --- | --- |
| Analisa Panen Cerdas | assets/banner_analisausaha.png | AnalysisScreen |
| Cek Harga & Stok Pasar Hari Ini | assets/banner_hargapasar.png | PasarScreen |
| Diskusi Bersama Komunitas | assets/banner_forum.png | ForumScreen |
| Foto Ikan dan AI Menjawabnya | assets/banner konsultasi ai.png | ConsultationScreen |

Presentasi mempertahankan foto/overlay gelap/rounded 20/teks putih dan tema Poppins inherited; tinggi mengikuti skala teks. Strip horizontal manual ditambahkan terpisah dari carousel Panduan Aplikasi existing, tanpa autoplay dan tanpa request baru. Bukan pemulihan pixel-identik: kontrol otomatis lama tidak dibawa kembali. Hero/layanan/SOS/persona/panduan/berita/komoditas serta aset/kredit tidak dihapus. Tujuan keempat memang ConsultationScreen berdasarkan source, bukan diasumsikan langsung AI.

### Verifikasi aktual

- Test terarah final 296 lulus exit 0; suite penuh final satu kali 672 lulus exit 0. Log C:/Users/Fajar/AppData/Local/Temp/samudera-profile-target-verified.txt dan samudera-profile-full-final.txt.
- Analyzer baseline 43 -> final 41, exit 1 keduanya: 2 warning existing dan 39 info final, tanpa diagnostic baru; dua deprecated info kartu stok lama hilang. Perbandingan normalized pada samudera-profile-diagnostics.json.
- Format 15 Dart 0 berubah exit 0; git diff --check exit 0; whitespace file baru 0. Final log tanpa missed-tap/overflow. Kegagalan awal constructor/fixture/test harness diperbaiki tanpa melewati assertion; kelanjutan debugging disetujui pengguna.
- Uji existing mencakup sesi guest/logout/switch/stale, pagination/error/retry, Forum/Pasar/pre-order; tambahan mencakup fokus dan exact owner route serta empat tujuan banner. Responsive anggota 320px/2x/keyboard/light-dark dan self/edit 320px/1.8x; tidak mengklaim seluruh matriks self/edit 2x atau emulator/UAT.
- Masih perlu perangkat: reproduksi ketukan author dengan build/payload aktual, dua akun/deleted, pagination >20, gambar tanpa Authorization, WA/pre-order, crop banner, Poppins/scroll/SafeArea/keyboard nyata. Laravel read-only, tidak mengakses API nyata, mengubah dependency/native/auth/token/config, commit/push/deploy.

## Penuntasan aset final — 25 Oktober 2026

Menggantikan status tertunda ikon/foto pada riwayat Task 01 di bawah. Forum Saya memakai `forum_saya.png` (Online Chat, mikan933 Flat); Semua Komoditas `semua_komoditas.png` (Fish, Magnific, Basic Rounded Flat). Registry 16 layanan diuji tanpa duplikasi bytes, termasuk kedua pasangan lama. Beranda/kategori/pencarian/persona memakai referensi registry existing; ukuran/Poppins/warna/navigasi tidak diubah.

Pengolah kini memakai JPEG final pekerja menata ikan di rak, sumber Quang Nguyen Vinh/Pexels, Vietnam. Decode sumber 7829x5222; turunan existing 1600x1067 tanpa crop permanen. Preview crop tengah pilihan persona ditinjau: pekerja, tangan dan rak ikan terlihat; detail BoxFit.contain menjaga keseluruhan foto. Tidak mengklaim dokumentasi Indramayu atau dukungan subjek.

Kredit lama/empat aset Task 01 tetap; tiga kredit baru dan tombol rujukan lisensi tersedia. Rincian sumber, hash, transparansi dan status bukti pada `C:/laragon/www/aquara_mobile/docs/beranda-2d/ASET_FINAL_20261025.md`. Catatan ini bukan lisensi unduhan; folder sumber licenses hanya README. Belum ada dokumen unduhan untuk membandingkan nama pembuat.

Baseline aktual terarah 65 test PASS exit 0, final 66 PASS exit 0; 320px/2x/light-dark termasuk kredit dan semua persona. Analyzer 43→43 exit 1 (isi identik setelah normalisasi lokasi), format 4 Dart 0 berubah exit 0 dan diff check exit 0. Suite penuh sengaja tidak diulang. Dua test awal gagal karena batas scroll harness menuju kredit panjang; diperbaiki batas scroll, bukan layout/fitur. Log `C:/Users/Fajar/AppData/Local/Temp/samudera-assets-*`.

Emulator/perangkat: tinjau crop lingkaran, keterbacaan ikon ukuran aktual, scroll kredit/tautan eksternal dan aksesibilitas tema/teks besar. Bukti unduhan dan penerimaan visual belum selesai; bukan UAT/rilis. Profil Task 03 dan logika fitur tidak disentuh.

## Task 03 — avatar/profil, 25 Oktober 2026

Poin 2 selesai implementasi dan pemeriksaan mock lokal, bukan integrasi API nyata/UAT. Kontrak baru mengacu pembacaan terarah `C:/laragon/www/aquara_proyek2/docs/API_DOCUMENTATION.md`, routes api, ProfileController, ProfileResource, ProfileProductResource dan resource Forum. Dokumen API Flutter lama belum memuat endpoint ini; `/user` tetap kontrak diri sendiri dan tidak dipakai untuk profil orang lain.

- `GET profiles/{id}`: privat Sanctum; success + data hanya id/name/foto_profil. `GET profiles/{id}/pasars?page=1&per_page=20`: success + array data + meta current_page/per_page/total/last_page. Berbeda dari envelope komentar data.data; query dibentuk lokal, tidak mengikuti URL paginator. Produk divalidasi milik target.
- `C:/laragon/www/aquara_mobile/lib/models/profile_summary.dart` mengallowlist relasi valid. Parser Forum/Pasar mempertahankan field kepemilikan existing, menambah identitas navigasi terpisah hanya nested user.id yang konsisten secara kanonik. String komentar legacy dengan user null tidak merusak daftar; tidak ditebak dari nama/ID 0.
- `C:/laragon/www/aquara_mobile/lib/widgets/profile_identity.dart`: area avatar/nama minimum tinggi 48px, nama membungkus, fallback netral; Image.network tanpa headers API. Lock per Navigator mencegah double-open. Self menuju ProfilScreen existing, other menuju `C:/laragon/www/aquara_mobile/lib/screens/member_profile_screen.dart`.
- Profil other menampilkan nama/foto dan daftar produk baca-saja, tanpa kemampuan pribadi/CRUD. Tidak mereuse aksi produk di halaman ini; WhatsApp dan pre-order pada Pasar existing tetap. `C:/laragon/www/aquara_mobile/lib/services/profile_api.dart` diintegrasikan ke facade existing, bukan transport baru. Tidak menyimpan profil ke disk/cache bersama.
- SessionBoundary, expectedSession/revision dan key target menjaga guest, logout/switch, dispose serta respons target lama. Data profil/produk dibersihkan saat sesi berubah. Loading/empty/error/retry manual; 401 terpusat, 403/404 tidak logout, 422 tersanitasi dan 429 memakai cooldown existing. Back mempertahankan layar sumber.

### Hasil aktual

Baseline 625 PASS; regresi gabungan 299 PASS; final khusus profil 25 PASS tanpa warning missed tap; suite penuh setelah kode final satu kali **650 PASS exit 0**. Analyzer **43→43**, 2 warning/41 info, exit 1; isi diagnostic identik setelah normalisasi baris/kolom. Format 12 file 0 berubah exit 0; git diff --check exit 0. Log `C:/Users/Fajar/AppData/Local/Temp/samudera-task03-*`.

Test mencakup tap nama/avatar post/root/reply/seller, self/other/invalid/deleted/legacy, double activation, null/error image tanpa headers, envelope/owner malformed, pagination/dedup/error-retry, status HTTP, guest, logout/switch pending maupun loaded, pergantian target dan 320px/2x/keyboard/light-dark. Timeout setup awal diperbaiki setelah izin gate debugging: inisialisasi sesi fake harus di zona widget test. Test legacy diperbarui mengikuti kontrak, bukan menghapus validasi tipe.

### Gate tersisa

Pengguna perlu menguji Flutter dengan API nyata dua akun: profile/produk lebih dari 20 item, deleted/legacy author, sesi berakhir/switch/Back, 403/404/429 serta CDN/storage tanpa Authorization. Perlu pemeriksaan emulator/perangkat untuk avatar/nama panjang, target sentuh, keyboard, tema/teks besar, state scroll/draft ketika Back, dan regresi forum/komentar/Pasar/pre-order/SOS. Tidak mengklaim validasi nyata dari mock. Tidak ada perubahan Laravel/native/dependency/auth/token/config, API nyata, aplikasi kedua, commit/push/deploy.

## Kelanjutan UI/penemuan layanan — 25 Oktober 2026

Status ini mendahului riwayat di bawah; bukan penyelesaian seluruh sembilan poin atau UAT. Acuan paket pengguna: `C:/Users/Fajar/Downloads/SAMUDERA_UI_Lanjutan_20261025/PROMPT_01_FLUTTER.md`. Referensi 01–16 dibaca sebagai struktur, bukan target identik piksel.

| Poin | Implementasi aktual | Status/gate |
| --- | --- | --- |
| 1 SOS | Card #009FE3, surfaceTint transparan, teks hitam; handler laporan/kamera existing tetap | Lokal lulus; visual perangkat belum |
| 2 Profil | Avatar/nama post/root/reply/seller; self existing, other baca-saja dan produk paginasi | Task 03 lokal 650 test lulus; API nyata/emulator belum |
| 3 Logo | Master contain 72→94px (+30,6% linear); padding transparan/master tetap, simbol utuh, hero asli tetap | Lokal 320px/2x lulus; ukuran visual emulator perlu tinjau |
| 4 Berita | CTA biru, preview maksimal 3 ID unik `/posts`, urutan terbaru-dahulu sesuai kontrak, tanggal invalid/null tidak dipalsukan, detail masing-masing | Guest tanpa request privat; login lewat jalur daftar existing. Tidak mengambil feed eksternal saat coding |
| 5 Komoditas | Card biru tepat, foreground hitam, angka/FCR/harga/asumsi untouched | Lokal lulus |
| 6 Ikon | Enam ikon final input dipakai; kredit lama tetap, registry tanpa duplikasi | Lokal selesai; bukti unduhan/emulator tersisa |
| 7 Persona | Lima kelompok/detail/foto aktif, termasuk Pengolah Vietnam; tidak menyimpan profesi/RBAC | Lokal selesai; emulator tersisa |
| 8 Kategori/search | 16 ID tepat satu dari 6 kategori, dedup, nama/alias/deskripsi/kategori, kategori kosong hidden; home membuka katalog yang sama | Lokal lulus |
| 9 Banner | Satu carousel manual 3 Panduan Aplikasi/Tim SAMUDERA, tiap banner menuju detail sesuai; tombol prev/next, no timer/polling | Lokal lulus; foto+teks Flutter, contain menjaga subjek. Bukan berita/dokumen resmi |

### Keputusan kontrak dan keamanan

- `C:/laragon/www/aquara_mobile/docs/API_DOCUMENTATION.md` bagian 5: `/posts` privat Sanctum, tanpa pagination/filter, newest-first. Preview memakai ApiService/ApiClient/parser reference existing, expectedSession dan guard mounted/revision. 401/429/cooldown tetap mekanisme existing; retry manual melalui ReferenceListBuilder, tidak auto-fetch saat resume atau per item. Tidak ada refresh sukses baru sehingga tidak ada cache berita stale lintas refresh yang dipertahankan. Saat sesi berubah hasil pending dibuang dan navigasi terpusat membersihkan layar.
- Persona memakai callback registry `_services` yang sama; navigator discovery memiliki lock tersendiri agar rekomendasi masih dapat membuka layar tujuan. Layar privat mempertahankan boundary existing. Tambak/Laut tidak menjanjikan Analisa karena model reference tidak mendefinisikan dukungan budidaya laut. Pengolah hanya menjanjikan pencarian bahan baku/produk aktual, bukan fitur penjualan olahan baru.
- Panduan lokal dipilih karena tidak ada artikel lokal dengan konten/judul sesuai yang dapat diverifikasi tanpa memanggil backend; tidak mengarang artikel aktual atau tanggal. Cuaca/KKP/TPI tetap DATA SIMULASI, bukan panduan keselamatan. Tidak mengubah service/auth/token/config/native/backend atau rumus.

### Riwayat audit Task 01 sebelum input final (bukan status terkini)

Semua 6 PNG dan 5 JPEG yang diminta ada. Signature/decoder System.Drawing mengonfirmasi PNG untuk ikon dan JPEG untuk foto. Seluruh 16 referensi dan 6 ikon ditinjau visual; 5 foto ditinjau lewat preview lokal 800px karena file asli terlalu besar untuk pembaca. Empat foto diperkecil proporsional menjadi 1600px lebar tanpa crop/teks/recolor ke `C:/laragon/www/aquara_mobile/assets/images/discovery/`; sumber asli tidak berubah. Runtime cacheWidth 240 untuk lingkaran, 1200 untuk detail/banner; foto detail contain. Ikon baru disalin byte-identik ke `C:/laragon/www/aquara_mobile/assets/icons/services/`.

| File input | Pemeriksaan dan keputusan |
| --- | --- |
| berita.png | PNG 512², surat kabar biru; dipakai, Smashicons, Flaticon newspaper_660628 |
| harga_pasar.png | PNG 512², browser/label harga; dipakai, Smashicons, Flaticon price-tag_4116340 |
| konsultasi.png | PNG 512², konsultasi layar/percakapan; dipakai, Assia Benkerroum, Flaticon consultation_8469077 |
| info_dinas.png | PNG 600×326, simbol ikan biru-oranye; aset milik pengguna, dipakai hanya Info Dinas |
| forum_saya.png | PNG 500², headset/operator monokrom, tidak sesuai deskripsi chat berwarna/atribusi kandidat; TIDAK dipakai |
| semua_komoditas.png | PNG 512², beberapa ikan berwarna, visual berbeda tetapi pembuat belum tercatat; TIDAK dipakai sampai atribusi tersedia |
| pembudidaya_tawar.jpg | JPEG 6591×4394, kegiatan memberi pakan, sesuai tema; HONG SON / Pexels 37052316 |
| tambak_laut.jpg | JPEG 5434×3615, kolam udara; Tom Fisk / Pexels 5774415 |
| nelayan.jpg | JPEG 5184×3456, pekerja/perahu/ikan; setengah lima sore / Pexels 30733108 |
| pedagang.jpg | JPEG 7008×4672, pajangan ikan; Mitchell Soeharsono / Pexels 36618308 |
| pengolah.jpg | JPEG 6016×4016, still-life ikan/pisau, tidak cocok deskripsi kandidat orang membersihkan ikan; TIDAK dipakai, sumber final perlu diberikan |

Sumber URL lengkap ada di halaman kredit existing `C:/laragon/www/aquara_mobile/lib/screens/icon_credits_screen.dart` dan manifest paket pengguna. Atribusi mengikuti manifest yang diberikan, bukan klaim konfirmasi situs/sertifikat unduhan. Folder input-assets/licenses hanya README. Bukti unduhan semua aset baru masih perlu dilengkapi. Tidak mengunduh/hotlink/membuat aset AI. Ketentuan distribusi raw files tetap perlu review sebelum publikasi repository.

Kekurangan tepat: varian berwarna `forum_saya.png` dengan URL/pembuat final; nama pembuat/bukti sumber `semua_komoditas.png`; foto `pengolah.jpg` yang sesuai sumber atau atribusi final untuk file aktual. Sampai itu tersedia, Forum/Forum Saya berbagi forum.png dan Katalog/Semua Komoditas berbagi katalog_ikan.png. Test membandingkan bytes seluruh 16 ID dan mengunci hanya dua pengecualian tersebut, bukan mengklaim semua ikon unik. Tidak mendaftarkan file yang tidak dipakai/hilang ke pubspec.

### Pemeriksaan aktual

- Analyzer baseline 43 (2 warning, 41 info), final 43, exit 1. Perbandingan isi diagnostic setelah normalisasi nomor baris: added=[], removed=[]. Tidak menutupi warning lama.
- 102 test terarah lulus exit 0 (discovery, home, visual alignment, reference data); suite penuh final satu kali **625 PASS exit 0**, 2m15s. Sebelumnya 608 adalah riwayat; 17 test baru pada tugas ini.
- Pengujian: 0/1/2/3/5 berita, dedup, detail tepat, null timestamp, malformed/error/manual double-retry, no guest request, stale session, coverage registry, search kosong/tidak ditemukan/alias/kategori, navigasi persona/guest/double-open, 3 banner/detail/Back, warna exact, FCR unchanged, decode aset asli terdaftar, 320px/2x/light-dark/keyboard/scroll. Regression suite mencakup layanan/session/401/429 existing.
- Interim: 4 kasus overflow banner 50px pada 320px/2x diperbaiki dengan ruang teks lebih besar. Assertion search lama diperbarui karena kategori kini dicari (Dinas menemukan Berita + Info Dinas). Dua test baru diperbaiki: finder Tooltip bukan IconButton dan fixture FCR int 1 (bukan string 1.00). Tidak mengubah angka aplikasi untuk meloloskan test.
- Format 7 Dart, 0 changed, exit 0; git diff --check exit 0. Log di `C:/Users/Fajar/AppData/Local/Temp/samudera-ui-*`, terutama full-final.txt/.exit, targeted-verified.txt/.exit, diagnostic-delta.json.
- File kode: `C:/laragon/www/aquara_mobile/lib/screens/home_screen.dart`, `C:/laragon/www/aquara_mobile/lib/screens/icon_credits_screen.dart`, `C:/laragon/www/aquara_mobile/lib/widgets/home_services.dart`, `C:/laragon/www/aquara_mobile/lib/widgets/home_news_preview.dart`, `C:/laragon/www/aquara_mobile/lib/widgets/service_discovery.dart`; tests `C:/laragon/www/aquara_mobile/test/service_discovery_test.dart` dan `C:/laragon/www/aquara_mobile/test/home_2d_test.dart`. Pubspec hanya deklarasi folder discovery; dependency unchanged.

### Gate emulator/integrasi belum dijalankan

Periksa urutan home, besar isi logo, crop lingkaran dan contain banner/detail, panjang banner pada perangkat, Poppins dan kontras, 320px/2x/landscape/tablet, keyboard nyata/SafeArea/TalkBack/fokus, swipe/tombol/reduced motion, Back/double tap, guest/login/logout/pergantian akun. Cocokkan 0–3 berita dan tanggal dengan backend dev melalui aplikasi setelah coding; fixture/sintetis existing, tidak membuat ulang pesanan atau mengirim SOS. Regresi forum/pre-order/kamera SOS tetap diuji perangkat terpisah. Profil baru setelah task 02/03. Tidak menjalankan emulator/aplikasi kedua, API nyata, build/release, migration, commit/push/deploy. UAT dinas, security/scalability dan rilis belum selesai.

## Kelanjutan aset dan metadata — 21 Oktober 2026 (acuan terkini)

Implementasi aset dan metadata serta verifikasi lokal selesai. Status terbaru ada di C:/laragon/www/aquara_mobile/TODO.md bagian Kelanjutan aset resmi dan metadata. Semua catatan penundaan aset/versi dan kegagalan interim di bagian historis di bawah bukan status pekerjaan aktif.

- Dua aset resmi dari paket pengguna: C:/laragon/www/aquara_mobile/assets/icons/whatsapp_official.png dan C:/laragon/www/aquara_mobile/assets/icons/instagram_official.png. Sumber lengkap, nama asli dan ketentuan ada di C:/laragon/www/aquara_mobile/docs/ASET_KONSULTASI_RESMI.md. Image.asset existing, contain, tanpa recolor/crop; 30px dengan ruang 12px pada alas putih, handler tautan unchanged. Master PNG tetap asli; cache decode 120px untuk memori.
- C:/laragon/www/aquara_mobile/lib/widgets/app_version_label.dart memakai PackageInfo.fromPlatform secara lazy saat widget tampil, FutureBuilder dengan loading/error/metadata kosong; digunakan Tentang dan footer Pengaturan. Tidak mengubah startup atau autentikasi. Pubspec tetap 1.1.0+2, bukan fallback UI.
- package_info_plus 8.3.1 dan platform interface 3.2.1; hanya dua tambahan lockfile. Syarat versi plugin: Flutter >=3.19, Dart >=3.3 <4, Java 17, AGP >=8.3, Gradle >=8.4, compileSDK 34 (rujukan https://pub.dev/packages/package_info_plus/versions/8.3.1). Toolchain existing: Flutter 3.35.2/Dart 3.9, JDK Flutter 21, AGP 8.9.1/Gradle 8.12/Kotlin 2.1.0; tidak di-upgrade. Registrasi plugin otomatis diperbolehkan khusus tugas ini; tidak mengedit native manual.
- Hasil aktual: 22 test terarah dan 571 suite penuh lulus, exit 0. Full suite satu kali setelah dependency final. Mock channel menghasilkan 7.8.9 (321), membuktikan bukan angka pubspec; kegagalan tidak mengekspos error native dan metadata kosong tidak menghasilkan angka palsu. Layout Tentang/Konsultasi 320px/2x light-dark dan decode aset lulus. Warna Tentang mengikuti tema, header Konsultasi tumbuh agar teks besar tidak overflow.
- Bukti mock tidak sama dengan metadata APK/perangkat. Riwayat distribusi belum diketahui; forum, penerimaan emulator dan kesiapan rilis tetap terbuka. Log C:/Users/Fajar/AppData/Local/Temp/samudera-assets-version-20261021/.
- Analyzer aktual baseline/final 43 (2 warning/41 info), exit 1; isi identik setelah normalisasi lokasi. Format lima Dart 0 berubah exit 0; diff check exit 0. Build debug yang diizinkan selesai exit 0 (371.9s). APK C:/laragon/www/aquara_mobile/build/app/outputs/flutter-apk/app-debug.apk diperiksa aapt SDK 36.0.0 exit 0: versionName 1.1.0, versionCode 2, compileSdk 36. Tidak menjalankan/menginstal aplikasi. Hash SHA256 dua PNG tujuan identik dengan sumber pengguna. Registrasi plugin macOS otomatis hanya menambah import dan registration package_info_plus.

## Riwayat tugas sebelumnya (bukan hasil kelanjutan aset/metadata)

## Pembaruan 21 Oktober 2026 — hasil final lokal, gate aset/versi/perangkat terbuka

Verifikasi final: baseline aktual 550 test, final 562 lulus exit 0; 159 terarah lulus exit 0. Analyzer 43 -> 43 (2 warning/41 info), exit 1, tidak ada diagnostic baru setelah normalisasi lokasi. Format 11 file 0 berubah exit 0; diff check exit 0. Suite penuh final dijalankan satu kali. Log C:/Users/Fajar/AppData/Local/Temp/samudera-ui-20261021/.

Setelah izin pengguna melanjutkan, kegagalan dua test prefill diselesaikan: expect pada callback fake picker bertabrakan dengan guard async WidgetTester, dipindah ke badan test. Kamera/gallery, preview, validasi tanpa POST, hapus foto, guest, batal/ditolak/error/invalid dan hasil akun lama lulus. Tidak melonggarkan validasi aplikasi. FeatureTabs selected/unselected dan overlay focus/pressed lulus pada 320px teks 2x light/dark; state disabled tidak ada pada TabBar existing. Riwayat penundaan berikut dipertahankan untuk audit, bukan status akhir.

Status aktual dan angka verifikasi ada di C:/laragon/www/aquara_mobile/TODO.md bagian Pembaruan UI / kamera SOS. Jangan memakai hasil historis di bawah sebagai bukti tugas ini selesai.

- C:/laragon/www/aquara_mobile/lib/screens/home_screen.dart: foto/ukuran hero tetap; panel dan search berpermukaan hitam alpha .55, teks/ikon putih; pencarian/saran tetap pada katalog layanan opaque existing. Navbar empat tujuan tetap dengan aksi kamera SOS di tengah, bukan tab halaman kosong. Aktif #009FE3, kamera aksen #F7941D.
- C:/laragon/www/aquara_mobile/lib/widgets/feature_tabs.dart: perbaikan warna label primary di atas header primary, memakai permukaan tema dan indikator biru dengan teks hitam. Controller/request existing tidak diganti. Belum diverifikasi test state selected/focus/disabled atau visual perangkat.
- Prefill foto diteruskan bersama pemilik sesi ke C:/laragon/www/aquara_mobile/lib/screens/sos_screen.dart; picker memakai validator/service existing. Dua test jalur sukses belum lulus; pekerjaan berhenti pada gate tiga kegagalan workflow, bukan dinyatakan selesai.
- Sumber ikon kamera/navbar: Material Icons bawaan Flutter; tidak menambah paket. WhatsApp memakai C:/laragon/www/aquara_mobile/assets/icons/whatsapp.png existing (asal unduhan belum terverifikasi). Sumber pemeriksaan merek resmi: https://about.meta.com/brand/resources/whatsapp/whatsapp-brand/ dan https://about.meta.com/brand/resources/instagram/instagram-brand/ mengembalikan Not Logged In pada pemeriksaan ini. Pengelola perlu mengakses manual, memeriksa ketentuan serta menyediakan aset Instagram dan bukti sumber WhatsApp. Tidak mengklaim aset existing telah disetujui merek.
- Versi manifest 1.1.0+2 bukan bukti metadata runtime. Mekanisme pembacaan versi belum tersedia; UI menyatakan belum tersedia. Riwayat distribusi/build number, naskah ketentuan pengelola/dinas, kamera/izin/lifecycle Android serta penerimaan visual 320px/2x/light-dark masih gate rilis terbuka.
- Audit forum tidak menambah fitur: kontrak create/delete komentar dan like posting tersedia, tetapi edit/like komentar serta parent/replies belum didokumentasikan. Lanjut hanya setelah konfirmasi kontrak Laravel pada task terpisah.

## Branding resource Android — hasil aktual 20 Oktober 2026

Bagian ini menggantikan status penundaan native pada riwayat 19 Oktober. Pengecualian branding pada instruksi workspace cocok dengan AGENTS.MD aktual. Implementasi resource dan build debug berhasil; penerimaan visual emulator tetap belum dilakukan.

- Konfigurasi C:/laragon/www/aquara_mobile/pubspec.yaml memakai assets/images/branding/samudera_logo.png untuk image_path dan adaptive_icon_foreground, background #FFFFFF, inset 0. Android true, iOS false, tidak ada konfigurasi generator web/Windows/macOS. Padding transparan asli dipertahankan; tidak crop/recolor PNG sumber 500x500. Alpha bounds sumber x=166..333, y=114..295; radius maksimum terhadap pusat canvas 145px, masih di dalam safe circle adaptive 33/108 dari sisi canvas.
- Generator flutter_launcher_icons 0.14.4 existing dieksekusi melalui Dart SDK/package_config existing di C:/Users/Fajar/AppData/Local/Temp/samudera-native-20261020/generator-stage/. Alasannya: implementasi generator menulis manifest meskipun nama ikon tidak diganti. Staging hanya berisi salinan pubspec, PNG dan manifest; hanya hasil res Android disalin ke workspace. Generator exit 0; pesan generik "No platform provided" muncul setelah langkah Android, tetapi hasil resource Android terbentuk dan diuji. Tidak menginstal dependency.
- C:/laragon/www/aquara_mobile/android/app/src/main/res/: mipmap launcher 48/72/96/144/192px, adaptive foreground 108/162/216/324/432px; XML adaptive inset 0%. colors.xml tetap bernilai putih seperti resource awal (berbeda dengan konfigurasi lama #009FE3).
- Splash PNG diturunkan dari seluruh canvas sumber dengan System.Drawing HighQualityBicubic tanpa crop/recolor, berukuran 288/432/576/864/1152px untuk mdpi sampai xxxhdpi (288dp). drawable dan drawable-v21/launch_background.xml memakai bitmap center pada putih. values-v31 dan values-night-v31/styles.xml mengatur windowSplashScreenBackground dan windowSplashScreenAnimatedIcon ke PNG khusus splash. NormalTheme dan splash Flutter tidak diubah; tidak menambah timer/animasi/library/native code.
- Acuan mekanisme: dokumentasi resmi Flutter platform-integration/android/splash-screen dan Android Developers develop/ui/views/launch/splash-screen. Android 12+ memakai atribut splash platform; ikon tanpa background berukuran 288dp dengan konten di lingkaran diameter 192dp. Test memeriksa safe circle tersebut pada seluruh density; ini bukan bukti tampilan emulator.
- Test baru C:/laragon/www/aquara_mobile/test/android_branding_test.dart: konfigurasi, referensi XML legacy/v31 light-dark, ukuran/alpha/warna biru-emas dan setiap piksel visible dalam safe circle untuk 15 PNG. XML resource juga diparse lewat PowerShell (exit 0). Sampel PNG launcher dan splash diperiksa visual lokal; posisi/padding canvas asli tidak dinormalisasi.
- Hasil aktual: 40 test terarah lulus exit 0; 550 suite penuh lulus exit 0. Analyzer baseline/final 43 (2 warning/41 info), exit 1; diagnostic sama termasuk posisi. Format check file test baru 0 berubah exit 0, diff check exit 0. Hash sumber dan file existing di lib/test/assets/platform lain, manifest, Gradle pengguna, AGENTS.MD dan lockfile tetap sama dengan awal tugas.
- Build debug lokal: `flutter build apk --debug --no-pub --dart-define=SAMUDERA_API_URL=https://api-dev.aquara.app/api`, exit 0; assembleDebug 435.6s. Artefak C:/laragon/www/aquara_mobile/build/app/outputs/flutter-apk/app-debug.apk (204186606 byte). Ini bukti kompilasi resource, bukan pengujian API/runtime. Log, exit code, baseline hashes dan perbandingan diagnostic: C:/Users/Fajar/AppData/Local/Temp/samudera-native-20261020/.

### Gate visual yang masih terbuka

- Launcher dari instalasi aplikasi yang sama: mask lingkaran/squircle dan ukuran optik logo dengan padding asli. Tidak membuat aplikasi kedua atau menghapus data/sesi untuk mengatasi cache ikon.
- Cold start dari launcher Android 12+ light/dark: logo tidak terpotong, background putih, transisi splash sistem ke splash Flutter tanpa logo lama; bandingkan Android sebelum 12. Tidak mengklaim cold-start diverifikasi hanya dari test XML.
- Nama launcher masih **AQUARA** pada android:label manifest. Manifest tidak diubah karena di luar pengecualian. Rename label memerlukan izin eksplisit terpisah; ini bukan rebranding identitas native menyeluruh.
- Tidak menjalankan emulator/aplikasi, request API nyata, membuka secret, release/CI, commit, push atau deploy. Foto, tema Flutter, header, grid, autentikasi dan fitur tidak disentuh.

## Kelanjutan teks brand — hasil aktual 19 Oktober 2026

- Teks AQUARA pada splash Flutter, judul/nama/deskripsi Tentang dan deskripsi Konsultasi AI onboarding kini SAMUDERA. Status teks legacy pada catatan sebelumnya bersifat historis. Nama kelas/package/import tidak diganti. Logo baru dan seluruh desain sebelumnya dipertahankan.
- Splash diberi SingleChildScrollView dan teks nama rata tengah: mengganti nama yang lebih panjang memicu overflow 2px pada 320px/teks 2×; perbaikan tidak mematikan assertion atau mengubah timer/handler sesi. Test logo splash/Tentang light-dark tetap lulus; test paging onboarding memeriksa teks SAMUDERA dan tidak ada AQUARA pada halaman tersebut.
- Test aktual: 42 terarah dan 543 suite penuh lulus exit 0. Analyzer 43→43, 2 warning/41 info, exit 1 tanpa error; normalized diagnostic sama. Format empat Dart 0 berubah exit 0; diff check exit 0. Log C:/Users/Fajar/AppData/Local/Temp/samudera-brand-text-20261019/.
- Native belum diimplementasikan karena instruksi proyek sesi melarang perubahan android/ kecuali permissions. Generator flutter_launcher_icons ^0.14.4 masih memakai assets/logo2.png untuk image_path/adaptive_icon_foreground. Manifest memakai @mipmap/ic_launcher, LaunchTheme dan NormalTheme; XML resource valid secara sintaks. Ini bukan verifikasi hasil visual atau perilaku Android 12+. Build debug tidak dijalankan; konfigurasi API tidak diubah.
- Selanjutnya, setelah batas instruksi native diselaraskan: regenerasi resource dari PNG SAMUDERA, build debug, cek mask launcher/adaptive safe zone, cold start/system splash Android 12+ light-dark pada emulator. Tidak menghapus sesi/data atau menjalankan aplikasi kedua. iOS/web/Windows tidak diubah; tidak mengklaim branding lintas platform selesai.

## Logo in-app — hasil aktual 19 Oktober 2026

Catatan ini menggantikan penundaan logo in-app di riwayat berikutnya. Native tetap audit saja sesuai keputusan pengguna setelah konflik aturan AGENTS.MD dikonfirmasi.

- Sumber C:/Users/Fajar/Downloads/SAMUDERA_UI_Konsisten/input-assets/samudera_logo.png: PNG sebenarnya 500×500, transparan, simbol ikan/gelombang tanpa wordmark. Decode lokal/Flutter berhasil. Target C:/laragon/www/aquara_mobile/assets/images/branding/samudera_logo.png identik SHA-256 dengan sumber, tanpa crop/recolor/konversi.
- Referensi bersama C:/laragon/www/aquara_mobile/lib/widgets/samudera_branding.dart dipakai pada Beranda 72×72, login tinggi 120, splash Flutter tinggi 180, Tentang 200×200 tanpa clip; semua BoxFit.contain. Register/reset tidak memiliki logo existing, tidak ditambahkan. Onboarding memakai ilustrasi layanan.
- Empat ilustrasi onboarding dan empat banner carousel diperiksa visual, tidak ditemukan logo AQUARA menyatu. Branding pihak ketiga dipertahankan. Teks legacy AQUARA di splash/Tentang/onboarding tidak diganti global; ini bukan rename aplikasi menyeluruh.
- Native Android masih logo lama; generator tetap menunjuk assets/logo2.png. XML launcher/splash/themes berhasil diparse. launch_background drawable/v21 tidak memiliki bitmap aktif. Tidak menjalankan generator/build native/aplikasi. iOS AppIcon 1024 dan web Icon-192 yang diperiksa masih Flutter default; Windows tidak diproses/diverifikasi visual.
- Lima test baru: decode/alpha, splash dan Tentang pada 320px/teks 2× light-dark. Terarah bersama Beranda/auth/SOS: 57 lulus exit 0. Suite penuh final satu kali: 542 lulus exit 0. Pembesaran login awal menggeser tombol test; dikembalikan ke tinggi existing tanpa menghapus assertion.
- Analyzer baseline/final 43 (2 warning/41 info), exit 1 tanpa error; isi sama setelah normalisasi posisi. Format enam Dart 0 berubah pada pemeriksaan akhir; diff check exit 0. Log C:/Users/Fajar/AppData/Local/Temp/samudera-logo-20261019/.
- Hash lib/test awal: hanya empat layar logo existing berubah. Signing C:/laragon/www/aquara_mobile/android/app/build.gradle.kts dan pubspec.lock identik awal. Service/model/sesi/foto/tema/grid/dependency/native tidak diubah; tanpa API nyata/commit/push/deploy.
- Emulator belum dijalankan: ukuran optik logo (padding transparan sumber besar), keterbacaan foto/light-dark, login keyboard/teks besar, splash cold start dan Tentang. Launcher/system splash tetap tertunda sampai aturan native selaras; hot reload tidak membuktikan branding native.

## Penyelarasan visual 19 Oktober 2026 (menggantikan aturan visual lama di bawah)

- Header Beranda memakai foto lokal penuh lebar, BoxFit.cover/centerRight, minimum tinggi adaptif 240–320; tinggi mengikuti isi saat teks besar. Identitas dan handler notifikasi/profil tetap, pencarian lokal di bawah identitas dalam foto. Banner carousel terpisah tetap.
- Sumber foto: C:/Users/Fajar/Downloads/SAMUDERA_UI_Konsisten/input-assets/samudera_hero.jpg; target C:/laragon/www/aquara_mobile/assets/images/home/samudera_hero.jpg. JPEG RGB 600×399, disalin tanpa konversi. Resolusi ini perlu ditinjau di perangkat besar.
- Sumber tema bersama: C:/laragon/www/aquara_mobile/lib/widgets/samudera_theme.dart. Aksen biru #009FE3, hijau #8CC63F, oranye #F7941D; netral/transparansi dan warna asli aset tetap diperbolehkan. Error tetap error, menggunakan oranye; tidak mengubah status/handler.
- AppBar tema: biru, judul Poppins 20 tebal putih, ikon putih, rata kiri/elevation 0. Berlaku untuk AppBar yang mewarisi tema, termasuk Info KKP/Cuaca/TPI, pre-order, SOS, katalog layanan, OTP/kontak. Override Info Eksternal diperbaiki menjadi putih; Tambah Jualan menjadi biru; Detail Berita 20. Header existing lain mempertahankan struktur/action/back.
- Wadah ikon grid utama/sekunder/katalog 64×64, padding 8, radius 16, putih; label di luar bidang putih, kartu luar transparan. Tinggi label/cell masih mengikuti isi; keseragaman tinggi seluruh cell belum dijamin.
- Logo DITUNDA atas pilihan pengguna: PNG yang diminta belum tersedia. JPEG 2048×2048 yang ditemukan bukan PNG transparan; pengguna memilih menyediakan PNG kemudian. Logo lama in-app tetap aktif. Tidak ada klaim rebranding lengkap.
- Native DITUNDA atas pilihan pengguna. Android launcher masih simbol ikan lama; adaptive icon inset 16%, generator existing menunjuk assets/logo2.png. launch_background yang diperiksa hanya putih tanpa gambar aktif; splash Android modern perlu perangkat. iOS/web/Windows resources ada tetapi tidak diproses atau dinyatakan selesai.
- Validasi: 129 test terarah + 3 test baru lulus; suite penuh final 537 lulus exit 0. Analyzer baseline/final 43 (2 warning/41 info), exit 1, isi diagnostic sama setelah lokasi dinormalisasi. Format final 37 file, 0 berubah; diff check exit 0. Beberapa layar yang tidak membutuhkan perubahan visual ikut mengalami format-only.
- Log aktual di C:/Users/Fajar/AppData/Local/Temp/: samudera-visual-targeted-final.txt, samudera-visual-new-tests.txt, samudera-visual-full.txt, samudera-visual-analyze-before.txt, samudera-visual-analyze-verified.txt. Dua kegagalan kompilasi penggantian warna diperbaiki setelah pengguna menyetujui kelanjutan debugging; tidak menghapus assertion.
- Batas validasi: belum menguji setiap header panjang pada 320px/2×; belum memastikan seluruh override surface/light-dark dan foreground snackbar langsung memenuhi keterbacaan. Tidak mengklaim audit kontras atau seluruh detail visual selesai. Emulator, status bar, crop foto, keyboard nyata, TalkBack, dan review semua layar tetap diperlukan.
- Tidak mengakses API nyata, mengubah service/model/session/native/signing/dependency, commit/push/deploy. Catatan HTTP pengguna sebelumnya bukan hasil pengujian tugas ini atau penerimaan dinas.

Keputusan pengguna 18 Oktober 2026: ilustrasi 2D Flat berwarna menggantikan acuan 3D. Dokumen ini mengatur presentasi, bukan kontrak API atau tanda kesiapan rilis.

## Susunan dan interaksi

1. Logo existing `C:/laragon/www/aquara_mobile/assets/logo2.png`, SAMUDERA, sapaan metadata/guest, Kabupaten Indramayu, notifikasi/login existing. Tidak ada jumlah notifikasi buatan.
2. Hero biru dengan ilustrasi ikan lokal; bukan data cuaca/GPS atau klaim bisnis.
3. Cari layanan SAMUDERA membuka katalog yang sama dengan Lihat semua dan Semua Layanan. Field di katalog menyaring nama layanan secara lokal, case-insensitive dan trim; tanpa request pencarian.
4. Empat layanan utama: Analisa Usaha, Pasar Ikan, Katalog Ikan, Forum Komunitas.
5. Layanan untukmu: Info KKP, Cuaca, Daftar TPI, Pesanan Grosir, Analisis Foto, Forum Saya, Berita, Semua Layanan. Tiga Info berbadge Simulasi.
6. SOS Bahari dekat layanan, hanya membuka formulir existing. Tidak mengirim laporan otomatis.
7. Empat banner existing beserta tujuan analisa/Pasar/forum/konsultasi; kontrol sebelumnya/berikutnya/jeda. Auto-slide tetap ada, tidak berjalan saat reduced motion, route tertutup, atau pencarian berfokus.
8. Berita/wawasan memakai tujuan berita existing; Analisa Komoditas mempertahankan fetch, retry, data, dan parameter kalkulator existing. Tidak membuat berita contoh.
9. Navigasi bawah tetap Beranda, Berita, Pasar, Profil. Slot Asisten setelah banner dicadangkan dalam kode, tanpa tombol aktif.

Katalog memuat 16 tujuan: empat utama, tujuh sekunder, Info Dinas, Harga Pasar, Konsultasi, Semua Komoditas, SOS Bahari. Pesanan Grosir membuka `PreOrderView.history`; riwayat di AppBar Pasar tetap dapat diakses ketika data Pasar kosong. Analisis Foto membuka AiFishoScreen existing; pusat Konsultasi lama tetap tersedia.

## Pola pengembangan

- Registry presentasi di `C:/laragon/www/aquara_mobile/lib/screens/home_screen.dart`, model/grid/katalog di `C:/laragon/www/aquara_mobile/lib/widgets/home_services.dart`: id stabil, label, asset, kelompok, order, badge, metadata akses dan callback. Tambahkan fitur melalui registry, bukan ListTile sebelum header.
- `requiresSession` hanya metadata presentasi, bukan otorisasi. SessionBoundary pada tujuan existing tetap otoritas guard client; backend tetap otoritas akses data. ApiService yang diinjeksi diteruskan ke tujuan yang mendukungnya.
- Navigator/MaterialPageRoute, SessionOwnedState, expectedSession, listener metadata, timer/dispose dan fetch referensi existing dipertahankan. Guard in-flight menolak callback navigasi ganda. Tidak memindahkan fetch tiap layanan ke Beranda.
- Tidak mengubah transport, token store, autentikasi, OTP, rumus kalkulator, pre-order, parser/service/cooldown Info atau dependency.

## Warna, layout, aksesibilitas

- Hero `#009FE3`, foreground gelap `#002C42`; tema existing tetap memiliki aksen `#8CC63F`, Poppins, light/dark. Surface mengikuti tema. PNG multicolor tanpa tint, BoxFit.contain, dekoratif dikeluarkan dari semantics.
- Bukti teal: pintasan Konsultasi lama memakai `Colors.teal` pada home_screen.dart. `C:/laragon/www/aquara_mobile/lib/main.dart` sudah memakai seed biru; tidak ada bukti seluruh warna menyimpang berasal dari tema global. Tema global dan layout auth tidak diubah.
- Margin 16 pada layar sempit, 20 pada layar lebih lebar; gap section 24; kartu 16–22; bidang ikon utama 64, sekunder 56. Grid empat kolom pada ruang memadai, dua pada layar sempit, satu/dua pada teks besar; tinggi mengikuti isi, tanpa ellipsis label layanan.
- AppBar tiga Info memakai biru/foreground gelap yang sama. Peringatan permanen lengkap, metadata cache/UTC, loading/error/data lama serta cooldown bersama tetap tidak diubah.

## Aset dan kredit

Sepuluh PNG pengguna disalin tanpa perubahan byte ke `C:/laragon/www/aquara_mobile/assets/icons/services/`. Semua signature PNG valid, berhasil didekode 512×512, memiliki alpha transparan, serta diperiksa visual melalui contact sheet lokal. Forum memiliki area transparan jauh lebih sedikit daripada ikon lain; file pengguna tidak dimodifikasi.

| Pembuat menurut manifest pengguna | File |
| --- | --- |
| AB Design | analisa_usaha.png, informasi.png, pesanan.png |
| Magnific | pasar.png |
| Smashicons | forum.png, cuaca.png, tpi.png, analisis_foto.png |
| smalllikeart | katalog_ikan.png, sos.png |

Sumber per ikon dan catatan atribusi disalin ke `C:/laragon/www/aquara_mobile/docs/beranda-2d/icon_manifest.json` dan `C:/laragon/www/aquara_mobile/docs/beranda-2d/IKON_DAN_ATRIBUSI.md`. Status unduhan di manifest merupakan catatan paket asal, bukan hasil verifikasi aset lokal. Kredit tampil melalui Profil dan bagian bawah Beranda, dengan tautan sumber setiap ikon menggunakan url_launcher existing. Tidak ada hotlink gambar runtime.

Folder sumber `C:/Users/Fajar/Downloads/SAMUDERA_Beranda_2D_Panduan/license-evidence` hanya berisi README, tidak ada sertifikat unduhan yang dapat disalin. Nama pembuat/ketentuan mengikuti manifest yang diberikan, tidak diverifikasi ulang lewat situs dalam tugas ini. Jangan menyatakan aset MIT/karya tim. Sebelum source repository dipublikasikan, tinjau ketentuan distribusi file mentah dan simpan bukti unduhan penyedia; implementasi ini bukan izin redistribusi paket ikon. Tidak mengubah konfigurasi/visibilitas Git.

## Hasil aktual pemeriksaan lokal

- 24 test baru: decoding/alpha sepuluh aset, registry seluruh tujuan dan guard callback ganda, guest/login, pencarian lokal/empty, 320px teks 2× light/dark, keyboard inset 280, scroll/SafeArea, notifikasi/login, katalog yang sama dan riwayat saat Pasar kosong.
- Test tujuan registry memeriksa widget route dan parameter, bukan integrasi backend; regresi layar/guard diuji suite existing dengan fake.
- Terarah enam berkas: **172 lulus, exit 0**. Regresi awal tiga berkas: **81 lulus, exit 0**.
- Suite penuh setelah perbaikan terakhir: **534 lulus, exit 0**. Suite sebelumnya juga 534 lulus; validasi diulang karena dua lint blok if kemudian diperbaiki. Baseline 510 dari Tahap 6 adalah hasil historis.
- Analyzer baseline **68 (2 warning/66 info)** menjadi **43 (2 warning/41 info)**, keduanya exit 1, tanpa error. Perbandingan isi normalized: tidak ada diagnostic baru; 25 deprecated withOpacity pada Beranda lama hilang. Empat diagnostic Profil bergeser +15 baris (370→385, 400→415, 564→579, 578→593); isinya sama. Dua warning existing di Pengaturan tetap.
- Delapan file Dart diformat, pemeriksaan akhir 0 berubah. Git diff --check exit 0. Pemeriksaan whitespace file baru dilakukan terpisah.
- Hash seluruh file existing lib/test/native yang dicatat hanya berubah pada tiga file aplikasi dan dua test terkait; kalkulator/auth/Pasar/service/native tetap identik. Pubspec hanya menambahkan daftar asset; pubspec.lock tidak memiliki diff.
- Log dan exit aktual: `C:/Users/Fajar/AppData/Local/Temp/samudera-beranda-20261018/`, terutama targeted-final-2.txt, full-verified.txt, analyze-verified.txt, diagnostic-comparison.json dan changed-existing.json.
- Percobaan awal decoder dalam fake async dihentikan karena menggantung; diperbaiki memakai runAsync. Finder Tooltip dan sisa baris patch diperbaiki tanpa melewati assertion. Kelanjutan debugging setelah tiga kegagalan disetujui pengguna.

## Belum dilakukan: emulator/UAT

- Tinjau visual PNG, terutama background forum, logo, banner crop, Poppins aktual dan warna pada emulator/perangkat light/dark.
- Uji 320px, layar umum/tablet/landscape, font 2×, keyboard nyata, gesture navigation/status bar, TalkBack, target sentuh dan fokus; pengujian widget bukan audit aksesibilitas perangkat lengkap.
- Periksa semua layanan, login/logout/pergantian akun dan Back, notifikasi, Pasar kosong/riwayat, SOS tanpa pengiriman otomatis; kontrol dan jeda banner termasuk reduced motion.
- Buka tautan atribusi di browser perangkat dan lengkapi bukti unduhan bila tersedia.
- Backend nyata, layanan resmi, Google/OTP WhatsApp, Asisten, parameter dinas dan deployment tetap tugas terpisah. Tidak menjalankan aplikasi kedua, mengakses API produksi, commit, push, atau deploy.
