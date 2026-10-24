class AppConfig {
  /// Alamat API. Emulator Android mengakses komputer host lewat 10.0.2.2.
  ///
  /// Untuk ponsel sungguhan (satu jaringan Wi-Fi dengan komputer):
  ///   php artisan serve --host=0.0.0.0
  ///   flutter run --dart-define=API_URL=http://192.168.x.x:8000/api
  static const String apiBaseUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'http://10.0.2.2:8000/api',
  );
}