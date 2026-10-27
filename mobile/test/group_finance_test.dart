import 'package:flutter_test/flutter_test.dart';
import 'package:kantongku_mobile/features/groups/group_finance.dart';

void main() {
  test('GroupExpense.fromJson membaca pengeluaran beserta porsinya', () {
    final expense = GroupExpense.fromJson({
      'id': 3,
      'group_id': 4,
      'title': 'Taksi',
      'total_amount': 90000,
      'split_type': 'exact',
      'expense_date': '2026-10-24',
      'note': null,
      'paid_by': {'id': 2, 'name': 'Teman Uji'},
      'created_by': {'id': 1, 'name': 'Ujiii123'},
      'shares': [
        {
          'user': {'id': 1, 'name': 'Ujiii123'},
          'amount_owed': 60000,
        },
        {
          'user': {'id': 2, 'name': 'Teman Uji'},
          'amount_owed': 30000,
        },
      ],
      'created_at': '2026-10-24T05:00:00.000000Z',
    });

    expect(expense.title, 'Taksi');
    expect(expense.paidById, 2);
    expect(expense.createdById, 1);
    expect(expense.note, isNull);
    expect(expense.shares, hasLength(2));
    expect(expense.shares.first.amountOwed, 60000);
    expect(expense.shares.fold<int>(0, (sum, share) => sum + share.amountOwed), 90000);
  });

  test('GroupBalances.fromJson membaca saldo dan cara melunasi', () {
    final data = GroupBalances.fromJson({
      'my_balance': 290000,
      'balances': [
        {'user_id': 1, 'name': 'Ujiii123', 'balance': 290000},
        {'user_id': 2, 'name': 'Teman Uji', 'balance': -290000},
      ],
      'settle_up': [
        {
          'from': {'id': 2, 'name': 'Teman Uji'},
          'to': {'id': 1, 'name': 'Ujiii123'},
          'amount': 290000,
        },
      ],
    });

    expect(data.myBalance, 290000);
    expect(data.balances.last.balance, -290000);
    expect(data.settleUp.single.fromId, 2);
    expect(data.settleUp.single.toName, 'Ujiii123');
    expect(data.settleUp.single.amount, 290000);
  });

  test('HistoryItem.fromJson membedakan pengeluaran dan pelunasan', () {
    final expense = HistoryItem.fromJson({
      'type': 'expense',
      'id': 1,
      'date': '2026-10-24',
      'title': 'Makan malam',
      'amount': 300000,
      'paid_by': {'id': 1, 'name': 'Ujiii123'},
      'recorded_at': '2026-10-24T05:00:00.000000Z',
    });

    final settlement = HistoryItem.fromJson({
      'type': 'settlement',
      'id': 7,
      'date': '2026-10-24',
      'from': {'id': 2, 'name': 'Teman Uji'},
      'to': {'id': 1, 'name': 'Ujiii123'},
      'amount': 40000,
      'note': 'Cicil',
    });

    expect(expense.isExpense, isTrue);
    expect(expense.paidByName, 'Ujiii123');
    expect(settlement.isExpense, isFalse);
    expect(settlement.fromId, 2);
    expect(settlement.toName, 'Ujiii123');
    expect(settlement.note, 'Cicil');
  });

  test('ExpenseInput.toJson hanya memuat nominal atau persen yang relevan', () {
    const input = ExpenseInput(
      title: 'Tiket wisata',
      totalAmount: 200000,
      paidBy: 1,
      date: '2026-10-24',
      splitType: 'percent',
      note: '  ',
      participants: [
        ParticipantInput(userId: 1, percent: 25),
        ParticipantInput(userId: 2, percent: 75),
      ],
    );

    final json = input.toJson();
    final participants = json['participants'] as List;

    expect(json['note'], isNull);
    expect(json['split_type'], 'percent');
    expect(participants.first, {'user_id': 1, 'percent': 25.0});
    expect((participants.last as Map).containsKey('amount'), isFalse);
  });
}