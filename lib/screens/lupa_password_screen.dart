import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import 'otp_screen.dart';

class LupaPasswordScreen extends StatefulWidget {
  const LupaPasswordScreen({super.key});

  @override
  _LupaPasswordScreenState createState() => _LupaPasswordScreenState();
}

class _LupaPasswordScreenState extends State<LupaPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _loginIdController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  
  bool _isObscure = true;

  void _showOtpMethodDialog() {
    if (!_formKey.currentState!.validate()) return;
    
    final loginId = _loginIdController.text.trim();
    final newPassword = _passwordController.text;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        bool isSending = false;
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 50, height: 5, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10))),
                  const SizedBox(height: 24),
                  Text("Kirim OTP Reset Password", style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87)),
                  const SizedBox(height: 8),
                  Text("Kami akan mengirimkan OTP ke kontak Anda.", textAlign: TextAlign.center, style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[600])),
                  const SizedBox(height: 24),
                  
                  if (isSending) 
                    const Padding(padding: EdgeInsets.all(20.0), child: Center(child: CircularProgressIndicator(color: Color(0xFF009FE3))))
                  else ...[
                    // OPSI WHATSAPP
                    ListTile(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.grey.shade300)),
                      leading: Image.asset('assets/icons/whatsapp.png', height: 32),
                      title: Text("Kirim via WhatsApp", style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                      onTap: () async {
                        setModalState(() => isSending = true);
                        var res = await ApiService().requestResetOtp(loginId, 'wa');
                        if (!context.mounted) return;
                        setModalState(() => isSending = false);
                        
                        if (res['success']) {
                          Navigator.pop(context); 
                          Navigator.push(context, MaterialPageRoute(builder: (_) => OtpScreen(phone: loginId, isResetPassword: true, newPassword: newPassword)));
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['message']), backgroundColor: Colors.red));
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    // OPSI EMAIL
                    ListTile(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.grey.shade300)),
                      leading: const Icon(Icons.email, color: Color(0xFF009FE3), size: 32),
                      title: Text("Kirim via Email", style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                      onTap: () async {
                        setModalState(() => isSending = true);
                        var res = await ApiService().requestResetOtp(loginId, 'email');
                        if (!context.mounted) return;
                        setModalState(() => isSending = false);
                        
                        if (res['success']) {
                          Navigator.pop(context); 
                          Navigator.push(context, MaterialPageRoute(builder: (_) => OtpScreen(phone: loginId, isResetPassword: true, newPassword: newPassword))); 
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['message']), backgroundColor: Colors.red));
                        }
                      },
                    ),
                  ],
                  const SizedBox(height: 20),
                ],
              ),
            );
          }
        );
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    final indramayuBlue = const Color(0xFF009FE3);
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(backgroundColor: Colors.white, elevation: 0, iconTheme: const IconThemeData(color: Colors.black)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Lupa Password?", style: GoogleFonts.poppins(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.black87)),
                const SizedBox(height: 8),
                Text("Masukkan Email/No HP yang terdaftar dan buat password baru Anda di sini.", style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[600])),
                const SizedBox(height: 40),

                TextFormField(
                  controller: _loginIdController,
                  decoration: InputDecoration(
                    labelText: "Email / Nomor HP Anda",
                    prefixIcon: Icon(Icons.person_search, color: indramayuBlue),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  validator: (val) => val!.isEmpty ? 'Tidak boleh kosong' : null,
                ),
                const SizedBox(height: 20),

                TextFormField(
                  controller: _passwordController,
                  obscureText: _isObscure,
                  decoration: InputDecoration(
                    labelText: "Password Baru Anda",
                    prefixIcon: Icon(Icons.lock_reset, color: indramayuBlue),
                    suffixIcon: IconButton(
                      icon: Icon(_isObscure ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setState(() => _isObscure = !_isObscure),
                    ),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  validator: (val) => val!.length < 6 ? 'Minimal 6 karakter' : null,
                ),
                const SizedBox(height: 40),

                SizedBox(
                  width: double.infinity, height: 55,
                  child: ElevatedButton(
                    onPressed: _showOtpMethodDialog,
                    style: ElevatedButton.styleFrom(backgroundColor: indramayuBlue, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                    child: Text("KIRIM KODE OTP", style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}