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

  Widget _menuTile(BuildContext context, IconData icon, String title, String path) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => context.push(path),
    );
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
                _menuTile(context, Icons.account_balance_wallet_outlined, 'Dompet', '/wallets'),
                const Divider(height: 1),
                _menuTile(context, Icons.category_outlined, 'Kategori', '/categories'),
                const Divider(height: 1),
                _menuTile(context, Icons.savings_outlined, 'Anggaran', '/budgets'),
                const Divider(height: 1),
                _menuTile(context, Icons.manage_accounts_outlined, 'Akun', '/account'),
                const Divider(height: 1),
                _menuTile(context, Icons.bar_chart_outlined, 'Laporan', '/reports'),
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