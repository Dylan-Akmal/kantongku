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
import 'settlement_sheet.dart';

class GroupBalancesPanel extends StatefulWidget {
  const GroupBalancesPanel({super.key, required this.group});

  final Group group;

  @override
  State<GroupBalancesPanel> createState() => _GroupBalancesPanelState();
}

class _GroupBalancesPanelState extends State<GroupBalancesPanel> {
  late final GroupFinanceRepository _repository =
      GroupFinanceRepository(context.read<ApiClient>());

  GroupBalances? _data;
  bool _loading = true;
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
      final data = await _repository.balances(widget.group.id);
      if (!mounted) return;
      setState(() => _data = data);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = apiErrorMessage(e, fallback: 'Gagal memuat saldo.'));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _settle({int? toUserId, int? amount}) async {
    final saved = await SettlementSheet.show(
      context,
      group: widget.group,
      toUserId: toUserId,
      amount: amount,
    );

    if (saved == true && mounted) {
      showMessage(context, 'Pelunasan dicatat.');
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final myId = context.watch<AuthProvider>().userId;
    final data = _data;

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
          if (_loading && data == null)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (data != null) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Posisimu di grup ini', style: theme.textTheme.bodyMedium),
                    const SizedBox(height: 4),
                    if (data.myBalance > 0)
                      Text(
                        'Kamu akan menerima ${formatRupiah(data.myBalance)}',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF047857),
                        ),
                      )
                    else if (data.myBalance < 0)
                      Text(
                        'Kamu berutang ${formatRupiah(data.myBalance.abs())}',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFFE11D48),
                        ),
                      )
                    else
                      Text(
                        'Kamu sudah lunas ✓',
                        style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: () => _settle(),
                      child: const Text('Catat pelunasan'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
                    child: Text(
                      'SALDO TIAP ANGGOTA',
                      style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.outline),
                    ),
                  ),
                  for (final row in data.balances)
                    ListTile(
                      title: Text(row.userId == myId ? '${row.name} (kamu)' : row.name),
                      trailing: row.balance > 0
                          ? Text(
                              'menerima ${formatRupiah(row.balance)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF059669),
                              ),
                            )
                          : row.balance < 0
                              ? Text(
                                  'berutang ${formatRupiah(row.balance.abs())}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFFE11D48),
                                  ),
                                )
                              : Text('lunas', style: TextStyle(color: theme.colorScheme.outline)),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                    child: Text(
                      'CARA MELUNASI SEMUANYA',
                      style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.outline),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 2, 16, 4),
                    child: Text(
                      'Pembayaran sesedikit mungkin agar semua saldo menjadi nol.',
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
                    ),
                  ),
                  if (data.settleUp.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('Tidak ada utang yang perlu dilunasi. 🎉'),
                    ),
                  for (final payment in data.settleUp)
                    ListTile(
                      title: Text('${payment.fromName} membayar ${payment.toName}'),
                      subtitle: Text(
                        formatRupiah(payment.amount),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      trailing: payment.fromId == myId
                          ? TextButton(
                              onPressed: () =>
                                  _settle(toUserId: payment.toId, amount: payment.amount),
                              child: const Text('Catat'),
                            )
                          : null,
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}