import 'package:flutter_test/flutter_test.dart';
import 'package:kantongku_mobile/features/transactions/transaction.dart';

void main() {
  test('Transaction.fromJson membaca pengeluaran', () {
    final transaction = Transaction.fromJson({
      'id': 5,
      'type': 'expense',
      'amount': 45000,
      'transaction_date': '2026-10-18',
      'note': 'Makan siang',
      'wallet': {'id': 2, 'name': 'BCA Utama', 'type': 'bank'},
      'to_wallet': null,
      'category': {'id': 1, 'name': 'Makan & Minum', 'type': 'expense'},
      'created_at': '2026-10-18T08:00:00.000000Z',
    });

    expect(transaction.amount, 45000);
    expect(transaction.title, 'Makan & Minum');
    expect(transaction.walletName, 'BCA Utama');
    expect(transaction.toWalletId, isNull);
    expect(transaction.note, 'Makan siang');
  });

  test('judul transfer memuat dompet asal dan tujuan', () {
    final transaction = Transaction.fromJson({
      'id': 6,
      'type': 'transfer',
      'amount': 500000,
      'transaction_date': '2026-10-18',
      'note': null,
      'wallet': {'id': 2, 'name': 'BCA Utama', 'type': 'bank'},
      'to_wallet': {'id': 1, 'name': 'Tunai', 'type': 'cash'},
      'category': null,
    });

    expect(transaction.title, 'BCA Utama → Tunai');
    expect(transaction.categoryId, isNull);
  });

  test('TransactionFilters.toQuery hanya memuat filter yang terisi', () {
    const filters = TransactionFilters(query: 'makan', type: 'expense', walletId: 2);

    expect(filters.isActive, isTrue);
    expect(filters.toQuery(), {'q': 'makan', 'type': 'expense', 'wallet_id': 2});

    expect(const TransactionFilters().isActive, isFalse);
    expect(const TransactionFilters().toQuery(), isEmpty);
  });

  test('TransactionInput.toJson tidak membawa kategori pada transfer', () {
    const input = TransactionInput(
      type: 'transfer',
      walletId: 2,
      toWalletId: 1,
      amount: 500000,
      date: '2026-10-18',
      note: '  ',
    );

    final json = input.toJson();

    expect(json['to_wallet_id'], 1);
    expect(json.containsKey('category_id'), isFalse);
    expect(json['note'], isNull);
  });
}