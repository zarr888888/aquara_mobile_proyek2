import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';

class GantiPasswordScreen extends StatefulWidget {
  const GantiPasswordScreen({super.key});

  @override
  State<GantiPasswordScreen> createState() => _GantiPasswordScreenState();
}

class _GantiPasswordScreenState extends State<GantiPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final ApiService _apiService = ApiService();

  final TextEditingController _oldPasswordController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  
  bool _obscureOld = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  Future<void> _submitUbahPassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final result = await _apiService.changePassword(
      _oldPasswordController.text,
      _newPasswordController.text,
    );

    setState(() => _isLoading = false);

    if (!mounted) return;
    if (result['success']) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['message']), backgroundColor: Colors.green),
      );
      Navigator.pop(context); // Lempar user kembali ke halaman Pengaturan kalau sukses
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['message']), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final indramayuBlue = const Color(0xFF009FE3);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text("Ubah Kata Sandi", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: indramayuBlue,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, color: Colors.orange),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text("Kata sandi baru harus memiliki panjang minimal 6 karakter demi keamanan akun Anda.",
                          style: GoogleFonts.poppins(fontSize: 12, color: Colors.black87),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 30),

                _buildPasswordField(
                  controller: _oldPasswordController,
                  label: "Kata Sandi Lama",
                  obscureText: _obscureOld,
                  onToggleVisibility: () => setState(() => _obscureOld = !_obscureOld),
                  validator: (value) => value == null || value.isEmpty ? 'Kata sandi lama wajib diisi' : null,
                  indramayuBlue: indramayuBlue,
                ),
                const SizedBox(height: 20),

                _buildPasswordField(
                  controller: _newPasswordController,
                  label: "Kata Sandi Baru",
                  obscureText: _obscureNew,
                  onToggleVisibility: () => setState(() => _obscureNew = !_obscureNew),
                  validator: (value) => value != null && value.length < 6 ? 'Password minimal 6 karakter' : null,
                  indramayuBlue: indramayuBlue,
                ),
                const SizedBox(height: 20),

                _buildPasswordField(
                  controller: _confirmPasswordController,
                  label: "Konfirmasi Sandi Baru",
                  obscureText: _obscureConfirm,
                  onToggleVisibility: () => setState(() => _obscureConfirm = !_obscureConfirm),
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Konfirmasi password wajib diisi';
                    if (value != _newPasswordController.text) return 'Kata sandi baru tidak cocok';
                    return null;
                  },
                  indramayuBlue: indramayuBlue,
                ),
                const SizedBox(height: 40),

                SizedBox(
                  width: double.infinity, height: 55,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _submitUbahPassword,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: indramayuBlue,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 0,
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Text("SIMPAN KATA SANDI", style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String label,
    required bool obscureText,
    required VoidCallback onToggleVisibility,
    required String? Function(String?) validator,
    required Color indramayuBlue,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      decoration: InputDecoration(
        labelText: label, labelStyle: GoogleFonts.poppins(color: Colors.grey),
        prefixIcon: Icon(Icons.lock_outline, color: indramayuBlue),
        suffixIcon: IconButton(
          icon: Icon(obscureText ? Icons.visibility_off : Icons.visibility, color: Colors.grey),
          onPressed: onToggleVisibility,
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: indramayuBlue, width: 2)),
      ),
      validator: validator,
    );
  }
}