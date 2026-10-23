const rupiah = new Intl.NumberFormat('id-ID', {
  style: 'currency',
  currency: 'IDR',
  maximumFractionDigits: 0,
})

export function formatRupiah(value) {
  return rupiah.format(value ?? 0)
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