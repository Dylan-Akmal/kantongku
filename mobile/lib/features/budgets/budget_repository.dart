import '../../core/api_client.dart';
import 'budget.dart';

class BudgetRepository {
  BudgetRepository(this._api);

  final ApiClient _api;

  Future<BudgetList> list(String month) async {
    final response = await _api.dio.get('/budgets', queryParameters: {'month': month});
    final body = response.data as Map<String, dynamic>;
    final meta = body['meta'] as Map<String, dynamic>;

    return BudgetList(
      budgets: (body['data'] as List)
          .map((item) => Budget.fromJson(item as Map<String, dynamic>))
          .toList(),
      totalBudget: (meta['total_budget'] as num).toInt(),
      totalSpent: (meta['total_spent'] as num).toInt(),
    );
  }

  /// Membuat anggaran baru, atau memperbarui bila kategori dan bulannya sudah punya anggaran.
  /// Mengembalikan pesan dari server.
  Future<String> save({
    required int categoryId,
    required String month,
    required int amount,
  }) async {
    final response = await _api.dio.post(
      '/budgets',
      data: {'category_id': categoryId, 'month': month, 'amount': amount},
    );

    return (response.data as Map<String, dynamic>)['message'] as String;
  }

  Future<void> delete(int id) async {
    await _api.dio.delete('/budgets/$id');
  }
}