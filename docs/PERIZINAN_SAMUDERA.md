# Perizinan SAMUDERA — panduan lokal PRD 8

Pemeriksaan editorial: **27 Oktober 2026**. Belum ditinjau/disetujui dinas.
Tanggal ini adalah snapshot katalog, bukan waktu render, tanggal publikasi,
atau bukti penerimaan dinas. Tidak ada scraping/fetch/polling di aplikasi.

## Sumber publik yang diperiksa

| URL | Isi/tujuan yang diperiksa dan batas penggunaan |
| --- | --- |
| https://jdih.kkp.go.id/Homedev/KamusHukum/2200 | Glosarium mendefinisikan KUSUKA sebagai identitas tunggal pelaku usaha/pendukung. Memuat beberapa rujukan peraturan; bukan formulir daftar atau keputusan hukum individual. |
| https://stelina.kkp.go.id/public/faq | Bagian registrasi KUSUKA menunjuk footer. Registrasi STELINA berbeda; syarat NIB/NPWP STELINA tidak disalin sebagai syarat KUSUKA. |
| https://portal-informasi.kkp.go.id/kusuka/dashboard/ | Tujuan tautan KUSUKA footer diperiksa: portal informasi dengan iframe dashboard, bukan formulir daftar terverifikasi. Tidak ditambahkan sebagai tombol pendaftaran. |
| https://perizinan.kkp.go.id/ | Portal layanan subsektor penangkapan/pengangkutan, navigasi layanan dan panduan. Tidak login, tracking permohonan, atau mengirim data. |
| https://perizinan.kkp.go.id/faq.php | Bagian SILAT/SIMKADA menampilkan panduan SIPI/SIKPI, OSS, baru/perpanjangan. Tidak menyimpulkan kewenangan hanya dari GT. FAQ memuat rumusan masa berlaku yang berbeda konteks; tidak menyalin durasi/biaya/syarat rinci. Dokumen unduhan dan alur pengajuan end-to-end tidak diuji. |
| https://www.bpjsketenagakerjaan.go.id/bukan-penerima-upah.html | Informasi program BPU dan kepesertaan; tidak menetapkan kategori semua nelayan atau menjanjikan manfaat/subsidi. |
| https://diskanla.indramayukab.go.id/sosialisasi-asuransi-nelayan/ | Berita sosialisasi/verifikasi/validasi BPJS nelayan Sukahaji, Patrol. Publikasi **10 Februari 2026**, bukan pembukaan bantuan/kuota atau kepesertaan otomatis. |
| https://diskanla.indramayukab.go.id/sample-page/kontak-kami/ | Halaman kontak dinas, termasuk alamat/telepon/call center di footer; menjadi akses pendampingan ketiga topik. Tidak menyalin nomor ke kanal konsultasi lama atau menjanjikan waktu respons. |

Selain berita tersebut, tanggal publikasi halaman tidak tercantum pada isi yang
diperiksa; tahun copyright/peraturan/berita sidebar tidak dipakai sebagai tanggal
publikasi. Pembacaan hanya halaman publik, tanpa login/formulir/pengajuan.

## Implementasi dan keamanan

### Penyederhanaan UI 27 Oktober 2026

Koreksi spacing terbatas berikutnya: Center shared scaffold menyebabkan ruang
atas besar ketika isi daftar lebih pendek daripada viewport. Halaman pilihan
secara eksplisit memakai Alignment.topCenter, padding 16 px; default alignment
detail dan seluruh konten/launcher/katalog tetap. Delapan test geometry pada
400×1200/320×640, teks 1×/2×, light/dark mengukur gap judul–AppBar tepat 16 px.
Test terarah 17 lulus exit 0; dua test integrasi Beranda gagal baik baseline maupun
final karena logo tidak termuat/overflow existing (rincian TODO), bukan klaim
seluruh file test hijau. Analyzer 38 → 38 tanpa delta isi. Suite penuh dan
emulator tidak dijalankan pada koreksi spacing ini.

