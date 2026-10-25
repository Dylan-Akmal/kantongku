import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/api_errors.dart';
import '../../core/ui.dart';
import '../../widgets/error_box.dart';
import '../categories/category.dart';
import '../categories/category_repository.dart';
import '../wallets/wallet.dart';
import '../wallets/wallet_repository.dart';
import 'transaction.dart';
import 'transaction_repository.dart';

class TransactionFormScreen extends StatefulWidget {
  const TransactionFormScreen({super.key, this.transaction});

  final Transaction? transaction;

  @override
  State<TransactionFormScreen> createState() => _TransactionFormScreenState();
}

class _TransactionFormScreenState extends State<TransactionFormScreen> {
  final _formKey = GlobalKey<FormState>();

  late final WalletRepository _walletRepository = WalletRepository(context.read<ApiClient>());
  late final CategoryRepository _categoryRepository =
      CategoryRepository(context.read<ApiClient>());
  late final TransactionRepository _transactionRepository =
      TransactionRepository(context.read<ApiClient>());

  final TextEditingController _amount = TextEditingController();
  final TextEditingController _note = TextEditingController();

  List<Wallet> _wallets = [];
  List<Category> _categories = [];
  bool _loadingOptions = true;
  String? _loadError;

  String _type = 'expense';
  int? _walletId;
  int? _toWalletId;
  int? _categoryId;
  DateTime _date = DateTime.now();

  bool _saving = false;
  String? _error;
  Map<String, String> _fieldErrors = {};

  bool get _editing => widget.transaction != null;

  @override
  void initState() {
    super.initState();

    final transaction = widget.transaction;
    if (transaction != null) {
      _type = transaction.type;
      _walletId = transaction.walletId;
      _toWalletId = transaction.toWalletId;
      _categoryId = transaction.categoryId;
      _date = DateTime.parse(transaction.date);
      _amount.text = '${transaction.amount}';
      _note.text = transaction.note ?? '';
    }

    _loadOptions();
  }

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _loadOptions() async {
    setState(() {
      _loadingOptions = true;
      _loadError = null;
    });

    try {
      final (walletList, expense, income) = await (
        _walletRepository.list(),
        _categoryRepository.list('expense'),
        _categoryRepository.list('income'),
      ).wait;

      if (!mounted) return;
      setState(() {
        _wallets = walletList.wallets;
        _categories = [...expense, ...income];

        // Pilihan yang tidak ada lagi (mis. dompet diarsipkan) dikosongkan agar dipilih ulang.
        if (!_wallets.any((wallet) => wallet.id == _walletId)) _walletId = null;
        if (!_wallets.any((wallet) => wallet.id == _toWalletId)) _toWalletId = null;
        if (!_categories.any((category) => category.id == _categoryId)) _categoryId = null;

        if (!_editing && _walletId == null && _wallets.isNotEmpty) {
          _walletId = _wallets.first.id;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadError = apiErrorMessage(e, fallback: 'Gagal memuat dompet dan kategori.'));
    } finally {
      if (mounted) setState(() => _loadingOptions = false);
    }
  }

  List<Category> get _visibleCategories =>
      _categories.where((category) => category.type == _type).toList();

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (picked != null && mounted) setState(() => _date = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final isTransfer = _type == 'transfer';
    final input = TransactionInput(
      type: _type,
      walletId: _walletId!,
      toWalletId: isTransfer ? _toWalletId : null,
      categoryId: isTransfer ? null : _categoryId,
      amount: int.parse(_amount.text),
      date: DateFormat('yyyy-MM-dd').format(_date),
      note: _note.text,
    );

    setState(() {
      _saving = true;
      _error = null;
      _fieldErrors = {};
    });

    try {
      if (_editing) {
        await _transactionRepository.update(widget.transaction!.id, input);
      } else {
        await _transactionRepository.create(input);
      }

      if (!mounted) return;
      showMessage(context, _editing ? 'Transaksi diperbarui.' : 'Transaksi dicatat.');
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = apiErrorMessage(e, fallback: 'Gagal menyimpan transaksi.');
        _fieldErrors = apiFieldErrors(e);
      });
    }
  }

