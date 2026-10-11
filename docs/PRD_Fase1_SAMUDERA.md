# PRD — Fase 1: Pembaruan Mandat Dinas & Killer Features
**Produk:** SAMUDERA (rebranding dari AQUARA)
**Modul:** Backend Laravel 12 + Web Admin Filament v3
**Target Infra:** Heroku (Heroku Postgres + Cloudinary)
**Status:** Disetujui untuk eksekusi
**Versi Dokumen:** 1.0

---

## 1. Latar Belakang & Problem Statement

AQUARA saat ini adalah aplikasi budidaya perikanan untuk pembudidaya tambak individual (fokus: jenis ikan, stok pengepul, forum komunitas, pasar jual-ikan, konsultasi AI penyakit ikan). Dinas Kelautan & Perikanan mengambil mandat baru untuk menjadikan platform ini **kanal resmi pengawasan dan pemberdayaan sektor kelautan-perikanan daerah**, bukan sekadar aplikasi komunitas.

**Masalah yang harus diselesaikan di Fase 1:**

1. **Identitas produk tidak sesuai mandat resmi** — nama "AQUARA" tersebar di kode, UI, notifikasi, dan komunikasi (push notification, judul), sementara mandat dinas menetapkan nama resmi **SAMUDERA**.
2. **Katalog jual-ikan (`Pasar`) tidak merepresentasikan realitas niaga** — tidak ada informasi stok, kategori komoditas (tawar/laut/olahan), maupun apakah barang dijual eceran atau grosir. Ini menyulitkan pembeli B2B dan analitik dinas.
3. **Tidak ada kanal darurat resmi** — laporan wabah penyakit ikan atau pencemaran limbah saat ini hanya bisa dibahas informal di Forum, tanpa status penanganan, tanpa PIC admin, dan tanpa bukti foto yang tersimpan permanen (risiko hilang karena Heroku ephemeral filesystem).
4. **Tidak ada mekanisme transaksi tonase besar (B2B)** — `Pasar` hanya cocok untuk transaksi retail kecil, sedangkan kebutuhan riil adalah negosiasi pre-order skala tonase antar pembudidaya/pengepul dan pembeli besar (restoran, eksportir, koperasi).
5. **Data eksternal krusial (KKP, BMKG, lokasi TPI) belum terhubung** — pembudidaya masih harus mencari informasi ini secara manual di luar aplikasi, padahal keputusan operasional (tebar benih, melaut, distribusi) sangat bergantung pada data ini.
6. **Tidak ada kanal bantuan cepat (helpdesk)** — pertanyaan seputar bantuan teknis/administratif dinas belum punya jalur otomatis, semua manual lewat WA/telepon.
7. **Risiko kehilangan data file (foto)** — Heroku menggunakan ephemeral filesystem; upload foto yang masih memakai `Storage::disk('public')` (di `Pasar`, `Forum/CommunityPost`) akan **hilang setiap dyno restart/deploy**. Ini bug produksi kritis yang harus diperbaiki total di Fase 1.

## 2. Target User

| Persona | Deskripsi | Kebutuhan Utama di Fase 1 |
|---|---|---|
| **Pembudidaya/Petambak** (`User` role default) | Pengguna mobile Flutter, pemilik tambak ikan tawar/laut/olahan | Jual komoditas dengan info stok jelas, ikut pre-order grosir, lapor darurat wabah/limbah, lihat cuaca & lokasi TPI, tanya cepat ke Asisten SAMUDERA |
| **Pembeli B2B/Pengepul** | Pembeli skala tonase (restoran, eksportir, koperasi) | Melihat katalog dengan tipe grosir & stok akurat, mengajukan pre-order tonase |
| **Admin Dinas** (Filament panel, role `admin`/Shield) | Petugas Dinas Kelautan & Perikanan | Mengelola & memantau semua data: katalog, laporan SOS, pre-order, memonitor dashboard info eksternal |
| **Tim Mobile (Flutter)** | Konsumen API internal | Kontrak API stabil (walau data eksternal masih mock) agar development UI tidak terblokir |

## 3. User Stories

### Rebranding
- **US-1.1** Sebagai pengguna aplikasi, saya melihat nama "SAMUDERA" secara konsisten di seluruh judul halaman, email/notifikasi, dan panel admin — bukan lagi "AQUARA".

