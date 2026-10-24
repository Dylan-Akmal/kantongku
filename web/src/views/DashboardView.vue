<script setup>
import { onMounted, reactive, ref } from 'vue'
import { RouterLink } from 'vue-router'
import http, { errorMessage } from '@/api/http'
import { useAuthStore } from '@/stores/auth'
import {
  currentMonth,
  formatDate,
  formatMonthLabel,
  formatRupiah,
  transactionTypeLabels,
  walletTypeLabels,
} from '@/utils/format'

const auth = useAuthStore()
const month = currentMonth()

// null berarti masih dimuat; isi (array atau objek) berarti hasilnya sudah ada.
const wallets = ref(null)
const totalBalance = ref(0)
const report = ref(null)
const budgets = ref(null)
const budgetTotals = ref({ total_budget: 0, total_spent: 0 })
const recent = ref(null)
const groups = ref(null)

const errors = reactive({ wallets: '', report: '', budgets: '', recent: '', groups: '' })

async function loadWallets() {
  try {
    const { data } = await http.get('/wallets')
    wallets.value = data.data
    totalBalance.value = data.meta.total_balance
  } catch (e) {
    errors.wallets = errorMessage(e, 'Gagal memuat dompet.')
    wallets.value = []
  }
}

async function loadReport() {
  try {
    const { data } = await http.get('/reports/monthly', { params: { month } })
    report.value = data.data
  } catch (e) {
    errors.report = errorMessage(e, 'Gagal memuat ringkasan bulan ini.')
  }
}

async function loadBudgets() {
  try {
    const { data } = await http.get('/budgets', { params: { month } })
    budgetTotals.value = data.meta
    budgets.value = data.data
      .slice()
      .sort((a, b) => b.percentage - a.percentage)
      .slice(0, 3)
  } catch (e) {
    errors.budgets = errorMessage(e, 'Gagal memuat anggaran.')
    budgets.value = []
  }
}

async function loadRecent() {
  try {
    const { data } = await http.get('/transactions', { params: { per_page: 5 } })
    recent.value = data.data
  } catch (e) {
    errors.recent = errorMessage(e, 'Gagal memuat transaksi terbaru.')
    recent.value = []
  }
}

async function loadGroups() {
  try {
    const { data } = await http.get('/groups')
    const list = data.data.slice(0, 5)

    const balances = await Promise.allSettled(
      list.map((group) => http.get(`/groups/${group.id}/balances`)),
    )

    groups.value = list.map((group, index) => ({
      ...group,
      balance:
        balances[index].status === 'fulfilled'
          ? balances[index].value.data.data.my_balance
          : null,
    }))
  } catch (e) {
    errors.groups = errorMessage(e, 'Gagal memuat grup.')
    groups.value = []
  }
}

onMounted(() => {
  loadWallets()
  loadReport()
  loadBudgets()
  loadRecent()
  loadGroups()
})

function barColor(percentage) {
  if (percentage >= 100) return 'bg-rose-500'
  if (percentage >= 80) return 'bg-amber-500'
  return 'bg-emerald-500'
}

function txTitle(transaction) {
  return transaction.type === 'transfer'
    ? `${transaction.wallet?.name} → ${transaction.to_wallet?.name}`
    : transaction.category?.name
}

function txAmount(transaction) {
  const value = formatRupiah(transaction.amount)
  if (transaction.type === 'income') return `+ ${value}`
  if (transaction.type === 'expense') return `− ${value}`
  return value
}

function txClass(transaction) {
  if (transaction.type === 'income') return 'text-emerald-600'
  if (transaction.type === 'expense') return 'text-rose-600'
  return 'text-slate-600'
}
</script>

