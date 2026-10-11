# Skema Database SAMUDERA (Fase 1 Update)

Dokumen ini adalah referensi struktur tabel utama untuk proyek SAMUDERA. Gunakan Eloquent standar yang kompatibel dengan PostgreSQL.

## 1. Tabel Eksisting: `katalog_penambak` (Perlu Diupdate)
Tabel ini sudah ada. Anda HANYA perlu membuat file migration baru untuk menambahkan 3 kolom berikut:
- `stok` (integer, default 0)
- `kategori` (enum/string: 'tawar', 'laut', 'olahan')
- `tipe_penjualan` (enum/string: 'eceran', 'grosir')

## 2. Tabel Baru: `lapor_darurat` (SOS Bahari)
Tabel ini baru dibuat untuk menampung pelaporan dari User ke Admin Dinas.
- `id` (Primary Key)
- `user_id` (Foreign Key ke tabel users)
- `jenis_sos` (string: contoh 'Wabah Penyakit', 'Pencemaran Limbah', 'Cuaca Ekstrem')
- `deskripsi` (text)
- `foto` (string, menampung URL dari Cloudinary)
- `status_laporan` (string/enum: 'Pending', 'Diproses', 'Selesai', default 'Pending')
- `admin_id` (Foreign Key ke tabel users/admin, nullable, untuk melacak admin yang memproses)
- `timestamps`

## 3. Tabel Baru: `pre_order` (Bursa Grosir)
Tabel ini baru dibuat untuk mencatat transaksi B2B skala besar yang berelasi dengan katalog.
- `id` (Primary Key)
- `user_id` (Foreign Key ke tabel users - pembeli)
- `katalog_id` (Foreign Key ke tabel katalog_penambak)
- `total_tonase` (integer/decimal, jumlah pesanan grosir)
- `tgl_pengambilan` (date)
- `status_bayar` (string/enum: 'Belum Bayar', 'DP', 'Lunas', default 'Belum Bayar')
- `timestamps`

## 4. Tabel Eksisting: `forum` (Informasi Relasi)
Tabel ini sudah ada. Pastikan endpoint API atau query di Controller menggunakan `user_id` untuk memfilter fitur "Forum Saya" (forum yang dibuat oleh user yang sedang login).