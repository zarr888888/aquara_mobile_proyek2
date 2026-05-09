import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../services/api_service.dart';

class TambahJualanScreen extends StatefulWidget {
  const TambahJualanScreen({super.key});

  @override
  _TambahJualanScreenState createState() => _TambahJualanScreenState();
}

class _TambahJualanScreenState extends State<TambahJualanScreen> {
  final _formKey = GlobalKey<FormState>();
  final ApiService _apiService = ApiService();

  final TextEditingController _namaIkanController = TextEditingController();
  final TextEditingController _hargaController = TextEditingController();
  final TextEditingController _lokasiController = TextEditingController();
  final TextEditingController _waController = TextEditingController();
  final TextEditingController _deskripsiController = TextEditingController();

  File? _image;
  final ImagePicker _picker = ImagePicker();
  bool _isLoading = false;

  Future<void> _pickImage() async {
        final pickedFile = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
      maxWidth: 1280,
      maxHeight: 1280,
    );
    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
      });
    }
  }

  Future<void> _submitJualan() async {
    if (!_formKey.currentState!.validate()) return;
    if (_image == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Mohon upload foto ikan terlebih dahulu!")));
      return;
    }

    setState(() => _isLoading = true);

    bool success = await _apiService.createPasar(
      namaIkan: _namaIkanController.text,
      harga: _hargaController.text,
      deskripsi: _deskripsiController.text,
      nomorWa: _waController.text,
      lokasi: _lokasiController.text,
      foto: _image,
    );

    setState(() => _isLoading = false);

    if (!mounted) return;
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Berhasil memposting jualan!", style: TextStyle(color: Colors.white)), backgroundColor: Colors.green));
      Navigator.pop(context, true); 
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Gagal memposting jualan. Coba lagi."), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text("Jual Hasil Tambak", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: const Color(0xFF8CC63F), 
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: Color(0xFF8CC63F)))
        : SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: GestureDetector(
                      onTap: _pickImage,
                      child: Container(
                        height: 180, width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.grey[100], borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey[300]!, style: BorderStyle.solid),
                        ),
                        child: _image != null
                            ? ClipRRect(borderRadius: BorderRadius.circular(16), child: Image.file(_image!, fit: BoxFit.cover))
                            : Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.add_a_photo, size: 50, color: Colors.grey[400]),
                                  const SizedBox(height: 10),
                                  Text("Tap untuk Upload Foto Ikan", style: GoogleFonts.poppins(color: Colors.grey[500])),
                                ],
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  _buildInputLabel("Nama Ikan / Barang"),
                  _buildTextField(_namaIkanController, "Contoh: Benih Gurame Ukuran Korek", Icons.pets),

                  _buildInputLabel("Harga per Kg (Rp)"),
                  _buildTextField(_hargaController, "Contoh: 35000", Icons.monetization_on, isNumber: true),

                  _buildInputLabel("Lokasi Tambak"),
                  _buildTextField(_lokasiController, "Contoh: Desa Karangsong", Icons.location_on),

                  _buildInputLabel("Nomor WhatsApp (Penjual)"),
                  _buildTextField(_waController, "Contoh: 08123456789", Icons.phone_android, isNumber: true),

                  _buildInputLabel("Spesifikasi & Minimal Order (Deskripsi)"),
                  _buildTextField(_deskripsiController, "Contoh: Ikan sehat, sisa panen 2 kwintal. Minimal ambil 50kg bisa nego.", Icons.description, maxLines: 4),

                  const SizedBox(height: 30),
                  
                  SizedBox(
                    width: double.infinity, height: 55,
                    child: ElevatedButton(
                      onPressed: _submitJualan,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF8CC63F), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: Text("POSTING JUALAN SEKARANG", style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  Widget _buildInputLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 16),
      child: Text(label, style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87)),
    );
  }

  Widget _buildTextField(TextEditingController controller, String hint, IconData icon, {bool isNumber = false, int maxLines = 1}) {
    return TextFormField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      maxLines: maxLines,
      decoration: InputDecoration(
        hintText: hint, hintStyle: GoogleFonts.poppins(color: Colors.grey[400], fontSize: 13),
        prefixIcon: maxLines == 1 ? Icon(icon, color: Colors.grey) : null,
        filled: true, fillColor: Colors.grey[50],
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF8CC63F), width: 1.5)),
      ),
      validator: (value) => value!.isEmpty ? 'Bagian ini tidak boleh kosong' : null,
    );
  }
}