<script setup>
import { onMounted, ref, watch } from 'vue'
import http, { errorMessage } from '@/api/http'
import DailyChart from '@/components/DailyChart.vue'
import { currentMonth, formatMonthLabel, formatRupiah } from '@/utils/format'

const month = ref(currentMonth())
const report = ref(null)
const days = ref([])
const loading = ref(true)
const exporting = ref(false)
const error = ref('')

async function load() {
  if (!month.value) return

  loading.value = true
  error.value = ''
  try {
    const params = { month: month.value }
    const [monthly, daily] = await Promise.all([
      http.get('/reports/monthly', { params }),
      http.get('/reports/daily', { params }),
    ])
    report.value = monthly.data.data
    days.value = daily.data.data
  } catch (e) {
    error.value = errorMessage(e, 'Gagal memuat laporan.')
  } finally {
    loading.value = false
  }
}

onMounted(load)
watch(month, load)

async function exportCsv() {
  exporting.value = true
  error.value = ''
  try {
    const response = await http.get('/reports/export', {
      params: { month: month.value },
      responseType: 'blob',
    })

    const disposition = response.headers['content-disposition'] ?? ''
    const match = disposition.match(/filename="?([^";]+)"?/)
    const filename = match ? match[1] : `kantongku-${month.value}.csv`

    const url = URL.createObjectURL(response.data)
    const link = document.createElement('a')
    link.href = url
    link.download = filename
    document.body.appendChild(link)
    link.click()
    link.remove()
    URL.revokeObjectURL(url)
  } catch {
    error.value = 'Gagal mengekspor CSV. Coba lagi.'
  } finally {
    exporting.value = false
  }
}
</script>

<template>
  <div>
    <div class="flex flex-wrap items-end justify-between gap-3">
      <div>
        <h1 class="text-xl font-bold">Laporan</h1>
        <p class="text-sm text-slate-500">Ringkasan pemasukan dan pengeluaran per bulan.</p>
      </div>
      <div class="flex items-end gap-2">
        <div>
          <label class="label" for="report-month">Bulan</label>
          <input id="report-month" v-model="month" type="month" class="input" />
        </div>
        <button class="btn-secondary py-2" :disabled="exporting || !month" @click="exportCsv">
          {{ exporting ? 'Mengunduh...' : 'Unduh CSV' }}
        </button>
      </div>
    </div>

    <p
      v-if="error"
      class="mt-4 rounded-lg border border-rose-200 bg-rose-50 px-3 py-2 text-sm text-rose-700"
    >
      {{ error }}
    </p>

    <p v-if="loading" class="mt-5 text-sm text-slate-500">Memuat...</p>

    <template v-else-if="report">
      <p class="mt-5 text-sm font-medium text-slate-600">{{ formatMonthLabel(month) }}</p>

      <div class="mt-2 grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
        <div class="card">
          <p class="text-sm text-slate-500">Pemasukan</p>
          <p class="mt-1 text-xl font-bold text-emerald-700">
            {{ formatRupiah(report.total_income) }}
          </p>
        </div>
        <div class="card">
          <p class="text-sm text-slate-500">Pengeluaran</p>
          <p class="mt-1 text-xl font-bold text-rose-600">
            {{ formatRupiah(report.total_expense) }}
          </p>
        </div>
        <div class="card">
          <p class="text-sm text-slate-500">Selisih</p>
          <p
            class="mt-1 text-xl font-bold"
            :class="report.net >= 0 ? 'text-emerald-700' : 'text-rose-600'"
          >
            {{ formatRupiah(report.net) }}
          </p>
        </div>
        <div class="card">
          <p class="text-sm text-slate-500">Jumlah transaksi</p>
          <p class="mt-1 text-xl font-bold text-slate-800">{{ report.transaction_count }}</p>
          <p class="text-xs text-slate-500">Transfer tidak dihitung</p>
        </div>
      </div>

      <p v-if="report.transaction_count === 0" class="mt-5 text-sm text-slate-500">
        Belum ada pemasukan atau pengeluaran pada bulan ini.
      </p>

      <div v-else class="mt-5 grid gap-4 lg:grid-cols-2">
        <div class="card">
          <h2 class="text-sm font-semibold uppercase tracking-wide text-slate-500">
            Pengeluaran per kategori
          </h2>
          <ul class="mt-4 space-y-4">
            <li v-for="row in report.expense_by_category" :key="row.category_id">
              <div class="flex items-center justify-between gap-2 text-sm">
                <span class="font-medium">{{ row.name }}</span>
                <span class="text-slate-600">
                  {{ formatRupiah(row.total) }}
                  <span class="text-xs text-slate-400">({{ row.percentage }}%)</span>
                </span>
              </div>
              <div class="mt-1.5 h-2 rounded-full bg-slate-100">
                <div
                  class="h-2 rounded-full bg-rose-500"
                  :style="{ width: row.percentage + '%' }"
                ></div>
              </div>
            </li>
            <li v-if="!report.expense_by_category.length" class="text-sm text-slate-500">
              Belum ada pengeluaran.
            </li>
          </ul>
        </div>

        <div class="card">
          <h2 class="text-sm font-semibold uppercase tracking-wide text-slate-500">
            Per hari
          </h2>
          <div class="mt-4">
            <DailyChart :days="days" />
          </div>
        </div>
      </div>
    </template>
  </div>
</template>