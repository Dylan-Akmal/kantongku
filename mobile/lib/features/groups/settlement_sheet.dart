import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/api_errors.dart';
import '../../widgets/error_box.dart';
import '../auth/auth_provider.dart';
import 'group.dart';
import 'group_finance_repository.dart';

class SettlementSheet extends StatefulWidget {
  const SettlementSheet({super.key, required this.group, this.toUserId, this.amount});

  final Group group;
  final int? toUserId;
  final int? amount;

  /// Mengembalikan true bila pelunasan berhasil dicatat.
  static Future<bool?> show(
    BuildContext context, {
    required Group group,
    int? toUserId,
    int? amount,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => SettlementSheet(group: group, toUserId: toUserId, amount: amount),
    );
  }

  @override
  State<SettlementSheet> createState() => _SettlementSheetState();
}

class _SettlementSheetState extends State<SettlementSheet> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _amount = TextEditingController();
  final TextEditingController _note = TextEditingController();

  int? _toUserId;
  bool _saving = false;
  String? _error;
  Map<String, String> _fieldErrors = {};

  @override
  void initState() {
    super.initState();
    _toUserId = widget.toUserId;
    if (widget.amount != null) _amount.text = '${widget.amount}';
  }

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final repository = GroupFinanceRepository(context.read<ApiClient>());

    setState(() {
      _saving = true;
      _error = null;
      _fieldErrors = {};
    });

    try {
      await repository.createSettlement(
        widget.group.id,
        toUserId: _toUserId!,
        amount: int.parse(_amount.text),
        note: _note.text,
      );

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = apiErrorMessage(e, fallback: 'Gagal mencatat pelunasan.');
        _fieldErrors = apiFieldErrors(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final myId = context.watch<AuthProvider>().userId;
    final others = widget.group.members.where((member) => member.id != myId).toList();

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Catat pelunasan',
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),
              if (_error != null && _fieldErrors.isEmpty) ...[
                ErrorBox(_error!),
                const SizedBox(height: 12),
              ],
              DropdownButtonFormField<int>(
                initialValue: _toUserId,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: 'Dibayarkan kepada',
                  border: const OutlineInputBorder(),
                  errorText: _fieldErrors['to_user_id'],
                ),
                items: [
                  for (final member in others)
                    DropdownMenuItem(value: member.id, child: Text(member.name)),
                ],
                onChanged: (value) => setState(() => _toUserId = value),
                validator: (value) => value == null ? 'Pilih anggota.' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _amount,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(12),
                ],
                decoration: InputDecoration(
                  labelText: 'Nominal (Rp)',
                  helperText: 'Aplikasi hanya mencatat. Pembayarannya kamu lakukan di luar aplikasi.',
                  helperMaxLines: 2,
                  border: const OutlineInputBorder(),
                  errorText: _fieldErrors['amount'],
                ),
                validator: (value) {
                  final amount = int.tryParse(value ?? '');
                  return (amount == null || amount < 1) ? 'Masukkan nominal.' : null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _note,
                inputFormatters: [LengthLimitingTextInputFormatter(255)],
                decoration: const InputDecoration(
                  labelText: 'Catatan (opsional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _saving ? null : () => Navigator.of(context).pop(),
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