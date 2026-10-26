import 'package:flutter_test/flutter_test.dart';
import 'package:kantongku_mobile/core/month.dart';
import 'package:kantongku_mobile/features/budgets/budget.dart';
import 'package:kantongku_mobile/features/reports/report.dart';

void main() {
  test('shiftMonth melewati batas tahun', () {
    expect(shiftMonth('2026-12', 1), '2027-01');
    expect(shiftMonth('2026-01', -1), '2025-12');
    expect(shiftMonth('2026-10', 0), '2026-10');
  });

  test('Budget.fromJson membaca anggaran yang melebihi batas', () {
    final budget = Budget.fromJson({
      'id': 1,
      'category': {'id': 3, 'name': 'Belanja'},
      'month': '2026-10',
      'amount': 200000,
      'spent': 250000,
      'remaining': -50000,
      'percentage': 125,
      'is_over': true,
    });

    expect(budget.categoryName, 'Belanja');
    expect(budget.spent, 250000);
    expect(budget.remaining, -50000);
    expect(budget.percentage, 125.0);
    expect(budget.isOver, isTrue);
  });

  test('MonthlyReport.fromJson membaca ringkasan dan rincian kategori', () {
    final report = MonthlyReport.fromJson({
      'month': '2026-10',
      'total_income': 5000000,
      'total_expense': 485000,
      'net': 4515000,
      'transaction_count': 6,
      'expense_by_category': [
        {'category_id': 3, 'name': 'Belanja', 'total': 250000, 'percentage': 51.5},
        {'category_id': 1, 'name': 'Makan & Minum', 'total': 105000, 'percentage': 21.6},
      ],
    });

    expect(report.net, 4515000);
    expect(report.transactionCount, 6);
    expect(report.expenseByCategory.first.name, 'Belanja');
    expect(report.expenseByCategory.first.percentage, 51.5);
  });

  test('DailyTotal.fromJson membaca satu hari', () {
    final day = DailyTotal.fromJson({'date': '2026-10-23', 'income': 5000000, 'expense': 145000});

    expect(day.date, '2026-10-23');
    expect(day.income, 5000000);
    expect(day.expense, 145000);
  });
}