### Katalog Produk (tabel `pasars`)
- **US-2.1** Sebagai pembudidaya, saya bisa mengisi jumlah **stok** saat menjual komoditas agar pembeli tahu ketersediaan riil.
- **US-2.2** Sebagai pembudidaya, saya bisa memilih **kategori** komoditas (`tawar`, `laut`, `olahan`) agar produk mudah ditemukan/difilter.
- **US-2.3** Sebagai pembudidaya, saya bisa menandai **tipe_penjualan** (`eceran` atau `grosir`) supaya pembeli tahu skema transaksi yang berlaku.
- **US-2.4** Sebagai Admin Dinas, saya bisa memfilter & memantau katalog di Filament berdasarkan kategori dan tipe penjualan.

### Forum Saya
- **US-3.1** Sebagai pengguna login, saya bisa melihat daftar diskusi forum yang **saya buat sendiri** (bukan bisa dipalsukan lewat query param bebas).
- **US-3.2** Sebagai pengguna, saya hanya bisa update/hapus forum yang saya buat sendiri (bukan milik user lain), diverifikasi dari token Sanctum, bukan `user_id` yang dikirim manual dari body request.

### Lapor Darurat (SOS Bahari)
- **US-4.1** Sebagai pembudidaya, saya bisa melaporkan kejadian darurat (wabah penyakit, pencemaran limbah, cuaca ekstrem) lengkap dengan deskripsi dan foto bukti.
- **US-4.2** Sebagai pembudidaya, foto yang saya unggah harus tetap dapat diakses admin meski aplikasi di-deploy ulang (tersimpan di Cloudinary, bukan disk lokal Heroku).
- **US-4.3** Sebagai Admin Dinas, saya menerima & mengelola laporan SOS di Filament, mengubah status (`Pending` → `Diproses` → `Selesai`), dan mencatat siapa admin yang menangani.
- **US-4.4** Sebagai pembudidaya, saya bisa cek status laporan saya sendiri via API.

### Bursa Grosir (Pre-Order)
- **US-5.1** Sebagai pembeli B2B, saya bisa mengajukan pre-order dengan jumlah tonase dan tanggal pengambilan ke komoditas grosir tertentu di katalog.
- **US-5.2** Sebagai Admin Dinas, saya bisa memantau seluruh transaksi pre-order dan status pembayarannya (`Belum Bayar`, `DP`, `Lunas`) di Filament.
- **US-5.3** Sebagai pembudidaya penjual, saya bisa melihat daftar pre-order yang masuk ke komoditas saya.

### Integrasi Eksternal
- **US-6.1** Sebagai pembudidaya, saya bisa melihat info resmi dari KKP di dashboard/aplikasi.
- **US-6.2** Sebagai pembudidaya, saya bisa melihat info cuaca BMKG sebelum memutuskan aktivitas melaut/tebar benih.
- **US-6.3** Sebagai pembudidaya, saya bisa melihat lokasi TPI (Tempat Pelelangan Ikan) terdekat di peta.
- **US-6.4** Sebagai Admin Dinas, saya melihat widget ringkasan ketiga info ini langsung di dashboard Filament tanpa perlu buka aplikasi lain.

### Asisten SAMUDERA (Chatbot)
- **US-7.1** Sebagai pengguna, saya bisa mengirim pertanyaan teks ke Asisten SAMUDERA dan mendapat balasan (dasar/mock di Fase 1) agar UI chat Flutter bisa langsung dikembangkan.

---

## 4. Daftar Fitur

### MVP (Fase 1 — wajib selesai)

