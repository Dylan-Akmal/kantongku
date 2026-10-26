class Budget {
  const Budget({
    required this.id,
    required this.categoryId,
    required this.categoryName,
    required this.amount,
    required this.spent,
    required this.remaining,
    required this.percentage,
    required this.isOver,
  });

  final int id;
  final int categoryId;
  final String categoryName;
  final int amount;
  final int spent;
  final int remaining;
  final double percentage;
  final bool isOver;

  factory Budget.fromJson(Map<String, dynamic> json) {
    final category = json['category'] as Map<String, dynamic>;

    return Budget(
      id: json['id'] as int,
      categoryId: category['id'] as int,
      categoryName: category['name'] as String,
      amount: (json['amount'] as num).toInt(),
      spent: (json['spent'] as num).toInt(),
      remaining: (json['remaining'] as num).toInt(),
      percentage: (json['percentage'] as num).toDouble(),
      isOver: json['is_over'] as bool,
    );
  }
}

class BudgetList {
  const BudgetList({
    required this.budgets,
    required this.totalBudget,
    required this.totalSpent,
  });

  final List<Budget> budgets;
  final int totalBudget;
  final int totalSpent;
}