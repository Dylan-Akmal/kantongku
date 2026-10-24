# Kantongku Web

Aplikasi web Kantongku dibangun dengan Vue 3, Vite, Tailwind CSS, Pinia, Vue Router, dan Axios. Aplikasi ini memakai REST API di folder `backend`.

## Menjalankan

Prasyarat: Node.js 20+ dan API sudah berjalan (lihat README di root repo).

```bash
npm install
cp .env.example .env   # sesuaikan VITE_API_URL bila perlu
npm run dev
```

Buka `http://localhost:5173`.

## Skrip

| Perintah | Fungsi |
|---|---|
| `npm run dev` | Server pengembangan dengan hot reload |
| `npm run build` | Build produksi ke folder `dist` |
| `npm run preview` | Pratinjau hasil build |

## Struktur `src`

- `api/` klien HTTP (Axios) beserta pengelolaan token dan pesan kesalahan
- `stores/` state global (Pinia), mis. status login
- `router/` rute dan penjaga halaman
- `layouts/` kerangka halaman setelah login
- `views/` halaman
- `components/` komponen yang dipakai ulang (pop-up, dialog konfirmasi)
- `utils/` fungsi bantu (format rupiah, label)