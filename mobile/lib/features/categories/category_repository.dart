import '../../../core/api_client.dart';
import 'category.dart';

class CategoryRepository {
  CategoryRepository(this._api);

  final ApiClient _api;

  Future<List<Category>> list(String type) async {
    final response = await _api.dio.get('/categories', queryParameters: {'type': type});
    final body = response.data as Map<String, dynamic>;

    return (body['data'] as List)
        .map((item) => Category.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<void> create({required String name, required String type}) async {
    await _api.dio.post('/categories', data: {'name': name, 'type': type});
  }

  Future<void> rename(int id, String name) async {
    await _api.dio.put('/categories/$id', data: {'name': name});
  }

  Future<void> delete(int id) async {
    await _api.dio.delete('/categories/$id');
  }
}