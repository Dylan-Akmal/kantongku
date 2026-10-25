import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/api_errors.dart';
import '../../core/format.dart';
import '../../core/labels.dart';
import '../../core/ui.dart';
import '../../widgets/error_box.dart';
import 'wallet.dart';
import 'wallet_form_sheet.dart';
import 'wallet_repository.dart';

class WalletsScreen extends StatefulWidget {
  const WalletsScreen({super.key});

  @override
  State<WalletsScreen> createState() => _WalletsScreenState();
}

class _WalletsScreenState extends State<WalletsScreen> {
  late final WalletRepository _repository = WalletRepository(context.read<ApiClient>());

  List<Wallet> _wallets = [];
  int _totalBalance = 0;
  bool _showArchived = false;
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
      final result = await _repository.list(includeArchived: _showArchived);
      if (!mounted) return;
      setState(() {
        _wallets = result.wallets;
        _totalBalance = result.totalBalance;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = apiErrorMessage(e, fallback: 'Gagal memuat dompet.'));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openForm([Wallet? wallet]) async {
    final saved = await WalletFormSheet.show(context, wallet: wallet);

    if (saved == true && mounted) {
      showMessage(context, wallet == null ? 'Dompet dibuat.' : 'Dompet diperbarui.');
      await _load();
    }
  }

  Future<void> _toggleArchive(Wallet wallet) async {
    try {
      await _repository.update(wallet.id, isArchived: !wallet.isArchived);
      if (!mounted) return;
      showMessage(
        context,
        wallet.isArchived ? 'Dompet diaktifkan kembali.' : 'Dompet diarsipkan.',
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      showMessage(context, apiErrorMessage(e, fallback: 'Gagal mengubah dompet.'));
    }
  }

  Future<void> _delete(Wallet wallet) async {
    final confirmed = await confirmDialog(
      context,
      title: 'Hapus dompet',
      message:
          'Hapus dompet "${wallet.name}"? Dompet yang sudah punya transaksi tidak bisa dihapus, cukup diarsipkan.',
      confirmText: 'Hapus',
      destructive: true,
    );

    if (!confirmed || !mounted) return;

    try {
      await _repository.delete(wallet.id);
      if (!mounted) return;
      showMessage(context, 'Dompet dihapus.');
      await _load();
    } catch (e) {
      if (!mounted) return;
      showMessage(context, apiErrorMessage(e, fallback: 'Gagal menghapus dompet.'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Dompet')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        icon: const Icon(Icons.add),
        label: const Text('Tambah dompet'),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          children: [
            if (_error != null) ...[
              ErrorBox(_error!),
              const SizedBox(height: 12),
            ],
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Total saldo dompet aktif', style: theme.textTheme.bodyMedium),
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
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Tampilkan dompet yang diarsipkan'),
              value: _showArchived,
              onChanged: (value) {
                setState(() => _showArchived = value);
                _load();
              },
            ),
            if (_loading && _wallets.isEmpty)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_wallets.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('Belum ada dompet.'),
              )
            else
              for (final wallet in _wallets)
                _WalletCard(
                  wallet: wallet,
                  onEdit: () => _openForm(wallet),
                  onToggleArchive: () => _toggleArchive(wallet),
                  onDelete: () => _delete(wallet),
                ),
          ],
        ),
      ),
    );
  }
}

class _WalletCard extends StatelessWidget {
  const _WalletCard({
    required this.wallet,
    required this.onEdit,
    required this.onToggleArchive,
    required this.onDelete,
  });

  final Wallet wallet;
  final VoidCallback onEdit;
  final VoidCallback onToggleArchive;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline);

    return Opacity(
      opacity: wallet.isArchived ? 0.6 : 1,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 4, 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      wallet.name,
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      '${walletTypeLabels[wallet.type] ?? ''}'
                      '${wallet.isArchived ? ' · Diarsipkan' : ''}',
                      style: muted,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      formatRupiah(wallet.balance),
                      style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    Text('Saldo awal ${formatRupiah(wallet.initialBalance)}', style: muted),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (value) {
                  switch (value) {
                    case 'edit':
                      onEdit();
                    case 'archive':
                      onToggleArchive();
                    case 'delete':
                      onDelete();
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 'edit', child: Text('Ubah')),
                  PopupMenuItem(
                    value: 'archive',
                    child: Text(wallet.isArchived ? 'Aktifkan' : 'Arsipkan'),
                  ),
                  const PopupMenuItem(value: 'delete', child: Text('Hapus')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}