import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../auth/auth_provider.dart';

class MorePage extends StatelessWidget {
  const MorePage({super.key});

  Future<void> _confirmLogout(BuildContext context) async {
    final auth = context.read<AuthProvider>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Keluar'),
        content: const Text('Yakin ingin keluar dari Kantongku?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Keluar'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
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
          const Card(
            child: Column(
              children: [
                ListTile(
                  leading: Icon(Icons.account_balance_wallet_outlined),
                  title: Text('Dompet'),
                  subtitle: Text('Segera hadir'),
                ),
                Divider(height: 1),
                ListTile(
                  leading: Icon(Icons.category_outlined),
                  title: Text('Kategori'),
                  subtitle: Text('Segera hadir'),
                ),
                Divider(height: 1),
                ListTile(
                  leading: Icon(Icons.savings_outlined),
                  title: Text('Anggaran'),
                  subtitle: Text('Segera hadir'),
                ),
                Divider(height: 1),
                ListTile(
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