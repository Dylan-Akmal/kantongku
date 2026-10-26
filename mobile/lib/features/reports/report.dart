class CategoryTotal {
  const CategoryTotal({required this.name, required this.total, required this.percentage});

  final String name;
  final int total;
  final double percentage;

  factory CategoryTotal.fromJson(Map<String, dynamic> json) {
    return CategoryTotal(
      name: json['name'] as String,
      total: (json['total'] as num).toInt(),
      percentage: (json['percentage'] as num).toDouble(),
    );
  }
}

class MonthlyReport {
  const MonthlyReport({
    required this.totalIncome,
    required this.totalExpense,
    required this.net,
    required this.transactionCount,
    required this.expenseByCategory,
  });

  final int totalIncome;
  final int totalExpense;
  final int net;
  final int transactionCount;
  final List<CategoryTotal> expenseByCategory;

  factory MonthlyReport.fromJson(Map<String, dynamic> json) {
    return MonthlyReport(
      totalIncome: (json['total_income'] as num).toInt(),
      totalExpense: (json['total_expense'] as num).toInt(),
      net: (json['net'] as num).toInt(),
      transactionCount: json['transaction_count'] as int,
      expenseByCategory: (json['expense_by_category'] as List)
          .map((item) => CategoryTotal.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}

class DailyTotal {
  const DailyTotal({required this.date, required this.income, required this.expense});

  final String date;
  final int income;
  final int expense;

  factory DailyTotal.fromJson(Map<String, dynamic> json) {
    return DailyTotal(
      date: json['date'] as String,
      income: (json['income'] as num).toInt(),
      expense: (json['expense'] as num).toInt(),
    );
  }
}