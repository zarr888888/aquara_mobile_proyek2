# ARCHITECTURE.md - SAMUDERA Mobile Architecture

## 1. Tech Stack Overview
- **Framework:** Flutter SDK.
- **Language:** Dart.
- **Communication:** REST API (menghubungi backend Laravel SAMUDERA).
- **Design System:** Material Design 3 dengan kustomisasi tema laut/pesisir.
- **Database:** PostgreSQL (Heroku Postgres) - *Local dev menggunakan MySQL, pastikan kode ORM agnostik.*
- **Cloud Storage:** Cloudinary (Manajemen Aset Gambar Media).
- **Hosting/PaaS:** Heroku.

## 2. Core Structure (Flutter)
- `lib/screens/` -> Tempat tampilan layar utama aplikasi (folder sudah ada).
- `lib/services/` -> Tempat logika HTTP memanggil API Laravel (folder sudah ada).
- `lib/widgets/` -> (BUAT FOLDER INI JIKA PERLU) Tempat komponen UI mandiri yang bisa dipakai ulang (contoh: Chatbot, Search Bar, Card Katalog).
- `lib/models/` -> (BUAT FOLDER INI JIKA PERLU) Tempat pembuatan class struktur data model JSON dari backend.