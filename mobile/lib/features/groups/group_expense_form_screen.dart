import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/api_errors.dart';
import '../../core/format.dart';
import '../../core/ui.dart';
import '../../widgets/error_box.dart';
import '../auth/auth_provider.dart';
import 'group.dart';
import 'group_finance.dart';
import 'group_finance_repository.dart';

class GroupExpenseFormScreen extends StatefulWidget {
  const GroupExpenseFormScreen({super.key, required this.group, this.expense});

  final Group group;
  final GroupExpense? expense;

  @override
  State<GroupExpenseFormScreen> createState() => _GroupExpenseFormScreenState();
}

class _GroupExpenseFormScreenState extends State<GroupExpenseFormScreen> {
  final _formKey = GlobalKey<FormState>();

  late final GroupFinanceRepository _repository =
      GroupFinanceRepository(context.read<ApiClient>());

  final TextEditingController _title = TextEditingController();
  final TextEditingController _total = TextEditingController();
  final TextEditingController _note = TextEditingController();

  // Per anggota: apakah ikut dibagi, dan nominal atau persen yang diketik.
  final Map<int, bool> _selected = {};
  final Map<int, TextEditingController> _values = {};

  int? _paidBy;
  DateTime _date = DateTime.now();
  String _splitType = 'equal';

  bool _saving = false;
  String? _error;
  Map<String, String> _fieldErrors = {};

  List<GroupMember> get _members => widget.group.members;
  bool get _editing => widget.expense != null;

