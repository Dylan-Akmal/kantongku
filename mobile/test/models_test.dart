import 'package:flutter_test/flutter_test.dart';
import 'package:kantongku_mobile/features/categories/category.dart';
import 'package:kantongku_mobile/features/wallets/wallet.dart';

void main() {
  test('Wallet.fromJson membaca balasan API dompet', () {
    final wallet = Wallet.fromJson({
      'id': 2,
      'name': 'BCA Utama',
      'type': 'bank',
      'initial_balance': 2000000,
      'balance': 5935000,
      'is_archived': false,
      'created_at': '2026-10-22T08:00:00.000000Z',
    });

    expect(wallet.id, 2);
    expect(wallet.name, 'BCA Utama');
    expect(wallet.type, 'bank');
    expect(wallet.initialBalance, 2000000);
    expect(wallet.balance, 5935000);
    expect(wallet.isArchived, isFalse);
  });

  test('Category.fromJson membaca balasan API kategori', () {
    final category = Category.fromJson({'id': 9, 'name': 'Gaji', 'type': 'income'});

    expect(category.id, 9);
    expect(category.name, 'Gaji');
    expect(category.type, 'income');
  });
}