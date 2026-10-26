import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/api_errors.dart';
import '../../core/format.dart';
import '../../widgets/error_box.dart';
import '../categories/category.dart';
import '../categories/category_repository.dart';
import 'budget.dart';
import 'budget_repository.dart';

class BudgetFormSheet extends StatefulWidget {
  const BudgetFormSheet({super.key, required this.month, this.budget});

  final String month;
  final Budget? budget;

  /// Mengembalikan pesan sukses dari server, atau null bila ditutup tanpa menyimpan.
  static Future<String?> show(BuildContext context, {required String month, Budget? budget}) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => BudgetFormSheet(month: month, budget: budget),
    );
  }

  @override
  State<BudgetFormSheet> createState() => _BudgetFormSheetState();
}

class _BudgetFormSheetState extends State<BudgetFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _amount = TextEditingController();

  List<Category> _categories = [];
  int? _categoryId;
  bool _loadingCategories = true;
  bool _saving = false;
  String? _error;
  Map<String, String> _fieldErrors = {};

  bool get _editing => widget.budget != null;

  @override
  void initState() {
    super.initState();

    final budget = widget.budget;
    if (budget != null) {
      _categoryId = budget.categoryId;
      _amount.text = '${budget.amount}';
    }

    _loadCategories();
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    try {
      final categories = await CategoryRepository(context.read<ApiClient>()).list('expense');
      if (!mounted) return;
      setState(() => _categories = categories);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = apiErrorMessage(e, fallback: 'Gagal memuat kategori.'));
    } finally {
      if (mounted) setState(() => _loadingCategories = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final repository = BudgetRepository(context.read<ApiClient>());

    setState(() {
      _saving = true;
      _error = null;
      _fieldErrors = {};
    });

    try {
      final message = await repository.save(
        categoryId: _categoryId!,
        month: widget.month,
        amount: int.parse(_amount.text),
      );

      if (!mounted) return;
      Navigator.of(context).pop(message);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = apiErrorMessage(e, fallback: 'Gagal menyimpan anggaran.');
        _fieldErrors = apiFieldErrors(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
                _editing ? 'Ubah anggaran' : 'Atur anggaran',
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
              ),
              Text(
                formatMonthLabel(widget.month),
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.outline),
              ),
              const SizedBox(height: 16),
              if (_error != null && _fieldErrors.isEmpty) ...[
                ErrorBox(_error!),
                const SizedBox(height: 12),
              ],
              if (_loadingCategories)
                const LinearProgressIndicator()
              else
                DropdownButtonFormField<int>(
                  initialValue: _categoryId,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: 'Kategori pengeluaran',
                    helperText: _editing
                        ? null
                        : 'Kategori yang sudah punya anggaran bulan ini akan diperbarui.',
                    helperMaxLines: 2,
                    border: const OutlineInputBorder(),
                    errorText: _fieldErrors['category_id'],
                  ),
                  items: [
                    for (final category in _categories)
                      DropdownMenuItem(value: category.id, child: Text(category.name)),
                  ],
                  onChanged: _editing ? null : (value) => setState(() => _categoryId = value),
                  validator: (value) => value == null ? 'Pilih kategori.' : null,
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
                  labelText: 'Batas anggaran (Rp)',
                  border: const OutlineInputBorder(),
                  errorText: _fieldErrors['amount'],
                ),
                validator: (value) {
                  final amount = int.tryParse(value ?? '');
                  return (amount == null || amount < 1) ? 'Masukkan batas anggaran.' : null;
                },
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
                    onPressed: _saving || _loadingCategories ? null : _save,
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