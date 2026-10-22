<script setup>
import { onMounted, ref } from 'vue'
import http, { errorMessage } from '@/api/http'
import { useAuthStore } from '@/stores/auth'
import { formatRupiah, walletTypeLabels } from '@/utils/format'

const auth = useAuthStore()

const wallets = ref([])
const totalBalance = ref(0)
const loading = ref(true)
const error = ref('')

onMounted(async () => {
  try {
    const { data } = await http.get('/wallets')
    wallets.value = data.data
    totalBalance.value = data.meta.total_balance
  } catch (e) {
    error.value = errorMessage(e, 'Gagal memuat dompet.')
  } finally {
    loading.value = false
  }
})
</script>

<template>
  <div>
    <h1 class="text-xl font-bold">Halo, {{ auth.user?.name }}</h1>
    <p class="text-sm text-slate-500">Ringkasan keuanganmu.</p>

    <p v-if="loading" class="mt-6 text-sm text-slate-500">Memuat...</p>

    <div
      v-else-if="error"
      class="mt-6 rounded-lg border border-rose-200 bg-rose-50 px-3 py-2 text-sm text-rose-700"
    >
      {{ error }}
    </div>

    <template v-else>
      <div class="card mt-6">
        <p class="text-sm text-slate-500">Total saldo</p>
        <p class="mt-1 text-3xl font-bold text-emerald-700">{{ formatRupiah(totalBalance) }}</p>
      </div>

      <h2 class="mt-6 mb-3 text-sm font-semibold uppercase tracking-wide text-slate-500">Dompet</h2>
      <div class="grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
        <div v-for="wallet in wallets" :key="wallet.id" class="card">
          <p class="font-medium">{{ wallet.name }}</p>
          <p class="text-xs text-slate-500">{{ walletTypeLabels[wallet.type] }}</p>
          <p class="mt-3 text-xl font-semibold">{{ formatRupiah(wallet.balance) }}</p>
        </div>
      </div>
    </template>
  </div>
</template>