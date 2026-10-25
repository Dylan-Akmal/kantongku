import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/api_errors.dart';
import '../../core/format.dart';
import '../../core/ui.dart';
import '../../widgets/error_box.dart';
import 'transaction.dart';
import 'transaction_filter_sheet.dart';
import 'transaction_form_screen.dart';
import 'transaction_repository.dart';

class TransactionsPage extends StatefulWidget {
  const TransactionsPage({super.key});

  @override
  State<TransactionsPage> createState() => _TransactionsPageState();
}

class _TransactionsPageState extends State<TransactionsPage> {
  late final TransactionRepository _repository =
      TransactionRepository(context.read<ApiClient>());

  final ScrollController _scroll = ScrollController();
  final List<Transaction> _items = [];

  TransactionFilters _filters = const TransactionFilters();
  int _page = 1;
  int _lastPage = 1;
  int _total = 0;

  bool _loading = true;
  bool _loadingMore = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _load();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 240) {
      _loadMore();
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final result = await _repository.list(page: 1, filters: _filters);
      if (!mounted) return;
      setState(() {
        _items
          ..clear()
          ..addAll(result.items);
        _page = result.currentPage;
        _lastPage = result.lastPage;
        _total = result.total;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = apiErrorMessage(e, fallback: 'Gagal memuat transaksi.'));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMore() async {
    if (_loading || _loadingMore || _page >= _lastPage) return;

    setState(() => _loadingMore = true);

    try {
      final result = await _repository.list(page: _page + 1, filters: _filters);
      if (!mounted) return;
      setState(() {
        _items.addAll(result.items);
        _page = result.currentPage;
        _lastPage = result.lastPage;
      });
    } catch (e) {
      if (!mounted) return;
      showMessage(context, apiErrorMessage(e, fallback: 'Gagal memuat transaksi berikutnya.'));
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  Future<void> _openFilters() async {
    final result = await TransactionFilterSheet.show(context, _filters);

    if (result != null && mounted) {
      setState(() => _filters = result);
      await _load();
    }
  }

  Future<void> _resetFilters() async {
    setState(() => _filters = const TransactionFilters());
    await _load();
  }

  Future<void> _openForm([Transaction? transaction]) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => TransactionFormScreen(transaction: transaction),
      ),
    );

    if (saved == true && mounted) await _load();
  }

  Widget _buildHeader() {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_error != null) ...[
            ErrorBox(_error!),
            const SizedBox(height: 8),
          ],
          Row(
            children: [
              Text(
                '$_total transaksi',
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.outline),
              ),
              const Spacer(),
              if (_filters.isActive)
                ActionChip(
                  avatar: const Icon(Icons.close, size: 16),
                  label: const Text('Filter aktif'),
                  onPressed: _resetFilters,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    if (_loading && _items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_loadingMore) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    if (_items.isEmpty && !_loading) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: Text('Belum ada transaksi yang cocok.')),
      );
    }

    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Transaksi'),
        actions: [
          IconButton(
            tooltip: 'Filter',
            icon: Badge(
              isLabelVisible: _filters.isActive,
              smallSize: 8,
              child: const Icon(Icons.filter_list),
            ),
            onPressed: _openFilters,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        icon: const Icon(Icons.add),
        label: const Text('Catat'),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView.builder(
          controller: _scroll,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
          itemCount: _items.length + 2,
          itemBuilder: (context, index) {
            if (index == 0) return _buildHeader();
            if (index == _items.length + 1) return _buildFooter();

            final transaction = _items[index - 1];
            return _TransactionTile(
              transaction: transaction,
              onTap: () => _openForm(transaction),
            );
          },
        ),
      ),
    );
  }
}

Color _typeColor(String type) => switch (type) {
      'income' => const Color(0xFF059669),
      'expense' => const Color(0xFFE11D48),
      _ => const Color(0xFF64748B),
    };

IconData _typeIcon(String type) => switch (type) {
      'income' => Icons.arrow_downward,
      'expense' => Icons.arrow_upward,
      _ => Icons.swap_horiz,
    };

String _amountText(Transaction transaction) {
  final value = formatRupiah(transaction.amount);

  return switch (transaction.type) {
    'income' => '+ $value',
    'expense' => '− $value',
    _ => value,
  };
}

class _TransactionTile extends StatelessWidget {
  const _TransactionTile({required this.transaction, required this.onTap});

  final Transaction transaction;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = _typeColor(transaction.type);

    final details = [
      formatDate(transaction.date),
      if (transaction.type != 'transfer') transaction.walletName,
      if ((transaction.note ?? '').isNotEmpty) transaction.note!,
    ].join(' · ');

    return Card(
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.12),
          child: Icon(_typeIcon(transaction.type), color: color, size: 20),
        ),
        title: Text(transaction.title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(details, maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: Text(
          _amountText(transaction),
          style: TextStyle(fontWeight: FontWeight.w700, color: color),
        ),
      ),
    );
  }
}