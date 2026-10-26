import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/api_errors.dart';
import '../../core/format.dart';
import '../../core/ui.dart';
import '../../widgets/error_box.dart';
import '../../widgets/month_switcher.dart';
import 'budget.dart';
import 'budget_form_sheet.dart';
import 'budget_repository.dart';

class BudgetsScreen extends StatefulWidget {
  const BudgetsScreen({super.key});

  @override
  State<BudgetsScreen> createState() => _BudgetsScreenState();
}

class _BudgetsScreenState extends State<BudgetsScreen> {
  late final BudgetRepository _repository = BudgetRepository(context.read<ApiClient>());

  String _month = currentMonth();
  List<Budget> _budgets = [];
  int _totalBudget = 0;
  int _totalSpent = 0;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final requested = _month;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final result = await _repository.list(requested);
      if (!mounted || requested != _month) return;
      setState(() {
        _budgets = result.budgets;
        _totalBudget = result.totalBudget;
        _totalSpent = result.totalSpent;
      });
    } catch (e) {
      if (!mounted || requested != _month) return;
      setState(() => _error = apiErrorMessage(e, fallback: 'Gagal memuat anggaran.'));
    } finally {
      if (mounted && requested == _month) setState(() => _loading = false);
    }
  }

  void _changeMonth(String month) {
    setState(() => _month = month);
    _load();
  }

  Future<void> _openForm([Budget? budget]) async {
    final message = await BudgetFormSheet.show(context, month: _month, budget: budget);

    if (message != null && mounted) {
      showMessage(context, message);
      await _load();
    }
  }

  Future<void> _delete(Budget budget) async {
    final confirmed = await confirmDialog(
      context,
      title: 'Hapus anggaran',
      message: 'Hapus anggaran "${budget.categoryName}" untuk ${formatMonthLabel(_month)}?',
      confirmText: 'Hapus',
      destructive: true,
    );

    if (!confirmed || !mounted) return;

    try {
      await _repository.delete(budget.id);
      if (!mounted) return;
      showMessage(context, 'Anggaran dihapus.');
      await _load();
    } catch (e) {
      if (!mounted) return;
      showMessage(context, apiErrorMessage(e, fallback: 'Gagal menghapus anggaran.'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalPercent =
        _totalBudget > 0 ? (_totalSpent / _totalBudget * 100).roundToDouble() : 0.0;

    return Scaffold(
      appBar: AppBar(title: const Text('Anggaran')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        icon: const Icon(Icons.add),
        label: const Text('Atur anggaran'),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
          children: [
            MonthSwitcher(month: _month, onChanged: _changeMonth),
            const SizedBox(height: 8),
            if (_error != null) ...[
              ErrorBox(_error!),
              const SizedBox(height: 12),
            ],
            _SummaryCard(
              spent: _totalSpent,
              total: _totalBudget,
              percentage: totalPercent,
            ),
            const SizedBox(height: 12),
            if (_loading && _budgets.isEmpty)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_budgets.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Belum ada anggaran untuk ${formatMonthLabel(_month)}.'),
              )
            else
              for (final budget in _budgets)
                _BudgetCard(
                  budget: budget,
                  onEdit: () => _openForm(budget),
                  onDelete: () => _delete(budget),
                ),
          ],
        ),
      ),
    );
  }
}

Color _barColor(double percentage) {
  if (percentage >= 100) return const Color(0xFFF43F5E);
  if (percentage >= 80) return const Color(0xFFF59E0B);
  return const Color(0xFF10B981);
}

String _percent(double value) {
  return value == value.roundToDouble() ? '${value.toInt()}' : value.toStringAsFixed(1);
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.spent, required this.total, required this.percentage});

  final int spent;
  final int total;
  final double percentage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Total terpakai', style: theme.textTheme.bodyMedium),
            const SizedBox(height: 4),
            Text(
              '${formatRupiah(spent)} dari ${formatRupiah(total)}',
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: (percentage / 100).clamp(0.0, 1.0),
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
              color: _barColor(percentage),
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
            ),
            const SizedBox(height: 6),
            Text(
              '${_percent(percentage)}% terpakai',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
            ),
          ],
        ),
      ),
    );
  }
}

class _BudgetCard extends StatelessWidget {
  const _BudgetCard({required this.budget, required this.onEdit, required this.onDelete});

  final Budget budget;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 4, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          budget.categoryName,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                      if (budget.isOver) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFE4E6),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: const Text(
                            'Melebihi anggaran',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFFBE123C),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'edit') onEdit();
                    if (value == 'delete') onDelete();
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: 'edit', child: Text('Ubah')),
                    PopupMenuItem(value: 'delete', child: Text('Hapus')),
                  ],
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${formatRupiah(budget.spent)} dari ${formatRupiah(budget.amount)}',
                    style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: (budget.percentage / 100).clamp(0.0, 1.0),
                    minHeight: 8,
                    borderRadius: BorderRadius.circular(4),
                    color: _barColor(budget.percentage),
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${_percent(budget.percentage)}% terpakai · '
                    '${budget.isOver ? 'melebihi ${formatRupiah(budget.remaining.abs())}' : 'sisa ${formatRupiah(budget.remaining)}'}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: budget.isOver ? const Color(0xFFBE123C) : theme.colorScheme.outline,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}