import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';

class UbahKontakScreen extends StatefulWidget {
  const UbahKontakScreen({super.key});
  @override
  State<UbahKontakScreen> createState() => _UbahKontakScreenState();
}

class _UbahKontakScreenState extends State<UbahKontakScreen> {
  final _formKey = GlobalKey<FormState>();
  final ApiService _apiService = ApiService();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final bool _isLoading = false;

  void _showOtpMethodDialog() {
    if (!_formKey.currentState!.validate()) return;
    
    final newEmail = _emailController.text.trim();
    final newPhone = _phoneController.text.trim();

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
                  Text("Pilih Target OTP", style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  if (isSending) const CircularProgressIndicator(color: Color(0xFF009FE3))
                  else ...[
                    ListTile(
                      leading: Image.asset('assets/icons/whatsapp.png', height: 24),
                      title: Text("Kirim ke WhatsApp Baru\n($newPhone)"),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: Colors.grey.shade300)),
                      onTap: () async {
                        setModalState(() => isSending = true);
                        var res = await _apiService.requestUbahKontakOtp(newPhone, 'wa');
                        if (!context.mounted) return;
                        setModalState(() => isSending = false);
                        
                        if (res['success']) {
                          Navigator.pop(context);
                          _showOtpInputDialog(newEmail, newPhone);
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['message']), backgroundColor: Colors.red));
                        }
                      },
                    ),
                    const SizedBox(height: 10),
                    if (newEmail.isNotEmpty)
                      ListTile(
                        leading: const Icon(Icons.email, color: Color(0xFF009FE3)),
                        title: Text("Kirim ke Email Baru\n($newEmail)"),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: Colors.grey.shade300)),
                        onTap: () async {
                          setModalState(() => isSending = true);
                          var res = await _apiService.requestUbahKontakOtp(newEmail, 'email');
                          if (!context.mounted) return;
                          setModalState(() => isSending = false);
                          
                          if (res['success']) {
                            Navigator.pop(context);
                            _showOtpInputDialog(newEmail, newPhone);
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

  void _showOtpInputDialog(String email, String phone) {
    TextEditingController otpController = TextEditingController();
    bool isVerifying = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text("Masukkan OTP", style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text("Masukkan 6 digit kode OTP yang telah dikirim."),
                  const SizedBox(height: 15),
                  TextField(
                    controller: otpController,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 24, letterSpacing: 5, fontWeight: FontWeight.bold),
                    decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text("Batal")),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF009FE3)),
                  onPressed: isVerifying ? null : () async {
                    if (otpController.text.length < 6) return;
                    setDialogState(() => isVerifying = true);
                    
                    var res = await _apiService.ubahKontak(email, phone, otpController.text);
                    if (!context.mounted) return;
                    setDialogState(() => isVerifying = false);

                    if (res['success']) {
                      Navigator.pop(context);
                      Navigator.pop(context); 
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['message']), backgroundColor: Colors.green));
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['message']), backgroundColor: Colors.red));
                    }
                  },
                  child: isVerifying ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(color: Colors.white)) : const Text("Verifikasi", style: TextStyle(color: Colors.white)),
                )
              ],
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
      appBar: AppBar(
        title: Text("Ubah Email / Nomor HP", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: indramayuBlue, elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _emailController, keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: "Email Baru (Opsional)", labelStyle: GoogleFonts.poppins(color: Colors.grey),
                    prefixIcon: Icon(Icons.email_outlined, color: indramayuBlue),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _phoneController, keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: "Nomor HP / WhatsApp Baru", labelStyle: GoogleFonts.poppins(color: Colors.grey),
                    prefixIcon: Icon(Icons.phone_android, color: indramayuBlue),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  validator: (value) => value == null || value.isEmpty ? 'Nomor HP wajib diisi' : null,
                ),
                const SizedBox(height: 40),
                SizedBox(
                  width: double.infinity, height: 55,
                  child: ElevatedButton(
                    onPressed: _showOtpMethodDialog,
                    style: ElevatedButton.styleFrom(backgroundColor: indramayuBlue, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                    child: Text("SIMPAN PERUBAHAN", style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
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