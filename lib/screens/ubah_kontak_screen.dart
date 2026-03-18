import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';

class UbahKontakScreen extends StatefulWidget {
  const UbahKontakScreen({Key? key}) : super(key: key);

  @override
  State<UbahKontakScreen> createState() => _UbahKontakScreenState();
}

class _UbahKontakScreenState extends State<UbahKontakScreen> {
  final _formKey = GlobalKey<FormState>();
  final ApiService _apiService = ApiService();

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  bool _isLoading = false;

  Future<void> _submitUbahKontak() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final result = await _apiService.ubahKontak(
      _emailController.text.trim(),
      _phoneController.text.trim(),
    );
    setState(() => _isLoading = false);

    if (result['success']) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result['message']), backgroundColor: Colors.green));
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result['message']), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    final indramayuBlue = const Color(0xFF009FE3);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text("Ubah Email / Nomor HP", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: indramayuBlue,
        elevation: 0,
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
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: "Email Baru (Opsional)", labelStyle: GoogleFonts.poppins(color: Colors.grey),
                    prefixIcon: Icon(Icons.email_outlined, color: indramayuBlue),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: indramayuBlue, width: 2)),
                  ),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: "Nomor HP / WhatsApp Baru", labelStyle: GoogleFonts.poppins(color: Colors.grey),
                    prefixIcon: Icon(Icons.phone_android, color: indramayuBlue),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: indramayuBlue, width: 2)),
                  ),
                  validator: (value) => value == null || value.isEmpty ? 'Nomor HP wajib diisi' : null,
                ),
                const SizedBox(height: 40),
                SizedBox(
                  width: double.infinity, height: 55,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _submitUbahKontak,
                    style: ElevatedButton.styleFrom(backgroundColor: indramayuBlue, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 0),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Text("SIMPAN PERUBAHAN", style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
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