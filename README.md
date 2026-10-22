# Kantongku

![Backend Tests](https://github.com/Dylan-Akmal/kantongku/actions/workflows/backend-tests.yml/badge.svg)

Aplikasi pencatat keuangan pribadi sekaligus alat patungan (split bill) bersama teman. Catat pemasukan dan pengeluaran di beberapa dompet, atur anggaran bulanan, lihat laporan, lalu buat grup untuk membagi pengeluaran bersama dan melacak siapa berutang kepada siapa.

> Status: backend selesai dan teruji (98 tes otomatis). Web (Vue 3) sedang dikerjakan, mobile (Flutter) menyusul.

## Fitur

**Keuangan pribadi**
- Banyak dompet (tunai, bank, e-wallet); saldo dihitung dari riwayat transaksi, bukan disimpan
- Pemasukan, pengeluaran, dan transfer antar dompet, lengkap dengan kategori
- Daftar transaksi dengan pencarian, filter, dan paginasi
- Anggaran bulanan per kategori dengan realisasi dan penanda melebihi batas
- Laporan bulanan, data grafik harian, dan ekspor CSV

**Patungan**
- Grup dengan kode undangan; pemilik dan anggota punya hak akses berbeda
- Pengeluaran bersama dengan tiga mode pembagian: sama rata, nominal, dan persen
- Saldo tiap anggota dan penyederhanaan utang (siapa membayar siapa, sesedikit mungkin)
- Pencatatan pelunasan dan riwayat grup
- Anggota baru bisa keluar atau dikeluarkan hanya jika saldonya sudah nol

## Teknologi

| Bagian | Teknologi |
|---|---|
| Backend | Laravel 12, Sanctum (token), MySQL |
| Web | Vue 3, Vite, Tailwind CSS, Pinia, Vue Router, Axios |
| Mobile | Flutter (menyusul) |
| Pengujian | PHPUnit, GitHub Actions (MySQL 8) |

## Struktur repo

```
kantongku/
├── backend/   REST API Laravel
├── web/       Aplikasi web Vue 3
├── docs/      SRS dan ERD
└── .github/   Workflow CI
```

Dokumentasi perancangan ada di [`docs/SRS.md`](docs/SRS.md) dan [`docs/ERD.md`](docs/ERD.md).

## Menjalankan backend

Prasyarat: PHP 8.2+, Composer, MySQL.

```bash
cd backend
composer install
cp .env.example .env
php artisan key:generate
```

Buat database `kantongku` di MySQL, sesuaikan `DB_*` di `.env`, lalu:

```bash
php artisan migrate
php artisan serve
```

API tersedia di `http://127.0.0.1:8000/api`.

## Pengujian

Tes berjalan di database MySQL terpisah agar data pengembangan tidak tersentuh. Buat database kosong bernama `kantongku_test` (tabelnya dibuat otomatis), lalu:

```bash
cd backend
php artisan test
```

Cakupan tes: autentikasi, dompet dan perhitungan saldo, transaksi, anggaran, laporan dan ekspor CSV, alur grup (keanggotaan, hak akses, privasi antargrup), tiga mode pembagian pengeluaran, penyederhanaan utang, pelunasan, dan aturan keluar grup. Semua tes juga dijalankan otomatis di GitHub Actions pada setiap push.

## Keputusan desain

- Semua nominal disimpan sebagai bilangan bulat rupiah (tanpa desimal) agar bebas galat pembulatan.
- Sisa pembulatan saat membagi pengeluaran dibebankan ke pembayar.
- Data pengguna terisolasi: sumber daya milik pengguna lain dijawab 404, bukan 403.