import '../../core/api_client.dart';
import 'transaction.dart';

class TransactionRepository {
  TransactionRepository(this._api);

  final ApiClient _api;

  Future<TransactionPage> list({
    required int page,
    int perPage = 15,
    TransactionFilters filters = const TransactionFilters(),
  }) async {
    final response = await _api.dio.get(
      '/transactions',
      queryParameters: {'page': page, 'per_page': perPage, ...filters.toQuery()},
    );

    final body = response.data as Map<String, dynamic>;
    final meta = body['meta'] as Map<String, dynamic>;

    return TransactionPage(
      items: (body['data'] as List)
          .map((item) => Transaction.fromJson(item as Map<String, dynamic>))
          .toList(),
      currentPage: meta['current_page'] as int,
      lastPage: meta['last_page'] as int,
      total: meta['total'] as int,
    );
  }

  Future<void> create(TransactionInput input) async {
    await _api.dio.post('/transactions', data: input.toJson());
  }

  Future<void> update(int id, TransactionInput input) async {
    await _api.dio.put('/transactions/$id', data: input.toJson());
  }

  Future<void> delete(int id) async {
    await _api.dio.delete('/transactions/$id');
  }
}