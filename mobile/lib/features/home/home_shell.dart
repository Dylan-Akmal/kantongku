import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../widgets/placeholder_page.dart';
import '../auth/auth_provider.dart';
import '../dashboard/dashboard_page.dart';
import 'more_page.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  final List<Widget> _pages = const [
    DashboardPage(),
    PlaceholderPage(title: 'Transaksi', icon: Icons.receipt_long_outlined),
    PlaceholderPage(title: 'Grup patungan', icon: Icons.group_outlined),
    MorePage(),
  ];

  @override
  void initState() {
    super.initState();
    context.read<AuthProvider>().refreshUser();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (index) => setState(() => _index = index),
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
          NavigationDestination(
            icon: Icon(Icons.menu),
            label: 'Lainnya',
          ),
        ],
      ),
    );
  }
}