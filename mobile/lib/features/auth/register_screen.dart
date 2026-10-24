import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/api_errors.dart';
import '../../widgets/error_box.dart';
import 'auth_layout.dart';
import 'auth_provider.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();

  bool _loading = false;
  bool _obscure = true;
  String? _error;
  Map<String, String> _fieldErrors = {};

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final auth = context.read<AuthProvider>();

    setState(() {
      _loading = true;
      _error = null;
      _fieldErrors = {};
    });

    try {
      await auth.register(_name.text.trim(), _email.text.trim(), _password.text);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = apiErrorMessage(e, fallback: 'Pendaftaran gagal. Coba lagi.');
        _fieldErrors = apiFieldErrors(e);
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthLayout(
      title: 'Daftar',
      subtitle: 'Buat akun gratis. Dompet dan kategori dibuatkan otomatis.',
      footer: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('Sudah punya akun?'),
          TextButton(onPressed: () => context.go('/login'), child: const Text('Masuk')),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            if (_error != null && _fieldErrors.isEmpty) ...[
              ErrorBox(_error!),
              const SizedBox(height: 16),
            ],
            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: 'Nama',
                border: const OutlineInputBorder(),
                errorText: _fieldErrors['name'],
              ),
              validator: (value) =>
                  (value == null || value.trim().isEmpty) ? 'Nama wajib diisi.' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: 'Email',
                border: const OutlineInputBorder(),
                errorText: _fieldErrors['email'],
              ),
              validator: (value) =>
                  (value == null || !value.contains('@')) ? 'Masukkan email yang valid.' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _password,
              obscureText: _obscure,
              decoration: InputDecoration(
                labelText: 'Kata sandi',
                helperText: 'Minimal 8 karakter.',
                border: const OutlineInputBorder(),
                errorText: _fieldErrors['password'],
                suffixIcon: IconButton(
                  icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
              validator: (value) =>
                  (value == null || value.length < 8) ? 'Minimal 8 karakter.' : null,
              onFieldSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _loading ? null : _submit,
                child: _loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Daftar'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}