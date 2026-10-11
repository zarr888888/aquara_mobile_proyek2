import '../widgets/session_boundary.dart';
import 'package:flutter/material.dart';
import 'otp_screen.dart';

class UbahKontakScreen extends StatelessWidget {
  const UbahKontakScreen({super.key});
  @override
  Widget build(BuildContext context) => SessionBoundary(
    private: true,
    builder: (_) => const _UbahKontakScreenContent(),
  );
}

class _UbahKontakScreenContent extends StatefulWidget {
  const _UbahKontakScreenContent();
  @override
  State<_UbahKontakScreenContent> createState() => _UbahKontakScreenState();
}

class _UbahKontakScreenState extends State<_UbahKontakScreenContent>
    with SessionOwnedState<_UbahKontakScreenContent> {
  final _form = GlobalKey<FormState>();
  final _target = TextEditingController();
  String _method = 'wa';
  @override
  void dispose() {
    _target.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Ubah kontak')),
    body: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Ubah satu kontak per verifikasi. Setelah berhasil, semua sesi akan dicabut dan Anda perlu login kembali.',
              ),
              DropdownButtonFormField<String>(
                initialValue: _method,
                items: const [
                  DropdownMenuItem(value: 'wa', child: Text('WhatsApp')),
                  DropdownMenuItem(value: 'email', child: Text('Email')),
                ],
                onChanged: (value) => setState(() => _method = value!),
              ),
              TextFormField(
                controller: _target,
                decoration: const InputDecoration(labelText: 'Kontak baru'),
                validator: (value) {
                  final text = (value ?? '').trim();
                  final valid = _method == 'wa'
                      ? RegExp(r'^\+?[0-9]{10,15}$').hasMatch(text)
                      : text.length <= 255 &&
                            RegExp(
                              r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
                            ).hasMatch(text);
                  return valid ? null : 'Kontak tidak valid.';
                },
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () {
                  if (!_form.currentState!.validate()) return;
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => OtpScreen(
                        identifier: _target.text.trim(),
                        purpose: OtpPurpose.contact,
                        method: _method,
                      ),
                    ),
                  );
                },
                child: const Text('Lanjut verifikasi'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
