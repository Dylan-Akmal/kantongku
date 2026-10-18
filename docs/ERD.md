# docs/ERD.md

# Entity Relationship Diagram (ERD)
## Kantongku

Dokumen ini menjelaskan struktur basis data Kantongku (MySQL 8). Seluruh nominal uang bertipe `bigint` dalam rupiah. Saldo dompet tidak disimpan, melainkan dihitung dari `initial_balance` ditambah transaksi. Nama tabel `split_groups` dipakai karena `groups` adalah kata cadangan di MySQL 8.

## Diagram

```mermaid
erDiagram
    users ||--o{ wallets : memiliki
    users ||--o{ categories : memiliki
    users ||--o{ transactions : mencatat
    users ||--o{ budgets : menetapkan
    users ||--o{ split_groups : memiliki
    users ||--o{ group_members : menjadi
    wallets ||--o{ transactions : "asal"
    wallets ||--o{ transactions : "tujuan transfer"
    categories ||--o{ transactions : mengelompokkan
    categories ||--o{ budgets : dibatasi
    split_groups ||--o{ group_members : beranggota
    split_groups ||--o{ group_expenses : berisi
    split_groups ||--o{ settlements : berisi
    group_expenses ||--o{ expense_shares : terbagi
    users ||--o{ group_expenses : membayar
    users ||--o{ expense_shares : menanggung
    users ||--o{ settlements : membayar
    users ||--o{ settlements : menerima

    users {
        bigint id PK
        string name
        string email UK
        string password
        timestamp created_at
        timestamp updated_at
    }
    wallets {
        bigint id PK
        bigint user_id FK
        string name
        enum type "cash, bank, ewallet"
        bigint initial_balance
        boolean is_archived
        timestamp created_at
        timestamp updated_at
    }
    categories {
        bigint id PK
        bigint user_id FK
        string name
        enum type "income, expense"
        timestamp created_at
        timestamp updated_at
    }
    transactions {
        bigint id PK
        bigint user_id FK
        bigint wallet_id FK
        bigint to_wallet_id FK "nullable, untuk transfer"
        bigint category_id FK "nullable, kosong untuk transfer"
        enum type "income, expense, transfer"
        bigint amount
        date transaction_date
        string note "nullable"
        timestamp created_at
        timestamp updated_at
    }
    budgets {
        bigint id PK
        bigint user_id FK
        bigint category_id FK
        date month "tanggal 1 bulan terkait"
        bigint amount
        timestamp created_at
        timestamp updated_at
    }
    split_groups {
        bigint id PK
        bigint owner_id FK
        string name
        string invite_code UK
        timestamp created_at
        timestamp updated_at
    }
    group_members {
        bigint id PK
        bigint group_id FK
        bigint user_id FK
        enum role "owner, member"
        timestamp joined_at
    }
    group_expenses {
        bigint id PK
        bigint group_id FK
        bigint paid_by FK
        bigint created_by FK
        string title
        bigint total_amount
        enum split_type "equal, exact, percent"
        date expense_date
        string note "nullable"
        timestamp created_at
        timestamp updated_at
        timestamp deleted_at "soft delete"
    }
    expense_shares {
        bigint id PK
        bigint expense_id FK
        bigint user_id FK
        bigint amount_owed
    }
    settlements {
        bigint id PK
        bigint group_id FK
        bigint from_user_id FK
        bigint to_user_id FK
        bigint amount
        string note "nullable"
        timestamp settled_at
        timestamp created_at
    }
```

## Daftar Tabel

| Tabel | Fungsi |
|---|---|
| `users` | Akun pengguna |
| `wallets` | Dompet milik pengguna (tunai, bank, e-wallet) |
| `categories` | Kategori pemasukan/pengeluaran milik pengguna |
| `transactions` | Pemasukan, pengeluaran, dan transfer antar dompet |
| `budgets` | Anggaran bulanan per kategori pengeluaran |
| `split_groups` | Grup patungan beserta kode undangan |
| `group_members` | Keanggotaan pengguna di grup dan perannya |
| `group_expenses` | Pengeluaran bersama dan siapa pembayarnya |
| `expense_shares` | Porsi tanggungan tiap anggota atas satu pengeluaran bersama |
| `settlements` | Catatan pelunasan utang antaranggota |

## Aturan dan Indeks

- `users.email` unik.
- `categories`: unik pada (`user_id`, `name`, `type`).
- `budgets`: unik pada (`user_id`, `category_id`, `month`).
- `group_members`: unik pada (`group_id`, `user_id`).
- `split_groups.invite_code` unik.
- `transactions`: indeks pada (`user_id`, `transaction_date`) dan (`wallet_id`).
- `expense_shares`: unik pada (`expense_id`, `user_id`); jumlah `amount_owed` per pengeluaran harus sama dengan `total_amount`.
- `transactions.type = transfer` mewajibkan `to_wallet_id` terisi, `category_id` kosong, dan dua dompet berbeda.
- `settlements`: `from_user_id` tidak boleh sama dengan `to_user_id`, dan `amount` lebih dari nol.
- `group_expenses` memakai soft delete agar riwayat dan saldo dapat ditelusuri.

## Rumus Saldo Anggota dalam Grup

Saldo bersih seorang anggota dihitung dari: total `total_amount` pengeluaran yang ia bayar, dikurangi total `amount_owed` miliknya, ditambah total pelunasan yang ia bayarkan, dikurangi total pelunasan yang ia terima. Saldo positif berarti ia masih harus menerima uang, saldo negatif berarti ia masih berutang. Jumlah saldo seluruh anggota dalam satu grup selalu nol.
