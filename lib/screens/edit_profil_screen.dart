import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../services/api_service.dart';

class EditProfilScreen extends StatefulWidget {
  final String currentName;
  final String currentFokus;

  const EditProfilScreen({Key? key, required this.currentName, required this.currentFokus}) : super(key: key);

  @override
  _EditProfilScreenState createState() => _EditProfilScreenState();
}

class _EditProfilScreenState extends State<EditProfilScreen> {
  final _formKey = GlobalKey<FormState>();
  final ApiService _apiService = ApiService();
  final ImagePicker _picker = ImagePicker();

  late TextEditingController _nameController;
  late TextEditingController _fokusController;
  
  File? _imageFile;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.currentName);
    _fokusController = TextEditingController(text: widget.currentFokus);
  }

  Future<void> _pilihFoto() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
      });
    }
  }

  Future<void> _simpanProfil() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final result = await _apiService.updateProfile(
      _nameController.text.trim(),
      _fokusController.text.trim(),
      _imageFile,
    );

    setState(() => _isLoading = false);

    if (result['success']) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Profil Berhasil Diperbarui!"), backgroundColor: Colors.green));
      Navigator.pop(context, true);
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
        title: Text("Edit Profil", style: GoogleFonts.poppins(color: Colors.black87, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Center(
                child: Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    CircleAvatar(
                      radius: 60,
                      backgroundColor: indramayuBlue.withOpacity(0.1),
                      child: _imageFile != null
                          ? ClipRRect(borderRadius: BorderRadius.circular(60), child: Image.file(_imageFile!, width: 120, height: 120, fit: BoxFit.cover))
                          : Icon(Icons.person, size: 70, color: indramayuBlue),
                    ),
                    GestureDetector(
                      onTap: _pilihFoto,
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: const BoxDecoration(color: Color(0xFF8CC63F), shape: BoxShape.circle),
                        child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),

              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: "Nama Lengkap / Nama Usaha",
                  prefixIcon: Icon(Icons.person_outline, color: indramayuBlue),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: indramayuBlue, width: 2)),
                ),
                validator: (value) => value!.isEmpty ? 'Nama tidak boleh kosong' : null,
              ),
              const SizedBox(height: 20),

              TextFormField(
                controller: _fokusController,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: "Fokus Budidaya (Contoh: Gurame, Nila)",
                  prefixIcon: Icon(Icons.set_meal, color: indramayuBlue),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: indramayuBlue, width: 2)),
                ),
              ),
              const SizedBox(height: 40),

              SizedBox(
                width: double.infinity, height: 55,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _simpanProfil,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: indramayuBlue,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text("SIMPAN PERUBAHAN", style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}