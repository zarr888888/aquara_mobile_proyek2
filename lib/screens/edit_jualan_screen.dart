import '../widgets/session_boundary.dart';
import '../widgets/pasar_operation_state.dart';
import '../widgets/pasar_optional_fields.dart';
import '../models/pasar_item.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../services/api_service.dart';

class EditJualanScreen extends StatelessWidget {
  final Map<String, dynamic> jualan;

  const EditJualanScreen({super.key, required this.jualan, this.api});
  final ApiService? api;

  @override
  Widget build(BuildContext context) => SessionBoundary(
    api: api,
    private: true,
    builder: (_) =>
        ownsPasar(jualan, (api ?? ApiService()).session.metadata['user_id'])
        ? _EditJualanScreenContent(jualan: jualan, api: api)
        : Scaffold(
            appBar: AppBar(title: const Text('Edit Jualan')),
            body: const Center(
              child: Text('Akses atau data Pasar tidak tersedia.'),
            ),
          ),
  );
}

class _EditJualanScreenContent extends StatefulWidget {
  final Map<String, dynamic> jualan;

  const _EditJualanScreenContent({required this.jualan, this.api});
  final ApiService? api;

  @override
  State<_EditJualanScreenContent> createState() => _EditJualanScreenState();
}

class _EditJualanScreenState extends State<_EditJualanScreenContent>
    with
        SessionOwnedState<_EditJualanScreenContent>,
        WidgetsBindingObserver,
        PasarOperationState<_EditJualanScreenContent> {
  late final ApiService _apiService = widget.api ?? ApiService();
  @override
  get stateSession => _apiService.session;
  @override
  ApiService get pasarApi => _apiService;
  late TextEditingController _stokController;
  String? _category, _saleType;
  bool _categoryChanged = false, _saleTypeChanged = false;
  @override
  void clearPasarPrivate() {
    for (final controller in [
      _namaIkanController,
      _hargaController,
      _deskripsiController,
      _nomorWaController,
      _lokasiController,
      _stokController,
    ]) {
      controller.clear();
    }
    _imageFile = null;
    _category = null;
    _saleType = null;
  }

  final _formKey = GlobalKey<FormState>();

  late TextEditingController _namaIkanController;
  late TextEditingController _hargaController;
  late TextEditingController _deskripsiController;
  late TextEditingController _nomorWaController;
  late TextEditingController _lokasiController;

  File? _imageFile;
  final ImagePicker _picker = ImagePicker();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _stokController = TextEditingController(
      text: pasarInteger(widget.jualan['stok'])?.toString() ?? '',
    );
    _category = pasarCategories.contains(widget.jualan['kategori'])
        ? widget.jualan['kategori']
        : null;
    _saleType = pasarSaleTypes.contains(widget.jualan['tipe_penjualan'])
        ? widget.jualan['tipe_penjualan']
        : null;
    openPasar();
    _namaIkanController = TextEditingController(
      text: widget.jualan['nama_ikan'],
    );
    _hargaController = TextEditingController(
      text: widget.jualan['harga'].toString(),
    );
    _deskripsiController = TextEditingController(
      text: widget.jualan['deskripsi'],
    );
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
    _stokController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    if (pasarBlocked) return;
    final XFile? pickedFile = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
      maxWidth: 1280,
      maxHeight: 1280,
    );
    if (sessionActive && pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
      });
    }
  }

  Future<void> _submitData() async {
    if (pasarBlocked ||
        _isLoading ||
        !ownsPasar(widget.jualan, stateSession.metadata['user_id'])) {
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final result = await _apiService.updatePasarItem(
      expectedSession: pasarOwner!,
      stok:
          _stokController.text ==
              (pasarInteger(widget.jualan['stok'])?.toString() ?? '')
          ? null
          : _stokController.text,
      kategori: _categoryChanged ? _category : null,
      tipePenjualan: _saleTypeChanged ? _saleType : null,
      id: widget.jualan['id'],
      namaIkan: _namaIkanController.text,
      harga: _hargaController.text,
      deskripsi: _deskripsiController.text,
      nomorWa: _nomorWaController.text,
      lokasi: _lokasiController.text,
      imageFile: _imageFile,
    );

    if (!mounted || !pasarActive) return;
    setState(() => _isLoading = false);
    if (result.isSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Jualan berhasil diperbarui!')),
      );
      Navigator.pop(context, true);
    } else {
      setState(() => pasarFailure(result.failure!, mutation: true));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Edit Jualan',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
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
                    pasarStatus(
                      checkList: () => Navigator.pop(context, 'check'),
                    ),
                    GestureDetector(
                      onTap: _pickImage,
                      child: Container(
                        height: 200,
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(color: Colors.grey[400]!),
                        ),
                        child: _imageFile != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(15),
                                child: Image.file(
                                  _imageFile!,
                                  fit: BoxFit.cover,
                                ),
                              )
                            : (pasarImage(widget.jualan['foto']) != null
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(15),
                                      child: Image.network(
                                        pasarImage(widget.jualan['foto'])!,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, error, stack) =>
                                            const Icon(Icons.broken_image),
                                      ),
                                    )
                                  : const Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.add_a_photo,
                                          size: 50,
                                          color: Colors.grey,
                                        ),
                                        SizedBox(height: 10),
                                        Text('Ganti Foto Jualan (Opsional)'),
                                      ],
                                    )),
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _namaIkanController,
                      decoration: const InputDecoration(
                        labelText: 'Nama Ikan',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) => pasarTextError(value, 255),
                    ),
                    const SizedBox(height: 15),
                    TextFormField(
                      controller: _hargaController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Harga (Rp, bilangan bulat)',
                        border: OutlineInputBorder(),
                      ),
                      validator: pasarNumberError,
                    ),
                    PasarOptionalFields(
                      stock: _stokController,
                      category: _category,
                      saleType: _saleType,
                      errors: pasarErrors,
                      onCategory: (v) => setState(() {
                        _category = v;
                        _categoryChanged = true;
                      }),
                      onSaleType: (v) => setState(() {
                        _saleType = v;
                        _saleTypeChanged = true;
                      }),
                    ),
                    const SizedBox(height: 15),
                    TextFormField(
                      controller: _lokasiController,
                      decoration: const InputDecoration(
                        labelText: 'Lokasi',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) => pasarTextError(value, 255),
                    ),
                    const SizedBox(height: 15),
                    TextFormField(
                      controller: _nomorWaController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Nomor WhatsApp',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) => pasarTextError(value, 20),
                    ),
                    const SizedBox(height: 15),
                    TextFormField(
                      controller: _deskripsiController,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'Deskripsi Tambahan',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) => pasarTextError(value, 2000),
                    ),
                    const SizedBox(height: 25),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF8CC63F),
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: pasarBlocked ? null : _submitData,
                      child: Text(
                        'SIMPAN PERUBAHAN',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
