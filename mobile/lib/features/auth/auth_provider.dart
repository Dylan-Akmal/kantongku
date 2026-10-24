import 'package:flutter/foundation.dart';

import '../../core/api_client.dart';
import '../../core/token_storage.dart';

class AuthProvider extends ChangeNotifier {
  AuthProvider(this._storage, this._api) {
    _api.onUnauthorized = _handleUnauthorized;
  }

  final TokenStorage _storage;
  final ApiClient _api;

  String? _token;
  Map<String, dynamic>? _user;

  bool get isLoggedIn => _token != null;
  Map<String, dynamic>? get user => _user;
  int? get userId => _user?['id'] as int?;
  String get userName => (_user?['name'] as String?) ?? '';

  /// Membaca sesi tersimpan saat aplikasi dibuka.
  Future<void> restore() async {
    _token = await _storage.readToken();
    _user = await _storage.readUser();
    notifyListeners();
  }

  Future<void> login(String email, String password) async {
    final response = await _api.dio.post(
      '/auth/login',
      data: {'email': email, 'password': password},
    );
    await _persist(response.data['data'] as Map<String, dynamic>);
  }

  Future<void> register(String name, String email, String password) async {
    final response = await _api.dio.post(
      '/auth/register',
      data: {'name': name, 'email': email, 'password': password},
    );
    await _persist(response.data['data'] as Map<String, dynamic>);
  }

  /// Menyegarkan data pengguna; kegagalan diabaikan (token tidak valid ditangani klien HTTP).
  Future<void> refreshUser() async {
    try {
      final response = await _api.dio.get('/me');
      _user = response.data['data'] as Map<String, dynamic>;
      await _storage.saveUser(_user!);
      notifyListeners();
    } catch (_) {}
  }

  Future<void> logout() async {
    try {
      await _api.dio.post('/auth/logout');
    } catch (_) {
      // Token mungkin sudah tidak berlaku; tetap bersihkan sesi lokal.
    }

    await _storage.clear();
    _token = null;
    _user = null;
    notifyListeners();
  }

  Future<void> _persist(Map<String, dynamic> data) async {
    final token = data['token'] as String;
    final user = data['user'] as Map<String, dynamic>;

    await _storage.saveSession(token, user);
    _token = token;
    _user = user;
    notifyListeners();
  }

  void _handleUnauthorized() {
    _token = null;
    _user = null;
    notifyListeners();
  }
}