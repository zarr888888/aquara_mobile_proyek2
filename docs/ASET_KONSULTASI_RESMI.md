# Aset konsultasi resmi — 21 Oktober 2026

Sumber adalah paket unduhan resmi yang diberikan pengguna di `C:/Users/Fajar/Downloads/SAMUDERA_Ikon_Resmi/`. Paket sumber tidak diubah. Hanya dua PNG disalin; tidak ada konversi ekstensi, redraw, crop atau recolor.

| Tujuan proyek | File sumber relatif terhadap folder paket |
| --- | --- |
| `C:/laragon/www/aquara_mobile/assets/icons/whatsapp_official.png` | `WhatsApp-Brand-Resource-Center/Brand Resource Center Page Downloads/01_Glyph/01_Digital RGB/02_PNG/Digital_Glyph_Green_RGB_2026.png` |
| `C:/laragon/www/aquara_mobile/assets/icons/instagram_official.png` | `IG_brand_asset_pack_2023/01 Static Glyph/01 Gradient Glyph/Instagram_Glyph_Gradient.png` |

## Rujukan sumber dan ketentuan

- WhatsApp: https://www.meta.com/id-id/brand/resources/whatsapp/whatsapp-brand/
- Instagram: https://www.meta.com/brand/resources/instagram/instagram-brand/
- Halaman resmi diperiksa: gunakan aset dari Brand Resource Center; jangan mengubah desain/warna WhatsApp, jangan menyiratkan endorsement/kemitraan Instagram atau membuat merek eksternal paling dominan. Nama merek tetap dieja asli. Pedoman dan ketentuan masing-masing pemilik merek tetap berlaku; ini bukan klaim lisensi open-source atau persetujuan khusus dari Meta.
- Paket lokal berisi AI/PNG/SVG/JPG dan metadata .DS_Store, tidak ditemukan PDF/TXT/Markdown pedoman. Tidak menghapus atau mengubah dokumen sumber. Rujukan pedoman adalah halaman resmi di atas, bukan dokumen lokal yang dikarang.

## Presentasi

Glyph hijau WhatsApp dan gradasi Instagram dipilih untuk tombol menuju layanan terkait, bukan logo aplikasi. `Image.asset` existing, `BoxFit.contain`, 30 logical pixels, tanpa color filter; padding 12 di setiap sisi tetap memberi ruang logo. Alas putih netral untuk kedua mode; wadah tetap 54x54. Decode dibatasi 120px untuk menghindari penggunaan bitmap master besar di memori, tanpa mengubah file sumber. Handler URL WhatsApp/Instagram existing tidak berubah. PNG WhatsApp lama tetap dipertahankan untuk pengguna existing lainnya, bukan diganti global.