| # | Fitur | Scope MVP |
|---|---|---|
| 1 | Rebranding AQUARA → SAMUDERA | Ganti semua string "AQUARA" di: judul Filament panel (`brandName`), teks notifikasi (`Notification::create`, Firebase push di `ForumController`, `PasarController`), `config/app.php` name, `.env.example`, README, teks statis lain yang eksplisit menyebut "AQUARA". **Tidak mengubah** nama tabel/kolom/namespace kode (agar tidak breaking, sesuai aturan "jangan hapus fitur lama"). |
| 2 | Katalog Produk (`pasars` + kolom baru) | Migration baru menambah `stok` (integer, default 0), `kategori` (string, check-constraint via Postgres-safe enum values: `tawar`/`laut`/`olahan`), `tipe_penjualan` (string: `eceran`/`grosir`, default `eceran`). Update `Pasar` model `$fillable`. Update `PasarResource` Filament (form + table columns + filter). Update `PasarController` API (`store`/`update` validasi & simpan field baru). |
| 3 | Forum Saya (hardening) | `ForumController::index` menerima parameter `mine=1` + wajib `auth:sanctum`, ambil `user_id` dari `$request->user()->id`, bukan dari query param. Endpoint update/delete/comment memverifikasi `ownership` (403 jika bukan pemilik). Route dipindah ke dalam grup `middleware('auth:sanctum')` untuk operasi tulis. |
| 4 | Lapor Darurat (SOS Bahari) | Tabel baru `lapor_darurats` (lihat data model). Model `LaporDarurat`. `LaporDaruratResource` Filament (list/status update/lihat foto). `LaporDaruratController` API (`store`, `index` utk riwayat user, `show`). Upload foto **wajib** ke `Storage::disk('cloudinary')`. |
| 5 | Bursa Grosir (Pre-Order) | Tabel baru `pre_orders`. Model `PreOrder` (relasi `belongsTo` ke `User` & `Pasar`). `PreOrderResource` Filament (list, filter status_bayar, update status). `PreOrderController` API (`store`, `index` utk pembeli & penjual). |
| 6 | Integrasi Eksternal (mock) | Endpoint `GET /api/info/kkp`, `GET /api/info/cuaca`, `GET /api/info/tpi` mengembalikan **mock JSON statis terstruktur** (bentuk final field sudah representatif, siap diisi data real di v2). Widget Filament dashboard: `InfoKkpWidget`, `InfoCuacaWidget`, `PetaTpiWidget` menampilkan data mock yang sama. |
| 7 | Asisten SAMUDERA (chatbot dasar) | Endpoint `POST /api/asisten/chat` menerima `{message}`, mengembalikan balasan mock/rule-based sederhana (belum LLM real) + menyimpan log percakapan ke tabel `asisten_chats` agar histori tersedia dan siap diintegrasikan ke LLM di v2. |
| 8 | Migrasi Cloudinary total | Install `cloudinary-labs/cloudinary-laravel`, tambah disk `cloudinary` di `config/filesystems.php`, refactor `PasarController`, `ForumController` (`CommunityPost`), dan `PasarResource`/Filament `FileUpload` agar semua upload foto baru memakai disk `cloudinary`. Data foto lama yang sudah ada tetap dibiarkan (tidak wajib migrasi data historis di Fase 1, hanya alur upload baru). |

### v2 (Next Phase — di luar scope Fase 1, dicatat sebagai referensi)

| # | Fitur | Catatan |
|---|---|---|
| v2-1 | Integrasi API resmi KKP & BMKG real-time | Butuh API key/MoU resmi dari instansi terkait |
| v2-2 | Peta TPI interaktif (Google Maps/Leaflet + koordinat GPS TPI real) | Butuh data koordinat TPI resmi dari Dinas |
| v2-3 | Asisten SAMUDERA berbasis LLM (mis. Gemini, mengikuti pola `AiConsultation` yang sudah pakai AI) | Reuse pola existing `AiConsultationController` |
| v2-4 | Migrasi file lama existing (`pasar-fotos`, `forum_images` di disk `public`) ke Cloudinary | Job/command Artisan terpisah, dijalankan sekali |
| v2-5 | Notifikasi otomatis (push FCM) untuk perubahan status Lapor Darurat & Pre-Order | Reuse pola Firebase Messaging existing |
| v2-6 | Rating/review pada transaksi Pre-Order | — |
| v2-7 | Multi-foto (galeri) untuk Lapor Darurat & Katalog | Saat ini 1 foto per record |

---

## 5. Sketsa Data Model (Postgres-safe, Eloquent Standard)

> Semua migration baru wajib file baru (`php artisan make:migration`), tidak mengedit migration lama yang sudah di-migrate, memakai tipe kolom aman Postgres (`string`, `text`, `integer`, `decimal`, `date`, `foreignId`), **tanpa** `DB::raw()` khusus MySQL.

### 5.1 Update Tabel Existing `pasars`
Migration baru: `xxxx_add_katalog_fields_to_pasars_table.php`

```php
Schema::table('pasars', function (Blueprint $table) {
    $table->integer('stok')->default(0)->after('harga');
    $table->string('kategori')->default('tawar')->after('stok'); // tawar | laut | olahan
    $table->string('tipe_penjualan')->default('eceran')->after('kategori'); // eceran | grosir
});
```
- Validasi enum dilakukan di layer aplikasi (Laravel `Rule::in([...])` pada Controller & Filament `Select::options()`), **bukan** native Postgres ENUM type, agar tetap portable dan mudah di-ALTER di masa depan.

