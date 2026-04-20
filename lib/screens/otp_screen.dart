import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart'; 
import 'home_screen.dart';
import 'login_screen.dart';

class OtpScreen extends StatefulWidget {
  final String phone; 
  final bool isRegistration; 
  final bool isResetPassword;
  final String newPassword; 

  const OtpScreen({
    super.key, 
    required this.phone, 
    this.isRegistration = false,
    this.isResetPassword = false,
    this.newPassword = "",
  }); 

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final List<TextEditingController> _controllers = List.generate(6, (index) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (index) => FocusNode());
  
  bool _isLoading = false; 
  bool _isResending = false; 

  @override
  void dispose() {
    for (var controller in _controllers) { controller.dispose(); }
    for (var node in _focusNodes) { node.dispose(); }
    super.dispose();
  }

  Future<void> _verifyOtp() async {
    String otpCode = _controllers.map((c) => c.text).join();
    if (otpCode.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Masukkan 6 digit OTP!'), backgroundColor: Colors.red));
      return;
    }

    setState(() => _isLoading = true);

    Map<String, dynamic> result;
    if (widget.isResetPassword) {
      result = await ApiService().resetPasswordWithOtp(widget.phone, otpCode, widget.newPassword);
    } else if (widget.isRegistration) {
      result = await ApiService().verifyRegistrationOtp(widget.phone, otpCode);
    } else {
      result = await ApiService().verifyOtpWa(widget.phone, otpCode);
    }

    setState(() => _isLoading = false);

    if (!context.mounted) return;

    if (result['success']) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result['message']), backgroundColor: Colors.green));
      
      if (widget.isResetPassword) {
        Navigator.pushAndRemoveUntil(
          context, 
          MaterialPageRoute(builder: (context) => const LoginScreen()), 
          (route) => false
        );
      } else {
        Navigator.pushAndRemoveUntil(
          context, 
          MaterialPageRoute(builder: (context) => const HomeScreen()), 
          (route) => false
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result['message']), backgroundColor: Colors.red));
      for (var c in _controllers) { c.clear(); }
      _focusNodes[0].requestFocus(); 
    }
  }

  @override
  Widget build(BuildContext context) {
    String targetText = widget.phone.contains('@') ? "Email" : "WhatsApp";

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 40),
                const Icon(Icons.security_rounded, size: 80, color: Color(0xFF009FE3)),
                const SizedBox(height: 24),
                const Text(
                  "Verifikasi Kode OTP",
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Text(
                  "Kami telah mengirimkan 6 digit kode OTP ke $targetText\n${widget.phone}.\nSilakan masukkan di bawah ini.",
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14, color: Colors.grey),
                ),
                const SizedBox(height: 40),
                
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(6, (index) => _buildOtpBox(index)),
                ),
                
                const SizedBox(height: 40),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _verifyOtp,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF009FE3),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text(
                            "Verifikasi",
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text("Belum menerima kode? ", style: TextStyle(color: Colors.grey)),
                    GestureDetector(
                      onTap: _isResending ? null : () async {
                        setState(() => _isResending = true);

                        Map<String, dynamic> response; 
                        String method = widget.phone.contains('@') ? 'email' : 'wa';
                        
                        if (widget.isResetPassword) {
                          response = await ApiService().requestResetOtp(widget.phone, method);
                        } else if (widget.isRegistration) {
                          response = await ApiService().requestRegistrationOtp(widget.phone, method);
                        } else {
                          response = await ApiService().sendOtpWa(widget.phone);
                        }
                        
                        setState(() => _isResending = false);

                        if (!context.mounted) return;
                        
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(response['message']),
                            backgroundColor: response['success'] ? Colors.green : Colors.red,
                          )
                        );
                      },
                      child: _isResending 
                        ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text(
                            "Kirim Ulang",
                            style: TextStyle(color: Color(0xFF009FE3), fontWeight: FontWeight.bold),
                          ),
                    )
                  ],
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOtpBox(int index) {
    return Flexible(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4.0), 
        child: SizedBox(
          height: 55, 
          child: TextField(
            controller: _controllers[index],
            focusNode: _focusNodes[index],
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            maxLength: 1, 
            inputFormatters: [FilteringTextInputFormatter.digitsOnly], 
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            decoration: InputDecoration(
              counterText: "", 
              contentPadding: EdgeInsets.zero,
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.grey.shade300, width: 2),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFF009FE3), width: 2),
              ),
            ),
            onChanged: (value) {
              if (value.isNotEmpty) {
                if (index < 5) {
                  _focusNodes[index + 1].requestFocus();
                } else {
                  _focusNodes[index].unfocus();
                  _verifyOtp(); 
                }
              } else if (value.isEmpty && index > 0) {
                _focusNodes[index - 1].requestFocus();
              }
            },
          ),
        ),
      ),
    );
  }
}