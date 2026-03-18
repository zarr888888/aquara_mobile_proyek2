import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'ai_fisho_screen.dart';

class ConsultationScreen extends StatelessWidget {
  const ConsultationScreen({super.key});

  Future<void> _launchURL(String urlString) async {
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      debugPrint('Gagal membuka link: $urlString');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Text(
          "Pusat Konsultasi", 
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white)
        ),
        backgroundColor: const Color(0xFF009FE3), 
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // HEADER BANNER
            Container(
              height: 140,
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF009FE3), Color(0xFF00D2FF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(color: Colors.blue.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 5))
                ]
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.support_agent, size: 50, color: Colors.white),
                  const SizedBox(height: 10),
                  Text(
                    "Kami Siap Membantu Anda",
                    style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),

            _buildMenuCard(
              context,
              title: "Dr. Fisho (AI Deteksi)",
              subtitle: "Cek penyakit ikan & kualitas air kolam secara otomatis pakai kamera",
              icon: Icons.document_scanner_rounded, 
              color: const Color(0xFF009FE3),
              onTap: () {
                Navigator.push(
                    context, 
                  MaterialPageRoute(builder: (context) => const AiFishoScreen())
                );
              },
            ),

            const SizedBox(height: 15),

            _buildMenuCard(
              context,
              title: "WhatsApp Penyuluh",
              subtitle: "Chat langsung dengan penyuluh Dinas Perikanan",
              icon: Icons.chat_rounded,
              color: const Color(0xFF25D366), 
              onTap: () {
                _launchURL('https://wa.me/6285321820026?text=Halo%20Dinas%20Perikanan,%20saya%20ingin%20konsultasi%20mengenai%20tambak%20saya.');
              },
            ),

            const SizedBox(height: 15),

            _buildMenuCard(
              context,
              title: "Instagram Dinas",
              subtitle: "Kirim DM atau lihat info terbaru di Instagram resmi",
              icon: Icons.camera_alt, 
              color: const Color(0xFFE1306C), 
              onTap: () {
                _launchURL('https://instagram.com/diskanla.indramayu'); 
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuCard(BuildContext context, {required String title, required String subtitle, required IconData icon, required Color color, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white, 
          borderRadius: BorderRadius.circular(15), 
          boxShadow: [
            BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 5))
          ]
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12), 
              decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle), 
              child: Icon(icon, color: color, size: 30)
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, 
                children: [
                  Text(title, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16)), 
                  const SizedBox(height: 4),
                  Text(subtitle, style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600]))
                ]
              )
            ),
            const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}