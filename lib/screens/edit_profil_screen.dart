import '../widgets/session_boundary.dart';
import 'dart:io';
import '../widgets/profile_cooldown_state.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../services/api_service.dart';
import '../services/api_result.dart';

class EditProfilScreen extends StatelessWidget {
  final String currentName;
  final String currentFokus;

  const EditProfilScreen({
    super.key,
    required this.currentName,
    required this.currentFokus,
    this.api,
    this.clock,
    this.pickImage,
  });
  final ApiService? api;
  final DateTime Function()? clock;
  final Future<XFile?> Function()? pickImage;

  @override
  Widget build(BuildContext context) => SessionBoundary(
    api: api,
    private: true,
    builder: (_) => _EditProfilScreenContent(
      api: api,
      clock: clock,
      pickImage: pickImage,
      currentName: currentName,
      currentFokus: currentFokus,
    ),
  );
}

class _EditProfilScreenContent extends StatefulWidget {
  final String currentName;
  final String currentFokus;

  const _EditProfilScreenContent({
    required this.currentName,
    required this.currentFokus,
    this.api,
    this.clock,
    this.pickImage,
  });
  final ApiService? api;
  final DateTime Function()? clock;
  final Future<XFile?> Function()? pickImage;

  @override
  _EditProfilScreenState createState() => _EditProfilScreenState();
}

class _EditProfilScreenState extends State<_EditProfilScreenContent>
    with
        SessionOwnedState<_EditProfilScreenContent>,
        WidgetsBindingObserver,
        ProfileCooldownState<_EditProfilScreenContent> {
  @override
  DateTime profileNow() => (widget.clock ?? DateTime.now)();
  final _formKey = GlobalKey<FormState>();
  late final ApiService _apiService = widget.api ?? ApiService();
  @override
  get stateSession => _apiService.session;
  final ImagePicker _picker = ImagePicker();

  late TextEditingController _nameController;
  late TextEditingController _fokusController;

  File? _imageFile;
  bool _isLoading = false;
  bool _picking = false;
  bool _uncertain = false;
  bool get _waiting => profileWait > 0;
  String? _message;
  Map<String, List<String>> _errors = {};

  @override
  void dispose() {
    _nameController.dispose();
    _fokusController.dispose();
    _imageFile = null;
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    openProfileCooldown();
    _nameController = TextEditingController(text: widget.currentName);
    _fokusController = TextEditingController(text: widget.currentFokus);
  }

  Future<void> _pilihFoto() async {
    if (!sessionActive || _picking || _isLoading) return;
    _picking = true;
    final owner = await stateSession.snapshot();
    if (!sessionActive || !stateSession.owns(owner)) return;
    try {
      final pickedFile =
          await (widget.pickImage?.call() ??
              _picker.pickImage(
                source: ImageSource.gallery,
                imageQuality: 70,
                maxWidth: 1280,
                maxHeight: 1280,
              ));
      if (sessionActive && stateSession.owns(owner) && pickedFile != null) {
        setState(() {
          _imageFile = File(pickedFile.path);
        });
      }
    } catch (_) {
      if (mounted && sessionActive) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Foto tidak dapat dibuka.')),
        );
      }
    } finally {
      if (sessionActive) setState(() => _picking = false);
    }
  }

  Future<void> _simpanProfil() async {
    if (!sessionActive ||
        _isLoading ||
        _picking ||
        _uncertain ||
        _waiting ||
        !_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);
    final owner = await stateSession.snapshot();
    if (!sessionActive || !stateSession.owns(owner)) return;

    final result = await _apiService.updateProfile(
      _nameController.text.trim(),
      _fokusController.text.trim(),
      _imageFile,
      expectedSession: owner,
    );

    if (!mounted || !sessionActive || !stateSession.owns(owner)) return;
    setState(() => _isLoading = false);
    if (result.isSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Profil Berhasil Diperbarui!"),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context, true);
    } else {
      final message = result.failure!.message;
      _message = message;
      _errors = Map.of(result.failure!.fieldErrors);
      _uncertain =
          result.failure!.kind == ApiErrorKind.timeout ||
          result.failure!.kind == ApiErrorKind.network;
      recordProfileFailure(result.failure!);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final indramayuBlue = const Color(0xFF009FE3);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          "Edit Profil",
          style: GoogleFonts.poppins(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        ),
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
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(60),
                              child: Image.file(
                                _imageFile!,
                                width: 120,
                                height: 120,
                                fit: BoxFit.cover,
                              ),
                            )
                          : Icon(Icons.person, size: 70, color: indramayuBlue),
                    ),
                    GestureDetector(
                      onTap: _pilihFoto,
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: const BoxDecoration(
                          color: Color(0xFF8CC63F),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.camera_alt,
                          color: Colors.white,
                          size: 20,
                        ),
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
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: indramayuBlue, width: 2),
                  ),
                ),
                validator: (value) =>
                    value!.isEmpty ? 'Nama tidak boleh kosong' : null,
              ),
              const SizedBox(height: 20),

              TextFormField(
                controller: _fokusController,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: "Fokus Budidaya (Contoh: Gurame, Nila)",
                  prefixIcon: Icon(Icons.set_meal, color: indramayuBlue),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: indramayuBlue, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 40),
              if (_message != null) Text(_message!),
              for (final field in ['name', 'fokus_budidaya', 'foto_profil'])
                if (_errors.containsKey(field))
                  Text('$field: ${_errors[field]!.join(' ')}'),
              if (_waiting) Text(profileWaitMessage),
              if (_uncertain) ...[
                const Text(
                  'Hasil pengiriman belum diketahui. Muat ulang profil sebelum mengirim ulang.',
                ),
                TextButton(
                  onPressed: _isLoading || _waiting
                      ? null
                      : () async {
                          if (_isLoading || _waiting || !sessionActive) return;
                          setState(() => _isLoading = true);
                          final owner = await stateSession.snapshot();
                          if (!mounted ||
                              !sessionActive ||
                              !stateSession.owns(owner)) {
                            return;
                          }
                          final result = await _apiService.currentUser(
                            expectedSession: owner,
                          );
                          if (!mounted ||
                              !sessionActive ||
                              !stateSession.owns(owner)) {
                            return;
                          }
                          setState(() {
                            _isLoading = false;
                            if (!result.isSuccess) {
                              recordProfileFailure(result.failure!);
                            }
                            if (result.isSuccess) {
                              final data = result.data as Map;
                              _nameController.text = data['name'];
                              _fokusController.text =
                                  data['fokus_budidaya'] ?? '';
                              _imageFile = null;
                              _uncertain = false;
                            }
                          });
                          if (!result.isSuccess && context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(result.failure!.message)),
                            );
                          }
                        },
                  child: const Text('Muat ulang profil'),
                ),
              ],

              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: _isLoading || _waiting || _uncertain || _picking
                      ? null
                      : _simpanProfil,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: indramayuBlue,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                          "SIMPAN PERUBAHAN",
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
}
