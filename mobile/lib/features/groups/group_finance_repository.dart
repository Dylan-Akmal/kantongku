import 'package:dio/dio.dart';

import '../../core/api_client.dart';
import 'group_finance.dart';

class GroupFinanceRepository {
  GroupFinanceRepository(this._api);

  final ApiClient _api;

  Paged<T> _paged<T>(Response<dynamic> response, T Function(Map<String, dynamic>) parse) {
    final body = response.data as Map<String, dynamic>;
    final meta = body['meta'] as Map<String, dynamic>;

    return Paged<T>(
      items: (body['data'] as List).map((item) => parse(item as Map<String, dynamic>)).toList(),
      currentPage: meta['current_page'] as int,
      lastPage: meta['last_page'] as int,
      total: meta['total'] as int,
    );
  }

  Future<Paged<GroupExpense>> expenses(int groupId, {int page = 1, int perPage = 10}) async {
    final response = await _api.dio.get(
      '/groups/$groupId/expenses',
      queryParameters: {'page': page, 'per_page': perPage},
    );

    return _paged(response, GroupExpense.fromJson);
  }

  Future<void> createExpense(int groupId, ExpenseInput input) async {
    await _api.dio.post('/groups/$groupId/expenses', data: input.toJson());
  }

  Future<void> updateExpense(int groupId, int expenseId, ExpenseInput input) async {
    await _api.dio.put('/groups/$groupId/expenses/$expenseId', data: input.toJson());
  }

  Future<void> deleteExpense(int groupId, int expenseId) async {
    await _api.dio.delete('/groups/$groupId/expenses/$expenseId');
  }

  Future<GroupBalances> balances(int groupId) async {
    final response = await _api.dio.get('/groups/$groupId/balances');
    final body = response.data as Map<String, dynamic>;

    return GroupBalances.fromJson(body['data'] as Map<String, dynamic>);
  }

  Future<void> createSettlement(
    int groupId, {
    required int toUserId,
    required int amount,
    String? note,
  }) async {
    final cleanNote = (note ?? '').trim();

    await _api.dio.post(
      '/groups/$groupId/settlements',
      data: {
        'to_user_id': toUserId,
        'amount': amount,
        'note': cleanNote.isEmpty ? null : cleanNote,
      },
    );
  }

  Future<void> deleteSettlement(int groupId, int settlementId) async {
    await _api.dio.delete('/groups/$groupId/settlements/$settlementId');
  }

  Future<Paged<HistoryItem>> history(int groupId, {int page = 1, int perPage = 15}) async {
    final response = await _api.dio.get(
      '/groups/$groupId/history',
      queryParameters: {'page': page, 'per_page': perPage},
    );

    return _paged(response, HistoryItem.fromJson);
  }
}