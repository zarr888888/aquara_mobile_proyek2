import '../widgets/session_boundary.dart';
import '../widgets/pasar_operation_state.dart';
import '../widgets/pasar_optional_fields.dart';
import '../models/pasar_item.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../services/api_service.dart';

class TambahJualanScreen extends StatelessWidget {
  const TambahJualanScreen({super.key, this.api});
  final ApiService? api;

  @override
  Widget build(BuildContext context) => SessionBoundary(
    api: api,
    private: true,
    builder: (_) => _TambahJualanScreenContent(api: api),
  );
}

class _TambahJualanScreenContent extends StatefulWidget {
  const _TambahJualanScreenContent({this.api});
  final ApiService? api;

  @override
  _TambahJualanScreenState createState() => _TambahJualanScreenState();
}

class _TambahJualanScreenState extends State<_TambahJualanScreenContent>
    with
        SessionOwnedState<_TambahJualanScreenContent>,
        WidgetsBindingObserver,
        PasarOperationState<_TambahJualanScreenContent> {
  final _formKey = GlobalKey<FormState>();
  late final ApiService _apiService = widget.api ?? ApiService();
  @override
  get stateSession => _apiService.session;
  @override
  ApiService get pasarApi => _apiService;
  final _stokController = TextEditingController();
  String? _category, _saleType;
  @override
  void initState() {
    super.initState();
    openPasar();
  }

  @override
  void clearPasarPrivate() {
    for (final controller in [
      _namaIkanController,
      _hargaController,
      _lokasiController,
      _waController,
      _deskripsiController,
      _stokController,
    ]) {
      controller.clear();
    }
    _image = null;
    _category = null;
    _saleType = null;
  }

  final TextEditingController _namaIkanController = TextEditingController();
  final TextEditingController _hargaController = TextEditingController();
  final TextEditingController _lokasiController = TextEditingController();
  final TextEditingController _waController = TextEditingController();
  final TextEditingController _deskripsiController = TextEditingController();

  File? _image;
  final ImagePicker _picker = ImagePicker();
  bool _isLoading = false;

  @override
  void dispose() {
    for (final controller in [
      _namaIkanController,
      _hargaController,
      _lokasiController,
      _waController,
      _deskripsiController,
      _stokController,
    ]) {
      controller.dispose();
    }
    _image = null;
    super.dispose();
  }

  Future<void> _pickImage() async {
    if (pasarBlocked) return;
    final pickedFile = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
      maxWidth: 1280,
      maxHeight: 1280,
    );
    if (sessionActive && pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
      });
    }
  }

  Future<void> _submitJualan() async {
    if (pasarBlocked || _isLoading) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final result = await _apiService.createPasar(
      expectedSession: pasarOwner!,
      stok: _stokController.text,
      kategori: _category,
      tipePenjualan: _saleType,
      namaIkan: _namaIkanController.text,
      harga: _hargaController.text,
      deskripsi: _deskripsiController.text,
      nomorWa: _waController.text,
      lokasi: _lokasiController.text,
      foto: _image,
    );

    if (!mounted || !pasarActive) return;
    setState(() => _isLoading = false);
    if (result.isSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Berhasil memposting jualan!",
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context, true);
    } else {
      setState(() => pasarFailure(result.failure!, mutation: true));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          "Jual Hasil Tambak",
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF8CC63F),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF8CC63F)),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    pasarStatus(
                      checkList: () => Navigator.pop(context, 'check'),
                    ),
                    Center(
                      child: GestureDetector(
                        onTap: _pickImage,
                        child: Container(
                          height: 180,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.grey[300]!,
                              style: BorderStyle.solid,
                            ),
                          ),
                          child: _image != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: Image.file(_image!, fit: BoxFit.cover),
                                )
                              : SingleChildScrollView(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.add_a_photo,
                                        size: 50,
                                        color: Colors.grey[400],
                                      ),
                                      const SizedBox(height: 10),
                                      Text(
                                        "Foto opsional, JPEG/PNG ≤ 2048 KB",
                                        textAlign: TextAlign.center,
                                        style: GoogleFonts.poppins(
                                          color: Colors.grey[500],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    _buildInputLabel("Nama Ikan / Barang"),
                    _buildTextField(
                      _namaIkanController,
                      "Contoh: Benih Gurame Ukuran Korek",
                      Icons.pets,
                    ),

                    _buildInputLabel("Harga (Rp, bilangan bulat)"),
                    _buildTextField(
                      _hargaController,
                      "Contoh: 35000",
                      Icons.monetization_on,
                      isNumber: true,
                    ),

                    PasarOptionalFields(
                      stock: _stokController,
                      category: _category,
                      saleType: _saleType,
                      errors: pasarErrors,
                      onCategory: (v) => setState(() => _category = v),
                      onSaleType: (v) => setState(() => _saleType = v),
                    ),
                    _buildInputLabel("Lokasi Tambak"),
                    _buildTextField(
                      _lokasiController,
                      "Contoh: Desa Karangsong",
                      Icons.location_on,
                    ),

                    _buildInputLabel("Nomor WhatsApp (Penjual)"),
                    _buildTextField(
                      _waController,
                      "Contoh: 08123456789",
                      Icons.phone_android,
                      isNumber: true,
                    ),

                    _buildInputLabel("Spesifikasi & Minimal Order (Deskripsi)"),
                    _buildTextField(
                      _deskripsiController,
                      "Jelaskan kondisi dan keterangan produk.",
                      Icons.description,
                      maxLines: 4,
                    ),

                    const SizedBox(height: 30),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: pasarBlocked ? null : _submitJualan,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF8CC63F),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Text(
                          "POSTING JUALAN SEKARANG",
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
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
      child: Text(
        label,
        style: GoogleFonts.poppins(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String hint,
    IconData icon, {
    bool isNumber = false,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      maxLines: maxLines,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.poppins(color: Colors.grey[400], fontSize: 13),
        prefixIcon: maxLines == 1 ? Icon(icon, color: Colors.grey) : null,
        filled: true,
        fillColor: Theme.of(context).colorScheme.surfaceContainerLow,
        errorText:
            pasarErrors[controller == _namaIkanController
                    ? 'nama_ikan'
                    : controller == _hargaController
                    ? 'harga'
                    : controller == _lokasiController
                    ? 'lokasi'
                    : controller == _waController
                    ? 'nomor_wa'
                    : 'deskripsi']
                ?.join(' '),
        errorMaxLines: 3,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF8CC63F), width: 1.5),
        ),
      ),
      validator: (value) => controller == _hargaController
          ? pasarNumberError(value)
          : pasarTextError(
              value,
              controller == _deskripsiController
                  ? 2000
                  : controller == _waController
                  ? 20
                  : 255,
            ),
    );
  }
}