### 5.2 Tabel Baru `lapor_darurats`
```php
Schema::create('lapor_darurats', function (Blueprint $table) {
    $table->id();
    $table->foreignId('user_id')->constrained('users')->cascadeOnDelete();
    $table->string('jenis_sos'); // 'Wabah Penyakit' | 'Pencemaran Limbah' | 'Cuaca Ekstrem'
    $table->text('deskripsi');
    $table->string('foto')->nullable(); // URL Cloudinary
    $table->string('status_laporan')->default('Pending'); // Pending | Diproses | Selesai
    $table->foreignId('admin_id')->nullable()->constrained('users')->nullOnDelete();
    $table->timestamps();
});
```
Model `LaporDarurat`: relasi `user()` (BelongsTo `User`), `admin()` (BelongsTo `User`, foreign key `admin_id`).

### 5.3 Tabel Baru `pre_orders`
```php
Schema::create('pre_orders', function (Blueprint $table) {
    $table->id();
    $table->foreignId('user_id')->constrained('users')->cascadeOnDelete(); // pembeli
    $table->foreignId('pasar_id')->constrained('pasars')->cascadeOnDelete(); // komoditas grosir
    $table->decimal('total_tonase', 10, 2); // decimal agar Postgres-safe utk pecahan ton
    $table->date('tgl_pengambilan');
    $table->string('status_bayar')->default('Belum Bayar'); // Belum Bayar | DP | Lunas
    $table->timestamps();
});
```
Model `PreOrder`: relasi `user()` (pembeli), `pasar()` (BelongsTo `Pasar`, komoditas yang dipesan; penjual didapat via `pasar.user`).

> Catatan naming: memakai `pasar_id` (bukan `katalog_id` seperti draft awal) karena katalog produk difinalisasi memakai tabel `pasars`, sesuai keputusan klarifikasi.

### 5.4 Tabel Baru `asisten_chats` (log Chatbot)
```php
Schema::create('asisten_chats', function (Blueprint $table) {
    $table->id();
    $table->foreignId('user_id')->nullable()->constrained('users')->nullOnDelete();
    $table->text('pertanyaan');
    $table->text('jawaban');
    $table->timestamps();
});
```
Model `AsistenChat`: relasi `user()` (nullable, untuk mendukung sesi guest/anonim di v1 mobile).

### 5.5 Tidak Ada Perubahan Skema untuk
- `community_posts` / `community_comments` (Forum) — hanya perubahan **query/controller** (ownership check), tidak ada kolom baru.
- `stocks`, `fish_types`, `posts`, `ai_consultations`, `notifications`, `users` — tidak tersentuh di Fase 1.

---

## 6. Kontrak API Baru/Berubah (Ringkasan)

| Method | Endpoint | Auth | Keterangan |
|---|---|---|---|
| POST | `/api/pasars` | Sanctum (existing, tanpa ubah auth) | + field `stok`, `kategori`, `tipe_penjualan` |
| POST | `/api/pasars/{id}/update` | Sanctum | idem |
| GET | `/api/forum?mine=1` | **Wajib** `auth:sanctum` (baru) | Filter forum milik user login |
| POST/PUT/DELETE | `/api/forum/**` (tulis) | **Wajib** `auth:sanctum` (baru) | Ownership check 403 jika bukan pemilik |
| POST | `/api/lapor-darurat` | `auth:sanctum` | multipart, field `jenis_sos`, `deskripsi`, `foto` |
| GET | `/api/lapor-darurat` | `auth:sanctum` | Riwayat laporan milik user login |
| POST | `/api/pre-order` | `auth:sanctum` | `pasar_id`, `total_tonase`, `tgl_pengambilan` |
| GET | `/api/pre-order` | `auth:sanctum` | Daftar pre-order milik user (sebagai pembeli/penjual) |
| GET | `/api/info/kkp` | Public | Mock JSON |
| GET | `/api/info/cuaca` | Public | Mock JSON |
| GET | `/api/info/tpi` | Public | Mock JSON (list lokasi + lat/lng) |
| POST | `/api/asisten/chat` | Public/Sanctum optional | `{message}` → `{reply}`, log ke `asisten_chats` |

Semua response tetap mengikuti konvensi existing: `{"success": bool, "message": string, "data": ...}`.

---

## 7. Filament Admin — Perubahan/Resource Baru

