import 'package:dio/dio.dart';

import '../../core/api_client.dart';
import 'group.dart';

class GroupRepository {
  GroupRepository(this._api);

  final ApiClient _api;

  Group _parse(Response<dynamic> response) {
    final body = response.data as Map<String, dynamic>;
    return Group.fromJson(body['data'] as Map<String, dynamic>);
  }

  Future<List<Group>> list() async {
    final response = await _api.dio.get('/groups');
    final body = response.data as Map<String, dynamic>;

    return (body['data'] as List)
        .map((item) => Group.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<Group> show(int id) async => _parse(await _api.dio.get('/groups/$id'));

  Future<Group> create(String name) async {
    return _parse(await _api.dio.post('/groups', data: {'name': name}));
  }

  Future<Group> join(String inviteCode) async {
    return _parse(await _api.dio.post('/groups/join', data: {'invite_code': inviteCode}));
  }

  Future<void> rename(int id, String name) async {
    await _api.dio.put('/groups/$id', data: {'name': name});
  }

  Future<void> regenerateCode(int id) async {
    await _api.dio.post('/groups/$id/regenerate-code');
  }

  Future<void> leave(int id) async {
    await _api.dio.post('/groups/$id/leave');
  }

  Future<void> removeMember(int groupId, int userId) async {
    await _api.dio.delete('/groups/$groupId/members/$userId');
  }

  Future<void> delete(int id) async {
    await _api.dio.delete('/groups/$id');
  }
}