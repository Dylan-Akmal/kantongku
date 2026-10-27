const Map<String, String> splitTypeLabels = {
  'equal': 'Sama rata',
  'exact': 'Nominal',
  'percent': 'Persen',
};

/// Hasil satu halaman dari daftar yang dipaginasi server.
class Paged<T> {
  const Paged({
    required this.items,
    required this.currentPage,
    required this.lastPage,
    required this.total,
  });

  final List<T> items;
  final int currentPage;
  final int lastPage;
  final int total;

  bool get hasMore => currentPage < lastPage;
}

class ExpenseShare {
  const ExpenseShare({required this.userId, required this.name, required this.amountOwed});

  final int userId;
  final String name;
  final int amountOwed;

  factory ExpenseShare.fromJson(Map<String, dynamic> json) {
    final user = json['user'] as Map<String, dynamic>?;

    return ExpenseShare(
      userId: (user?['id'] as int?) ?? 0,
      name: (user?['name'] as String?) ?? '',
      amountOwed: (json['amount_owed'] as num).toInt(),
    );
  }
}

class GroupExpense {
  const GroupExpense({
    required this.id,
    required this.title,
    required this.totalAmount,
    required this.splitType,
    required this.expenseDate,
    required this.paidById,
    required this.paidByName,
    required this.createdById,
    required this.createdByName,
    required this.shares,
    this.note,
  });

  final int id;
  final String title;
  final int totalAmount;
  final String splitType;
  final String expenseDate;
  final String? note;
  final int paidById;
  final String paidByName;
  final int createdById;
  final String createdByName;
  final List<ExpenseShare> shares;

  factory GroupExpense.fromJson(Map<String, dynamic> json) {
    final paidBy = json['paid_by'] as Map<String, dynamic>;
    final createdBy = json['created_by'] as Map<String, dynamic>;

    return GroupExpense(
      id: json['id'] as int,
      title: json['title'] as String,
      totalAmount: (json['total_amount'] as num).toInt(),
      splitType: json['split_type'] as String,
      expenseDate: json['expense_date'] as String,
      note: json['note'] as String?,
      paidById: paidBy['id'] as int,
      paidByName: paidBy['name'] as String,
      createdById: createdBy['id'] as int,
      createdByName: createdBy['name'] as String,
      shares: (json['shares'] as List)
          .map((item) => ExpenseShare.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}

class MemberBalance {
  const MemberBalance({required this.userId, required this.name, required this.balance});

  final int userId;
  final String name;
  final int balance;

  factory MemberBalance.fromJson(Map<String, dynamic> json) {
    return MemberBalance(
      userId: json['user_id'] as int,
      name: (json['name'] as String?) ?? '',
      balance: (json['balance'] as num).toInt(),
    );
  }
}

/// Satu pembayaran dalam daftar "cara melunasi semuanya".
class Payment {
  const Payment({
    required this.fromId,
    required this.fromName,
    required this.toId,
    required this.toName,
    required this.amount,
  });

  final int fromId;
  final String fromName;
  final int toId;
  final String toName;
  final int amount;

  factory Payment.fromJson(Map<String, dynamic> json) {
    final from = json['from'] as Map<String, dynamic>;
    final to = json['to'] as Map<String, dynamic>;

    return Payment(
      fromId: from['id'] as int,
      fromName: (from['name'] as String?) ?? '',
      toId: to['id'] as int,
      toName: (to['name'] as String?) ?? '',
      amount: (json['amount'] as num).toInt(),
    );
  }
}

class GroupBalances {
  const GroupBalances({
    required this.myBalance,
    required this.balances,
    required this.settleUp,
  });

  final int myBalance;
  final List<MemberBalance> balances;
  final List<Payment> settleUp;

  factory GroupBalances.fromJson(Map<String, dynamic> json) {
    return GroupBalances(
      myBalance: (json['my_balance'] as num).toInt(),
      balances: (json['balances'] as List)
          .map((item) => MemberBalance.fromJson(item as Map<String, dynamic>))
          .toList(),
      settleUp: (json['settle_up'] as List)
          .map((item) => Payment.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// Satu baris di riwayat grup: pengeluaran atau pelunasan.
class HistoryItem {
  const HistoryItem({
    required this.type,
    required this.id,
    required this.date,
    required this.amount,
    this.title,
    this.note,
    this.paidByName,
    this.fromId,
    this.fromName,
    this.toName,
  });

  final String type;
  final int id;
  final String date;
  final int amount;
  final String? title;
  final String? note;
  final String? paidByName;
  final int? fromId;
  final String? fromName;
  final String? toName;

  bool get isExpense => type == 'expense';

  factory HistoryItem.fromJson(Map<String, dynamic> json) {
    final paidBy = json['paid_by'] as Map<String, dynamic>?;
    final from = json['from'] as Map<String, dynamic>?;
    final to = json['to'] as Map<String, dynamic>?;

    return HistoryItem(
      type: json['type'] as String,
      id: json['id'] as int,
      date: json['date'] as String,
      amount: (json['amount'] as num).toInt(),
      title: json['title'] as String?,
      note: json['note'] as String?,
      paidByName: paidBy?['name'] as String?,
      fromId: from?['id'] as int?,
      fromName: from?['name'] as String?,
      toName: to?['name'] as String?,
    );
  }
}

class ParticipantInput {
  const ParticipantInput({required this.userId, this.amount, this.percent});

  final int userId;
  final int? amount;
  final double? percent;
}

class ExpenseInput {
  const ExpenseInput({
    required this.title,
    required this.totalAmount,
    required this.paidBy,
    required this.date,
    required this.splitType,
    required this.participants,
    this.note,
  });

  final String title;
  final int totalAmount;
  final int paidBy;
  final String date;
  final String splitType;
  final List<ParticipantInput> participants;
  final String? note;

  Map<String, dynamic> toJson() {
    final cleanNote = (note ?? '').trim();

    return {
      'title': title,
      'total_amount': totalAmount,
      'paid_by': paidBy,
      'expense_date': date,
      'note': cleanNote.isEmpty ? null : cleanNote,
      'split_type': splitType,
      'participants': [
        for (final participant in participants)
          {
            'user_id': participant.userId,
            'amount': ?participant.amount,
            'percent': ?participant.percent,
          },
      ],
    };
  }
}