| Resource/Widget | Jenis | Detail |
|---|---|---|
| `PasarResource` | Update | Tambah field form: `stok` (numeric), `kategori` (Select: tawar/laut/olahan), `tipe_penjualan` (Select: eceran/grosir). Tambah kolom tabel + filter `SelectFilter` utk kategori & tipe_penjualan. |
| `LaporDaruratResource` | Baru | List (foto sbg `ImageColumn`, badge warna per `status_laporan`), form edit status + assign `admin_id`, filter by `status_laporan`/`jenis_sos`. |
| `PreOrderResource` | Baru | List dgn relasi `pasar.nama_ikan`, `user.name`; filter `status_bayar`; kolom `total_tonase`, `tgl_pengambilan`. |
| `InfoKkpWidget` | Baru (Widget) | Menampilkan mock info KKP terbaru di dashboard. |
| `InfoCuacaWidget` | Baru (Widget) | Menampilkan mock ringkasan cuaca BMKG. |
| `PetaTpiWidget` | Baru (Widget) | Menampilkan daftar/list lokasi TPI mock (peta interaktif masuk v2). |
| Branding Filament | Update | `brandName()` di Panel Provider dari "AQUARA" → "SAMUDERA", ganti logo/favicon jika ada asset lama bernama AQUARA. |

---

## 8. Batasan & Asumsi (Constraints)

- Tidak boleh menghapus tabel/kolom/fitur lama (`stocks`, `fish_types`, `ai_consultations`, dst) — Fase 1 murni **tambah & update**.
- Semua migration baru harus file baru (`php artisan make:migration`), tidak edit migration yang sudah jalan.
- Tidak ada `DB::raw()` spesifik MySQL; semua query pakai Eloquent/Query Builder standar.
- Upload foto baru (SOS Bahari, dan refactor Pasar/Forum) wajib lewat `Storage::disk('cloudinary')`. Data foto lama di disk `public` tidak dimigrasi otomatis di Fase 1 (dicatat sebagai utang teknis v2).
- Integrasi KKP/BMKG/TPI/Chatbot di Fase 1 **mock data**, kontrak field harus final agar tim Flutter tidak perlu ubah model data saat data real dipasang di v2.
- Rebranding tidak mengganti nama tabel/model/namespace PHP (`App\Models\...`) untuk menghindari breaking change besar pada relasi & migration existing; hanya string tampilan/komunikasi.

---

## 9. Success Metrics

| Metrik | Target Fase 1 |
|---|---|
| Konsistensi rebranding | 0 kemunculan string "AQUARA" tersisa di UI Filament, notifikasi, dan file konfigurasi publik (`app.name`, judul panel) — diverifikasi via grep. |
| Kolom Katalog Produk terisi | 100% record baru `pasars` pasca-rilis memiliki `kategori` & `tipe_penjualan` terisi valid (bukan null/kosong). |
| Keamanan Forum Saya | 0 insiden user bisa mengedit/menghapus forum milik user lain (diverifikasi via automated test ownership). |
| Adopsi Lapor Darurat | Admin Dinas dapat memproses laporan SOS end-to-end (Pending→Selesai) dalam Filament tanpa kendala foto hilang pasca redeploy Heroku. |
| Persistensi file | 100% foto baru (SOS Bahari, Pasar, Forum) tetap dapat diakses setelah simulasi restart dyno/redeploy (foto tersimpan di Cloudinary, URL tetap valid). |
| Kesiapan API untuk Flutter | Seluruh endpoint baru (#6, #7) mengembalikan response terstruktur sesuai kontrak (§6) dan terdokumentasi, sehingga tim mobile dapat mulai development UI tanpa blocking. |
| Non-regresi | Seluruh fitur existing (Forum, Pasar, Stock, FishType, AiConsultation, Notifikasi/FCM) tetap berfungsi setelah perubahan (diverifikasi manual smoke test + `php artisan test`). |

---

## 10. Urutan Eksekusi Disarankan (untuk sesi Act selanjutnya)

1. Rebranding string (low risk, high visibility win).
2. Migration `pasars` (stok/kategori/tipe_penjualan) + update `PasarResource` & `PasarController`.
3. Install & konfigurasi `cloudinary-labs/cloudinary-laravel` (disk `cloudinary`), refactor upload `Pasar` & `Forum`.
4. Tabel + Model + Resource + Controller `LaporDarurat` (pakai disk cloudinary sejak awal).
5. Tabel + Model + Resource + Controller `PreOrder`.
6. Endpoint mock Integrasi Eksternal + Widget Filament.
7. Tabel + Model + Controller `AsistenChat` (chatbot dasar).
8. Regression check: jalankan `php artisan migrate`, smoke test seluruh endpoint existing & baru.





