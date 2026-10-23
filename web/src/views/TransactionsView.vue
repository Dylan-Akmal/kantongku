<script setup>
import { onMounted, onUnmounted, reactive, ref, watch } from 'vue'
import http, { errorMessage } from '@/api/http'
import ConfirmModal from '@/components/ConfirmModal.vue'
import TransactionFormModal from '@/components/TransactionFormModal.vue'
import { formatDate, formatRupiah, transactionTypeLabels } from '@/utils/format'

const PER_PAGE = 15

const transactions = ref([])
const meta = ref({ current_page: 1, last_page: 1, total: 0 })
const page = ref(1)
const loading = ref(true)
const error = ref('')
const notice = ref('')

const wallets = ref([])
const categories = ref([])

const filters = reactive({
  q: '',
  type: '',
  wallet_id: '',
  category_id: '',
  date_from: '',
  date_to: '',
})

const formOpen = ref(false)
const editing = ref(null)
const deleting = ref(null)
const deleteBusy = ref(false)

const typeClasses = {
  income: 'bg-emerald-100 text-emerald-700',
  expense: 'bg-rose-100 text-rose-700',
  transfer: 'bg-sky-100 text-sky-700',
}

let noticeTimer
let filterTimer

function flash(message) {
  notice.value = message
  clearTimeout(noticeTimer)
  noticeTimer = setTimeout(() => (notice.value = ''), 3000)
}

onUnmounted(() => {
  clearTimeout(noticeTimer)
  clearTimeout(filterTimer)
})

async function load() {
  loading.value = true
  error.value = ''

  const params = { page: page.value, per_page: PER_PAGE }
  for (const [key, value] of Object.entries(filters)) {
    if (value !== '') params[key] = value
  }

  try {
    const { data } = await http.get('/transactions', { params })
    transactions.value = data.data
    meta.value = data.meta
  } catch (e) {
    error.value = errorMessage(e, 'Gagal memuat transaksi.')
  } finally {
    loading.value = false
  }
}

async function loadOptions() {
  try {
    const [walletResponse, categoryResponse] = await Promise.all([
      http.get('/wallets'),
      http.get('/categories'),
    ])
    wallets.value = walletResponse.data.data
    categories.value = categoryResponse.data.data
  } catch (e) {
    error.value = errorMessage(e, 'Gagal memuat dompet dan kategori.')
  }
}

onMounted(() => {
  loadOptions()
  load()
})

watch(filters, () => {
  clearTimeout(filterTimer)
  filterTimer = setTimeout(() => {
    page.value = 1
    load()
  }, 300)
})

function resetFilters() {
  Object.assign(filters, {
    q: '',
    type: '',
    wallet_id: '',
    category_id: '',
    date_from: '',
    date_to: '',
  })
}

function goTo(target) {
  if (target < 1 || target > meta.value.last_page) return
  page.value = target
  load()
}

function openCreate() {
  editing.value = null
  formOpen.value = true
}

function openEdit(transaction) {
  editing.value = transaction
  formOpen.value = true
}

async function onSaved(message) {
  formOpen.value = false
  flash(message)
  await load()
}

async function remove() {
  deleteBusy.value = true
  error.value = ''
  try {
    await http.delete(`/transactions/${deleting.value.id}`)
    flash('Transaksi dihapus.')
    await load()

    // Bila yang dihapus adalah satu-satunya data di halaman terakhir, mundur satu halaman.
    if (transactions.value.length === 0 && page.value > 1) {
      page.value -= 1
      await load()
    }
  } catch (e) {
    error.value = errorMessage(e, 'Gagal menghapus transaksi.')
  } finally {
    deleting.value = null
    deleteBusy.value = false
  }
}

function title(transaction) {
  return transaction.type === 'transfer'
    ? `${transaction.wallet?.name} → ${transaction.to_wallet?.name}`
    : transaction.category?.name
}

function detail(transaction) {
  const parts = []
  if (transaction.type !== 'transfer') parts.push(transaction.wallet?.name)
  if (transaction.note) parts.push(transaction.note)
  return parts.join(' · ')
}

function amountText(transaction) {
  const value = formatRupiah(transaction.amount)
  if (transaction.type === 'income') return `+ ${value}`
  if (transaction.type === 'expense') return `− ${value}`
  return value
}

function amountClass(transaction) {
  if (transaction.type === 'income') return 'text-emerald-600'
  if (transaction.type === 'expense') return 'text-rose-600'
  return 'text-slate-600'
}
</script>

