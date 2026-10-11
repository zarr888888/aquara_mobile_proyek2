import 'dart:async';
import 'package:flutter/material.dart';
import '../services/api_result.dart';
import '../services/api_service.dart';
import '../services/auth_cooldown.dart';
import 'home_screen.dart';
import 'login_screen.dart';
import 'register_screen.dart';
import 'lupa_password_screen.dart';
import 'otp_screen.dart';

enum AuthFormMode { login, register, reset }

class AuthFormScreen extends StatefulWidget {
  const AuthFormScreen({
    super.key,
    required this.mode,
    this.api,
    this.onAuthenticated,
  });
  final AuthFormMode mode;
  final ApiService? api;
  final VoidCallback? onAuthenticated;
  @override
  State<AuthFormScreen> createState() => _AuthFormScreenState();
}

class _AuthFormScreenState extends State<AuthFormScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  late final ApiService _api = widget.api ?? ApiService();
  bool _busy = false;
  bool _hidden = true;
  String _method = 'wa';
  String? _message;
  Timer? _timer;
  Map<String, List<String>> _errors = {};
  bool get _register => widget.mode == AuthFormMode.register;
  bool get _reset => widget.mode == AuthFormMode.reset;
  int get _wait => AuthCooldown.instance.remaining('auth');

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
    for (final c in [_name, _email, _phone, _password]) {
      c.dispose();
    }
    super.dispose();
  }

  void _authenticated() {
    _password.clear();
    if (widget.onAuthenticated != null) {
      widget.onAuthenticated!();
      return;
    }
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const HomeScreen()),
      (_) => false,
    );
  }

  void _failure(ApiResult<Object?> result, {bool passwordLogin = false}) {
    AuthCooldown.instance.record(result, 'auth');
    _errors = result.failure?.fieldErrors ?? {};
    _message = passwordLogin && result.statusCode == 401
        ? 'Email/nomor HP atau kata sandi salah.'
        : result.failure?.message ?? 'Permintaan gagal.';
    _form.currentState?.validate();
  }

  Future<void> _openOtp(
    OtpPurpose purpose,
    String identifier, {
    String? password,
  }) async {
    _password.clear();
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OtpScreen(
          identifier: identifier,
          purpose: purpose,
          method: _method,
          newPassword: password,
          api: _api,
          onAuthenticated: widget.onAuthenticated,
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (_busy || _wait > 0) return;
    setState(() {
      _errors = {};
      _message = null;
    });
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      if (_reset) {
        await _openOtp(
          OtpPurpose.reset,
          _email.text.trim(),
          password: _password.text,
        );
      } else if (_register) {
        final result = await _api.registerUser(
          _name.text.trim(),
          _email.text.trim(),
          _phone.text.trim(),
          _password.text,
        );
        if (!mounted) return;
        if (result.isSuccess) {
          final identifier = _phone.text.trim();
          _password.clear();
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => OtpScreen(
                identifier: identifier,
                purpose: OtpPurpose.register,
                method: _method,
                api: _api,
                onAuthenticated: widget.onAuthenticated,
              ),
            ),
          );
        } else {
          _failure(result);
        }
      } else {
        final id = _email.text.trim();
        final result = await _api.loginUser(id, _password.text);
        if (!mounted) return;
        if (result.isSuccess) {
          _authenticated();
        } else if (result.statusCode == 403) {
          await _openOtp(OtpPurpose.register, id);
        } else {
          _failure(result, passwordLogin: true);
        }
      }
    } catch (_) {
      if (mounted) {
        _message = 'Layanan autentikasi tidak tersedia. Silakan coba kembali.';
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _google() async {
    if (_busy || _wait > 0) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final result = await _api.loginWithGoogle();
      if (!mounted) return;
      if (result.isSuccess) {
        _authenticated();
      } else {
        _failure(result);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String? _server(String key) => _errors[key]?.join(' ');
  bool _validEmail(String v) =>
      v.length <= 255 && RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(v);
  bool _validPhone(String v) => RegExp(r'^\+?[0-9]{10,15}$').hasMatch(v);

  @override
  Widget build(BuildContext context) {
    final disabled = _busy || _wait > 0;
    final title = _register
        ? 'Daftar SAMUDERA'
        : _reset
        ? 'Reset kata sandi'
        : 'Masuk SAMUDERA';
    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        appBar: AppBar(title: Text(title)),
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
                      if (_register)
                        TextFormField(
                          controller: _name,
                          enabled: !_busy,
                          decoration: const InputDecoration(
                            labelText: 'Nama lengkap',
                          ),
                          validator: (v) =>
                              _server('name') ??
                              ((v ?? '').trim().isEmpty || v!.length > 255
                                  ? 'Nama wajib, maksimal 255 karakter.'
                                  : null),
                        ),
                      TextFormField(
                        controller: _email,
                        enabled: !_busy,
                        keyboardType: _register
                            ? TextInputType.emailAddress
                            : TextInputType.text,
                        autofillHints: const [AutofillHints.username],
                        decoration: InputDecoration(
                          labelText: _register
                              ? 'Email (opsional)'
                              : 'Email / nomor HP',
                        ),
                        validator: (v) {
                          final value = (v ?? '').trim();
                          if (_register && value.isEmpty) {
                            return _server('email');
                          }
                          return _server(_register ? 'email' : 'login_id') ??
                              (_validEmail(value) ||
                                      (!_register && _validPhone(value))
                                  ? null
                                  : 'Masukkan email atau nomor HP yang valid.');
                        },
                      ),
                      if (_register)
                        TextFormField(
                          controller: _phone,
                          enabled: !_busy,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(
                            labelText: 'Nomor WhatsApp',
                          ),
                          validator: (v) =>
                              _server('phone') ??
                              (_validPhone((v ?? '').trim()) &&
                                      v!.trim().length <= 15
                                  ? null
                                  : 'Nomor WA 10–15 karakter, format konsisten.'),
                        ),
                      TextFormField(
                        controller: _password,
                        enabled: !_busy,
                        obscureText: _hidden,
                        autocorrect: false,
                        enableSuggestions: false,
                        autofillHints: [
                          _register || _reset
                              ? AutofillHints.newPassword
                              : AutofillHints.password,
                        ],
                        decoration: InputDecoration(
                          labelText: _reset ? 'Kata sandi baru' : 'Kata sandi',
                          suffixIcon: IconButton(
                            tooltip: 'Tampilkan/sembunyikan kata sandi',
                            onPressed: _busy
                                ? null
                                : () => setState(() => _hidden = !_hidden),
                            icon: Icon(
                              _hidden ? Icons.visibility : Icons.visibility_off,
                            ),
                          ),
                        ),
                        validator: (v) {
                          final value = v ?? '';
                          return _server(
                                _reset ? 'new_password' : 'password',
                              ) ??
                              (value.length <
                                          (_reset
                                              ? 12
                                              : _register
                                              ? 6
                                              : 1) ||
                                      (_reset && value.length > 128)
                                  ? (_reset
                                        ? 'Password baru harus 12–128 karakter.'
                                        : 'Kata sandi tidak valid (daftar minimal 6 karakter).')
                                  : null);
                        },
                      ),
                      const SizedBox(height: 16),
                      if (_register || _reset)
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
                          onChanged: _busy
                              ? null
                              : (v) => setState(() => _method = v!),
                          validator: (_) =>
                              _register &&
                                  _method == 'email' &&
                                  _email.text.trim().isEmpty
                              ? 'Isi email untuk kanal email.'
                              : null,
                        ),
                      if (_message != null)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Text(
                            _message!,
                            key: const Key('auth_error'),
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ),
                      if (_wait > 0)
                        Text('Tunggu $_wait detik sebelum mencoba kembali.'),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: disabled ? null : _submit,
                        child: _busy
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(),
                              )
                            : Text(
                                _register
                                    ? 'Daftar'
                                    : _reset
                                    ? 'Lanjut verifikasi OTP'
                                    : 'Masuk',
                              ),
                      ),
                      if (!_reset) ...[
                        OutlinedButton(
                          onPressed: disabled
                              ? null
                              : () async {
                                  setState(() => _busy = true);
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => OtpScreen(
                                        identifier: '',
                                        purpose: OtpPurpose.login,
                                        method: 'wa',
                                        api: _api,
                                        onAuthenticated: widget.onAuthenticated,
                                      ),
                                    ),
                                  );
                                  if (mounted) setState(() => _busy = false);
                                },
                          child: const Text('Masuk dengan WhatsApp'),
                        ),
                        OutlinedButton(
                          onPressed: disabled ? null : _google,
                          child: const Text('Masuk dengan Google'),
                        ),
                      ],
                      if (!_register && !_reset) ...[
                        TextButton(
                          onPressed: disabled
                              ? null
                              : () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => RegisterScreen(api: _api),
                                  ),
                                ),
                          child: const Text('Buat akun'),
                        ),
                        TextButton(
                          onPressed: disabled
                              ? null
                              : () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        LupaPasswordScreen(api: _api),
                                  ),
                                ),
                          child: const Text('Lupa kata sandi?'),
                        ),
                      ],
                      if (_register || _reset)
                        TextButton(
                          onPressed: disabled
                              ? null
                              : () => Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => LoginScreen(api: _api),
                                  ),
                                ),
                          child: const Text('Kembali ke login'),
                        ),
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
}