<template>
  <div>
    <h1 class="text-xl font-bold">Halo, {{ auth.user?.name }}</h1>
    <p class="text-sm text-slate-500">Ringkasan keuanganmu, {{ formatMonthLabel(month) }}.</p>

    <div class="mt-5 grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
      <div class="card">
        <p class="text-sm text-slate-500">Total saldo</p>
        <p v-if="wallets === null" class="mt-1 text-sm text-slate-400">Memuat...</p>
        <p v-else class="mt-1 text-xl font-bold text-emerald-700">
          {{ formatRupiah(totalBalance) }}
        </p>
      </div>

      <div class="card">
        <p class="text-sm text-slate-500">Pemasukan bulan ini</p>
        <p v-if="errors.report" class="mt-1 text-sm text-rose-600">{{ errors.report }}</p>
        <p v-else-if="report === null" class="mt-1 text-sm text-slate-400">Memuat...</p>
        <p v-else class="mt-1 text-xl font-bold text-emerald-700">
          {{ formatRupiah(report.total_income) }}
        </p>
      </div>

      <div class="card">
        <p class="text-sm text-slate-500">Pengeluaran bulan ini</p>
        <p v-if="errors.report" class="mt-1 text-sm text-rose-600">—</p>
        <p v-else-if="report === null" class="mt-1 text-sm text-slate-400">Memuat...</p>
        <p v-else class="mt-1 text-xl font-bold text-rose-600">
          {{ formatRupiah(report.total_expense) }}
        </p>
      </div>

      <div class="card">
        <p class="text-sm text-slate-500">Selisih bulan ini</p>
        <p v-if="errors.report" class="mt-1 text-sm text-rose-600">—</p>
        <p v-else-if="report === null" class="mt-1 text-sm text-slate-400">Memuat...</p>
        <p
          v-else
          class="mt-1 text-xl font-bold"
          :class="report.net >= 0 ? 'text-emerald-700' : 'text-rose-600'"
        >
          {{ formatRupiah(report.net) }}
        </p>
      </div>
    </div>

    <div class="mt-6 grid gap-4 lg:grid-cols-2">
      <section class="card">
        <div class="flex items-center justify-between gap-2">
          <h2 class="text-sm font-semibold uppercase tracking-wide text-slate-500">Anggaran</h2>
          <RouterLink to="/budgets" class="text-sm text-emerald-700 hover:underline">
            Lihat semua
          </RouterLink>
        </div>

        <p v-if="errors.budgets" class="mt-3 text-sm text-rose-600">{{ errors.budgets }}</p>
        <p v-else-if="budgets === null" class="mt-3 text-sm text-slate-400">Memuat...</p>
        <p v-else-if="!budgets.length" class="mt-3 text-sm text-slate-500">
          Belum ada anggaran bulan ini.
          <RouterLink to="/budgets" class="text-emerald-700 hover:underline">Atur anggaran</RouterLink>
        </p>

        <ul v-else class="mt-4 space-y-4">
          <li v-for="budget in budgets" :key="budget.id">
            <div class="flex items-center justify-between gap-2 text-sm">
              <span class="font-medium">{{ budget.category.name }}</span>
              <span :class="budget.is_over ? 'font-semibold text-rose-600' : 'text-slate-500'">
                {{ formatRupiah(budget.spent) }} / {{ formatRupiah(budget.amount) }}
              </span>
            </div>
            <div class="mt-1.5 h-2 rounded-full bg-slate-100">
              <div
                class="h-2 rounded-full"
                :class="barColor(budget.percentage)"
                :style="{ width: Math.min(budget.percentage, 100) + '%' }"
              ></div>
            </div>
          </li>
        </ul>
      </section>

      <section class="card">
        <div class="flex items-center justify-between gap-2">
          <h2 class="text-sm font-semibold uppercase tracking-wide text-slate-500">
            Transaksi terbaru
          </h2>
          <RouterLink to="/transactions" class="text-sm text-emerald-700 hover:underline">
            Lihat semua
          </RouterLink>
        </div>

        <p v-if="errors.recent" class="mt-3 text-sm text-rose-600">{{ errors.recent }}</p>
        <p v-else-if="recent === null" class="mt-3 text-sm text-slate-400">Memuat...</p>
        <p v-else-if="!recent.length" class="mt-3 text-sm text-slate-500">
          Belum ada transaksi.
          <RouterLink to="/transactions" class="text-emerald-700 hover:underline">
            Catat yang pertama
          </RouterLink>
        </p>

        <ul v-else class="mt-3 divide-y divide-slate-100">
          <li
            v-for="transaction in recent"
            :key="transaction.id"
            class="flex items-center justify-between gap-3 py-2.5 text-sm"
          >
            <div>
              <p class="font-medium">{{ txTitle(transaction) }}</p>
              <p class="text-xs text-slate-500">
                {{ formatDate(transaction.transaction_date) }} ·
                {{ transactionTypeLabels[transaction.type] }}
              </p>
            </div>
            <span class="whitespace-nowrap font-semibold" :class="txClass(transaction)">
              {{ txAmount(transaction) }}
            </span>
          </li>
        </ul>
      </section>

      <section class="card">
        <div class="flex items-center justify-between gap-2">
          <h2 class="text-sm font-semibold uppercase tracking-wide text-slate-500">Dompet</h2>
          <RouterLink to="/wallets" class="text-sm text-emerald-700 hover:underline">
            Kelola
          </RouterLink>
        </div>

        <p v-if="errors.wallets" class="mt-3 text-sm text-rose-600">{{ errors.wallets }}</p>
        <p v-else-if="wallets === null" class="mt-3 text-sm text-slate-400">Memuat...</p>

        <ul v-else class="mt-3 divide-y divide-slate-100">
          <li
            v-for="wallet in wallets"
            :key="wallet.id"
            class="flex items-center justify-between gap-3 py-2.5 text-sm"
          >
            <div>
              <p class="font-medium">{{ wallet.name }}</p>
              <p class="text-xs text-slate-500">{{ walletTypeLabels[wallet.type] }}</p>
            </div>
            <span class="font-semibold">{{ formatRupiah(wallet.balance) }}</span>
          </li>
        </ul>
      </section>

      <section class="card">
        <div class="flex items-center justify-between gap-2">
          <h2 class="text-sm font-semibold uppercase tracking-wide text-slate-500">
            Grup patungan
          </h2>
          <RouterLink to="/groups" class="text-sm text-emerald-700 hover:underline">
            Lihat semua
          </RouterLink>
        </div>

        <p v-if="errors.groups" class="mt-3 text-sm text-rose-600">{{ errors.groups }}</p>
        <p v-else-if="groups === null" class="mt-3 text-sm text-slate-400">Memuat...</p>
        <p v-else-if="!groups.length" class="mt-3 text-sm text-slate-500">
          Belum ada grup.
          <RouterLink to="/groups" class="text-emerald-700 hover:underline">
            Buat atau gabung grup
          </RouterLink>
        </p>

        <ul v-else class="mt-3 divide-y divide-slate-100">
          <li v-for="group in groups" :key="group.id">
            <RouterLink
              :to="{ name: 'group-detail', params: { id: group.id }, query: { tab: 'balances' } }"
              class="flex items-center justify-between gap-3 py-2.5 text-sm hover:text-emerald-700"
            >
              <div>
                <p class="font-medium">{{ group.name }}</p>
                <p class="text-xs text-slate-500">{{ group.member_count }} anggota</p>
              </div>
              <span
                v-if="group.balance !== null"
                class="whitespace-nowrap font-semibold"
                :class="
                  group.balance > 0
                    ? 'text-emerald-600'
                    : group.balance < 0
                      ? 'text-rose-600'
                      : 'text-slate-400'
                "
              >
                <template v-if="group.balance > 0">
                  menerima {{ formatRupiah(group.balance) }}
                </template>
                <template v-else-if="group.balance < 0">
                  berutang {{ formatRupiah(Math.abs(group.balance)) }}
                </template>
                <template v-else>lunas</template>
              </span>
            </RouterLink>
          </li>
        </ul>
      </section>
    </div>
  </div>
</template>