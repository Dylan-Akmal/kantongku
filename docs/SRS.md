# docs/SRS.md

# Software Requirements Specification (SRS)
## Kantongku — Pencatat Keuangan dan Patungan

| Item | Keterangan |
|---|---|
| Versi | 1.0 |
| Penulis | Dylan Akmal Adi Mahendra |
| Status | Draf awal |
| Platform | REST API (Laravel 12), Web (Vue 3), Mobile (Flutter) |

---

## 1. Pendahuluan

### 1.1 Tujuan
Dokumen ini menjelaskan kebutuhan fungsional dan non-fungsional aplikasi Kantongku, yaitu aplikasi pencatat keuangan pribadi yang juga membantu patungan (split bill) bersama teman. Dokumen menjadi acuan perancangan, pengembangan, dan pengujian.

### 1.2 Ruang Lingkup
Kantongku memungkinkan pengguna mencatat pemasukan dan pengeluaran di beberapa dompet, mengatur anggaran bulanan, melihat laporan, serta membuat grup patungan untuk membagi pengeluaran bersama dan melacak siapa berutang kepada siapa. Aplikasi tersedia di web dan mobile dengan fitur yang setara, memakai satu backend API yang sama.

### 1.3 Definisi dan Istilah
| Istilah | Arti |
|---|---|
| Dompet | Tempat menyimpan uang pengguna: tunai, rekening bank, atau e-wallet |
| Transaksi | Catatan pemasukan, pengeluaran, atau transfer antar dompet |
| Anggaran | Batas pengeluaran bulanan untuk satu kategori |
| Grup | Kumpulan pengguna yang berbagi pengeluaran |
| Pengeluaran bersama | Pengeluaran yang dibayar satu anggota dan dibagi ke anggota lain |
| Porsi | Bagian pengeluaran bersama yang menjadi tanggungan satu anggota |
| Pelunasan | Pembayaran utang antaranggota di luar aplikasi yang dicatat di aplikasi |

---

## 2. Deskripsi Umum

### 2.1 Perspektif Produk
Aplikasi mandiri berarsitektur klien-server. Web dan mobile berkomunikasi dengan REST API yang diamankan token Laravel Sanctum.

### 2.2 Peran Pengguna
| Peran | Deskripsi |
|---|---|
| Pengguna | Pemilik akun; mengelola dompet, kategori, transaksi, dan anggaran miliknya sendiri |
| Pemilik grup | Pengguna yang membuat grup; dapat mengubah nama grup, mengeluarkan anggota, dan menghapus grup |
| Anggota grup | Pengguna yang bergabung lewat kode undangan; dapat mencatat pengeluaran bersama dan pelunasan |

### 2.3 Asumsi dan Batasan
- Semua nominal memakai rupiah (IDR) dan disimpan sebagai bilangan bulat tanpa desimal.
- Anggota grup harus memiliki akun Kantongku.
- Data keuangan pribadi bersifat privat; anggota grup hanya melihat data pengeluaran bersama di grup yang sama.
- Pelunasan hanya dicatat; aplikasi tidak memproses pembayaran sungguhan.
- Zona waktu aplikasi: Asia/Jakarta.

---

## 3. Kebutuhan Fungsional

### 3.1 Autentikasi dan Akun
| ID | Kebutuhan |
|---|---|
| FR-01 | Pengguna dapat mendaftar dengan nama, email, dan kata sandi |
| FR-02 | Pengguna dapat masuk dan keluar; sesi memakai token Sanctum |
| FR-03 | Pengguna dapat melihat dan mengubah profil serta mengganti kata sandi |
| FR-04 | Saat mendaftar, sistem membuat kategori bawaan dan satu dompet "Tunai" |

### 3.2 Dompet
| ID | Kebutuhan |
|---|---|
| FR-05 | Pengguna dapat membuat, melihat, mengubah, dan mengarsipkan dompet (tunai, bank, e-wallet) dengan saldo awal |
| FR-06 | Saldo dompet dihitung dari saldo awal ditambah seluruh transaksi dompet tersebut |
| FR-07 | Pengguna melihat total saldo seluruh dompet aktif |

### 3.3 Kategori
| ID | Kebutuhan |
|---|---|
| FR-08 | Pengguna dapat membuat, mengubah, dan menghapus kategori bertipe pemasukan atau pengeluaran |
| FR-09 | Kategori yang sudah dipakai transaksi tidak dapat dihapus, hanya dapat diubah namanya |

### 3.4 Transaksi
| ID | Kebutuhan |
|---|---|
| FR-10 | Pengguna dapat mencatat pemasukan dan pengeluaran dengan dompet, kategori, nominal, tanggal, dan catatan |
| FR-11 | Pengguna dapat mencatat transfer antar dua dompet miliknya; transfer tidak masuk hitungan pemasukan/pengeluaran |
| FR-12 | Pengguna dapat mengubah dan menghapus transaksi |
| FR-13 | Daftar transaksi mendukung pencarian catatan, filter dompet, kategori, tipe, rentang tanggal, dan paginasi |

