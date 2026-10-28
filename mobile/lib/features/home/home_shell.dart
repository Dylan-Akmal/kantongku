import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../auth/auth_provider.dart';
import '../dashboard/dashboard_page.dart';
import '../groups/groups_page.dart';
import '../transactions/transactions_page.dart';
import 'more_page.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  // Naik setiap kali pengguna kembali ke Beranda dari tab lain, agar data dimuat ulang.
  int _dashboardVersion = 0;

  @override
  void initState() {
    super.initState();
    context.read<AuthProvider>().refreshUser();
  }

  void _select(int index) {
    setState(() {
      if (index == 0 && _index != 0) _dashboardVersion++;
      _index = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          DashboardPage(
            key: ValueKey(_dashboardVersion),
            onOpenTransactions: () => _select(1),
            onOpenGroups: () => _select(2),
          ),
          const TransactionsPage(),
          const GroupsPage(),
          const MorePage(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _select,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Beranda',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'Transaksi',
          ),
          NavigationDestination(
            icon: Icon(Icons.group_outlined),
            selectedIcon: Icon(Icons.group),
            label: 'Grup',
          ),
          NavigationDestination(icon: Icon(Icons.menu), label: 'Lainnya'),
        ],
      ),
    );
  }
}