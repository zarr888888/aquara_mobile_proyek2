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
          style: GoogleFonts.poppins(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16),
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
                "SYARAT DAN KETENTUAN\nAQUARA",
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 24),
            _buildSectionTitle("Perjanjian Penggunaan"),
            _buildParagraph("Perjanjian Penggunaan berikut adalah perjanjian yang harus ditaati dalam penggunaan aplikasi AQUARA (selanjutnya disebut “Aplikasi”) serta penggunaan atas konten, layanan, dan fitur yang ada di dalamnya. Aplikasi ini dikembangkan dalam rangka mendukung program perikanan air tawar dan dapat bermitra dengan Dinas Perikanan dan Kelautan (Diskanla) Kabupaten Indramayu. Harap Anda membaca perjanjian penggunaan ini dengan sebaik-baiknya. Dengan mengakses dan menggunakan Aplikasi ini, berarti Anda telah memahami dan setuju untuk terikat dengan semua peraturan yang berlaku. Jika Anda tidak setuju, Kami mempersilahkan Anda untuk tidak menggunakan Aplikasi ini."),
            
            _buildSectionTitle("Perubahan Perjanjian Penggunaan"),
            _buildParagraph("Pengelola Aplikasi AQUARA dapat setiap saat mengganti, menambah, atau mengurangi Perjanjian penggunaan ini. Anda terikat oleh setiap perubahan tersebut dan Kami menghimbau Anda untuk secara berkala mengakses halaman ini guna melihat informasi terbaru."),
            
            _buildSectionTitle("Hak Kekayaan Intelektual"),
            _buildParagraph("Setiap logo, merek, layanan, konten, dan fitur milik AQUARA (dan mitra terkait) sebagaimana terdapat di Aplikasi ini berada di bawah perlindungan hukum yang berlaku di Indonesia. Anda tidak dibenarkan untuk menggunakan atau mengaplikasikan logo dan aset tanpa persetujuan tertulis sebelumnya."),
            
            _buildSectionTitle("Kewajiban Penggunaan Aplikasi"),
            _buildParagraph("Penggunaan Anda atas Aplikasi ini harus tunduk pada hukum dan peraturan perundang-undangan dalam wilayah Republik Indonesia. Anda menjamin bahwa Anda akan menggunakan layanan edukasi, forum, dan pasar pada Aplikasi ini dengan itikad baik dan tidak untuk tujuan melanggar hukum, penipuan, atau merugikan pihak lain.\n\nAnda setuju untuk membebaskan pengelola AQUARA atas segala tuntutan maupun gugatan pihak lain mengenai hal-hal yang mungkin terjadi sehubungan dengan pelanggaran Anda atas Ketentuan Penggunaan ini."),
            
            _buildSectionTitle("Penyalahgunaan Fitur dan Konten"),
            _buildParagraph("Anda akan bertanggungjawab penuh atas setiap konten, diskusi, maupun produk jualan yang Anda unggah di dalam Aplikasi. Pengelola AQUARA tidak bertanggung jawab atas kerugian transaksi antar pengguna di dalam fitur Pasar."),
            
            _buildSectionTitle("Penangguhan dan Pemutusan Layanan"),
            _buildParagraph("Pengelola AQUARA berhak, demi kenyamanan seluruh pengguna, untuk melakukan penangguhan atau pemutusan akses akun Anda tanpa pemberitahuan terlebih dahulu apabila terindikasi hal-hal berikut:\n1. Terdapat perbaikan atau pemeliharaan sistem.\n2. Anda melakukan tindakan spamming, penipuan, penyebaran ujaran kebencian, atau hal-hal yang merugikan komunitas perikanan.\n3. Anda menyalahgunakan layanan untuk tujuan ilegal."),
            
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
        style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.bold, color: const Color(0xFF0079C3)),
      ),
    );
  }

  Widget _buildParagraph(String text) {
    return Text(
      text,
      textAlign: TextAlign.justify,
      style: GoogleFonts.poppins(fontSize: 13, color: Colors.black87, height: 1.6),
    );
  }
}