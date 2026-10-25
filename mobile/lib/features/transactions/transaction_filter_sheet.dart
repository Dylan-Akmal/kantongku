import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/format.dart';
import '../../core/labels.dart';
import '../categories/category.dart';
import '../categories/category_repository.dart';
import '../wallets/wallet.dart';
import '../wallets/wallet_repository.dart';
import 'transaction.dart';

class TransactionFilterSheet extends StatefulWidget {
  const TransactionFilterSheet({super.key, required this.initial});

  final TransactionFilters initial;

  /// Mengembalikan filter baru, atau null bila lembar ditutup tanpa menerapkan.
  static Future<TransactionFilters?> show(BuildContext context, TransactionFilters initial) {
    return showModalBottomSheet<TransactionFilters>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => TransactionFilterSheet(initial: initial),
    );
  }

  @override
  State<TransactionFilterSheet> createState() => _TransactionFilterSheetState();
}

class _TransactionFilterSheetState extends State<TransactionFilterSheet> {
  late final TextEditingController _query = TextEditingController(text: widget.initial.query);

  late String? _type = widget.initial.type;
  late int? _walletId = widget.initial.walletId;
  late int? _categoryId = widget.initial.categoryId;
  late String? _dateFrom = widget.initial.dateFrom;
  late String? _dateTo = widget.initial.dateTo;

  List<Wallet> _wallets = [];
  List<Category> _categories = [];
  bool _optionsLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadOptions();
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _loadOptions() async {
    final api = context.read<ApiClient>();

    try {
      final (walletList, expense, income) = await (
        WalletRepository(api).list(includeArchived: true),
        CategoryRepository(api).list('expense'),
        CategoryRepository(api).list('income'),
      ).wait;

      if (!mounted) return;
      setState(() {
        _wallets = walletList.wallets;
        _categories = [...expense, ...income];

        if (!_wallets.any((wallet) => wallet.id == _walletId)) _walletId = null;
        if (!_categories.any((category) => category.id == _categoryId)) _categoryId = null;

        _optionsLoaded = true;
      });
    } catch (_) {
      // Filter tetap bisa dipakai tanpa pilihan dompet dan kategori.
    }
  }

  List<Category> get _visibleCategories =>
      _categories.where((category) => _type == null || category.type == _type).toList();

  Future<void> _pickRange() async {
    final now = DateTime.now();

    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 1, 12, 31),
      initialDateRange: (_dateFrom != null && _dateTo != null)
          ? DateTimeRange(start: DateTime.parse(_dateFrom!), end: DateTime.parse(_dateTo!))
          : null,
    );

    if (picked == null || !mounted) return;

    final format = DateFormat('yyyy-MM-dd');
    setState(() {
      _dateFrom = format.format(picked.start);
      _dateTo = format.format(picked.end);
    });
  }

  void _apply() {
    Navigator.of(context).pop(
      TransactionFilters(
        query: _query.text.trim(),
        type: _type,
        walletId: _walletId,
        categoryId: _categoryId,
        dateFrom: _dateFrom,
        dateTo: _dateTo,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasRange = _dateFrom != null && _dateTo != null;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Filter transaksi',
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _query,
              textInputAction: TextInputAction.search,
              decoration: const InputDecoration(
                labelText: 'Cari catatan',
                hintText: 'Contoh: makan siang',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Text('Jenis', style: theme.textTheme.labelLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('Semua'),
                  selected: _type == null,
                  onSelected: (_) => setState(() {
                    _type = null;
                    _categoryId = null;
                  }),
                ),
                for (final entry in transactionTypeLabels.entries)
                  ChoiceChip(
                    label: Text(entry.value),
                    selected: _type == entry.key,
                    onSelected: (_) => setState(() {
                      _type = entry.key;
                      _categoryId = null;
                    }),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            if (_optionsLoaded) ...[
              DropdownButtonFormField<int?>(
                initialValue: _walletId,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Dompet',
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem<int?>(value: null, child: Text('Semua dompet')),
                  for (final wallet in _wallets)
                    DropdownMenuItem<int?>(value: wallet.id, child: Text(wallet.name)),
                ],
                onChanged: (value) => setState(() => _walletId = value),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<int?>(
                key: ValueKey('filter-category-$_type'),
                initialValue: _categoryId,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Kategori',
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem<int?>(value: null, child: Text('Semua kategori')),
                  for (final category in _visibleCategories)
                    DropdownMenuItem<int?>(
                      value: category.id,
                      child: Text(
                        _type == null
                            ? '${category.name} · ${category.type == 'expense' ? 'keluar' : 'masuk'}'
                            : category.name,
                      ),
                    ),
                ],
                onChanged: (value) => setState(() => _categoryId = value),
              ),
              const SizedBox(height: 16),
            ],
            OutlinedButton.icon(
              onPressed: _pickRange,
              icon: const Icon(Icons.date_range_outlined),
              label: Text(
                hasRange
                    ? '${formatDate(_dateFrom)} – ${formatDate(_dateTo)}'
                    : 'Pilih rentang tanggal',
              ),
            ),
            if (hasRange)
              TextButton(
                onPressed: () => setState(() {
                  _dateFrom = null;
                  _dateTo = null;
                }),
                child: const Text('Hapus rentang tanggal'),
              ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(const TransactionFilters()),
                  child: const Text('Reset'),
                ),
                const SizedBox(width: 8),
                FilledButton(onPressed: _apply, child: const Text('Terapkan')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}