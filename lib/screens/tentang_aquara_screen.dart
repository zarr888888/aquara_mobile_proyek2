import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class TentangAquaraScreen extends StatelessWidget {
  const TentangAquaraScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final indramayuBlue = const Color(0xFF009FE3);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text("Tentang AQUARA", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: indramayuBlue,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context)),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  color: indramayuBlue.withOpacity(0.05), 
                  shape: BoxShape.circle,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(75),
                  child: Image.asset(
                    'assets/logo.jpeg', 
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text("AQUARA", style: GoogleFonts.poppins(fontSize: 28, fontWeight: FontWeight.w900, color: indramayuBlue, letterSpacing: 2)),
              Text("Versi 1.0.0", style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey)),
              const SizedBox(height: 30),
              Text(
                "AQUARA adalah Sitem Informasi Pasar dan Analisa Usaha & Edukasi yang dikembangkan untuk mendukung para pembudidaya ikan.",
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(fontSize: 14, color: Colors.black87, height: 1.6),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: const Color(0xFFF8F9FA), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.withOpacity(0.2))),
                child: Column(
                  children: [
                    Text("Bekerja Sama Dengan:", style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600])),
                    const SizedBox(height: 8),
                    Text("Dinas Perikanan dan Kelautan (Diskanla)\nKabupaten Indramayu", textAlign: TextAlign.center, style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87)),
                  ],
                ),
              ),
              const SizedBox(height: 40),
              Text("© 2026 Hak Cipta Dilindungi", style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey)),
            ],
          ),
        ),
      ),
    );
  }
}