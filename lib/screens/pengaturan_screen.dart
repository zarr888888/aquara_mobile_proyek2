import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'ganti_password_screen.dart';
import '../main.dart';
import 'ubah_kontak_screen.dart';
import 'home_screen.dart';
import 'package:shared_preferences/shared_preferences.dart'; 
import '../services/api_service.dart';
import 'bantuan_screen.dart';
import 'syarat_ketentuan_screen.dart';
import 'tentang_aquara_screen.dart';

class PengaturanScreen extends StatefulWidget {
  const PengaturanScreen({Key? key}) : super(key: key);

  @override
  State<PengaturanScreen> createState() => _PengaturanScreenState();
}

class _PengaturanScreenState extends State<PengaturanScreen> {
  // Variabel sementara untuk tombol Switch
  bool _isDarkMode = false;
  bool _isNotifOn = true;

  @override
  Widget build(BuildContext context) {
    final indramayuBlue = const Color(0xFF009FE3);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Text("Pengaturan", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: indramayuBlue,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // KELOMPOK 1: AKUN & KEAMANAN
          _buildSectionHeader("Akun & Keamanan"),
          _buildSettingsCard([
            _buildListTile(Icons.email_outlined, "Ubah Email / Nomor HP", onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const UbahKontakScreen()));
            }),
            _buildDivider(),
            _buildListTile(Icons.lock_outline, "Ubah Kata Sandi", onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const GantiPasswordScreen()));
            }),
            _buildDivider(),
            _buildListTile(Icons.delete_outline, "Hapus Akun", color: Colors.red, onTap: () {
              showDialog(
                context: context,
                builder: (dialogContext) => AlertDialog(
                  title: Text("Hapus Akun Permanen?", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.red)),
                  content: Text("Semua data tambak, forum, dan profil Anda akan hilang. Apakah Anda yakin?", style: GoogleFonts.poppins()),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext), 
                      child: const Text("Batal", style: TextStyle(color: Colors.grey))
                    ),
                    TextButton(
                      onPressed: () async {
                        Navigator.pop(dialogContext); 
                        
                        bool success = await ApiService().hapusAkun();
                        
                        if (success) {
                          SharedPreferences prefs = await SharedPreferences.getInstance();
                          await prefs.clear();
                          
                          if (!mounted) return;
                          Navigator.pushAndRemoveUntil(
                            context, 
                            MaterialPageRoute(builder: (context) => const HomeScreen()), 
                            (route) => false 
                          );
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Akun berhasil dihapus permanen"), backgroundColor: Colors.red));
                        } else {
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Gagal menghapus akun. Coba lagi."), backgroundColor: Colors.orange));
                        }
                      }, 
                      child: const Text("Ya, Hapus", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))
                    ),
                  ],
                ),
              );
            }),
          ]),

          const SizedBox(height: 25),

          // KELOMPOK 2: PREFERENSI APLIKASI
          _buildSectionHeader("Preferensi Aplikasi"),
          _buildSettingsCard([
            SwitchListTile(
              activeTrackColor: indramayuBlue,
              secondary: const Icon(Icons.dark_mode_outlined, color: Colors.black87),
              title: Text("Mode Gelap (Dark Mode)", style: GoogleFonts.poppins(fontSize: 14)),
              value: false, 
              onChanged: (value) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Fitur Dark Mode sedang dalam pengembangan untuk versi berikutnya!"),
                    backgroundColor: Colors.orange,
                  ),
                );
              },
            ),
            _buildDivider(),
            SwitchListTile(
              activeTrackColor: indramayuBlue,
              secondary: const Icon(Icons.notifications_active_outlined, color: Colors.black87),
              title: Text("Notifikasi Info Pasar", style: GoogleFonts.poppins(fontSize: 14)),
              value: _isNotifOn,
              onChanged: (value) {
                setState(() => _isNotifOn = value);
              },
            ),
          ]),

          const SizedBox(height: 25),

          // KELOMPOK 3: BANTUAN & INFORMASI
          _buildSectionHeader("Bantuan & Informasi"),
          _buildSettingsCard([
            _buildListTile(Icons.help_outline, "Pusat Bantuan / FAQ", onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const BantuanScreen()));
            }),
            _buildDivider(),
            _buildListTile(Icons.description_outlined, "Syarat & Ketentuan", onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const SyaratKetentuanScreen()));
            }),
            _buildDivider(),
            _buildListTile(Icons.info_outline, "Tentang AQUARA", onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const TentangAquaraScreen()));
            }),
          ]),
          
          const SizedBox(height: 30),
          Center(
            child: Text("AQUARA Versi 1.0.0\nDiskanla Indramayu", textAlign: TextAlign.center, style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey)),
          )
        ],
      ),
    );
  }


  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, left: 5),
      child: Text(
        title,
        style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey[700]),
      ),
    );
  }

  Widget _buildSettingsCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 5))],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildListTile(IconData icon, String title, {Color? color, required VoidCallback onTap}) {
    return ListTile(
      leading: Icon(icon, color: color ?? Colors.black87),
      title: Text(title, style: GoogleFonts.poppins(fontSize: 14, color: color ?? Colors.black87)),
      trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
      onTap: onTap,
    );
  }

  Widget _buildDivider() {
    return const Divider(height: 1, thickness: 1, indent: 50, endIndent: 20, color: Color(0xFFF0F0F0));
  }

  void _showDevSnackBar(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Fitur ini sedang dalam tahap pengembangan!")));
  }
}