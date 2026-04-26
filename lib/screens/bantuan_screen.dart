import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class BantuanScreen extends StatelessWidget {
  const BantuanScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final indramayuBlue = const Color(0xFF009FE3);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text("Pusat Bantuan / FAQ", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: indramayuBlue,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text("Pertanyaan yang Sering Diajukan", style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
          const SizedBox(height: 15),
          _buildFAQItem("Bagaimana cara menggunakan Analisa Usaha?", "Pilih menu Analisa Usaha di Beranda, masukkan data luas kolam, jenis ikan, dan target panen Anda. Sistem akan menghitung perkiraan modal dan keuntungan secara otomatis."),
          _buildFAQItem("Dari mana data Harga Pasar berasal?", "Data harga pasar ikan air tawar di-update secara berkala berdasarkan pantauan langsung di pasar-pasar tradisional Kabupaten Indramayu."),
          _buildFAQItem("Apakah aplikasi ini gratis?", "Ya, seluruh fitur di dalam aplikasi AQUARA 100% gratis dan dikembangkan khusus untuk membantu para petambak ikan di Indramayu."),
          _buildFAQItem("Bagaimana cara bertanya di Forum?", "Buka menu Forum di bawah, pastikan Anda sudah login, lalu klik tombol 'Tulis Pertanyaan' untuk memulai diskusi dengan petambak lain atau penyuluh dinas."),
        ],
      ),
    );
  }

  Widget _buildFAQItem(String question, String answer) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.withOpacity(0.2))),
      child: ExpansionTile(
        title: Text(question, style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFF009FE3))),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Text(answer, style: GoogleFonts.poppins(fontSize: 13, color: Colors.black87, height: 1.5)),
          )
        ],
      ),
    );
  }
}