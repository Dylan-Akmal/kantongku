import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/api_client.dart';
import '../../../core/api_errors.dart';
import '../../../core/ui.dart';
import '../../../widgets/error_box.dart';
import 'category.dart';
import 'category_form_sheet.dart';
import 'category_repository.dart';

class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  late final CategoryRepository _repository = CategoryRepository(context.read<ApiClient>());

  String _type = 'expense';
  List<Category> _categories = [];
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
      final categories = await _repository.list(_type);
      if (!mounted) return;
      setState(() => _categories = categories);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = apiErrorMessage(e, fallback: 'Gagal memuat kategori.'));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openForm([Category? category]) async {
    final saved = await CategoryFormSheet.show(context, type: _type, category: category);

    if (saved == true && mounted) {
      showMessage(context, category == null ? 'Kategori dibuat.' : 'Kategori diperbarui.');
      await _load();
    }
  }

  Future<void> _delete(Category category) async {
    final confirmed = await confirmDialog(
      context,
      title: 'Hapus kategori',
      message:
          'Hapus kategori "${category.name}"? Kategori yang sudah dipakai transaksi tidak bisa dihapus.',
      confirmText: 'Hapus',
      destructive: true,
    );

    if (!confirmed || !mounted) return;

    try {
      await _repository.delete(category.id);
      if (!mounted) return;
      showMessage(context, 'Kategori dihapus.');
      await _load();
    } catch (e) {
      if (!mounted) return;
      showMessage(context, apiErrorMessage(e, fallback: 'Gagal menghapus kategori.'));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Kategori')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        icon: const Icon(Icons.add),
        label: const Text('Tambah kategori'),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          children: [
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'expense', label: Text('Pengeluaran')),
                ButtonSegment(value: 'income', label: Text('Pemasukan')),
              ],
              selected: {_type},
              onSelectionChanged: (selection) {
                setState(() => _type = selection.first);
                _load();
              },
            ),
            const SizedBox(height: 16),
            if (_error != null) ...[
              ErrorBox(_error!),
              const SizedBox(height: 12),
            ],
            if (_loading && _categories.isEmpty)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_categories.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('Belum ada kategori.'),
              )
            else
              Card(
                child: Column(
                  children: [
                    for (var i = 0; i < _categories.length; i++) ...[
                      if (i > 0) const Divider(height: 1),
                      ListTile(
                        title: Text(_categories[i].name),
                        trailing: PopupMenuButton<String>(
                          onSelected: (value) {
                            if (value == 'rename') _openForm(_categories[i]);
                            if (value == 'delete') _delete(_categories[i]);
                          },
                          itemBuilder: (context) => const [
                            PopupMenuItem(value: 'rename', child: Text('Ubah nama')),
                            PopupMenuItem(value: 'delete', child: Text('Hapus')),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}