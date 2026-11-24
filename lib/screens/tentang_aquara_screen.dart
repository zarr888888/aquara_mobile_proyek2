import 'package:flutter/material.dart';
import '../widgets/app_version_label.dart';
import '../widgets/samudera_branding.dart';
import 'package:google_fonts/google_fonts.dart';

class TentangAquaraScreen extends StatelessWidget {
  const TentangAquaraScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final indramayuBlue = const Color(0xFF009FE3);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: Text(
          "Tentang SAMUDERA",
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: indramayuBlue,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  color: indramayuBlue.withOpacity(0.05),
                  shape: BoxShape.circle,
                ),
                child: Image.asset(
                  samuderaLogoAsset,
                  fit: BoxFit.contain,
                  semanticLabel: 'Logo SAMUDERA',
                ),
              ),
              const SizedBox(height: 20),
              Text(
                "SAMUDERA",
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: indramayuBlue,
                  letterSpacing: 2,
                ),
              ),
              AppVersionLabel(
                style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 30),
              Text(
                "SAMUDERA adalah Sistem Aplikasi Manajemen Usaha, Data, dan Edukasi Perikanan & Kelautan yang dikembangkan untuk mendukung para pembudidaya ikan dan nelayan.",
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Theme.of(context).colorScheme.onSurface,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.withOpacity(0.2)),
                ),
                child: Column(
                  children: [
                    Text(
                      "Bekerja Sama Dengan:",
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Dinas Perikanan dan Kelautan (Diskanla)\nKabupaten Indramayu",
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
              Text(
                "© 2026 Hak Cipta Dilindungi",
                style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
