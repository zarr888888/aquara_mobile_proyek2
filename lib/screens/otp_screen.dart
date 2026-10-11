import '../widgets/session_boundary.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_result.dart';
import '../services/api_service.dart';
import '../services/auth_cooldown.dart';
import 'home_screen.dart';
import 'login_screen.dart';

enum OtpPurpose { register, login, reset, contact, delete }

class OtpScreen extends StatelessWidget {
  const OtpScreen({
    super.key,
    required this.identifier,
    required this.purpose,
    required this.method,
    this.newPassword,
    this.api,
    this.onAuthenticated,
  });
  final String identifier;
  final OtpPurpose purpose;
  final String method;
  final String? newPassword;
  final ApiService? api;
  final VoidCallback? onAuthenticated;
  @override
  Widget build(BuildContext context) {
    Widget content() => _OtpScreenContent(
      identifier: identifier,
      purpose: purpose,
      method: method,
      newPassword: newPassword,
      api: api,
      onAuthenticated: onAuthenticated,
    );
    if (purpose != OtpPurpose.contact && purpose != OtpPurpose.delete) {
      return content();
    }
    return SessionBoundary(api: api, builder: (_) => content());
  }
}

class _OtpScreenContent extends StatefulWidget {
  const _OtpScreenContent({
    required this.identifier,
    required this.purpose,
    required this.method,
    this.newPassword,
    this.api,
    this.onAuthenticated,
  });
  final String identifier;
  final OtpPurpose purpose;
  final String method;
  final String? newPassword;
  final ApiService? api;
  final VoidCallback? onAuthenticated;
  @override
  State<_OtpScreenContent> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<_OtpScreenContent> {
  final _form = GlobalKey<FormState>();
  final _otp = TextEditingController();
  late final _identifier = TextEditingController(text: widget.identifier);
  late final ApiService _api = widget.api ?? ApiService();
  late final int _ownerRevision = _api.session.revision;
  bool get _private =>
      widget.purpose == OtpPurpose.contact ||
      widget.purpose == OtpPurpose.delete;
  bool get _current => !_private || _ownerRevision == _api.session.revision;
  late String _method = widget.method;
  bool _busy = false;
  bool _sent = false;
  bool _needsNewCode = false;
  DateTime? _expires;
  String? _message;
  Timer? _timer;
  int get _wait => AuthCooldown.instance.remaining('otp');
  bool get _expired => _expires != null && !DateTime.now().isBefore(_expires!);
  bool get _canVerify => _sent && !_expired && !_needsNewCode && !_busy;
  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _otp.dispose();
    _identifier.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_busy || _wait > 0) return;
    final id = _identifier.text.trim();
    if (widget.purpose == OtpPurpose.login &&
        !RegExp(r'^\+?[0-9]{10,15}$').hasMatch(id)) {
      setState(
        () => _message = 'Nomor WA wajib 10–15 digit, awalan + opsional.',
      );
      return;
    }
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final result = await switch (widget.purpose) {
        OtpPurpose.register => _api.requestRegistrationOtp(id, _method),
        OtpPurpose.login => _api.sendOtpWa(id),
        OtpPurpose.reset => _api.requestResetOtp(id, _method),
        OtpPurpose.contact => _api.requestUbahKontakOtp(id, _method),
        OtpPurpose.delete => _api.requestHapusAkunOtp(_method),
      };
      if (!mounted || !_current) return;
      if (result.isSuccess) {
        _sent = true;
        _needsNewCode = false;
        _otp.clear();
        _expires = DateTime.now().add(const Duration(minutes: 5));
        AuthCooldown.instance.wait('otp', const Duration(seconds: 60));
        _message = 'Kode dikirim. Berlaku 5 menit. Gunakan kode terbaru.';
      } else {
        _error(result);
      }
    } catch (_) {
      if (mounted && _current) {
        _message = 'Tidak dapat mengirim OTP. Silakan coba kembali.';
      }
    } finally {
      if (mounted && _current) setState(() => _busy = false);
    }
  }

  void _error(ApiResult<Object?> result) {
    if (result.failure?.kind == ApiErrorKind.unauthenticated) {
      if (widget.purpose == OtpPurpose.contact ||
          widget.purpose == OtpPurpose.delete) {
        return;
      }
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => LoginScreen(api: _api)),
        (_) => false,
      );
      return;
    }
    _message = result.statusCode == 401
        ? 'Kode OTP salah, kedaluwarsa, atau sudah digunakan.'
        : result.failure?.message ?? 'Verifikasi gagal.';
    if (result.statusCode == 429) {
      AuthCooldown.instance.record(result, 'otp');
      _needsNewCode = true;
      _message =
          '${_message!} Setelah waktu tunggu, minta kode baru sebelum verifikasi.';
    }
  }

  Future<void> _verify() async {
    if (!_canVerify || !_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final id = _identifier.text.trim();
      final result = await switch (widget.purpose) {
        OtpPurpose.register => _api.verifyRegistrationOtp(id, _otp.text),
        OtpPurpose.login => _api.verifyOtpWa(id, _otp.text),
        OtpPurpose.reset => _api.resetPasswordWithOtp(
          id,
          _otp.text,
          widget.newPassword ?? '',
        ),
        OtpPurpose.contact => _api.ubahKontak(_method, id, _otp.text),
        OtpPurpose.delete => _api.hapusAkun(_otp.text),
      };
      if (!mounted || !_current) return;
      if (result.isSuccess) {
        _otp.clear();
        if (widget.purpose == OtpPurpose.register ||
            widget.purpose == OtpPurpose.login) {
          if (widget.onAuthenticated != null) {
            widget.onAuthenticated!();
          } else {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const HomeScreen()),
              (_) => false,
            );
          }
        } else if (widget.purpose == OtpPurpose.reset) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => LoginScreen(api: _api)),
            (_) => false,
          );
        }
      } else {
        _error(result);
      }
    } catch (_) {
      if (mounted && _current) {
        _message = 'Tidak dapat memverifikasi OTP. Silakan coba kembali.';
      }
    } finally {
      if (mounted && _current) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: Scaffold(
      appBar: AppBar(title: const Text('Verifikasi OTP')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Form(
                key: _form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      widget.purpose == OtpPurpose.register
                          ? 'Akun belum aktif. Kirim kode untuk menyelesaikan verifikasi registrasi.'
                          : widget.purpose == OtpPurpose.delete
                          ? 'Konfirmasi penghapusan akun dengan OTP.'
                          : 'Kirim kode verifikasi melalui kanal yang dipilih.',
                    ),
                    if (widget.purpose != OtpPurpose.delete)
                      TextFormField(
                        controller: _identifier,
                        enabled:
                            widget.purpose == OtpPurpose.login &&
                            !_sent &&
                            !_busy,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'Email / nomor tujuan atau akun',
                        ),
                      ),
                    if (widget.purpose == OtpPurpose.register ||
                        widget.purpose == OtpPurpose.reset ||
                        widget.purpose == OtpPurpose.delete)
                      DropdownButtonFormField<String>(
                        initialValue: _method,
                        decoration: const InputDecoration(
                          labelText: 'Kanal OTP',
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'wa',
                            child: Text('WhatsApp'),
                          ),
                          DropdownMenuItem(
                            value: 'email',
                            child: Text('Email'),
                          ),
                        ],
                        onChanged: _busy || _sent
                            ? null
                            : (v) => setState(() => _method = v!),
                      ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _otp,
                      enabled: _sent && !_busy,
                      keyboardType: TextInputType.number,
                      autofillHints: const [AutofillHints.oneTimeCode],
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(6),
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Kode OTP 6 digit',
                      ),
                      validator: (v) => RegExp(r'^[0-9]{6}$').hasMatch(v ?? '')
                          ? null
                          : 'OTP wajib tepat 6 digit.',
                    ),
                    if (_message != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text(_message!),
                      ),
                    if (_expired)
                      const Text('Kode sudah kedaluwarsa. Minta kode baru.'),
                    if (_wait > 0)
                      Text('Kirim ulang tersedia dalam $_wait detik.'),
                    const Text(
                      'Kode baru menggantikan kode sebelumnya, termasuk kode untuk tujuan lain. Batas pengiriman dan percobaan ditentukan server.',
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _canVerify ? _verify : null,
                      child: const Text('Verifikasi'),
                    ),
                    OutlinedButton(
                      onPressed: _busy || _wait > 0 ? null : _send,
                      child: Text(_sent ? 'Kirim ulang OTP' : 'Kirim OTP'),
                    ),
                    if (_busy) const Center(child: CircularProgressIndicator()),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
