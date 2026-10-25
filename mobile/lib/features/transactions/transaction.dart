class Transaction {
  const Transaction({
    required this.id,
    required this.type,
    required this.amount,
    required this.date,
    required this.walletId,
    required this.walletName,
    this.note,
    this.toWalletId,
    this.toWalletName,
    this.categoryId,
    this.categoryName,
  });

  final int id;
  final String type;
  final int amount;
  final String date;
  final String? note;
  final int walletId;
  final String walletName;
  final int? toWalletId;
  final String? toWalletName;
  final int? categoryId;
  final String? categoryName;

  factory Transaction.fromJson(Map<String, dynamic> json) {
    final wallet = json['wallet'] as Map<String, dynamic>;
    final toWallet = json['to_wallet'] as Map<String, dynamic>?;
    final category = json['category'] as Map<String, dynamic>?;

    return Transaction(
      id: json['id'] as int,
      type: json['type'] as String,
      amount: (json['amount'] as num).toInt(),
      date: json['transaction_date'] as String,
      note: json['note'] as String?,
      walletId: wallet['id'] as int,
      walletName: wallet['name'] as String,
      toWalletId: toWallet?['id'] as int?,
      toWalletName: toWallet?['name'] as String?,
      categoryId: category?['id'] as int?,
      categoryName: category?['name'] as String?,
    );
  }

  /// Judul baris: nama kategori, atau "Asal → Tujuan" untuk transfer.
  String get title {
    if (type == 'transfer') return '$walletName → ${toWalletName ?? ''}';
    return categoryName ?? '';
  }
}

class TransactionFilters {
  const TransactionFilters({
    this.query = '',
    this.type,
    this.walletId,
    this.categoryId,
    this.dateFrom,
    this.dateTo,
  });

  final String query;
  final String? type;
  final int? walletId;
  final int? categoryId;
  final String? dateFrom;
  final String? dateTo;

  bool get isActive =>
      query.isNotEmpty ||
      type != null ||
      walletId != null ||
      categoryId != null ||
      dateFrom != null ||
      dateTo != null;

  /// Hanya memuat filter yang terisi, sesuai nama parameter di API.
  Map<String, dynamic> toQuery() {
    return {
      if (query.isNotEmpty) 'q': query,
      'type': ?type,
      'wallet_id': ?walletId,
      'category_id': ?categoryId,
      'date_from': ?dateFrom,
      'date_to': ?dateTo,
    };
  }
}

class TransactionInput {
  const TransactionInput({
    required this.type,
    required this.walletId,
    required this.amount,
    required this.date,
    this.toWalletId,
    this.categoryId,
    this.note,
  });

  final String type;
  final int walletId;
  final int? toWalletId;
  final int? categoryId;
  final int amount;
  final String date;
  final String? note;

  Map<String, dynamic> toJson() {
    final cleanNote = (note ?? '').trim();

    return {
      'type': type,
      'wallet_id': walletId,
      'to_wallet_id': ?toWalletId,
      'category_id': ?categoryId,
      'amount': amount,
      'transaction_date': date,
      'note': cleanNote.isEmpty ? null : cleanNote,
    };
  }
}

class TransactionPage {
  const TransactionPage({
    required this.items,
    required this.currentPage,
    required this.lastPage,
    required this.total,
  });

  final List<Transaction> items;
  final int currentPage;
  final int lastPage;
  final int total;
}