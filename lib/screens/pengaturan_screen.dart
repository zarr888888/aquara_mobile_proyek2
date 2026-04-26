import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'ganti_password_screen.dart';
import 'ubah_kontak_screen.dart';
import 'home_screen.dart';
import 'package:shared_preferences/shared_preferences.dart'; 
import '../services/api_service.dart';
import 'bantuan_screen.dart';
import 'syarat_ketentuan_screen.dart';
import 'tentang_aquara_screen.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class PengaturanScreen extends StatefulWidget {
  const PengaturanScreen({super.key});

  @override
  State<PengaturanScreen> createState() => _PengaturanScreenState();
}

class _PengaturanScreenState extends State<PengaturanScreen> {
  // Variabel sementara untuk tombol Switch
  final bool _isDarkMode = false;
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
                    TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text("Batal", style: TextStyle(color: Colors.grey))),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(dialogContext); 
                        _showDeleteOtpMethodDialog(context);
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
              onChanged: (value) async {
                setState(() => _isNotifOn = value);
                
                if (value) {
                  try {
                    await FirebaseMessaging.instance.subscribeToTopic("info_pasar");
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Anda akan menerima notifikasi Info Pasar."), backgroundColor: Colors.green));
                  } catch (e) {
                     ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Gagal mengaktifkan notifikasi."), backgroundColor: Colors.red));
                     setState(() => _isNotifOn = false);
                  }
                } 
                else {
                  try {
                    await FirebaseMessaging.instance.unsubscribeFromTopic("info_pasar");
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Notifikasi Info Pasar dimatikan."), backgroundColor: Colors.orange));
                  } catch (e) {
                     setState(() => _isNotifOn = true);
                  }
                }
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

  void _showDeleteOtpMethodDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        bool isSending = false;
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text("Verifikasi Keamanan", style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red)),
                  const SizedBox(height: 8),
                  const Text("Pilih metode pengiriman OTP untuk menghapus akun Anda:", textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  if (isSending) const CircularProgressIndicator(color: Colors.red)
                  else ...[
                    ListTile(
                      leading: Image.asset('assets/icons/whatsapp.png', height: 24),
                      title: const Text("Kirim OTP ke WhatsApp Terdaftar"),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: Colors.grey.shade300)),
                      onTap: () async {
                        setModalState(() => isSending = true);
                        var res = await ApiService().requestHapusAkunOtp('wa');
                        if (!context.mounted) return;
                        setModalState(() => isSending = false);
                        
                        if (res['success']) {
                          Navigator.pop(context);
                          _showDeleteOtpInputDialog(context);
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['message']), backgroundColor: Colors.red));
                        }
                      },
                    ),
                    const SizedBox(height: 10),
                    ListTile(
                      leading: const Icon(Icons.email, color: Color(0xFF009FE3)),
                      title: const Text("Kirim OTP ke Email Terdaftar"),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: Colors.grey.shade300)),
                      onTap: () async {
                        setModalState(() => isSending = true);
                        var res = await ApiService().requestHapusAkunOtp('email');
                        if (!context.mounted) return;
                        setModalState(() => isSending = false);
                        
                        if (res['success']) {
                          Navigator.pop(context);
                          _showDeleteOtpInputDialog(context);
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['message']), backgroundColor: Colors.red));
                        }
                      },
                    ),
                  ]
                ],
              ),
            );
          }
        );
      }
    );
  }

  void _showDeleteOtpInputDialog(BuildContext context) {
    TextEditingController otpController = TextEditingController();
    bool isVerifying = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text("Masukkan OTP", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.red)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text("Masukkan 6 digit kode OTP untuk konfirmasi penghapusan permanen."),
                  const SizedBox(height: 15),
                  TextField(
                    controller: otpController,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 24, letterSpacing: 5, fontWeight: FontWeight.bold, color: Colors.red),
                    decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text("Batal")),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  onPressed: isVerifying ? null : () async {
                    if (otpController.text.length < 6) return;
                    setDialogState(() => isVerifying = true);
                    
                    bool success = await ApiService().hapusAkun(otpController.text);
                    if (!context.mounted) return;
                    setDialogState(() => isVerifying = false);

                    if (success) {
                      SharedPreferences prefs = await SharedPreferences.getInstance();
                      await prefs.clear();
                      if (!context.mounted) return;
                      Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const HomeScreen()), (route) => false);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Akun Anda telah musnah selamanya."), backgroundColor: Colors.black));
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Kode OTP Salah! Gagal menghapus akun."), backgroundColor: Colors.red));
                    }
                  },
                  child: isVerifying ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(color: Colors.white)) : const Text("HANCURKAN AKUN", style: TextStyle(color: Colors.white)),
                )
              ],
            );
          }
        );
      }
    );
  }
}