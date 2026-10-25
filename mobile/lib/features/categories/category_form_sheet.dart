import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/api_client.dart';
import '../../../core/api_errors.dart';
import '../../../widgets/error_box.dart';
import 'category.dart';
import 'category_repository.dart';

class CategoryFormSheet extends StatefulWidget {
  const CategoryFormSheet({super.key, required this.type, this.category});

  final String type;
  final Category? category;

  /// Mengembalikan true bila kategori berhasil disimpan.
  static Future<bool?> show(BuildContext context, {required String type, Category? category}) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => CategoryFormSheet(type: type, category: category),
    );
  }

  @override
  State<CategoryFormSheet> createState() => _CategoryFormSheetState();
}

class _CategoryFormSheetState extends State<CategoryFormSheet> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _name =
      TextEditingController(text: widget.category?.name ?? '');

  bool _saving = false;
  String? _error;
  Map<String, String> _fieldErrors = {};

  bool get _editing => widget.category != null;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final repository = CategoryRepository(context.read<ApiClient>());

    setState(() {
      _saving = true;
      _error = null;
      _fieldErrors = {};
    });

    try {
      if (_editing) {
        await repository.rename(widget.category!.id, _name.text.trim());
      } else {
        await repository.create(name: _name.text.trim(), type: widget.type);
      }

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = apiErrorMessage(e, fallback: 'Gagal menyimpan kategori.');
        _fieldErrors = apiFieldErrors(e);
      });
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final typeLabel = widget.type == 'expense' ? 'pengeluaran' : 'pemasukan';

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
                _editing ? 'Ubah nama kategori' : 'Tambah kategori',
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),
              if (_error != null && _fieldErrors.isEmpty) ...[
                ErrorBox(_error!),
                const SizedBox(height: 12),
              ],
              TextFormField(
                controller: _name,
                textCapitalization: TextCapitalization.sentences,
                inputFormatters: [LengthLimitingTextInputFormatter(50)],
                decoration: InputDecoration(
                  labelText: 'Nama',
                  helperText: _editing
                      ? 'Jenis kategori tidak bisa diubah setelah dibuat.'
                      : 'Kategori ini untuk $typeLabel.',
                  border: const OutlineInputBorder(),
                  errorText: _fieldErrors['name'],
                ),
                validator: (value) =>
                    (value == null || value.trim().isEmpty) ? 'Nama wajib diisi.' : null,
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