Halaman awal kini “Pilih panduan yang dibutuhkan”: kartu KUSUKA, SIPI/SIKPI,
Perlindungan Nelayan, satu Bantuan Diskanla dan catatan pengajuan. Seluruh kartu
dapat diketuk; judul/tinggi mengikuti teks. Detail memakai satu
PerizinanDetailScreen menerima objek katalog existing, dengan ringkasan, kartu
langkah bernomor, Perlu diketahui, CTA resmi, bantuan dan ExpansionTile
“Sumber & pembaruan” tertutup awal. Sumber menampilkan nama/domain/tanggal
pemeriksaan; publikasi hanya jika tersedia, tanpa URL mentah. Semua sumber tetap
dapat dibuka. CTA utama: FAQ STELINA, portal KKP, dan informasi BPU; berita
sosialisasi hanya sumber pendukung. Status belum ditinjau dinas ada di bagian
sumber. Back mempertahankan posisi daftar, double-open dicegah.

Tidak ada perubahan pada C:/laragon/www/aquara_mobile/lib/models/perizinan_guide.dart:
fakta/URL/tanggal 27 Oktober 2026/allowlist tetap. Handler launch existing dibagi
melalui satu mixin untuk daftar/detail, bukan transport atau launcher paralel.
Screenshot pengguna menunjukkan masalah panjang halaman lama; bukan bukti UAT
layout baru. Emulator, TalkBack, browser/resume dan review dinas masih diperlukan.

Validasi UI aktual: baseline 71 test terarah, final 72 (exit 0); suite penuh
final sekali 766 lulus exit 0. Analyzer 38 → 38 diagnostic exit 1 tanpa delta
isi setelah normalisasi lokasi. Format lima Dart 0 berubah exit 0; diff check
bersih. Test menjaga assertion URL/konten/privasi, menguji primary CTA, sumber
expand-collapse, posisi Back, double-open, decode/alpha/kredit ikon dan 320px/2×
light-dark. Tidak membuka browser/API sungguhan.

- Katalog terstruktur: C:/laragon/www/aquara_mobile/lib/models/perizinan_guide.dart.
  Ringkasan, langkah, batas, nama sumber, URL, label aksi dan metadata terpisah dari widget.
- Layar publik: C:/laragon/www/aquara_mobile/lib/screens/perizinan_screen.dart.
  Tiga kartu pilihan menuju detail topik bersama, sumber dan kontak dinas.
- Registry existing C:/laragon/www/aquara_mobile/lib/widgets/home_services.dart
  dan callback C:/laragon/www/aquara_mobile/lib/screens/home_screen.dart:
  Semua Layanan → Nelayan & Kelautan → Perizinan; Cari Layanan menerima KUSUKA,
  SIPI, SIKPI, asuransi, BPJS. Satu tujuan melalui _openPage/MaterialPageRoute
  dan guard double-open existing, tanpa mengubah guard privat.
- url_launcher existing, externalApplication setelah tap, tanpa header/token,
  tanpa canLaunch/network check saat build. Allowlist URL **persis** katalog;
  skema selain HTTPS, userinfo, port eksplisit, query, fragment, path/host lain
  ditolak. Kebijakan ini membatasi URL awal aplikasi, bukan navigasi/redirect
  berikutnya di browser milik pengguna. Tidak ada token yang diserahkan.
- Guard in-flight lintas semua tombol; gagal/exception disanitasi, tidak logout
  atau retry otomatis; completion setelah dispose diabaikan.
- Tidak ada form, API SAMUDERA, data akun, storage, endpoint, dependency baru,
  WebView atau perubahan backend/native. KUSUKA ≠ SIPI/SIKPI ≠ perlindungan.

## UI dan penerimaan

AppBar tema existing #009FE3/Poppins/back. Card Material dan warna surface tema,
scroll SafeArea, lebar baca maksimum 760, tanpa tinggi teks tetap. Ikon Certificate
pengguna menggantikan ikon dokumen sementara; wadah 64×64/padding 8 tetap.
Lihat C:/laragon/www/aquara_mobile/docs/beranda-2d/ASET_PERIZINAN.md.

Implementasi lokal dan test otomatis bukan pemeriksaan emulator atau penerimaan
dinas. Sebelum rilis: tinjau redaksi/jalur KUSUKA/layanan terkini dengan dinas,
periksa ulang URL, review ikon khusus bila dibutuhkan, uji browser perangkat,
back/resume, TalkBack, light/dark dan teks besar. Membuka browser tidak membuktikan
pendaftaran, penerbitan izin/polis, atau kepesertaan berhasil.

PRD 7 Cuaca resmi, PRD 9 Peta TPI interaktif, smart router PRD 10, Omni-Search
PRD 12 dan kesiapan rilis tetap backlog terpisah. Info mock bukan layanan resmi.