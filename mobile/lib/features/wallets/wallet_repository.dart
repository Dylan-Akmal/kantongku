import '../../core/api_client.dart';
import 'wallet.dart';

class WalletList {
  const WalletList({required this.wallets, required this.totalBalance});

  final List<Wallet> wallets;
  final int totalBalance;
}

class WalletRepository {
  WalletRepository(this._api);

  final ApiClient _api;

  Future<WalletList> list({bool includeArchived = false}) async {
    final response = await _api.dio.get(
      '/wallets',
      queryParameters: {'archived': includeArchived ? 1 : 0},
    );

    final body = response.data as Map<String, dynamic>;
    final wallets = (body['data'] as List)
        .map((item) => Wallet.fromJson(item as Map<String, dynamic>))
        .toList();
    final meta = body['meta'] as Map<String, dynamic>;

    return WalletList(
      wallets: wallets,
      totalBalance: (meta['total_balance'] as num).toInt(),
    );
  }

  Future<void> create({
    required String name,
    required String type,
    required int initialBalance,
  }) async {
    await _api.dio.post(
      '/wallets',
      data: {'name': name, 'type': type, 'initial_balance': initialBalance},
    );
  }

  Future<void> update(
    int id, {
    String? name,
    String? type,
    int? initialBalance,
    bool? isArchived,
  }) async {
    await _api.dio.put(
      '/wallets/$id',
      data: {
        'name': ?name,
        'type': ?type,
        'initial_balance': ?initialBalance,
        'is_archived': ?isArchived,
      },
    );
  }

  Future<void> delete(int id) async {
    await _api.dio.delete('/wallets/$id');
  }
}