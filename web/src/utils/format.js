const rupiah = new Intl.NumberFormat('id-ID', {
  style: 'currency',
  currency: 'IDR',
  maximumFractionDigits: 0,
})

const compact = new Intl.NumberFormat('id-ID', {
  notation: 'compact',
  maximumFractionDigits: 1,
})

export function formatRupiah(value) {
  return rupiah.format(value ?? 0)
}

/** Angka ringkas untuk sumbu grafik, mis. 1500000 menjadi "1,5 jt". */
export function formatCompact(value) {
  return compact.format(value ?? 0)
}

/** "2026-10-18" menjadi "18 Okt 2026". */
export function formatDate(iso) {
  if (!iso) return ''
  return new Date(`${iso}T00:00:00`).toLocaleDateString('id-ID', {
    day: 'numeric',
    month: 'short',
    year: 'numeric',
  })
}

/** Tanggal hari ini (zona waktu perangkat) dalam format YYYY-MM-DD. */
export function todayLocal() {
  const now = new Date()
  const month = String(now.getMonth() + 1).padStart(2, '0')
  const day = String(now.getDate()).padStart(2, '0')
  return `${now.getFullYear()}-${month}-${day}`
}

/** Bulan berjalan dalam format YYYY-MM. */
export function currentMonth() {
  return todayLocal().slice(0, 7)
}

/** "2026-10" menjadi "Oktober 2026". */
export function formatMonthLabel(month) {
  if (!month) return ''
  return new Date(`${month}-01T00:00:00`).toLocaleDateString('id-ID', {
    month: 'long',
    year: 'numeric',
  })
}

export const walletTypeLabels = {
  cash: 'Tunai',
  bank: 'Bank',
  ewallet: 'E-wallet',
}

export const transactionTypeLabels = {
  income: 'Pemasukan',
  expense: 'Pengeluaran',
  transfer: 'Transfer',
}