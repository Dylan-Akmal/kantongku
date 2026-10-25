class Wallet {
  const Wallet({
    required this.id,
    required this.name,
    required this.type,
    required this.initialBalance,
    required this.balance,
    required this.isArchived,
  });

  final int id;
  final String name;
  final String type;
  final int initialBalance;
  final int balance;
  final bool isArchived;

  factory Wallet.fromJson(Map<String, dynamic> json) {
    return Wallet(
      id: json['id'] as int,
      name: json['name'] as String,
      type: json['type'] as String,
      initialBalance: (json['initial_balance'] as num).toInt(),
      balance: (json['balance'] as num).toInt(),
      isArchived: json['is_archived'] as bool,
    );
  }
}