  Future<void> _delete() async {
    final confirmed = await confirmDialog(
      context,
      title: 'Hapus transaksi',
      message: 'Hapus transaksi ini? Saldo dompet akan dihitung ulang.',
      confirmText: 'Hapus',
      destructive: true,
    );

    if (!confirmed || !mounted) return;

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await _transactionRepository.delete(widget.transaction!.id);

      if (!mounted) return;
      showMessage(context, 'Transaksi dihapus.');
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = apiErrorMessage(e, fallback: 'Gagal menghapus transaksi.');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isTransfer = _type == 'transfer';

    return Scaffold(
      appBar: AppBar(
        title: Text(_editing ? 'Ubah transaksi' : 'Catat transaksi'),
        actions: [
          if (_editing)
            IconButton(
              tooltip: 'Hapus',
              icon: const Icon(Icons.delete_outline),
              onPressed: _saving ? null : _delete,
            ),
        ],
      ),
      body: _loadingOptions
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ErrorBox(_loadError!),
                        const SizedBox(height: 12),
                        OutlinedButton(onPressed: _loadOptions, child: const Text('Coba lagi')),
                      ],
                    ),
                  ),
                )
              : Form(
                  key: _formKey,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      if (_error != null && _fieldErrors.isEmpty) ...[
                        ErrorBox(_error!),
                        const SizedBox(height: 16),
                      ],
                      SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(value: 'expense', label: Text('Pengeluaran')),
                          ButtonSegment(value: 'income', label: Text('Pemasukan')),
                          ButtonSegment(value: 'transfer', label: Text('Transfer')),
                        ],
                        selected: {_type},
                        onSelectionChanged: (selection) => setState(() {
                          _type = selection.first;
                          _categoryId = null;
                          _toWalletId = null;
                        }),
                      ),
                      const SizedBox(height: 20),
                      DropdownButtonFormField<int>(
                        initialValue: _walletId,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: isTransfer ? 'Dari dompet' : 'Dompet',
                          border: const OutlineInputBorder(),
                          errorText: _fieldErrors['wallet_id'],
                        ),
                        items: [
                          for (final wallet in _wallets)
                            DropdownMenuItem(value: wallet.id, child: Text(wallet.name)),
                        ],
                        onChanged: (value) => setState(() {
                          _walletId = value;
                          if (_toWalletId == value) _toWalletId = null;
                        }),
                        validator: (value) => value == null ? 'Pilih dompet.' : null,
                      ),
                      const SizedBox(height: 16),
                      if (isTransfer)
                        DropdownButtonFormField<int>(
                          key: ValueKey('to-wallet-$_walletId'),
                          initialValue: _toWalletId,
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText: 'Ke dompet',
                            border: const OutlineInputBorder(),
                            errorText: _fieldErrors['to_wallet_id'],
                          ),
                          items: [
                            for (final wallet in _wallets.where((w) => w.id != _walletId))
                              DropdownMenuItem(value: wallet.id, child: Text(wallet.name)),
                          ],
                          onChanged: (value) => setState(() => _toWalletId = value),
                          validator: (value) => value == null ? 'Pilih dompet tujuan.' : null,
                        )
                      else
                        DropdownButtonFormField<int>(
                          key: ValueKey('category-$_type'),
                          initialValue: _categoryId,
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText: 'Kategori',
                            border: const OutlineInputBorder(),
                            errorText: _fieldErrors['category_id'],
                          ),
                          items: [
                            for (final category in _visibleCategories)
                              DropdownMenuItem(value: category.id, child: Text(category.name)),
                          ],
                          onChanged: (value) => setState(() => _categoryId = value),
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
                          labelText: 'Nominal (Rp)',
                          border: const OutlineInputBorder(),
                          errorText: _fieldErrors['amount'],
                        ),
                        validator: (value) {
                          final amount = int.tryParse(value ?? '');
                          return (amount == null || amount < 1) ? 'Masukkan nominal.' : null;
                        },
                      ),
                      const SizedBox(height: 16),
                      InkWell(
                        onTap: _pickDate,
                        child: InputDecorator(
                          decoration: InputDecoration(
                            labelText: 'Tanggal',
                            border: const OutlineInputBorder(),
                            suffixIcon: const Icon(Icons.calendar_today_outlined),
                            errorText: _fieldErrors['transaction_date'],
                          ),
                          child: Text(DateFormat('d MMMM y', 'id_ID').format(_date)),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _note,
                        inputFormatters: [LengthLimitingTextInputFormatter(255)],
                        decoration: InputDecoration(
                          labelText: 'Catatan (opsional)',
                          border: const OutlineInputBorder(),
                          errorText: _fieldErrors['note'],
                        ),
                      ),
                      const SizedBox(height: 24),
                      FilledButton(
                        onPressed: _saving ? null : _save,
                        child: _saving
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Simpan'),
                      ),
                    ],
                  ),
                ),
    );
  }
}