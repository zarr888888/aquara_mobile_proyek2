import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import 'home_screen.dart';
import 'register_screen.dart';
import 'syarat_ketentuan_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final ApiService _apiService = ApiService();
  
  final TextEditingController _loginIdController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  
  bool _isLoading = false;
  bool _isObscure = true;

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final result = await _apiService.loginUser(
      _loginIdController.text.trim(),
      _passwordController.text,
    );

    setState(() => _isLoading = false);

    if (result['success']) {
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
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(
                    'assets/logo2.png',
                    height: 120,
                    errorBuilder: (context, error, stackTrace) => Icon(Icons.water_drop, size: 100, color: indramayuBlue), // Fallback kalau logo belum kebaca
                  ),
                  const SizedBox(height: 24),
                  
                  // Teks Sambutan
                  Text(
                    "Selamat Datang di AQUARA",
                    style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Silakan masuk untuk melanjutkan",
                    style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 40),

                  TextFormField(
                    controller: _loginIdController,
                    decoration: InputDecoration(
                      labelText: "Email atau Nomor HP",
                      labelStyle: GoogleFonts.poppins(color: Colors.grey),
                      prefixIcon: Icon(Icons.person_outline, color: indramayuBlue),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: indramayuBlue, width: 2),
                      ),
                    ),
                    validator: (value) => value!.isEmpty ? 'Tidak boleh kosong' : null,
                  ),
                  const SizedBox(height: 20),

                  TextFormField(
                    controller: _passwordController,
                    obscureText: _isObscure,
                    decoration: InputDecoration(
                      labelText: "Password",
                      labelStyle: GoogleFonts.poppins(color: Colors.grey),
                      prefixIcon: Icon(Icons.lock_outline, color: indramayuBlue),
                      suffixIcon: IconButton(
                        icon: Icon(_isObscure ? Icons.visibility_off : Icons.visibility, color: Colors.grey),
                        onPressed: () => setState(() => _isObscure = !_isObscure),
                      ),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: indramayuBlue, width: 2),
                      ),
                    ),
                    validator: (value) => value!.isEmpty ? 'Password tidak boleh kosong' : null,
                  ),
                  
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {},
                      child: Text("Lupa Password?", style: GoogleFonts.poppins(color: indramayuBlue, fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(height: 10),

                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _handleLogin,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: indramayuBlue,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Text("MASUK", style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                    ),
                  ),
                  const SizedBox(height: 30),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text("Belum punya akun? ", style: GoogleFonts.poppins(color: Colors.grey[600])),
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const RegisterScreen()),
                          );
                        },
                        child: Text("Daftar Sekarang", style: GoogleFonts.poppins(color: indramayuGreen, fontWeight: FontWeight.bold)),
                      ),
                    ],
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
}