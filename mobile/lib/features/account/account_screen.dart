import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/api_errors.dart';
import '../../core/ui.dart';
import '../../widgets/error_box.dart';
import '../auth/auth_provider.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  bool _loading = true;
  String? _error;
  String _name = '';
  String _email = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final response = await context.read<ApiClient>().dio.get('/me');
      final body = response.data as Map<String, dynamic>;
      final user = (body['data'] ?? body) as Map<String, dynamic>;

      if (!mounted) return;
      setState(() {
        _name = user['name'] as String;
        _email = user['email'] as String;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = apiErrorMessage(e, fallback: 'Gagal memuat profil.'));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Akun')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ErrorBox(_error!),
                        const SizedBox(height: 12),
                        OutlinedButton(onPressed: _load, child: const Text('Coba lagi')),
                      ],
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _ProfileCard(name: _name, email: _email),
                    const SizedBox(height: 16),
                    const _PasswordCard(),
                  ],
                ),
    );
  }
}

class _ProfileCard extends StatefulWidget {
  const _ProfileCard({required this.name, required this.email});

  final String name;
  final String email;

  @override
  State<_ProfileCard> createState() => _ProfileCardState();
}

class _ProfileCardState extends State<_ProfileCard> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name = TextEditingController(text: widget.name);
  late final TextEditingController _email = TextEditingController(text: widget.email);

  bool _saving = false;
  String? _error;
  Map<String, String> _fieldErrors = {};

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _saving = true;
      _error = null;
      _fieldErrors = {};
    });

    try {
      await context.read<ApiClient>().dio.put(
        '/me',
        data: {'name': _name.text.trim(), 'email': _email.text.trim()},
      );

      if (!mounted) return;
      context.read<AuthProvider>().refreshUser();
      setState(() => _saving = false);
      showMessage(context, 'Profil diperbarui.');
    } catch (e) {
      if (!mounted) return;

      final fieldErrors = apiFieldErrors(e);

      setState(() {
        _saving = false;
        _fieldErrors = fieldErrors;
        _error = fieldErrors.isEmpty
            ? apiErrorMessage(e, fallback: 'Gagal menyimpan profil.')
            : null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Profil',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),
              if (_error != null) ...[
                ErrorBox(_error!),
                const SizedBox(height: 12),
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
                validator: (value) {
                  final text = value?.trim() ?? '';
                  return (text.isEmpty || !text.contains('@')) ? 'Masukkan email yang valid.' : null;
                },
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: Text(_saving ? 'Menyimpan...' : 'Simpan profil'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PasswordCard extends StatefulWidget {
  const _PasswordCard();

  @override
  State<_PasswordCard> createState() => _PasswordCardState();
}

class _PasswordCardState extends State<_PasswordCard> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _current = TextEditingController();
  final TextEditingController _next = TextEditingController();
  final TextEditingController _confirm = TextEditingController();

  bool _saving = false;
  bool _obscure = true;
  String? _error;
  Map<String, String> _fieldErrors = {};

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _saving = true;
      _error = null;
      _fieldErrors = {};
    });

    try {
      await context.read<ApiClient>().dio.put(
        '/me/password',
        data: {'current_password': _current.text, 'password': _next.text},
      );

      if (!mounted) return;
      _current.clear();
      _next.clear();
      _confirm.clear();
      setState(() => _saving = false);
      showMessage(context, 'Kata sandi diubah.');
    } catch (e) {
      if (!mounted) return;

      final fieldErrors = apiFieldErrors(e);

      setState(() {
        _saving = false;
        _fieldErrors = fieldErrors;
        _error = fieldErrors.isEmpty
            ? apiErrorMessage(e, fallback: 'Gagal mengubah kata sandi.')
            : null;
      });
    }
  }

  InputDecoration _decoration(String label, String? errorText) {
    return InputDecoration(
      labelText: label,
      border: const OutlineInputBorder(),
      errorText: errorText,
      suffixIcon: IconButton(
        tooltip: _obscure ? 'Tampilkan' : 'Sembunyikan',
        icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
        onPressed: () => setState(() => _obscure = !_obscure),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Ubah kata sandi',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),
              if (_error != null) ...[
                ErrorBox(_error!),
                const SizedBox(height: 12),
              ],
              TextFormField(
                controller: _current,
                obscureText: _obscure,
                decoration: _decoration('Kata sandi saat ini', _fieldErrors['current_password']),
                validator: (value) =>
                    (value == null || value.isEmpty) ? 'Masukkan kata sandi saat ini.' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _next,
                obscureText: _obscure,
                decoration: _decoration('Kata sandi baru', _fieldErrors['password']),
                validator: (value) =>
                    (value == null || value.length < 8) ? 'Minimal 8 karakter.' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _confirm,
                obscureText: _obscure,
                decoration: _decoration('Ulangi kata sandi baru', null),
                validator: (value) =>
                    value != _next.text ? 'Konfirmasi kata sandi tidak sama.' : null,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: Text(_saving ? 'Menyimpan...' : 'Ubah kata sandi'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}