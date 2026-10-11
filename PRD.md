# PRD - SAMUDERA (Sistem Aplikasi Manajemen Usaha, Data, dan Edukasi peRikanan & kelAutan)

**Version:** 3.0 (Update Mandat Dinas & Killer Features)
**Status:** 🟢 Active Development

## 1. Executive Summary
SAMUDERA adalah evolusi dari aplikasi AQUARA yang mencakup seluruh ekosistem Dinas Perikanan dan Kelautan Kab. Indramayu. Sistem ini dirancang untuk mengalahkan kompetitor (Wong Reang & Sintren Ayu) dengan menghadirkan fitur B2B, pelaporan darurat, integrasi API eksternal, dan Asisten AI. Deployment dilakukan di Heroku (PostgreSQL + Cloudinary).

## 2. Target Users
- **Petambak/Nelayan:** Butuh info harga pasar, cuaca laut BMKG, perizinan, dan navigasi pintar.
- **Admin Dinas:** Butuh laporan darurat (SOS Bahari) masuk ke dashboard secara real-time.

## 3. Fitur MVP (Fase 1 - Mandat Dinas & Killer Features)
1. **Rebranding:** Ubah semua teks dan logo AQUARA menjadi SAMUDERA.
2. **Katalog Produk:** Upgrade struktur data dengan penambahan `stok` dan filter `kategori` (tawar, laut, olahan).
3. **Info KKP:** Widget/tautan terintegrasi ke Instagram resmi KKP atau Web Diskanla di Beranda.
4. **Forum Saya:** Tab dan filter khusus di Halaman Profil untuk memanajemen forum buatan user sendiri.
5. **Lapor Darurat:** Form pelaporan spesifik (limbah, cuaca ekstrem, wabah) yang datanya masuk ke dashboard Diskanla.
6. **Bursa Grosir:** Fitur Pre-Order panen B2B untuk transaksi komoditas skala tonase di dalam Katalog.
7. **Info Cuaca:** Halaman/Widget penarik data API BMKG (angin, gelombang, pasang surut).
8. **Perizinan:** Pusat panduan akses pendaftaran E-KUSUKA (SIPI/SIKPI) & asuransi nelayan.
9. **Peta TPI:** Peta digital interaktif lokasi pelelangan dan harga ikan real-time.
10. **Asisten SAMUDERA:** Chatbot helpdesk (mengambang di pojok layar) untuk info birokrasi, smart router navigasi, dan info kilat.
11. **Infrastruktur Cloud:** Global Search Bar di Beranda & Integrasi Cloudinary untuk semua upload gambar (wajib untuk Heroku).
12. **Global Search (Omni-Search):** Sebuah search bar tunggal yang muncul di Navbar utama (Beranda, Pasar, Forum, dll). Saat pengguna mengetik, hasil pencarian dari *tiga sumber berbeda* (Produk Pasar, Judul Forum, dan Judul Artikel Bantuan) akan muncul secara bersamaan dalam satu dropdown/list.