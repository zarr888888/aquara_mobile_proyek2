# AGENTS.md - Rules for AI Coding Agents (Flutter)

## 1. Project Identity
- **App Name:** SAMUDERA Mobile (Flutter)
- **Primary Color:** Biru Laut, Putih, dan warna maritim.
- **Deployment Target:** Heroku (Ephemeral Filesystem) + Heroku Postgres.

## 2. Core Rules (NEVER DO THIS)
- ❌ **JANGAN PERNAH** menjalankan perintah PHP, Composer, atau Artisan di repositori ini. Ini adalah proyek Flutter murni.
- ❌ **JANGAN PERNAH** mengotak-atik folder `android/` atau `ios/` kecuali diminta secara eksplisit untuk mengatur perizinan (permissions).
- ❌ **JANGAN PERNAH** merombak arsitektur State Management yang sudah berjalan di Proyek 2.

## 3. Flutter & API Rules
- Gunakan `flutter pub run` atau perintah standar Flutter.
- Aplikasi ini mengambil data dari REST API Laravel. Pastikan semua HTTP Request menangani error dan timeout dengan baik.
- Tampilan UI/Widget harus responsif dan tidak overflow di layar berukuran kecil.