import 'package:dio/dio.dart';

/// Pesan kesalahan dari server, atau teks cadangan bila server tidak menjawab.
String apiErrorMessage(
  Object error, {
  String fallback = 'Terjadi kesalahan. Coba lagi.',
}) {
  if (error is DioException) {
    final response = error.response;

    if (response == null) {
      return 'Tidak bisa terhubung ke server. Pastikan API sedang berjalan.';
    }

    final data = response.data;
    if (data is Map && data['message'] is String) {
      return data['message'] as String;
    }
  }

  return fallback;
}

/// Kesalahan per kolom dari validasi server (422), mis. {'email': '...'}.
Map<String, String> apiFieldErrors(Object error) {
  if (error is DioException) {
    final data = error.response?.data;

    if (data is Map && data['errors'] is Map) {
      final errors = data['errors'] as Map;

      return errors.map<String, String>((key, value) {
        final first = value is List && value.isNotEmpty ? value.first : value;
        return MapEntry(key.toString(), first.toString());
      });
    }
  }

  return {};
}