# Kantongku Mobile

Aplikasi Android Kantongku, dibangun dengan Flutter. Aplikasi ini memakai REST API di folder `backend`.

## Menjalankan

Prasyarat: Flutter SDK, Android Studio dengan emulator (atau ponsel Android), dan API yang sudah berjalan (lihat README di root repo).

```bash
flutter pub get
flutter run
```

Alamat API bawaan adalah `http://10.0.2.2:8000/api`, yaitu alamat komputer host dari dalam emulator Android. Untuk ponsel sungguhan, jalankan backend dengan `php artisan serve --host=0.0.0.0` lalu ganti alamatnya:

```bash
flutter run --dart-define=API_URL=http://192.168.x.x:8000/api
```

Jika build Android gagal karena versi Java tidak cocok dengan Gradle, arahkan Gradle ke JDK yang kompatibel lewat berkas pengguna `~/.gradle/gradle.properties` (`org.gradle.java.home=...`). Jangan menaruh jalur itu di dalam repo.

## Pengujian

```bash
flutter analyze
flutter test
```

Keduanya juga dijalankan otomatis di GitHub Actions (workflow **Mobile Checks**).

## Struktur `lib`

- `core/` konfigurasi, klien HTTP (Dio), penyimpanan token, format rupiah dan tanggal, label
- `features/` satu folder per fitur: `auth`, `dashboard`, `home`, `wallets`, `categories`, `transactions`, `budgets`, `reports`, `groups`, `account`
- `widgets/` komponen yang dipakai ulang (kotak galat, pemilih bulan, lembar satu isian)
- `router.dart` rute dengan penjaga login (go_router)
- `app.dart` dan `main.dart` tema, bahasa Indonesia, dan perakit aplikasi

Setiap fitur memisahkan model, repository (pemanggilan API), dan layar.