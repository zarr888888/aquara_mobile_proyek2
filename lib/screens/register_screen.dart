import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import 'home_screen.dart';
import 'syarat_ketentuan_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({Key? key}) : super(key: key);

  @override
  _RegisterScreenState createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final ApiService _apiService = ApiService();
  
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  
  bool _isLoading = false;
  bool _isObscure = true;

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final result = await _apiService.registerUser(
      _nameController.text.trim(),
      _emailController.text.trim(),
      _phoneController.text.trim(),
      _passwordController.text,
    );

    setState(() => _isLoading = false);

    if (result['success']) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Pendaftaran Berhasil!"), backgroundColor: Colors.green),
      );
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const HomeScreen()),
        (route) => false,
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['message']), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final indramayuBlue = const Color(0xFF009FE3);
    final indramayuGreen = const Color(0xFF8CC63F);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 10.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Buat Akun Baru", style: GoogleFonts.poppins(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.black87)),
                  const SizedBox(height: 8),
                  Text("Daftar untuk bergabung dengan komunitas pembudidaya Indramayu", style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[600])),
                  const SizedBox(height: 40),

                  _buildTextField(_nameController, "Nama Lengkap", Icons.person_outline, indramayuBlue),
                  const SizedBox(height: 16),

                  _buildTextField(_emailController, "Email (Opsional)", Icons.email_outlined, indramayuBlue, isEmail: true),
                  const SizedBox(height: 16),

                  _buildTextField(_phoneController, "Nomor HP / WhatsApp", Icons.phone_android, indramayuBlue, isNumber: true),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _passwordController,
                    obscureText: _isObscure,
                    decoration: InputDecoration(
                      labelText: "Password Minimal 6 Karakter", labelStyle: GoogleFonts.poppins(color: Colors.grey),
                      prefixIcon: Icon(Icons.lock_outline, color: indramayuBlue),
                      suffixIcon: IconButton(
                        icon: Icon(_isObscure ? Icons.visibility_off : Icons.visibility, color: Colors.grey),
                        onPressed: () => setState(() => _isObscure = !_isObscure),
                      ),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: indramayuBlue, width: 2)),
                    ),
                    validator: (value) => value != null && value.length < 6 ? 'Password minimal 6 karakter' : null,
                  ),
                  const SizedBox(height: 40),

                  SizedBox(
                    width: double.infinity, height: 55,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _handleRegister,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: indramayuGreen,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 0,
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Text("DAFTAR SEKARANG", style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                    ),
                  ),

                        const SizedBox(height: 30),
                  Wrap(
                    alignment: WrapAlignment.center,
                    children: [
                      Text(
                        "Dengan masuk dan atau daftar akun, Anda menyetujui ",
                        style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[700]),
                        textAlign: TextAlign.center,
                      ),
                      GestureDetector(
                        onTap: () {
                          Navigator.push(context, MaterialPageRoute(builder: (context) => const SyaratKetentuanScreen()));
                        },
                        child: Text(
                          "S&K yang berlaku.",
                          style: GoogleFonts.poppins(
                            fontSize: 12, 
                            color: Colors.green, 
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, IconData icon, Color focusColor, {bool isEmail = false, bool isNumber = false}) {
    return TextFormField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.phone : (isEmail ? TextInputType.emailAddress : TextInputType.text),
      decoration: InputDecoration(
        labelText: label, labelStyle: GoogleFonts.poppins(color: Colors.grey),
        prefixIcon: Icon(icon, color: focusColor),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: focusColor, width: 2)),
      ),
      validator: (value) {
        if (!isEmail && (value == null || value.isEmpty)) return '$label tidak boleh kosong';
        return null;
      },
    );
  }
}