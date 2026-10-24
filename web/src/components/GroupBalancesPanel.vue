<script setup>
import { computed, onMounted, onUnmounted, reactive, ref } from 'vue'
import http, { errorMessage, validationErrors } from '@/api/http'
import BaseModal from '@/components/BaseModal.vue'
import { useAuthStore } from '@/stores/auth'
import { formatRupiah } from '@/utils/format'

const props = defineProps({
  group: { type: Object, required: true },
})

const auth = useAuthStore()

const summary = ref(null)
const loading = ref(true)
const error = ref('')
const notice = ref('')

let noticeTimer
function flash(message) {
  notice.value = message
  clearTimeout(noticeTimer)
  noticeTimer = setTimeout(() => (notice.value = ''), 3000)
}
onUnmounted(() => clearTimeout(noticeTimer))

async function load() {
  error.value = ''
  try {
    const { data } = await http.get(`/groups/${props.group.id}/balances`)
    summary.value = data.data
  } catch (e) {
    error.value = errorMessage(e, 'Gagal memuat saldo.')
  } finally {
    loading.value = false
  }
}

onMounted(load)

const myBalance = computed(() => summary.value?.my_balance ?? 0)
const otherMembers = computed(() => props.group.members.filter((m) => m.id !== auth.user?.id))

const settleOpen = ref(false)
const settleForm = reactive({ to_user_id: '', amount: '', note: '' })
const settleErrors = ref({})
const settleError = ref('')
const settling = ref(false)

function openSettle(prefill = {}) {
  settleForm.to_user_id = prefill.to_user_id ?? ''
  settleForm.amount = prefill.amount ?? ''
  settleForm.note = ''
  settleErrors.value = {}
  settleError.value = ''
  settleOpen.value = true
}

async function settle() {
  settling.value = true
  settleError.value = ''
  settleErrors.value = {}

  try {
    await http.post(`/groups/${props.group.id}/settlements`, {
      to_user_id: Number(settleForm.to_user_id),
      amount: Number(settleForm.amount),
      note: settleForm.note || null,
    })
    settleOpen.value = false
    flash('Pelunasan dicatat.')
    await load()
  } catch (e) {
    settleError.value = errorMessage(e, 'Gagal mencatat pelunasan.')
    settleErrors.value = validationErrors(e)
  } finally {
    settling.value = false
  }
}
</script>

