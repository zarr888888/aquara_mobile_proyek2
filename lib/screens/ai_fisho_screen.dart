import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class AiFishoScreen extends StatefulWidget {
  const AiFishoScreen({super.key});

  @override
  State<AiFishoScreen> createState() => _AiFishoScreenState();
}

class _AiFishoScreenState extends State<AiFishoScreen> {
  File? _image;
  bool _isLoading = false;
  Map<String, dynamic>? _resultData;

  final ImagePicker _picker = ImagePicker();
  final indramayuBlue = const Color(0xFF009FE3);

  Future<void> _pickImage(ImageSource source) async {
    final pickedFile = await _picker.pickImage(source: source, imageQuality: 80);
    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
        _resultData = null; 
      });
    }
  }

  Future<void> _analyzeImage() async {
    if (_image == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      var uri = Uri.parse('http://192.168.43.63:8000/api/ai-analyze'); 
      
      var request = http.MultipartRequest('POST', uri);
      
      request.headers.addAll({
        'Accept': 'application/json',
      });

      request.files.add(await http.MultipartFile.fromPath('image', _image!.path));

      var response = await request.send();
      var responseData = await response.stream.bytesToString();
      
      var jsonResult = json.decode(responseData);

      if (response.statusCode == 200 || response.statusCode == 201) {
        setState(() {
          _resultData = jsonResult['data'];
        });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Analisa Selesai!"), backgroundColor: Colors.green));
      } else {
        _showError(jsonResult['message'] ?? "Error Kode: ${response.statusCode}");
      }
    } catch (e) {
      _showError("Terjadi kesalahan: $e");
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.red));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Text("Dr. Fisho AI", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: indramayuBlue,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // KOTAK PREVIEW FOTO
            Container(
              height: 250,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: indramayuBlue.withOpacity(0.3), width: 2),
              ),
              child: _image != null
                  ? ClipRRect(borderRadius: BorderRadius.circular(18), child: Image.file(_image!, fit: BoxFit.cover))
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.camera_alt_outlined, size: 60, color: Colors.grey[400]),
                        const SizedBox(height: 10),
                        Text("Belum ada foto yang dipilih", style: GoogleFonts.poppins(color: Colors.grey)),
                      ],
                    ),
            ),
            const SizedBox(height: 20),

            // TOMBOL KAMERA & GALERI
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _pickImage(ImageSource.camera),
                    icon: const Icon(Icons.camera),
                    label: const Text("Kamera"),
                    style: ElevatedButton.styleFrom(backgroundColor: indramayuBlue, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 15)),
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _pickImage(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library),
                    label: const Text("Galeri"),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 15)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 25),

            ElevatedButton(
              onPressed: _isLoading || _image == null ? null : _analyzeImage,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              ),
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : Text("ANALISA SEKARANG", style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 30),

            if (_resultData != null)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), border: Border.all(color: indramayuBlue)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.check_circle, color: Colors.green, size: 30),
                        const SizedBox(width: 10),
                        Text("Hasil Diagnosa AI", style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const Divider(height: 30, thickness: 1),
                    _buildResultRow("Penyakit:", _resultData!['disease_detected']),
                    const SizedBox(height: 10),
                    _buildResultRow("Kualitas Air:", _resultData!['water_quality_status']),
                    const SizedBox(height: 15),
                    Text("Solusi Penanganan:", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.red)),
                    const SizedBox(height: 5),
                    Text(_resultData!['solution'] ?? '-', style: GoogleFonts.poppins(fontSize: 13, height: 1.5)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultRow(String title, String? value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.grey[700], fontSize: 13)),
        Text(value ?? '-', style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600, color: indramayuBlue)),
      ],
    );
  }
}