### 3.5 Anggaran
| ID | Kebutuhan |
|---|---|
| FR-14 | Pengguna dapat menetapkan anggaran bulanan per kategori pengeluaran |
| FR-15 | Sistem menampilkan realisasi, sisa, dan persentase pemakaian anggaran, serta penanda jika melebihi batas |

### 3.6 Laporan
| ID | Kebutuhan |
|---|---|
| FR-16 | Laporan bulanan: total pemasukan, total pengeluaran, selisih, dan pengeluaran per kategori |
| FR-17 | Grafik pengeluaran harian dalam satu bulan |
| FR-18 | Ekspor transaksi sebulan ke CSV |

### 3.7 Grup Patungan
| ID | Kebutuhan |
|---|---|
| FR-19 | Pengguna dapat membuat grup; sistem membuat kode undangan unik dan menjadikan pembuatnya pemilik |
| FR-20 | Pengguna dapat bergabung ke grup dengan memasukkan kode undangan |
| FR-21 | Pemilik dapat mengubah nama grup, membuat ulang kode undangan, mengeluarkan anggota, dan menghapus grup |
| FR-22 | Anggota dapat keluar dari grup selama saldonya dengan anggota lain sudah nol |

### 3.8 Pengeluaran Bersama
| ID | Kebutuhan |
|---|---|
| FR-23 | Anggota dapat mencatat pengeluaran bersama: judul, total, pembayar, tanggal, catatan, dan peserta |
| FR-24 | Pembagian mendukung tiga mode: sama rata, nominal per orang, dan persen per orang |
| FR-25 | Jumlah seluruh porsi harus sama dengan total; pada mode sama rata, sisa pembulatan dibebankan ke pembayar |
| FR-26 | Anggota dapat mengubah atau menghapus pengeluaran bersama yang ia buat atau yang ia bayar; pemilik grup dapat menghapus apa pun |

### 3.9 Saldo dan Pelunasan
| ID | Kebutuhan |
|---|---|
| FR-27 | Sistem menghitung saldo bersih tiap anggota: total yang dibayar dikurangi total porsi, disesuaikan pelunasan |
| FR-28 | Sistem menampilkan penyederhanaan utang: daftar pembayaran minimal (siapa membayar siapa, berapa) agar semua saldo menjadi nol |
| FR-29 | Anggota dapat mencatat pelunasan kepada anggota lain dengan nominal dan catatan |
| FR-30 | Riwayat grup menampilkan pengeluaran bersama dan pelunasan secara kronologis |

---

## 4. Kebutuhan Non-Fungsional
| ID | Kategori | Kebutuhan |
|---|---|---|
| NFR-01 | Keamanan | Kata sandi di-hash; setiap endpoint (kecuali daftar dan masuk) membutuhkan token |
| NFR-02 | Privasi | Pengguna hanya dapat mengakses data miliknya dan data grup yang ia ikuti; akses lain dibalas 403/404 |
| NFR-03 | Akurasi | Nominal disimpan sebagai bigint rupiah; perhitungan saldo dan pembagian bebas galat pembulatan |
| NFR-04 | Integritas | Pembuatan pengeluaran bersama beserta porsinya berjalan dalam satu transaksi database |
| NFR-05 | Kinerja | Endpoint daftar merespons di bawah 500 ms pada data uji 10.000 transaksi |
| NFR-06 | Validasi | Semua input divalidasi di server; kesalahan dikembalikan sebagai 422 dengan pesan jelas |
| NFR-07 | Kualitas | Logika inti (saldo, pembagian, penyederhanaan utang, hak akses) dicakup tes otomatis dan dijalankan di CI |
| NFR-08 | Kompatibilitas | Web berjalan di peramban modern; mobile berjalan di Android 8 ke atas |
| NFR-09 | Pemeliharaan | Kode terstruktur per fitur; dokumentasi API dan README tersedia |

---

## 5. Antarmuka Eksternal
- **API**: REST JSON, autentikasi header `Authorization: Bearer <token>`.
- **Web**: Vue 3 (Vite), Tailwind CSS, Pinia, Vue Router, Axios.
- **Mobile**: Flutter, menghubungi API yang sama.
- **Database**: MySQL 8.

---

## 6. Kasus Penggunaan Utama
1. **Mencatat pengeluaran harian**: pengguna memilih dompet, kategori, nominal, lalu menyimpan; saldo dompet dan realisasi anggaran ikut berubah.
2. **Patungan makan bersama**: anggota A membayar Rp300.000 untuk tiga orang dengan pembagian sama rata; sistem membuat tiga porsi Rp100.000 dan saldo B dan C menjadi -Rp100.000 terhadap A.
3. **Melunasi utang**: B membayar A di luar aplikasi lalu mencatat pelunasan Rp100.000; saldo B dan A diperbarui.
4. **Penyederhanaan utang**: dalam grup besar dengan banyak utang silang, sistem menampilkan daftar pembayaran paling sedikit untuk menutup semua utang.

---

## 7. Di Luar Cakupan (Pengembangan Lanjutan)
- Anggota grup tanpa akun (teman tamu).
- Pembayaran sungguhan lewat payment gateway.
- Transaksi berulang dan pengingat tagihan.
- Beda mata uang.
- Struk foto dan pembacaan otomatis (OCR).
