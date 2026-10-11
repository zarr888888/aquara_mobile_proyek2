# workflow.md - SAMUDERA Development Workflow

## 1. Kapan Harus Minta Izin User (STOP & ASK)
- Sebelum menjalankan `php artisan migrate`.
- Sebelum menginstall package baru via Composer atau NPM/Pub.
- Jika error terjadi 3 kali berturut-turut saat debugging.

## 2. Kapan Boleh Jalan Sendiri
- Membuat file Controller, Model, atau Filament Resource baru.
- Memperbaiki syntax error yang jelas.
- Membaca file di dalam direktori `app/` atau `resources/`.

## 3. Kriteria Selesai (Definition of Done)
Sebuah tugas dianggap selesai jika:
✅ Kode tidak menghasilkan error di terminal/browser.
✅ UI merespons dengan baik (tidak berantakan).
✅ Checklist di `TODO.md` sudah di-update menjadi `[x]`.