import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/api_errors.dart';
import '../../core/format.dart';
import '../../core/labels.dart';
import '../../widgets/error_box.dart';
import '../auth/auth_provider.dart';
import '../budgets/budget.dart';
import '../budgets/budget_repository.dart';
import '../groups/group_finance_repository.dart';
import '../groups/group_repository.dart';
import '../reports/report.dart';
import '../reports/report_repository.dart';
import '../transactions/transaction.dart';
import '../transactions/transaction_repository.dart';
import '../wallets/wallet_repository.dart';

const Color _green = Color(0xFF059669);
const Color _red = Color(0xFFE11D48);
const Color _amber = Color(0xFFD97706);
const Color _slate = Color(0xFF64748B);

class _GroupPosition {
  const _GroupPosition({required this.id, required this.name, required this.balance});

  final int id;
  final String name;
  final int balance;
}

class _DashboardData {
  const _DashboardData({
    required this.wallets,
    required this.report,
    required this.budgets,
    required this.recent,
    required this.groups,
  });

  final WalletList wallets;
  final MonthlyReport report;
  final BudgetList budgets;
  final List<Transaction> recent;
  final List<_GroupPosition> groups;
}

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key, this.onOpenTransactions, this.onOpenGroups});

  /// Dipanggil saat "Lihat semua" di kartu transaksi diketuk (pindah ke tab Transaksi).
  final VoidCallback? onOpenTransactions;

  /// Dipanggil saat "Lihat semua" di kartu grup diketuk (pindah ke tab Grup).
  final VoidCallback? onOpenGroups;

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  _DashboardData? _data;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// Saldo saya di tiap grup. Kegagalan di sini tidak boleh menggagalkan seluruh beranda.
  Future<List<_GroupPosition>> _loadGroups(ApiClient api) async {
    try {
      final groups = await GroupRepository(api).list();
      final finance = GroupFinanceRepository(api);

      return await Future.wait(
        groups.map((group) async {
          final balances = await finance.balances(group.id);

          return _GroupPosition(id: group.id, name: group.name, balance: balances.myBalance);
        }),
      );
    } catch (_) {
      return const [];
    }
  }

  Future<void> _load() async {
    final api = context.read<ApiClient>();
    final month = currentMonth();

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final (wallets, report, budgets, recent, groups) = await (
        WalletRepository(api).list(),
        ReportRepository(api).monthly(month),
        BudgetRepository(api).list(month),
        TransactionRepository(api).list(page: 1, perPage: 5),
        _loadGroups(api),
      ).wait;

      if (!mounted) return;
      setState(() {
        _data = _DashboardData(
          wallets: wallets,
          report: report,
          budgets: budgets,
          recent: recent.items,
          groups: groups,
        );
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = apiErrorMessage(e, fallback: 'Gagal memuat beranda.'));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openGroup(int id) async {
    await context.push('/groups/$id');
    if (mounted) await _load();
  }

  Color _budgetColor(Budget budget) {
    if (budget.isOver) return _red;
    if (budget.percentage >= 80) return _amber;
    return _green;
  }

  Widget _sectionHeader(String title, {String? actionLabel, VoidCallback? onAction}) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Text(
            title,
            style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.outline),
          ),
          const Spacer(),
          if (actionLabel != null && onAction != null)
            TextButton(onPressed: onAction, child: Text(actionLabel)),
        ],
      ),
    );
  }

  Widget _stat(String label, String value, Color? color) {
    final theme = Theme.of(context);

    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700, color: color),
          ),
        ],
      ),
    );
  }

  Widget _balanceCard(_DashboardData data) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Total saldo', style: theme.textTheme.bodyMedium),
            const SizedBox(height: 4),
            Text(
              formatRupiah(data.wallets.totalBalance),
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _monthCard(_DashboardData data) {
    final report = data.report;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionHeader('BULAN INI · ${formatMonthLabel(currentMonth()).toUpperCase()}'),
            Row(
              children: [
                _stat('Pemasukan', formatRupiah(report.totalIncome), _green),
                _stat('Pengeluaran', formatRupiah(report.totalExpense), _red),
                _stat('Selisih', formatRupiah(report.net), report.net >= 0 ? _green : _red),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _budgetCard(_DashboardData data) {
    final theme = Theme.of(context);
    final list = data.budgets;
    final top = ([...list.budgets]..sort((a, b) => b.percentage.compareTo(a.percentage))).take(3);

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionHeader(
              'ANGGARAN BULAN INI',
              actionLabel: 'Lihat semua',
              onAction: () => context.push('/budgets'),
            ),
            if (list.budgets.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'Belum ada anggaran bulan ini.',
                  style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.outline),
                ),
              )
            else ...[
              Text(
                '${formatRupiah(list.totalSpent)} dari ${formatRupiah(list.totalBudget)}',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
              for (final budget in top)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            budget.categoryName,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          Text(
                            '${formatRupiah(budget.spent)} / ${formatRupiah(budget.amount)}',
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      LinearProgressIndicator(
                        value: (budget.percentage / 100).clamp(0.0, 1.0),
                        minHeight: 8,
                        borderRadius: BorderRadius.circular(4),
                        color: _budgetColor(budget),
                        backgroundColor: theme.colorScheme.surfaceContainerHighest,
                      ),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _recentTile(Transaction transaction) {
    final color = switch (transaction.type) {
      'income' => _green,
      'expense' => _red,
      _ => _slate,
    };

    final icon = switch (transaction.type) {
      'income' => Icons.arrow_downward,
      'expense' => Icons.arrow_upward,
      _ => Icons.swap_horiz,
    };

    final value = formatRupiah(transaction.amount);
    final amount = switch (transaction.type) {
      'income' => '+ $value',
      'expense' => '\u2212 $value',
      _ => value,
    };

    return ListTile(
      dense: true,
      leading: CircleAvatar(
        radius: 18,
        backgroundColor: color.withValues(alpha: 0.12),
        child: Icon(icon, color: color, size: 18),
      ),
      title: Text(transaction.title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(
        '${formatDate(transaction.date)} · ${transaction.walletName}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Text(amount, style: TextStyle(fontWeight: FontWeight.w700, color: color)),
    );
  }

  Widget _recentCard(_DashboardData data) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: _sectionHeader(
                'TRANSAKSI TERBARU',
                actionLabel: 'Lihat semua',
                onAction: widget.onOpenTransactions,
              ),
            ),
            if (data.recent.isEmpty)
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Text('Belum ada transaksi.'),
              )
            else
              for (final transaction in data.recent) _recentTile(transaction),
          ],
        ),
      ),
    );
  }

  Widget _walletsCard(_DashboardData data) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: _sectionHeader(
                'DOMPET',
                actionLabel: 'Kelola',
                onAction: () => context.push('/wallets'),
              ),
            ),
            for (final wallet in data.wallets.wallets)
              ListTile(
                dense: true,
                title: Text(wallet.name),
                subtitle: Text(walletTypeLabels[wallet.type] ?? ''),
                trailing: Text(
                  formatRupiah(wallet.balance),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _groupsCard(_DashboardData data) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: _sectionHeader(
                'SALDO GRUP',
                actionLabel: 'Lihat semua',
                onAction: widget.onOpenGroups,
              ),
            ),
            for (final group in data.groups)
              ListTile(
                dense: true,
                onTap: () => _openGroup(group.id),
                title: Text(group.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                trailing: group.balance > 0
                    ? Text(
                        'menerima ${formatRupiah(group.balance)}',
                        style: const TextStyle(fontWeight: FontWeight.w600, color: _green),
                      )
                    : group.balance < 0
                        ? Text(
                            'berutang ${formatRupiah(group.balance.abs())}',
                            style: const TextStyle(fontWeight: FontWeight.w600, color: _red),
                          )
                        : Text('lunas', style: TextStyle(color: theme.colorScheme.outline)),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = context.watch<AuthProvider>().userName;
    final data = _data;

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Halo, $name',
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            Text(
              'Ringkasan keuanganmu.',
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.outline),
            ),
            const SizedBox(height: 16),
            if (_error != null) ...[
              ErrorBox(_error!),
              const SizedBox(height: 16),
            ],
            if (_loading && data == null)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (data != null) ...[
              _balanceCard(data),
              const SizedBox(height: 12),
              _monthCard(data),
              const SizedBox(height: 12),
              _budgetCard(data),
              const SizedBox(height: 12),
              _recentCard(data),
              const SizedBox(height: 12),
              _walletsCard(data),
              if (data.groups.isNotEmpty) ...[
                const SizedBox(height: 12),
                _groupsCard(data),
              ],
            ],
          ],
        ),
      ),
    );
  }
}