import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kantongku_mobile/core/api_errors.dart';
import 'package:kantongku_mobile/core/format.dart';

DioException serverError(Map<String, dynamic> body, {int status = 422}) {
  final request = RequestOptions(path: '/auth/login');
  return DioException(
    requestOptions: request,
    response: Response(requestOptions: request, statusCode: status, data: body),
  );
}

void main() {
  test('formatRupiah memakai titik sebagai pemisah ribuan', () {
    final text = formatRupiah(1500000);

    expect(text, startsWith('Rp'));
    expect(text, contains('1.500.000'));
  });

  test('pesan kesalahan diambil dari balasan server', () {
    final error = serverError({'message': 'Email atau kata sandi salah.'}, status: 401);

    expect(apiErrorMessage(error), 'Email atau kata sandi salah.');
  });

  test('tanpa balasan server, pesannya soal koneksi', () {
    final error = DioException(requestOptions: RequestOptions(path: '/x'));

    expect(apiErrorMessage(error), contains('terhubung'));
  });

  test('kesalahan per kolom diambil dari errors', () {
    final error = serverError({
      'message': 'The email has already been taken.',
      'errors': {
        'email': ['The email has already been taken.'],
      },
    });

    expect(apiFieldErrors(error), {'email': 'The email has already been taken.'});
  });
}