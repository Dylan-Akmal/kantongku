import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/api_errors.dart';
import '../../core/labels.dart';
import '../../widgets/error_box.dart';
import 'wallet.dart';
import 'wallet_repository.dart';

class WalletFormSheet extends StatefulWidget {
  const WalletFormSheet({super.key, this.wallet});

  final Wallet? wallet;

  /// Mengembalikan true bila dompet berhasil disimpan.
  static Future<bool?> show(BuildContext context, {Wallet? wallet}) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => WalletFormSheet(wallet: wallet),
    );
  }

  @override
  State<WalletFormSheet> createState() => _WalletFormSheetState();
}

class _WalletFormSheetState extends State<WalletFormSheet> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _name =
      TextEditingController(text: widget.wallet?.name ?? '');
  late final TextEditingController _balance =
      TextEditingController(text: '${widget.wallet?.initialBalance ?? 0}');
  late String _type = widget.wallet?.type ?? 'bank';

  bool _saving = false;
  String? _error;
  Map<String, String> _fieldErrors = {};

  bool get _editing => widget.wallet != null;

  @override
  void dispose() {
    _name.dispose();
    _balance.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final repository = WalletRepository(context.read<ApiClient>());
    final balance = int.tryParse(_balance.text) ?? 0;

    setState(() {
      _saving = true;
      _error = null;
      _fieldErrors = {};
    });

    try {
      if (_editing) {
        await repository.update(
          widget.wallet!.id,
          name: _name.text.trim(),
          type: _type,
          initialBalance: balance,
        );
      } else {
        await repository.create(
          name: _name.text.trim(),
          type: _type,
          initialBalance: balance,
        );
      }

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = apiErrorMessage(e, fallback: 'Gagal menyimpan dompet.');
        _fieldErrors = apiFieldErrors(e);
      });
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        20 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _editing ? 'Ubah dompet' : 'Tambah dompet',
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),
              if (_error != null && _fieldErrors.isEmpty) ...[
                ErrorBox(_error!),
                const SizedBox(height: 12),
              ],
              TextFormField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                inputFormatters: [LengthLimitingTextInputFormatter(50)],
                decoration: InputDecoration(
                  labelText: 'Nama',
                  hintText: 'Contoh: BCA, GoPay',
                  border: const OutlineInputBorder(),
                  errorText: _fieldErrors['name'],
                ),
                validator: (value) =>
                    (value == null || value.trim().isEmpty) ? 'Nama wajib diisi.' : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _type,
                decoration: InputDecoration(
                  labelText: 'Jenis',
                  border: const OutlineInputBorder(),
                  errorText: _fieldErrors['type'],
                ),
                items: [
                  for (final entry in walletTypeLabels.entries)
                    DropdownMenuItem(value: entry.key, child: Text(entry.value)),
                ],
                onChanged: (value) => setState(() => _type = value ?? _type),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _balance,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(12),
                ],
                decoration: InputDecoration(
                  labelText: 'Saldo awal (Rp)',
                  border: const OutlineInputBorder(),
                  errorText: _fieldErrors['initial_balance'],
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _saving ? null : () => Navigator.of(context).pop(false),
                    child: const Text('Batal'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _saving ? null : _save,
                    child: Text(_saving ? 'Menyimpan...' : 'Simpan'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}