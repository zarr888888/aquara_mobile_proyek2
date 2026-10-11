import '../widgets/session_boundary.dart';
import 'dart:async';
import '../services/ai_analysis_api.dart';
import '../services/api_service.dart';
import '../services/api_result.dart';
import '../services/session_service.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

class AiFishoScreen extends StatelessWidget {
  const AiFishoScreen({super.key, this.api, this.pickImage, this.clock});
  final DateTime Function()? clock;
  final ApiService? api;
  final Future<XFile?> Function(ImageSource)? pickImage;

  @override
  Widget build(BuildContext context) => SessionBoundary(
    private: true,
    api: api,
    builder: (_) =>
        _AiFishoScreenContent(api: api, pickImage: pickImage, clock: clock),
  );
}

class _AiFishoScreenContent extends StatefulWidget {
  const _AiFishoScreenContent({this.api, this.pickImage, this.clock});
  final DateTime Function()? clock;
  final ApiService? api;
  final Future<XFile?> Function(ImageSource)? pickImage;

  @override
  State<_AiFishoScreenContent> createState() => _AiFishoScreenState();
}

class _AiFishoScreenState extends State<_AiFishoScreenContent>
    with SessionOwnedState<_AiFishoScreenContent>, WidgetsBindingObserver {
  late final ApiService _api = widget.api ?? ApiService();
  @override
  SessionService get stateSession => _api.session;
  AiImage? _image;
  SessionSnapshot? _imageOwner;
  bool _isLoading = false;
  bool _picking = false;
  bool _attempted = false;
  AiAnalysis? _resultData;
  ApiFailure? _failure;
  DateTime? _retryAt;
  Timer? _timer;
  StreamSubscription<int>? _subscription;
  DateTime _now() => (widget.clock ?? DateTime.now)();
  int get _wait {
    final milliseconds = _retryAt?.difference(_now()).inMilliseconds ?? 0;
    return milliseconds <= 0 ? 0 : (milliseconds / 1000).ceil();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _subscription = stateSession.changes.listen((_) {
      if (!sessionActive) _clear();
    });
  }

  void _clear() {
    _timer?.cancel();
    _timer = null;
    _image = null;
    _imageOwner = null;
    _resultData = null;
    _failure = null;
    _retryAt = null;
    _isLoading = false;
    _picking = false;
    _attempted = false;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && sessionActive) setState(() {});
  }

  @override
  void dispose() {
    _clear();
    _subscription?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  final ImagePicker _picker = ImagePicker();
  final indramayuBlue = const Color(0xFF009FE3);

  Future<void> _pickImage(ImageSource source) async {
    if (!sessionActive || _isLoading || _picking) return;
    final revision = stateSession.revision;
    setState(() => _picking = true);
    try {
      final owner = await stateSession.snapshot();
      if (!sessionActive ||
          owner.revision != revision ||
          !stateSession.owns(owner)) {
        return;
      }
      final pickedFile =
          await (widget.pickImage?.call(source) ??
              _picker.pickImage(
                source: source,
                imageQuality: 70,
                maxWidth: 1280,
                maxHeight: 1280,
              ));
      if (!sessionActive || !stateSession.owns(owner) || pickedFile == null) {
        return;
      }
      setState(() {
        _image = null;
        _imageOwner = null;
        _resultData = null;
        _failure = null;
        _attempted = false;
      });
      final result = await AiImage.read(pickedFile);
      if (!sessionActive || !stateSession.owns(owner)) return;
      setState(() {
        _image = result.data;
        _imageOwner = result.isSuccess ? owner : null;
        _failure = result.failure;
      });
    } catch (_) {
      if (sessionActive && stateSession.revision == revision) {
        setState(
          () => _failure = ApiFailure(
            kind: ApiErrorKind.validation,
            message: 'Foto tidak dapat dibuka. Silakan pilih kembali.',
          ),
        );
      }
    } finally {
      if (sessionActive && stateSession.revision == revision) {
        setState(() => _picking = false);
      }
    }
  }

  Future<void> _analyzeImage() async {
    final owner = _imageOwner;
    final image = _image;
    if (!sessionActive ||
        _isLoading ||
        _picking ||
        _wait > 0 ||
        image == null ||
        owner == null ||
        !stateSession.owns(owner)) {
      return;
    }

    setState(() {
      _isLoading = true;
      _attempted = true;
      _resultData = null;
      _failure = null;
    });

    try {
      final result = await _api.analyzeImage(
        image: image,
        expectedSession: owner,
      );
      if (!sessionActive || !stateSession.owns(owner)) return;
      setState(() {
        _resultData = result.data;
        _failure = result.failure;
      });
      if (_failure?.kind == ApiErrorKind.rateLimited) {
        _retryAt =
            _failure!.retryAt ??
            _now().add(_failure!.retryAfter ?? const Duration(seconds: 60));
        _timer?.cancel();
        _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
          if (!sessionActive || _wait == 0) timer.cancel();
          if (sessionActive) setState(() {});
        });
      }
    } catch (_) {
      if (sessionActive && stateSession.owns(owner)) {
        setState(
          () => _failure = ApiFailure(
            kind: ApiErrorKind.network,
            message: 'Hasil analisis belum diterima.',
          ),
        );
      }
    } finally {
      if (sessionActive && stateSession.owns(owner)) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          "Dr. Fisho AI",
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
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
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: indramayuBlue.withOpacity(0.3),
                  width: 2,
                ),
              ),
              child: _image != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: Image.memory(
                        _image!.bytes,
                        fit: BoxFit.cover,
                        errorBuilder: (_, error, stack) =>
                            const Center(child: Text('Preview tidak tersedia')),
                      ),
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.camera_alt_outlined,
                          size: 60,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          "Belum ada foto yang dipilih",
                          style: GoogleFonts.poppins(color: Colors.grey),
                        ),
                      ],
                    ),
            ),
            const SizedBox(height: 20),

            // TOMBOL KAMERA & GALERI
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isLoading || _picking
                        ? null
                        : () => _pickImage(ImageSource.camera),
                    icon: const Icon(Icons.camera),
                    label: const Text("Kamera"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: indramayuBlue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                    ),
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isLoading || _picking
                        ? null
                        : () => _pickImage(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library),
                    label: const Text("Galeri"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 25),

            ElevatedButton(
              onPressed: _isLoading || _picking || _wait > 0 || _image == null
                  ? null
                  : _analyzeImage,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : Text(
                      _attempted ? "KIRIM ANALISIS BARU" : "ANALISA SEKARANG",
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
            const SizedBox(height: 30),
            if (_isLoading)
              const Text(
                'Mengunggah dan menganalisis foto… Menutup layar tidak menjamin pemrosesan server berhenti.',
              ),
            if (_failure != null)
              Text(
                _failure!.kind == ApiErrorKind.timeout ||
                        _failure!.kind == ApiErrorKind.network
                    ? 'Hasil belum diterima. Analisis mungkin sudah diproses di server. Tidak tersedia pemeriksaan status atau riwayat.'
                    : _failure!.message,
                key: const ValueKey('ai-error'),
              ),
            if (_wait > 0)
              Text(
                'Tunggu $_wait detik sebelum mengirim kembali. ${_failure?.retryAfter == null && _failure?.retryAt == null ? "Ini jeda lokal, bukan waktu reset kuota server/provider." : "Mengikuti waktu tunggu server."}',
              ),
            if (_attempted && !_isLoading)
              const Text(
                'Mengirim ulang dapat menghasilkan analisis baru. Tidak ada pengiriman ulang otomatis.',
              ),

            if (_resultData != null)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: indramayuBlue),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.check_circle,
                          color: Colors.green,
                          size: 30,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            "Hasil Diagnosa AI",
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 30, thickness: 1),
                    _buildResultRow("Penyakit:", _resultData!.disease),
                    const SizedBox(height: 10),
                    _buildResultRow("Kualitas Air:", _resultData!.waterQuality),
                    const SizedBox(height: 15),
                    Text(
                      "Solusi Penanganan:",
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      _resultData!.solution,
                      style: GoogleFonts.poppins(fontSize: 13, height: 1.5),
                    ),
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
        Text(
          title,
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: Colors.grey[700],
            fontSize: 13,
          ),
        ),
        Text(
          value ?? '-',
          style: GoogleFonts.poppins(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: indramayuBlue,
          ),
        ),
      ],
    );
  }
}
