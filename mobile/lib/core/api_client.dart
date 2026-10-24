import 'package:dio/dio.dart';

import 'config.dart';
import 'token_storage.dart';

class ApiClient {
  ApiClient(this._storage)
      : dio = Dio(
          BaseOptions(
            baseUrl: AppConfig.apiBaseUrl,
            connectTimeout: const Duration(seconds: 10),
            receiveTimeout: const Duration(seconds: 20),
            headers: {'Accept': 'application/json'},
          ),
        ) {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _storage.readToken();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (error, handler) async {
          final isAuthRequest = error.requestOptions.path.startsWith('/auth/');

          if (error.response?.statusCode == 401 && !isAuthRequest) {
            await _storage.clear();
            onUnauthorized?.call();
          }

          handler.next(error);
        },
      ),
    );
  }

  final TokenStorage _storage;
  final Dio dio;

  /// Dipanggil saat server menolak token (401) di luar permintaan masuk atau daftar.
  void Function()? onUnauthorized;
}