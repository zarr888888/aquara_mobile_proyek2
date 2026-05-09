import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../services/api_service.dart';

class EditJualanScreen extends StatefulWidget {
  final Map<String, dynamic> jualan;

  const EditJualanScreen({super.key, required this.jualan});

  @override
  State<EditJualanScreen> createState() => _EditJualanScreenState();
}

class _EditJualanScreenState extends State<EditJualanScreen> {
  final ApiService _apiService = ApiService();
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _namaIkanController;
  late TextEditingController _hargaController;
  late TextEditingController _deskripsiController;
  late TextEditingController _nomorWaController;
  late TextEditingController _lokasiController;

  File? _imageFile;
  final ImagePicker _picker = ImagePicker();
  bool _isLoading = false;
  final String storageUrl = 'https://aquara.app/storage/';

  @override
  void initState() {
    super.initState();
    _namaIkanController = TextEditingController(text: widget.jualan['nama_ikan']);
    _hargaController = TextEditingController(text: widget.jualan['harga'].toString());
    _deskripsiController = TextEditingController(text: widget.jualan['deskripsi']);
    _nomorWaController = TextEditingController(text: widget.jualan['nomor_wa']);
    _lokasiController = TextEditingController(text: widget.jualan['lokasi']);
  }

  @override
  void dispose() {
    _namaIkanController.dispose();
    _hargaController.dispose();
    _deskripsiController.dispose();
    _nomorWaController.dispose();
    _lokasiController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final XFile? pickedFile = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
      maxWidth: 1280,
      maxHeight: 1280,
    );
    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
      });
    }
  }

  Future<void> _submitData() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    bool success = await _apiService.updatePasarItem(
      id: widget.jualan['id'],
      namaIkan: _namaIkanController.text,
      harga: _hargaController.text,
      deskripsi: _deskripsiController.text,
      nomorWa: _nomorWaController.text,
      lokasi: _lokasiController.text,
      imageFile: _imageFile,
    );

    setState(() => _isLoading = false);
    
    if (!mounted) return;
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Jualan berhasil diperbarui!')));
      Navigator.pop(context, true); 
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gagal memperbarui jualan.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Edit Jualan', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: const Color(0xFF009FE3),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    GestureDetector(
                      onTap: _pickImage,
                      child: Container(
                        height: 200,
                        decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.grey[400]!)),
                        child: _imageFile != null
                            ? ClipRRect(borderRadius: BorderRadius.circular(15), child: Image.file(_imageFile!, fit: BoxFit.cover))
                            : (widget.jualan['foto'] != null
                                ? ClipRRect(borderRadius: BorderRadius.circular(15), child: Image.network(storageUrl + widget.jualan['foto'], fit: BoxFit.cover))
                                : const Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.add_a_photo, size: 50, color: Colors.grey), SizedBox(height: 10), Text('Ganti Foto Jualan (Opsional)')])),
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _namaIkanController,
                      decoration: const InputDecoration(labelText: 'Nama Ikan', border: OutlineInputBorder()),
                      validator: (value) => value!.isEmpty ? 'Tidak boleh kosong' : null,
                    ),
                    const SizedBox(height: 15),
                    TextFormField(
                      controller: _hargaController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Harga per Kg (Rp)', border: OutlineInputBorder()),
                      validator: (value) => value!.isEmpty ? 'Tidak boleh kosong' : null,
                    ),
                    const SizedBox(height: 15),
                    TextFormField(
                      controller: _lokasiController,
                      decoration: const InputDecoration(labelText: 'Lokasi', border: OutlineInputBorder()),
                      validator: (value) => value!.isEmpty ? 'Tidak boleh kosong' : null,
                    ),
                    const SizedBox(height: 15),
                    TextFormField(
                      controller: _nomorWaController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(labelText: 'Nomor WhatsApp', border: OutlineInputBorder()),
                      validator: (value) => value!.isEmpty ? 'Tidak boleh kosong' : null,
                    ),
                    const SizedBox(height: 15),
                    TextFormField(
                      controller: _deskripsiController,
                      maxLines: 4,
                      decoration: const InputDecoration(labelText: 'Deskripsi Tambahan', border: OutlineInputBorder()),
                      validator: (value) => value!.isEmpty ? 'Tidak boleh kosong' : null,
                    ),
                    const SizedBox(height: 25),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8CC63F), padding: const EdgeInsets.symmetric(vertical: 15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                      onPressed: _submitData,
                      child: Text('SIMPAN PERUBAHAN', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}