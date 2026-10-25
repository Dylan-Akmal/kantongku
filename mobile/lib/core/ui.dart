import 'package:flutter/material.dart';

/// Dialog "Yakin?". Mengembalikan true bila pengguna menyetujui.
Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmText = 'Ya',
  bool destructive = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Batal'),
        ),
        FilledButton(
          style: destructive
              ? FilledButton.styleFrom(backgroundColor: const Color(0xFFBE123C))
              : null,
          onPressed: () => Navigator.pop(dialogContext, true),
          child: Text(confirmText),
        ),
      ],
    ),
  );

  return result ?? false;
}

void showMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}