<template>
  <div>
    <p
      v-if="notice"
      class="rounded-lg border border-emerald-200 bg-emerald-50 px-3 py-2 text-sm text-emerald-700"
    >
      {{ notice }}
    </p>
    <p
      v-if="error"
      class="rounded-lg border border-rose-200 bg-rose-50 px-3 py-2 text-sm text-rose-700"
    >
      {{ error }}
    </p>

    <p v-if="loading" class="text-sm text-slate-500">Memuat...</p>

    <div v-else-if="summary" class="space-y-4">
      <div class="card">
        <p class="text-sm text-slate-500">Posisimu di grup ini</p>
        <p v-if="myBalance > 0" class="mt-1 text-2xl font-bold text-emerald-700">
          Kamu akan menerima {{ formatRupiah(myBalance) }}
        </p>
        <p v-else-if="myBalance < 0" class="mt-1 text-2xl font-bold text-rose-600">
          Kamu berutang {{ formatRupiah(Math.abs(myBalance)) }}
        </p>
        <p v-else class="mt-1 text-2xl font-bold text-slate-700">Kamu sudah lunas ✓</p>

        <button class="btn-secondary mt-4" @click="openSettle()">Catat pelunasan</button>
      </div>

      <div class="card p-0">
        <div class="border-b border-slate-100 px-5 py-3">
          <h2 class="text-sm font-semibold uppercase tracking-wide text-slate-500">
            Saldo tiap anggota
          </h2>
        </div>
        <ul class="divide-y divide-slate-100">
          <li
            v-for="row in summary.balances"
            :key="row.user_id"
            class="flex items-center justify-between gap-3 px-5 py-3 text-sm"
          >
            <span class="font-medium">
              {{ row.name }}
              <span v-if="row.user_id === auth.user?.id" class="text-slate-400">(kamu)</span>
            </span>
            <span
              v-if="row.balance > 0"
              class="font-semibold text-emerald-600"
            >
              menerima {{ formatRupiah(row.balance) }}
            </span>
            <span v-else-if="row.balance < 0" class="font-semibold text-rose-600">
              berutang {{ formatRupiah(Math.abs(row.balance)) }}
            </span>
            <span v-else class="text-slate-400">lunas</span>
          </li>
        </ul>
      </div>

      <div class="card p-0">
        <div class="border-b border-slate-100 px-5 py-3">
          <h2 class="text-sm font-semibold uppercase tracking-wide text-slate-500">
            Cara melunasi semuanya
          </h2>
          <p class="text-xs text-slate-500">Pembayaran sesedikit mungkin agar semua saldo menjadi nol.</p>
        </div>
        <ul class="divide-y divide-slate-100">
          <li
            v-for="(payment, index) in summary.settle_up"
            :key="index"
            class="flex flex-wrap items-center justify-between gap-3 px-5 py-3 text-sm"
          >
            <span>
              <span class="font-medium">{{ payment.from.name }}</span>
              membayar
              <span class="font-medium">{{ payment.to.name }}</span>
            </span>
            <span class="flex items-center gap-3">
              <span class="font-semibold">{{ formatRupiah(payment.amount) }}</span>
              <button
                v-if="payment.from.id === auth.user?.id"
                class="btn-secondary"
                @click="openSettle({ to_user_id: payment.to.id, amount: payment.amount })"
              >
                Catat pelunasan
              </button>
            </span>
          </li>
          <li v-if="!summary.settle_up.length" class="px-5 py-4 text-sm text-slate-500">
            Tidak ada utang yang perlu dilunasi. 🎉
          </li>
        </ul>
      </div>
    </div>

    <BaseModal :open="settleOpen" title="Catat pelunasan" @close="settleOpen = false">
      <form class="space-y-4" @submit.prevent="settle">
        <p
          v-if="settleError && !Object.keys(settleErrors).length"
          class="rounded-lg border border-rose-200 bg-rose-50 px-3 py-2 text-sm text-rose-700"
        >
          {{ settleError }}
        </p>

        <div>
          <label class="label" for="settle-to">Dibayarkan kepada</label>
          <select id="settle-to" v-model="settleForm.to_user_id" class="input" required>
            <option value="" disabled>Pilih anggota</option>
            <option v-for="member in otherMembers" :key="member.id" :value="member.id">
              {{ member.name }}
            </option>
          </select>
          <p v-if="settleErrors.to_user_id" class="field-error">{{ settleErrors.to_user_id[0] }}</p>
        </div>

        <div>
          <label class="label" for="settle-amount">Nominal (Rp)</label>
          <input
            id="settle-amount"
            v-model="settleForm.amount"
            type="number"
            class="input"
            min="1"
            step="1"
            required
          />
          <p v-if="settleErrors.amount" class="field-error">{{ settleErrors.amount[0] }}</p>
          <p class="mt-1 text-xs text-slate-500">
            Aplikasi hanya mencatat. Pembayaran sungguhannya kamu lakukan di luar aplikasi.
          </p>
        </div>

        <div>
          <label class="label" for="settle-note">Catatan (opsional)</label>
          <input id="settle-note" v-model="settleForm.note" type="text" class="input" maxlength="255" />
        </div>

        <div class="flex justify-end gap-2 pt-2">
          <button type="button" class="btn-secondary" @click="settleOpen = false">Batal</button>
          <button type="submit" class="btn-primary" :disabled="settling">
            {{ settling ? 'Menyimpan...' : 'Simpan' }}
          </button>
        </div>
      </form>
    </BaseModal>
  </div>
</template>