  @override
  void initState() {
    super.initState();

    for (final member in _members) {
      _selected[member.id] = false;
      _values[member.id] = TextEditingController();
    }

    final expense = widget.expense;

    if (expense != null) {
      _title.text = expense.title;
      _total.text = '${expense.totalAmount}';
      _note.text = expense.note ?? '';
      _paidBy = expense.paidById;
      _date = DateTime.parse(expense.expenseDate);
      _splitType = expense.splitType;

      for (final share in expense.shares) {
        // Anggota yang sudah tidak ada di grup diabaikan.
        if (!_selected.containsKey(share.userId)) continue;

        _selected[share.userId] = true;

        if (expense.splitType == 'exact') {
          _values[share.userId]!.text = '${share.amountOwed}';
        } else if (expense.splitType == 'percent') {
          _values[share.userId]!.text =
              _formatPercent(share.amountOwed / expense.totalAmount * 100);
        }
      }

      if (!_members.any((member) => member.id == _paidBy)) _paidBy = null;
    } else {
      _paidBy = context.read<AuthProvider>().userId;
      for (final member in _members) {
        _selected[member.id] = true;
      }
    }

    // Pendengar dipasang setelah nilai awal terisi, supaya rincian ikut diperbarui saat mengetik.
    _total.addListener(_onChanged);
    for (final controller in _values.values) {
      controller.addListener(_onChanged);
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _total.dispose();
    _note.dispose();
    for (final controller in _values.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  String _formatPercent(double value) {
    final rounded = (value * 100).round() / 100;
    return rounded == rounded.roundToDouble() ? '${rounded.toInt()}' : '$rounded';
  }

  int get _totalValue => int.tryParse(_total.text) ?? 0;

  double _percentOf(int id) =>
      double.tryParse(_values[id]!.text.replaceAll(',', '.')) ?? 0;

  List<int> get _selectedIds => [
        for (final member in _members)
          if (_selected[member.id] == true) member.id,
      ];

  int get _exactSum =>
      _selectedIds.fold(0, (sum, id) => sum + (int.tryParse(_values[id]!.text) ?? 0));

  double get _percentSum =>
      (_selectedIds.fold<double>(0, (sum, id) => sum + _percentOf(id)) * 100).round() / 100;

  // Sisa pembulatan dibebankan ke pembayar bila ia ikut dibagi; jika tidak, ke peserta pertama.
  int get _remainderTarget {
    final ids = _selectedIds;
    return (_paidBy != null && ids.contains(_paidBy)) ? _paidBy! : ids.first;
  }

  Map<int, int> get _preview {
    final ids = _selectedIds;
    final total = _totalValue;
    if (ids.isEmpty || total <= 0) return const {};

    final result = <int, int>{};

    if (_splitType == 'equal') {
      final base = total ~/ ids.length;
      for (final id in ids) {
        result[id] = base;
      }
      result[_remainderTarget] = result[_remainderTarget]! + (total - base * ids.length);
    } else if (_splitType == 'percent' && _percentSum == 100) {
      for (final id in ids) {
        result[id] = total * (_percentOf(id) * 100).round() ~/ 10000;
      }
      final assigned = result.values.fold(0, (sum, value) => sum + value);
      result[_remainderTarget] = result[_remainderTarget]! + (total - assigned);
    }

    return result;
  }

  bool get _canSubmit {
    if (_selectedIds.isEmpty || _totalValue <= 0) return false;
    if (_splitType == 'exact') return _exactSum == _totalValue;
    if (_splitType == 'percent') return _percentSum == 100;
    return true;
  }

  void _setSplitType(String value) {
    setState(() {
      _splitType = value;
      for (final controller in _values.values) {
        controller.clear();
      }
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (picked != null && mounted) setState(() => _date = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || !_canSubmit) return;

    final participants = [
      for (final id in _selectedIds)
        ParticipantInput(
          userId: id,
          amount: _splitType == 'exact' ? int.parse(_values[id]!.text) : null,
          percent: _splitType == 'percent' ? _percentOf(id) : null,
        ),
    ];

    final input = ExpenseInput(
      title: _title.text.trim(),
      totalAmount: _totalValue,
      paidBy: _paidBy!,
      date: DateFormat('yyyy-MM-dd').format(_date),
      splitType: _splitType,
      participants: participants,
      note: _note.text,
    );

    setState(() {
      _saving = true;
      _error = null;
      _fieldErrors = {};
    });

    try {
      if (_editing) {
        await _repository.updateExpense(widget.group.id, widget.expense!.id, input);
      } else {
        await _repository.createExpense(widget.group.id, input);
      }

      if (!mounted) return;
      showMessage(context, _editing ? 'Pengeluaran diperbarui.' : 'Pengeluaran dicatat.');
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = apiErrorMessage(e, fallback: 'Gagal menyimpan pengeluaran.');
        _fieldErrors = apiFieldErrors(e);
      });
    }
  }

  Widget _participantRow(GroupMember member, Map<int, int> preview) {
    final selected = _selected[member.id] == true;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Checkbox(
            value: selected,
            onChanged: (value) => setState(() => _selected[member.id] = value ?? false),
          ),
          Expanded(
            child: Text(member.name, overflow: TextOverflow.ellipsis),
          ),
          if (selected && _splitType == 'exact')
            SizedBox(
              width: 120,
              child: TextField(
                controller: _values[member.id],
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(12),
                ],
                decoration: const InputDecoration(
                  isDense: true,
                  hintText: 'Rp',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
          if (selected && _splitType == 'percent')
            SizedBox(
              width: 88,
              child: TextField(
                controller: _values[member.id],
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                  LengthLimitingTextInputFormatter(6),
                ],
                decoration: const InputDecoration(
                  isDense: true,
                  hintText: '%',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
          if (selected && _splitType != 'exact' && preview[member.id] != null)
            SizedBox(
              width: 96,
              child: Text(
                formatRupiah(preview[member.id]!),
                textAlign: TextAlign.right,
                style: const TextStyle(fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }

  Widget _splitHint(ThemeData theme) {
    const good = Color(0xFF059669);
    const bad = Color(0xFFBE123C);

    if (_selectedIds.isEmpty) {
      return const Text('Pilih minimal satu peserta.', style: TextStyle(color: bad, fontSize: 12));
    }

    switch (_splitType) {
      case 'exact':
        final ok = _exactSum == _totalValue && _totalValue > 0;
        return Text(
          'Jumlah porsi ${formatRupiah(_exactSum)} dari total ${formatRupiah(_totalValue)}. '
          '${ok ? 'Sudah pas.' : 'Harus sama persis.'}',
          style: TextStyle(color: ok ? good : bad, fontSize: 12),
        );
      case 'percent':
        final ok = _percentSum == 100;
        return Text(
          'Total persen ${_formatPercent(_percentSum)}%. ${ok ? 'Sudah pas.' : 'Harus tepat 100%.'}',
          style: TextStyle(color: ok ? good : bad, fontSize: 12),
        );
      default:
        return Text(
          'Dibagi rata. Sisa pembulatan (bila ada) dibebankan ke pembayar.',
          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final preview = _preview;
    final participantErrors = _fieldErrors.entries
        .where((entry) => entry.key.startsWith('participants'))
        .map((entry) => entry.value)
        .toList();

    return Scaffold(
      appBar: AppBar(title: Text(_editing ? 'Ubah pengeluaran' : 'Catat pengeluaran')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_error != null && _fieldErrors.isEmpty) ...[
              ErrorBox(_error!),
              const SizedBox(height: 16),
            ],
            TextFormField(
              controller: _title,
              textCapitalization: TextCapitalization.sentences,
              inputFormatters: [LengthLimitingTextInputFormatter(100)],
              decoration: InputDecoration(
                labelText: 'Judul',
                hintText: 'Contoh: Makan malam',
                border: const OutlineInputBorder(),
                errorText: _fieldErrors['title'],
              ),
              validator: (value) =>
                  (value == null || value.trim().isEmpty) ? 'Judul wajib diisi.' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _total,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(12),
              ],
              decoration: InputDecoration(
                labelText: 'Total (Rp)',
                border: const OutlineInputBorder(),
                errorText: _fieldErrors['total_amount'],
              ),
              validator: (value) {
                final amount = int.tryParse(value ?? '');
                return (amount == null || amount < 1) ? 'Masukkan total.' : null;
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<int>(
              initialValue: _paidBy,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: 'Dibayar oleh',
                border: const OutlineInputBorder(),
                errorText: _fieldErrors['paid_by'],
              ),
              items: [
                for (final member in _members)
                  DropdownMenuItem(value: member.id, child: Text(member.name)),
              ],
              onChanged: (value) => setState(() => _paidBy = value),
              validator: (value) => value == null ? 'Pilih pembayar.' : null,
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: _pickDate,
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: 'Tanggal',
                  border: const OutlineInputBorder(),
                  suffixIcon: const Icon(Icons.calendar_today_outlined),
                  errorText: _fieldErrors['expense_date'],
                ),
                child: Text(DateFormat('d MMMM y', 'id_ID').format(_date)),
              ),
            ),
            const SizedBox(height: 20),
            Text('Cara membagi', style: theme.textTheme.labelLarge),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'equal', label: Text('Sama rata')),
                ButtonSegment(value: 'exact', label: Text('Nominal')),
                ButtonSegment(value: 'percent', label: Text('Persen')),
              ],
              selected: {_splitType},
              onSelectionChanged: (selection) => _setSplitType(selection.first),
            ),
            const SizedBox(height: 16),
            Text('Dibagi ke siapa', style: theme.textTheme.labelLarge),
            const SizedBox(height: 4),
            for (final member in _members) _participantRow(member, preview),
            const SizedBox(height: 4),
            _splitHint(theme),
            if (participantErrors.isNotEmpty) ...[
              const SizedBox(height: 8),
              for (final message in participantErrors) ErrorBox(message),
            ],
            const SizedBox(height: 16),
            TextFormField(
              controller: _note,
              inputFormatters: [LengthLimitingTextInputFormatter(255)],
              decoration: InputDecoration(
                labelText: 'Catatan (opsional)',
                border: const OutlineInputBorder(),
                errorText: _fieldErrors['note'],
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: (_saving || !_canSubmit) ? null : _save,
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
  }
}