<template>
  <div>
    <div class="flex flex-wrap items-center justify-between gap-3">
      <div>
        <h1 class="text-xl font-bold">Transaksi</h1>
        <p class="text-sm text-slate-500">Catatan pemasukan, pengeluaran, dan transfer.</p>
      </div>
      <button class="btn-primary" @click="openCreate">+ Catat transaksi</button>
    </div>

    <p
      v-if="notice"
      class="mt-4 rounded-lg border border-emerald-200 bg-emerald-50 px-3 py-2 text-sm text-emerald-700"
    >
      {{ notice }}
    </p>
    <p
      v-if="error"
      class="mt-4 rounded-lg border border-rose-200 bg-rose-50 px-3 py-2 text-sm text-rose-700"
    >
      {{ error }}
    </p>

    <div class="card mt-5">
      <div class="grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
        <div class="sm:col-span-2 lg:col-span-3">
          <label class="label" for="f-q">Cari catatan</label>
          <input
            id="f-q"
            v-model="filters.q"
            type="search"
            class="input"
            placeholder="Contoh: makan siang"
          />
        </div>

        <div>
          <label class="label" for="f-type">Jenis</label>
          <select id="f-type" v-model="filters.type" class="input">
            <option value="">Semua</option>
            <option v-for="(label, value) in transactionTypeLabels" :key="value" :value="value">
              {{ label }}
            </option>
          </select>
        </div>

        <div>
          <label class="label" for="f-wallet">Dompet</label>
          <select id="f-wallet" v-model="filters.wallet_id" class="input">
            <option value="">Semua</option>
            <option v-for="wallet in wallets" :key="wallet.id" :value="wallet.id">
              {{ wallet.name }}
            </option>
          </select>
        </div>

        <div>
          <label class="label" for="f-category">Kategori</label>
          <select id="f-category" v-model="filters.category_id" class="input">
            <option value="">Semua</option>
            <optgroup label="Pengeluaran">
              <option
                v-for="category in categories.filter((c) => c.type === 'expense')"
                :key="category.id"
                :value="category.id"
              >
                {{ category.name }}
              </option>
            </optgroup>
            <optgroup label="Pemasukan">
              <option
                v-for="category in categories.filter((c) => c.type === 'income')"
                :key="category.id"
                :value="category.id"
              >
                {{ category.name }}
              </option>
            </optgroup>
          </select>
        </div>

        <div>
          <label class="label" for="f-from">Dari tanggal</label>
          <input id="f-from" v-model="filters.date_from" type="date" class="input" />
        </div>

        <div>
          <label class="label" for="f-to">Sampai tanggal</label>
          <input id="f-to" v-model="filters.date_to" type="date" class="input" />
        </div>

        <div class="flex items-end">
          <button type="button" class="btn-secondary w-full" @click="resetFilters">
            Reset filter
          </button>
        </div>
      </div>
    </div>

    <p v-if="loading" class="mt-5 text-sm text-slate-500">Memuat...</p>

    <div v-else class="card mt-4 overflow-x-auto p-0">
      <table class="w-full min-w-[40rem] text-left text-sm">
        <thead class="border-b border-slate-200 bg-slate-50 text-xs uppercase tracking-wide text-slate-500">
          <tr>
            <th class="px-4 py-3 font-medium">Tanggal</th>
            <th class="px-4 py-3 font-medium">Jenis</th>
            <th class="px-4 py-3 font-medium">Keterangan</th>
            <th class="px-4 py-3 text-right font-medium">Nominal</th>
            <th class="px-4 py-3"></th>
          </tr>
        </thead>
        <tbody class="divide-y divide-slate-100">
          <tr v-for="transaction in transactions" :key="transaction.id">
            <td class="whitespace-nowrap px-4 py-3 text-slate-500">
              {{ formatDate(transaction.transaction_date) }}
            </td>
            <td class="px-4 py-3">
              <span class="badge" :class="typeClasses[transaction.type]">
                {{ transactionTypeLabels[transaction.type] }}
              </span>
            </td>
            <td class="px-4 py-3">
              <p class="font-medium">{{ title(transaction) }}</p>
              <p v-if="detail(transaction)" class="text-xs text-slate-500">
                {{ detail(transaction) }}
              </p>
            </td>
            <td
              class="whitespace-nowrap px-4 py-3 text-right font-semibold"
              :class="amountClass(transaction)"
            >
              {{ amountText(transaction) }}
            </td>
            <td class="whitespace-nowrap px-4 py-3 text-right">
              <button class="btn-secondary mr-2" @click="openEdit(transaction)">Ubah</button>
              <button class="btn-secondary text-rose-600" @click="deleting = transaction">
                Hapus
              </button>
            </td>
          </tr>

          <tr v-if="!transactions.length">
            <td colspan="5" class="px-4 py-6 text-center text-slate-500">
              Belum ada transaksi yang cocok.
            </td>
          </tr>
        </tbody>
      </table>
    </div>

    <div v-if="!loading && meta.total > 0" class="mt-4 flex flex-wrap items-center justify-between gap-3">
      <p class="text-sm text-slate-500">
        Halaman {{ meta.current_page }} dari {{ meta.last_page }} · {{ meta.total }} transaksi
      </p>
      <div class="flex gap-2">
        <button
          class="btn-secondary"
          :disabled="meta.current_page <= 1"
          @click="goTo(meta.current_page - 1)"
        >
          ← Sebelumnya
        </button>
        <button
          class="btn-secondary"
          :disabled="meta.current_page >= meta.last_page"
          @click="goTo(meta.current_page + 1)"
        >
          Berikutnya →
        </button>
      </div>
    </div>

    <TransactionFormModal
      :open="formOpen"
      :transaction="editing"
      :wallets="wallets"
      :categories="categories"
      @close="formOpen = false"
      @saved="onSaved"
    />

    <ConfirmModal
      :open="deleting !== null"
      title="Hapus transaksi"
      message="Hapus transaksi ini? Saldo dompet akan dihitung ulang."
      confirm-text="Hapus"
      :loading="deleteBusy"
      @confirm="remove"
      @cancel="deleting = null"
    />
  </div>
</template>