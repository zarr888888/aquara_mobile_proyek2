# Security Hardening Fase 1.5

## Deployment gate

Migration `2026_09_27_134324_create_otp_challenges_table` dibuat tetapi BELUM dijalankan
ke database aplikasi. Deploy controller OTP baru harus bersama migration tersebut;
jangan mengaktifkan alur baru sebelum tabel tersedia. Seluruh OTP legacy tidak diterima lagi.
Pengguna perlu meminta kode baru. Tidak ada seeder yang dijalankan pada database aplikasi.

## OTP

Semua route lama dipertahankan, handler dipindahkan ke OtpController/OtpService.
Challenge diikat ke akun, purpose (register/login/reset/contact/delete), channel, dan target.
Satu challenge aktif per akun; kirim ulang menggantikan challenge sebelumnya.
Kode random_int enam digit disimpan sebagai hash, masa berlaku lima menit.
Cooldown kirim 60 detik; maksimal tiga pengiriman dan lima kegagalan verifikasi per akun
dalam jendela 15 menit. Ganti tujuan/IP/token atau resend tidak mereset counter akun.
Middleware throttle IP existing tetap aktif untuk endpoint publik.
Verifikasi dan tindakan sensitif dilakukan dalam transaksi dengan lock baris user.
Counter kegagalan di-commit sebelum respons error. Konsumsi kode dan tindakan berhasil
commit bersama sehingga kode tidak dapat digunakan ulang setelah sukses.
Gagal kirim provider membatalkan challenge, tidak membocorkan kode di respons/log.
Reset password dan perubahan kontak mencabut token Sanctum akun.

### Perubahan kontrak

- Reset password: `new_password` minimal 12 karakter.
- Kirim OTP kontak: `method` (`email`/`wa`) dan `target_contact`.
- Konfirmasi kontak: `method`, `target_contact` yang sama, dan `otp` string enam digit.
  Body `email` atau `phone` ditolak. Satu operasi hanya mengubah satu kontak terverifikasi.
- Endpoint hapus akun tetap menerima `otp`, tetapi hanya challenge purpose delete yang diterima.
- Tidak ada client-supplied purpose: tujuan ditentukan handler server.
- HTTP 401 untuk OTP tidak valid; HTTP 429 untuk batas akun/cooldown; 503 untuk gagal kirim.

## Seeder

Isi SEED_SUPER_ADMIN_EMAIL/PASSWORD dan/atau SEED_ADMIN_EMAIL/PASSWORD melalui environment.
Tidak ada akun privileged default. Password minimal 16 karakter, disimpan bcrypt.
Rerun tidak mereset password atau mempromosikan akun existing yang tidak memiliki role tersebut.
Hapus secret bootstrap dari environment setelah provisioning sesuai prosedur operasional.
PERHATIAN: akun lama yang sudah dibuat dengan password lemah tidak berubah otomatis.
Rotasi password/token akun lama dan kredensial Fonnte tetap wajib dilakukan oleh operator.

## Upload Filament

PasarResource, FishTypeResource, PostResource, dan AiConsultationResource menggunakan
CloudinaryFileUpload (disk cloudinary dan trait UploadsToCloudinary).
Upload permanen berupa URL HTTPS Cloudinary; tipe JPEG/PNG/WebP maksimal 5 MB.
Preview memakai URL langsung tanpa lookup arbitrary URL. Validasi hostname Cloudinary diperketat.
Tidak menghapus media otomatis saat form dibatalkan; cleanup orphan merupakan pekerjaan terpisah.
File legacy tidak dimigrasi dan preview legacy path tidak ditampilkan oleh komponen baru.
Livewire tetap memakai temporary upload staging; bukan penyimpanan permanen public.

## Validasi dan batasan

Seluruh suite: **48 test / 641 assertion lulus**, SQLite in-memory dan mock provider.
Test mencakup pasangan cross-purpose, replay, expiry, target substitution, lockout,
cooldown/kuota kirim lintas tujuan, bcrypt/idempotensi seeder, disk dan callback upload Cloudinary.
Belum dilakukan uji konkurensi multi-proses Postgres, kirim WA/email nyata, atau upload browser
end-to-end ke Cloudinary. Pengujian tersebut masih diperlukan sebelum produksi.
Ini penyelesaian tiga area kode, bukan pengesahan keamanan seluruh aplikasi atau penghapusan
seluruh blocker pada Audit_Final_Fase1.md.