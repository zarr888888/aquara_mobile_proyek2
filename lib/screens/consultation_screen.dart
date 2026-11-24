import '../widgets/samudera_theme.dart';
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
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: Text(
          "Pusat Konsultasi",
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
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
              constraints: const BoxConstraints(minHeight: 140),
              padding: const EdgeInsets.all(16),
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF009FE3), Color(0xFF009FE3)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: SamuderaColors.blue.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.support_agent,
                    size: 50,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    "Kami Siap Membantu Anda",
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),

            _buildMenuCard(
              context,
              title: "Dr. Fisho (AI Deteksi)",
              subtitle:
                  "Cek penyakit ikan & kualitas air kolam secara otomatis pakai kamera",
              icon: Icons.photo_camera_outlined,
              color: const Color(0xFF009FE3),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AiFishoScreen(),
                  ),
                );
              },
            ),

            const SizedBox(height: 15),

            _buildMenuCard(
              context,
              title: "WhatsApp Penyuluh",
              subtitle: "Chat langsung dengan penyuluh Dinas Perikanan",
              icon: Icons.chat_rounded,
              asset: 'assets/icons/whatsapp_official.png',
              color: const Color(0xFF8CC63F),
              onTap: () {
                _launchURL(
                  'https://wa.me/6285321820026?text=Halo%20Dinas%20Perikanan,%20saya%20ingin%20konsultasi%20mengenai%20tambak%20saya.',
                );
              },
            ),

            const SizedBox(height: 15),

            _buildMenuCard(
              context,
              title: "Instagram Dinas",
              subtitle: "Kirim DM atau lihat info terbaru di Instagram resmi",
              icon: Icons.camera_alt,
              asset: 'assets/icons/instagram_official.png',
              color: const Color(0xFFF7941D),
              onTap: () {
                _launchURL('https://instagram.com/diskanla.indramayu');
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    String? asset,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: asset == null ? color.withOpacity(0.1) : Colors.white,
                shape: BoxShape.circle,
              ),
              child: asset == null
                  ? Icon(icon, color: color, size: 30)
                  : Image.asset(
                      asset,
                      width: 30,
                      height: 30,
                      fit: BoxFit.contain,
                      cacheWidth: 120,
                      semanticLabel: title,
                    ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}
