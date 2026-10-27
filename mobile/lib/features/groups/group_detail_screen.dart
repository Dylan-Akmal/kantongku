import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/api_errors.dart';
import '../../widgets/error_box.dart';
import 'group.dart';
import 'group_balances_panel.dart';
import 'group_expenses_panel.dart';
import 'group_history_panel.dart';
import 'group_members_panel.dart';
import 'group_repository.dart';

class GroupDetailScreen extends StatefulWidget {
  const GroupDetailScreen({super.key, required this.groupId});

  final int groupId;

  @override
  State<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends State<GroupDetailScreen> {
  late final GroupRepository _repository = GroupRepository(context.read<ApiClient>());

  Group? _group;
  bool _loading = true;
  bool _notFound = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _error = null;
      _notFound = false;
      if (_group == null) _loading = true;
    });

    try {
      final group = await _repository.show(widget.groupId);
      if (!mounted) return;
      setState(() => _group = group);
    } on DioException catch (e) {
      if (!mounted) return;
      if (e.response?.statusCode == 404) {
        setState(() {
          _group = null;
          _notFound = true;
        });
      } else {
        setState(() => _error = apiErrorMessage(e, fallback: 'Gagal memuat grup.'));
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = apiErrorMessage(e, fallback: 'Gagal memuat grup.'));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final group = _group;

    if (group == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Grup')),
        body: _buildPlaceholder(),
      );
    }

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: Text(group.name),
          bottom: const TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(text: 'Pengeluaran'),
              Tab(text: 'Saldo'),
              Tab(text: 'Riwayat'),
              Tab(text: 'Anggota'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            GroupExpensesPanel(group: group),
            GroupBalancesPanel(group: group),
            GroupHistoryPanel(group: group),
            GroupMembersPanel(group: group, onRefresh: _load),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_notFound) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Grup tidak ditemukan.\nGrup ini tidak ada, atau kamu bukan anggotanya.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ErrorBox(_error ?? 'Gagal memuat grup.'),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: _load, child: const Text('Coba lagi')),
          ],
        ),
      ),
    );
  }
}