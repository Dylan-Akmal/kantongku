import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/api_errors.dart';
import '../../core/format.dart';
import '../../core/labels.dart';
import '../../widgets/error_box.dart';
import '../auth/auth_provider.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  List<Map<String, dynamic>> _wallets = [];
  num _totalBalance = 0;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final api = context.read<ApiClient>();

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final response = await api.dio.get('/wallets');
      final body = response.data as Map<String, dynamic>;

      if (!mounted) return;
      setState(() {
        _wallets = (body['data'] as List).cast<Map<String, dynamic>>();
        _totalBalance = body['meta']['total_balance'] as num;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = apiErrorMessage(e, fallback: 'Gagal memuat dompet.'));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = context.watch<AuthProvider>().userName;

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            Text('Halo, $name', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            Text(
              'Ringkasan keuanganmu.',
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.outline),
            ),
            const SizedBox(height: 16),
            if (_error != null) ...[
              ErrorBox(_error!),
              const SizedBox(height: 16),
            ],
            if (_loading && _wallets.isEmpty)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              )
            else ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Total saldo', style: theme.textTheme.bodyMedium),
                      const SizedBox(height: 4),
                      Text(
                        formatRupiah(_totalBalance),
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'DOMPET',
                style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.outline),
              ),
              const SizedBox(height: 8),
              for (final wallet in _wallets)
                Card(
                  child: ListTile(
                    title: Text(wallet['name'] as String),
                    subtitle: Text(walletTypeLabels[wallet['type']] ?? ''),
                    trailing: Text(
                      formatRupiah(wallet['balance'] as num),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}