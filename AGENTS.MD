# AGENTS.md - Rules for AI Coding Agents (Flutter)

## 1. Project Identity
- **App Name:** SAMUDERA Mobile (Flutter)
- **Primary Color:** Biru Laut, Putih, dan warna maritim.
- **Deployment Target:** Heroku (Ephemeral Filesystem) + Heroku Postgres.

## 2. Core Rules (NEVER DO THIS)
- ❌ **JANGAN PERNAH** menjalankan perintah PHP, Composer, atau Artisan di repositori ini. Ini adalah proyek Flutter murni.
- Jangan mengubah folder android/ atau ios/, kecuali dalam cakupan berikut:
  1. Pengaturan permissions yang diminta secara eksplisit oleh pengguna.
  2. Branding Android SAMUDERA yang telah diizinkan pengguna:
     boleh mengubah atau menghasilkan ulang resource launcher/adaptive
     icon dan splash pada android/app/src/main/res/, serta menyesuaikan
     field sumber gambar dan parameter branding pada konfigurasi
     flutter_launcher_icons existing di pubspec.yaml.
     Gunakan logo pengguna tanpa dependency baru.
     Generator hanya boleh menghasilkan resource Android.

  Pengecualian branding tidak mencakup signing/keystore, Firebase/OAuth,
  applicationId/namespace/bundle identifier, Gradle, AndroidManifest.xml,
  permissions, intent filter, kode/logika native, endpoint,
  atau konfigurasi API. Folder ios/ tetap di luar cakupan.
  Build APK debug lokal untuk verifikasi branding diizinkan;
  build release, CI, commit, push, dan deploy tetap memerlukan izin terpisah.
- ❌ **JANGAN PERNAH** merombak arsitektur State Management yang sudah berjalan di Proyek 2.

## 3. Flutter & API Rules
- Gunakan `flutter pub run` atau perintah standar Flutter.
- Aplikasi ini mengambil data dari REST API Laravel. Pastikan semua HTTP Request menangani error dan timeout dengan baik.
- Tampilan UI/Widget harus responsif dan tidak overflow di layar berukuran kecil.