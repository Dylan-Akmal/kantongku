import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/api_errors.dart';
import '../../core/labels.dart';
import '../../widgets/error_box.dart';
import '../../widgets/single_field_sheet.dart';
import 'group.dart';
import 'group_repository.dart';
import 'group_utils.dart';

class GroupsPage extends StatefulWidget {
  const GroupsPage({super.key});

  @override
  State<GroupsPage> createState() => _GroupsPageState();
}

class _GroupsPageState extends State<GroupsPage> {
  late final GroupRepository _repository = GroupRepository(context.read<ApiClient>());

  List<Group> _groups = [];
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
      final groups = await _repository.list();
      if (!mounted) return;
      setState(() => _groups = groups);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = apiErrorMessage(e, fallback: 'Gagal memuat grup.'));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openDetail(int id) async {
    await context.push('/groups/$id');
    if (mounted) await _load();
  }

  Future<void> _create() async {
    final group = await SingleFieldSheet.show<Group>(
      context,
      title: 'Buat grup',
      label: 'Nama grup',
      hint: 'Contoh: Trip Bali',
      submitText: 'Buat grup',
      onSubmit: _repository.create,
    );

    if (group != null && mounted) await _openDetail(group.id);
  }

  Future<void> _join() async {
    final group = await SingleFieldSheet.show<Group>(
      context,
      title: 'Gabung dengan kode',
      label: 'Kode undangan',
      hint: 'Contoh: YU92EY7M',
      helper: 'Minta kode ini dari pemilik atau anggota grup.',
      submitText: 'Gabung',
      maxLength: 12,
      errorKey: 'invite_code',
      uppercaseCode: true,
      onSubmit: (code) => _repository.join(code.toUpperCase()),
    );

    if (group != null && mounted) await _openDetail(group.id);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Grup patungan')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _create,
        icon: const Icon(Icons.add),
        label: const Text('Buat grup'),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
          children: [
            Text(
              'Bagi pengeluaran bersama teman dan lacak siapa berutang.',
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.outline),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _join,
              icon: const Icon(Icons.login),
              label: const Text('Gabung dengan kode'),
            ),
            const SizedBox(height: 12),
            if (_error != null) ...[
              ErrorBox(_error!),
              const SizedBox(height: 12),
            ],
            if (_loading && _groups.isEmpty)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_groups.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Belum ada grup. Buat grup baru, atau gabung memakai kode undangan dari temanmu.',
                ),
              )
            else
              for (final group in _groups)
                Card(
                  child: ListTile(
                    onTap: () => _openDetail(group.id),
                    leading: CircleAvatar(child: Text(initials(group.name))),
                    title: Text(
                      group.name,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text('${group.memberCount} anggota · Pemilik: ${group.ownerName}'),
                    trailing: Chip(
                      label: Text(roleLabels[group.myRole] ?? ''),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}