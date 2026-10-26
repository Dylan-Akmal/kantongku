import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/api_errors.dart';
import '../../core/format.dart';
import '../../widgets/error_box.dart';
import '../../widgets/month_switcher.dart';
import 'daily_bar_chart.dart';
import 'report.dart';
import 'report_repository.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  late final ReportRepository _repository = ReportRepository(context.read<ApiClient>());

  String _month = currentMonth();
  MonthlyReport? _report;
  List<DailyTotal> _days = [];
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
      final (report, days) = await (
        _repository.monthly(requested),
        _repository.daily(requested),
      ).wait;

      if (!mounted || requested != _month) return;
      setState(() {
        _report = report;
        _days = days;
      });
    } catch (e) {
      if (!mounted || requested != _month) return;
      setState(() => _error = apiErrorMessage(e, fallback: 'Gagal memuat laporan.'));
    } finally {
      if (mounted && requested == _month) setState(() => _loading = false);
    }
  }

  void _changeMonth(String month) {
    setState(() => _month = month);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final report = _report;

    return Scaffold(
      appBar: AppBar(title: const Text('Laporan')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            MonthSwitcher(month: _month, onChanged: _changeMonth),
            const SizedBox(height: 8),
            if (_error != null) ...[
              ErrorBox(_error!),
              const SizedBox(height: 12),
            ],
            if (_loading && report == null)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (report != null) ...[
              Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      label: 'Pemasukan',
                      value: formatRupiah(report.totalIncome),
                      color: const Color(0xFF047857),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatCard(
                      label: 'Pengeluaran',
                      value: formatRupiah(report.totalExpense),
                      color: const Color(0xFFE11D48),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      label: 'Selisih',
                      value: formatRupiah(report.net),
                      color: report.net >= 0 ? const Color(0xFF047857) : const Color(0xFFE11D48),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatCard(
                      label: 'Jumlah transaksi',
                      value: '${report.transactionCount}',
                      note: 'Transfer tidak dihitung',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (report.transactionCount == 0)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('Belum ada pemasukan atau pengeluaran pada bulan ini.'),
                )
              else ...[
                _CategoryCard(items: report.expenseByCategory),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'PER HARI',
                          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                color: Theme.of(context).colorScheme.outline,
                              ),
                        ),
                        const SizedBox(height: 12),
                        DailyBarChart(days: _days),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value, this.color, this.note});

  final String label;
  final String value;
  final Color? color;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: theme.textTheme.bodySmall),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ),
            if (note != null)
              Text(
                note!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline,
                  fontSize: 11,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({required this.items});

  final List<CategoryTotal> items;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'PENGELUARAN PER KATEGORI',
              style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.outline),
            ),
            const SizedBox(height: 12),
            for (final item in items) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      item.name,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  Text('${formatRupiah(item.total)} (${item.percentage}%)'),
                ],
              ),
              const SizedBox(height: 6),
              LinearProgressIndicator(
                value: (item.percentage / 100).clamp(0.0, 1.0),
                minHeight: 8,
                borderRadius: BorderRadius.circular(4),
                color: const Color(0xFFF43F5E),
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
              ),
              const SizedBox(height: 14),
            ],
            if (items.isEmpty) const Text('Belum ada pengeluaran.'),
          ],
        ),
      ),
    );
  }
}