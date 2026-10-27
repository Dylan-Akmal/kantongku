import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/api_errors.dart';
import '../../core/format.dart';
import '../../core/ui.dart';
import '../../widgets/error_box.dart';
import '../auth/auth_provider.dart';
import 'group.dart';
import 'group_expense_form_screen.dart';
import 'group_finance.dart';
import 'group_finance_repository.dart';

class GroupExpensesPanel extends StatefulWidget {
  const GroupExpensesPanel({super.key, required this.group});

  final Group group;

  @override
  State<GroupExpensesPanel> createState() => _GroupExpensesPanelState();
}

class _GroupExpensesPanelState extends State<GroupExpensesPanel> {
  late final GroupFinanceRepository _repository =
      GroupFinanceRepository(context.read<ApiClient>());

  final List<GroupExpense> _items = [];
  int _page = 1;
  int _total = 0;
  bool _hasMore = false;
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;

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
      final result = await _repository.expenses(widget.group.id);
      if (!mounted) return;
      setState(() {
        _items
          ..clear()
          ..addAll(result.items);
        _page = result.currentPage;
        _total = result.total;
        _hasMore = result.hasMore;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = apiErrorMessage(e, fallback: 'Gagal memuat pengeluaran.'));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMore() async {
    setState(() => _loadingMore = true);

    try {
      final result = await _repository.expenses(widget.group.id, page: _page + 1);
      if (!mounted) return;
      setState(() {
        _items.addAll(result.items);
        _page = result.currentPage;
        _hasMore = result.hasMore;
      });
    } catch (e) {
      if (!mounted) return;
      showMessage(context, apiErrorMessage(e, fallback: 'Gagal memuat pengeluaran berikutnya.'));
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  bool _canEdit(GroupExpense expense) {
    final me = context.read<AuthProvider>().userId;
    return me == expense.createdById || me == expense.paidById;
  }

  bool _canDelete(GroupExpense expense) => _canEdit(expense) || widget.group.isOwner;

  Future<void> _openForm([GroupExpense? expense]) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => GroupExpenseFormScreen(group: widget.group, expense: expense),
      ),
    );

    if (saved == true && mounted) await _load();
  }

  Future<void> _delete(GroupExpense expense) async {
    final confirmed = await confirmDialog(
      context,
      title: 'Hapus pengeluaran',
      message: 'Hapus "${expense.title}"? Saldo semua anggota akan dihitung ulang.',
      confirmText: 'Hapus',
      destructive: true,
    );

    if (!confirmed || !mounted) return;

    try {
      await _repository.deleteExpense(widget.group.id, expense.id);
      if (!mounted) return;
      showMessage(context, 'Pengeluaran dihapus.');
      await _load();
    } catch (e) {
      if (!mounted) return;
      showMessage(context, apiErrorMessage(e, fallback: 'Gagal menghapus pengeluaran.'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        icon: const Icon(Icons.add),
        label: const Text('Catat pengeluaran'),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
          children: [
            if (_error != null) ...[
              ErrorBox(_error!),
              const SizedBox(height: 12),
            ],
            Text(
              '$_total pengeluaran bersama',
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.outline),
            ),
            const SizedBox(height: 8),
            if (_loading && _items.isEmpty)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_items.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('Belum ada pengeluaran bersama. Catat yang pertama dengan tombol di bawah.'),
              )
            else
              for (final expense in _items)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    expense.title,
                                    style: theme.textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    [
                                      formatDate(expense.expenseDate),
                                      'Dibayar oleh ${expense.paidByName}',
                                      if ((expense.note ?? '').isNotEmpty) expense.note!,
                                    ].join(' · '),
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.outline,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  formatRupiah(expense.totalAmount),
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Chip(
                                  label: Text(splitTypeLabels[expense.splitType] ?? ''),
                                  visualDensity: VisualDensity.compact,
                                ),
                              ],
                            ),
                          ],
                        ),
                        const Divider(height: 20),
                        for (final share in expense.shares)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(share.name),
                                Text(formatRupiah(share.amountOwed)),
                              ],
                            ),
                          ),
                        if (_canEdit(expense) || _canDelete(expense))
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Row(
                              children: [
                                if (_canEdit(expense))
                                  OutlinedButton(
                                    onPressed: () => _openForm(expense),
                                    child: const Text('Ubah'),
                                  ),
                                if (_canEdit(expense) && _canDelete(expense))
                                  const SizedBox(width: 8),
                                if (_canDelete(expense))
                                  OutlinedButton(
                                    onPressed: () => _delete(expense),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: const Color(0xFFBE123C),
                                    ),
                                    child: const Text('Hapus'),
                                  ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
            if (_hasMore)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: OutlinedButton(
                  onPressed: _loadingMore ? null : _loadMore,
                  child: Text(_loadingMore ? 'Memuat...' : 'Muat lebih banyak'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}