import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/api_errors.dart';
import '../../core/format.dart';
import '../../core/labels.dart';
import '../../core/ui.dart';
import '../../widgets/single_field_sheet.dart';
import '../auth/auth_provider.dart';
import 'group.dart';
import 'group_repository.dart';
import 'group_utils.dart';

class GroupMembersPanel extends StatefulWidget {
  const GroupMembersPanel({super.key, required this.group, required this.onRefresh});

  final Group group;
  final Future<void> Function() onRefresh;

  @override
  State<GroupMembersPanel> createState() => _GroupMembersPanelState();
}

class _GroupMembersPanelState extends State<GroupMembersPanel> {
  late final GroupRepository _repository = GroupRepository(context.read<ApiClient>());

  /// Menjalankan aksi, menampilkan hasilnya, lalu memuat ulang halaman
  /// atau (bila [leaveScreen]) kembali ke daftar grup.
  Future<void> _run(
    Future<void> Function() action, {
    required String success,
    bool leaveScreen = false,
  }) async {
    try {
      await action();
      if (!mounted) return;
      showMessage(context, success);

      if (leaveScreen) {
        context.pop();
      } else {
        await widget.onRefresh();
      }
    } catch (e) {
      if (!mounted) return;
      showMessage(context, apiErrorMessage(e, fallback: 'Aksi gagal. Coba lagi.'));
    }
  }

  Future<void> _copyCode() async {
    await Clipboard.setData(ClipboardData(text: widget.group.inviteCode));
    if (!mounted) return;
    showMessage(context, 'Kode undangan disalin.');
  }

  Future<void> _rename() async {
    final group = widget.group;

    final updated = await SingleFieldSheet.show<bool>(
      context,
      title: 'Ubah nama grup',
      label: 'Nama grup',
      initialValue: group.name,
      submitText: 'Simpan',
      onSubmit: (name) async {
        await _repository.rename(group.id, name);
        return true;
      },
    );

    if (updated == true && mounted) {
      showMessage(context, 'Nama grup diperbarui.');
      await widget.onRefresh();
    }
  }

  Future<void> _regenerate() async {
    final confirmed = await confirmDialog(
      context,
      title: 'Buat ulang kode undangan',
      message: 'Kode lama tidak akan berlaku lagi. Anggota yang sudah bergabung tidak terpengaruh.',
      confirmText: 'Buat ulang',
    );

    if (!confirmed || !mounted) return;

    await _run(
      () => _repository.regenerateCode(widget.group.id),
      success: 'Kode undangan dibuat ulang.',
    );
  }

  Future<void> _remove(GroupMember member) async {
    final confirmed = await confirmDialog(
      context,
      title: 'Keluarkan anggota',
      message:
          'Keluarkan ${member.name} dari grup? Ini hanya bisa dilakukan jika saldonya di grup sudah nol.',
      confirmText: 'Keluarkan',
      destructive: true,
    );

    if (!confirmed || !mounted) return;

    await _run(
      () => _repository.removeMember(widget.group.id, member.id),
      success: '${member.name} dikeluarkan dari grup.',
    );
  }

  Future<void> _leave() async {
    final confirmed = await confirmDialog(
      context,
      title: 'Keluar dari grup',
      message:
          'Kamu hanya bisa keluar jika saldomu di grup sudah nol. Untuk bergabung lagi, kamu butuh kode undangan.',
      confirmText: 'Keluar',
      destructive: true,
    );

    if (!confirmed || !mounted) return;

    await _run(
      () => _repository.leave(widget.group.id),
      success: 'Kamu telah keluar dari grup.',
      leaveScreen: true,
    );
  }

  Future<void> _delete() async {
    final confirmed = await confirmDialog(
      context,
      title: 'Hapus grup',
      message:
          'Menghapus grup juga menghapus semua pengeluaran dan pelunasan di dalamnya, untuk semua anggota. Tindakan ini tidak bisa dibatalkan.',
      confirmText: 'Hapus grup',
      destructive: true,
    );

    if (!confirmed || !mounted) return;

    await _run(
      () => _repository.delete(widget.group.id),
      success: 'Grup dihapus.',
      leaveScreen: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final group = widget.group;
    final myId = context.watch<AuthProvider>().userId;

    return RefreshIndicator(
      onRefresh: widget.onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            '${group.memberCount} anggota · Pemilik: ${group.ownerName} · '
            'Peranmu: ${roleLabels[group.myRole] ?? ''}',
            style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.outline),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Kode undangan', style: theme.textTheme.bodyMedium),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          group.inviteCode,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 3,
                          ),
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        tooltip: 'Salin kode',
                        icon: const Icon(Icons.copy_outlined),
                        onPressed: _copyCode,
                      ),
                    ],
                  ),
                  if (group.isOwner)
                    TextButton(onPressed: _regenerate, child: const Text('Buat ulang kode')),
                  Text(
                    'Bagikan kode ini ke temanmu. Mereka memasukkannya lewat tombol "Gabung dengan kode".',
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
                  child: Text(
                    'ANGGOTA (${group.members.length})',
                    style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.outline),
                  ),
                ),
                for (final member in group.members)
                  ListTile(
                    leading: CircleAvatar(child: Text(initials(member.name))),
                    title: Text(member.id == myId ? '${member.name} (kamu)' : member.name),
                    subtitle: Text(
                      '${roleLabels[member.role] ?? ''} · bergabung ${formatDate(member.joinedDate)}',
                    ),
                    trailing: (group.isOwner && !member.isOwner)
                        ? TextButton(
                            onPressed: () => _remove(member),
                            style: TextButton.styleFrom(foregroundColor: const Color(0xFFBE123C)),
                            child: const Text('Keluarkan'),
                          )
                        : null,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'PENGATURAN GRUP',
                    style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.outline),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (group.isOwner) ...[
                        OutlinedButton(onPressed: _rename, child: const Text('Ubah nama')),
                        OutlinedButton(
                          onPressed: _delete,
                          style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFFBE123C)),
                          child: const Text('Hapus grup'),
                        ),
                      ] else
                        OutlinedButton(
                          onPressed: _leave,
                          style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFFBE123C)),
                          child: const Text('Keluar dari grup'),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}