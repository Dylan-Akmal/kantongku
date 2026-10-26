import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/api_errors.dart';
import 'error_box.dart';

/// Lembar dari bawah dengan satu isian teks. [onSubmit] menjalankan aksinya;
/// hasilnya dikembalikan ke pemanggil lewat Navigator.pop.
class SingleFieldSheet<T> extends StatefulWidget {
  const SingleFieldSheet({
    super.key,
    required this.title,
    required this.label,
    required this.submitText,
    required this.onSubmit,
    this.hint,
    this.helper,
    this.initialValue = '',
    this.maxLength = 60,
    this.errorKey = 'name',
    this.uppercaseCode = false,
  });

  final String title;
  final String label;
  final String submitText;
  final Future<T> Function(String value) onSubmit;
  final String? hint;
  final String? helper;
  final String initialValue;
  final int maxLength;

  /// Nama kolom di balasan kesalahan server yang ditampilkan di bawah isian.
  final String errorKey;

  /// Tampilan untuk kode undangan: huruf besar, lebar tetap.
  final bool uppercaseCode;

  /// Mengembalikan hasil [onSubmit], atau null bila lembar ditutup tanpa menyimpan.
  static Future<T?> show<T>(
    BuildContext context, {
    required String title,
    required String label,
    required String submitText,
    required Future<T> Function(String value) onSubmit,
    String? hint,
    String? helper,
    String initialValue = '',
    int maxLength = 60,
    String errorKey = 'name',
    bool uppercaseCode = false,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => SingleFieldSheet<T>(
        title: title,
        label: label,
        submitText: submitText,
        onSubmit: onSubmit,
        hint: hint,
        helper: helper,
        initialValue: initialValue,
        maxLength: maxLength,
        errorKey: errorKey,
        uppercaseCode: uppercaseCode,
      ),
    );
  }

  @override
  State<SingleFieldSheet<T>> createState() => _SingleFieldSheetState<T>();
}

class _SingleFieldSheetState<T> extends State<SingleFieldSheet<T>> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _controller = TextEditingController(text: widget.initialValue);

  bool _saving = false;
  String? _error;
  String? _fieldError;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _saving = true;
      _error = null;
      _fieldError = null;
    });

    try {
      final result = await widget.onSubmit(_controller.text.trim());

      if (!mounted) return;
      Navigator.of(context).pop(result);
    } catch (e) {
      if (!mounted) return;

      final fieldError = apiFieldErrors(e)[widget.errorKey];

      setState(() {
        _saving = false;
        _fieldError = fieldError;
        _error = fieldError == null ? apiErrorMessage(e, fallback: 'Gagal menyimpan.') : null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.title,
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),
              if (_error != null) ...[
                ErrorBox(_error!),
                const SizedBox(height: 12),
              ],
              TextFormField(
                controller: _controller,
                autofocus: true,
                textCapitalization:
                    widget.uppercaseCode ? TextCapitalization.characters : TextCapitalization.words,
                style: widget.uppercaseCode
                    ? const TextStyle(fontFamily: 'monospace', letterSpacing: 2, fontSize: 18)
                    : null,
                inputFormatters: [LengthLimitingTextInputFormatter(widget.maxLength)],
                decoration: InputDecoration(
                  labelText: widget.label,
                  hintText: widget.hint,
                  helperText: widget.helper,
                  border: const OutlineInputBorder(),
                  errorText: _fieldError,
                ),
                validator: (value) =>
                    (value == null || value.trim().isEmpty) ? '${widget.label} wajib diisi.' : null,
                onFieldSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _saving ? null : () => Navigator.of(context).pop(),
                    child: const Text('Batal'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _saving ? null : _submit,
                    child: Text(_saving ? 'Memproses...' : widget.submitText),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}