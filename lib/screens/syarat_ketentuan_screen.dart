import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class SyaratKetentuanScreen extends StatelessWidget {
  const SyaratKetentuanScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Syarat dan Ketentuan",
          style: GoogleFonts.poppins(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Text(
                "SYARAT DAN KETENTUAN\nSAMUDERA",
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 24),
            _buildSectionTitle("Perjanjian Penggunaan"),
            _buildParagraph(
              "SAMUDERA mendukung kegiatan pembudidaya ikan dan nelayan melalui edukasi, forum, pasar, analisa usaha, konsultasi, dan pelaporan SOS. Naskah penggunaan ini perlu ditinjau pengelola/dinas sebelum rilis; belum dinyatakan disahkan.",
            ),

            _buildSectionTitle("Perubahan Perjanjian Penggunaan"),
            _buildParagraph(
              "Naskah penggunaan SAMUDERA dapat diperbarui untuk mencerminkan fitur yang tersedia. Periksa halaman ini untuk informasi terbaru.",
            ),

            _buildSectionTitle("Hak Kekayaan Intelektual"),
            _buildParagraph(
              "Logo, merek, dan aset pihak ketiga tetap milik pemiliknya. Penggunaannya mengikuti ketentuan masing-masing penyedia; kredit ilustrasi tersedia di aplikasi.",
            ),

            _buildSectionTitle("Kewajiban Penggunaan Aplikasi"),
            _buildParagraph(
              "Gunakan forum, pasar, konsultasi, dan laporan SAMUDERA dengan itikad baik. Jangan mengunggah konten menyesatkan, spam, atau informasi pribadi orang lain tanpa hak. Periksa kebenaran informasi sebelum membagikannya.",
            ),

            _buildSectionTitle("Penyalahgunaan Fitur dan Konten"),
            _buildParagraph(
              "Periksa rincian produk dan berkomunikasi dengan penjual sebelum membuat kesepakatan. Pasar dan pre-order bukan pembayaran dalam aplikasi, dan pembuatan pre-order tidak menjamin reservasi stok.",
            ),

            _buildSectionTitle("Analisa Usaha dan Konsultasi"),
            _buildParagraph(
              "Hasil analisa usaha adalah estimasi berdasarkan input dan asumsi, bukan kepastian keuntungan. Analisis foto/AI tidak menjamin diagnosis yang benar; konfirmasikan dengan tenaga yang kompeten. Tautan konsultasi membuka layanan eksternal dan tidak menjamin ketersediaan atau waktu balasan.",
            ),
            _buildSectionTitle('SOS / Lapor Darurat'),
            _buildParagraph(
              'Memilih foto tidak mengirim laporan. Lengkapi jenis dan deskripsi lalu tekan Kirim laporan secara eksplisit. Status laporan bukan jaminan respons darurat atau pemantauan 24 jam. Jangan mengandalkan aplikasi sebagai satu-satunya sarana bantuan dalam keadaan berbahaya.',
            ),
            _buildSectionTitle('Informasi Simulasi'),
            _buildParagraph(
              'Informasi berlabel mock atau simulasi merupakan data contoh, bukan informasi resmi terkini. Jangan menjadikannya satu-satunya dasar keputusan keselamatan, cuaca, harga, atau perizinan.',
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 8),
      child: Text(
        title,
        style: GoogleFonts.poppins(
          fontSize: 15,
          fontWeight: FontWeight.bold,
          color: const Color(0xFF009FE3),
        ),
      ),
    );
  }

  Widget _buildParagraph(String text) {
    return Text(
      text,
      textAlign: TextAlign.justify,
      style: GoogleFonts.poppins(
        fontSize: 13,
        color: Colors.black87,
        height: 1.6,
      ),
    );
  }
}
