import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/ui.dart';
import '../auth/auth_provider.dart';

class MorePage extends StatelessWidget {
  const MorePage({super.key});

  Future<void> _confirmLogout(BuildContext context) async {
    final auth = context.read<AuthProvider>();

    final confirmed = await confirmDialog(
      context,
      title: 'Keluar',
      message: 'Yakin ingin keluar dari Kantongku?',
      confirmText: 'Keluar',
    );

    if (confirmed) {
      await auth.logout();
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: const CircleAvatar(child: Icon(Icons.person_outline)),
              title: Text(auth.userName),
              subtitle: Text((auth.user?['email'] as String?) ?? ''),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.account_balance_wallet_outlined),
                  title: const Text('Dompet'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/wallets'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.category_outlined),
                  title: const Text('Kategori'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/categories'),
                ),
                const Divider(height: 1),
                const ListTile(
                  leading: Icon(Icons.savings_outlined),
                  title: Text('Anggaran'),
                  subtitle: Text('Segera hadir'),
                ),
                const Divider(height: 1),
                const ListTile(
                  leading: Icon(Icons.bar_chart_outlined),
                  title: Text('Laporan'),
                  subtitle: Text('Segera hadir'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.logout, color: Color(0xFFBE123C)),
              title: const Text('Keluar', style: TextStyle(color: Color(0xFFBE123C))),
              onTap: () => _confirmLogout(context),
            ),
          ),
        ],
      ),
    );
  }
}