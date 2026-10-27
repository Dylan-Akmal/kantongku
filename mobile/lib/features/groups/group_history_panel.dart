import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/api_errors.dart';
import '../../core/format.dart';
import '../../core/ui.dart';
import '../../widgets/error_box.dart';
import '../auth/auth_provider.dart';
import 'group.dart';
import 'group_finance.dart';
import 'group_finance_repository.dart';

class GroupHistoryPanel extends StatefulWidget {
  const GroupHistoryPanel({super.key, required this.group});

  final Group group;

  @override
  State<GroupHistoryPanel> createState() => _GroupHistoryPanelState();
}

class _GroupHistoryPanelState extends State<GroupHistoryPanel> {
  late final GroupFinanceRepository _repository =
      GroupFinanceRepository(context.read<ApiClient>());

  final List<HistoryItem> _items = [];
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
      final result = await _repository.history(widget.group.id);
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
      setState(() => _error = apiErrorMessage(e, fallback: 'Gagal memuat riwayat.'));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMore() async {
    setState(() => _loadingMore = true);

    try {
      final result = await _repository.history(widget.group.id, page: _page + 1);
      if (!mounted) return;
      setState(() {
        _items.addAll(result.items);
        _page = result.currentPage;
        _hasMore = result.hasMore;
      });
    } catch (e) {
      if (!mounted) return;
      showMessage(context, apiErrorMessage(e, fallback: 'Gagal memuat riwayat berikutnya.'));
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  bool _canDeleteSettlement(HistoryItem item) {
    final me = context.read<AuthProvider>().userId;
    return !item.isExpense && (widget.group.isOwner || item.fromId == me);
  }

  Future<void> _deleteSettlement(HistoryItem item) async {
    final confirmed = await confirmDialog(
      context,
      title: 'Hapus pelunasan',
      message: 'Hapus catatan pelunasan ini? Saldo anggota yang terkait akan dihitung ulang.',
      confirmText: 'Hapus',
      destructive: true,
    );

    if (!confirmed || !mounted) return;

    try {
      await _repository.deleteSettlement(widget.group.id, item.id);
      if (!mounted) return;
      showMessage(context, 'Pelunasan dihapus.');
      await _load();
    } catch (e) {
      if (!mounted) return;
      showMessage(context, apiErrorMessage(e, fallback: 'Gagal menghapus pelunasan.'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          if (_error != null) ...[
            ErrorBox(_error!),
            const SizedBox(height: 12),
          ],
          Text(
            '$_total aktivitas',
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
              child: Text('Belum ada aktivitas di grup ini.'),
            )
          else
            for (final item in _items)
              Card(
                child: ListTile(
                  leading: Text(item.isExpense ? '🧾' : '💸', style: const TextStyle(fontSize: 24)),
                  title: Text(
                    item.isExpense
                        ? '${item.title} · dibayar ${item.paidByName}'
                        : '${item.fromName} melunasi ${item.toName}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    [
                      formatDate(item.date),
                      if ((item.note ?? '').isNotEmpty) item.note!,
                    ].join(' · '),
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        formatRupiah(item.amount),
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: item.isExpense ? null : const Color(0xFF059669),
                        ),
                      ),
                      if (_canDeleteSettlement(item))
                        InkWell(
                          onTap: () => _deleteSettlement(item),
                          child: const Text(
                            'Hapus',
                            style: TextStyle(color: Color(0xFFBE123C), fontSize: 12),
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
    );
  }
}