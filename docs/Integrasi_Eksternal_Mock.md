# Integrasi Eksternal Mock — Fase 1

## Cakupan

GET `/api/info/kkp`, `/api/info/cuaca`, dan `/api/info/tpi` bersifat publik sesuai PRD.
Tidak ada chatbot, migration baru, API key, atau HTTP request ke penyedia eksternal.
Seluruh data adalah ilustrasi, bukan pengumuman resmi, prakiraan aktual, atau lokasi TPI terverifikasi.
Jangan gunakan data ini untuk keputusan keselamatan pelayaran.

## Kontrak respons

- `success`: boolean.
- `message`: peringatan data simulasi.
- `data.is_mock`: selalu `true` pada implementasi ini.
- `data.source`: `Simulasi SAMUDERA`.
- `data.generated_at`: waktu pembuatan payload cache (ISO 8601), bukan waktu observasi.
- `data.items`: daftar item.

Field item KKP: `id`, `judul`, `ringkasan`, `published_at` (nullable).
Field item cuaca: `id`, `wilayah`, `kondisi`, `suhu_c`, `kecepatan_angin_kmh`,
`tinggi_gelombang_m`, `valid_at` (nullable).
Field item TPI: `id`, `nama`, `alamat`, `lat`, `lng` (koordinat ilustrasi).
Tanggal publikasi/validitas bernilai null karena bukan informasi aktual.

## Pembatasan dan cache

- Kuota bersama 30 request per menit per IP untuk ketiga endpoint, termasuk cache hit.
- Request melebihi kuota menerima HTTP 429, `success: false`, `data: null`, dan header `Retry-After`.
- Mengganti endpoint atau query string tidak membuat kuota baru.
- Payload disimpan selama 300 detik melalui Laravel Cache dan dipakai bersama API/widget.
- Cache key hanya berasal dari tiga jenis yang diizinkan, bukan query string pengguna.
- Widget tidak memakai polling otomatis.

## Otorisasi widget

`InfoKkpWidget`, `InfoCuacaWidget`, dan `PetaTpiWidget` ditemukan otomatis oleh panel admin.
Hanya role `Admin Dinas` dan `super_admin` yang diizinkan.
Pemeriksaan dilakukan pada visibility, lifecycle boot Livewire, dan sebelum pembacaan data.
Komponen bawaan Filament menampilkan string dengan escaping, tanpa raw HTML.
Peta interaktif tidak termasuk Fase 1; TPI ditampilkan sebagai daftar informasi.

## Deployment

Gunakan cache bersama yang persisten di seluruh dyno (misalnya konfigurasi database cache
yang tersedia di proyek), bukan array/file lokal untuk produksi Heroku.
Pastikan tabel cache existing sudah tersedia jika menggunakan `CACHE_STORE=database`.
Konfigurasi trusted proxy harus sesuai infrastruktur agar IP klien tidak dapat dipalsukan
dan semua pengguna tidak dianggap berasal dari IP proxy yang sama.
Pengguna di balik NAT berbagi kuota IP; sesuaikan batas berdasarkan pemantauan penggunaan.
Throttle aplikasi bukan pengganti proteksi DDoS di reverse proxy/WAF atau lapisan jaringan.
Deployment multi-dyno dan trusted proxy belum diverifikasi oleh pengujian lokal.

Jika integrasi nyata ditambahkan kelak, simpan secret sebagai environment variable dan
bacalah melalui file config Laravel; jangan menaruh secret di controller, widget, atau respons API.

## Pengujian

`php artisan test --compact --filter=ExternalInfoTest`

Test memakai SQLite in-memory dan cache array terisolasi. Cakupan: kontrak publik,
cache reuse/expiry, kuota lintas endpoint, reset kuota, IP terpisah, akses role,
penolakan mount langsung, pencabutan role pada request berikutnya, serta escaping HTML.