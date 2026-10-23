<script setup>
import { computed, reactive, ref, watch } from 'vue'
import http, { errorMessage, validationErrors } from '@/api/http'
import BaseModal from '@/components/BaseModal.vue'
import { todayLocal } from '@/utils/format'

const props = defineProps({
  open: { type: Boolean, default: false },
  transaction: { type: Object, default: null },
  wallets: { type: Array, required: true },
  categories: { type: Array, required: true },
})

const emit = defineEmits(['close', 'saved'])

const types = [
  { value: 'expense', label: 'Pengeluaran' },
  { value: 'income', label: 'Pemasukan' },
  { value: 'transfer', label: 'Transfer' },
]

const form = reactive({
  type: 'expense',
  wallet_id: '',
  to_wallet_id: '',
  category_id: '',
  amount: '',
  transaction_date: todayLocal(),
  note: '',
})

const errors = ref({})
const error = ref('')
const saving = ref(false)

const availableCategories = computed(() =>
  props.categories.filter((category) => category.type === form.type),
)

const targetWallets = computed(() => props.wallets.filter((wallet) => wallet.id !== form.wallet_id))

watch(
  () => props.open,
  (isOpen) => {
    if (!isOpen) return

    errors.value = {}
    error.value = ''

    const t = props.transaction
    if (t) {
      Object.assign(form, {
        type: t.type,
        wallet_id: t.wallet?.id ?? '',
        to_wallet_id: t.to_wallet?.id ?? '',
        category_id: t.category?.id ?? '',
        amount: t.amount,
        transaction_date: t.transaction_date,
        note: t.note ?? '',
      })
    } else {
      Object.assign(form, {
        type: 'expense',
        wallet_id: props.wallets[0]?.id ?? '',
        to_wallet_id: '',
        category_id: '',
        amount: '',
        transaction_date: todayLocal(),
        note: '',
      })
    }
  },
)

function setType(value) {
  form.type = value
  form.category_id = ''
  form.to_wallet_id = ''
}

async function submit() {
  saving.value = true
  error.value = ''
  errors.value = {}

  const payload = {
    type: form.type,
    wallet_id: Number(form.wallet_id),
    amount: Number(form.amount),
    transaction_date: form.transaction_date,
    note: form.note || null,
  }

  if (form.type === 'transfer') {
    payload.to_wallet_id = Number(form.to_wallet_id)
  } else {
    payload.category_id = Number(form.category_id)
  }

  try {
    if (props.transaction) {
      await http.put(`/transactions/${props.transaction.id}`, payload)
      emit('saved', 'Transaksi diperbarui.')
    } else {
      await http.post('/transactions', payload)
      emit('saved', 'Transaksi dicatat.')
    }
  } catch (e) {
    error.value = errorMessage(e, 'Gagal menyimpan transaksi.')
    errors.value = validationErrors(e)
  } finally {
    saving.value = false
  }
}
</script>

<template>
  <BaseModal
    :open="open"
    :title="transaction ? 'Ubah transaksi' : 'Catat transaksi'"
    @close="emit('close')"
  >
    <form class="space-y-4" @submit.prevent="submit">
      <p
        v-if="error && !Object.keys(errors).length"
        class="rounded-lg border border-rose-200 bg-rose-50 px-3 py-2 text-sm text-rose-700"
      >
        {{ error }}
      </p>

      <div class="grid grid-cols-3 gap-1 rounded-lg bg-slate-100 p-1 text-sm">
        <button
          v-for="item in types"
          :key="item.value"
          type="button"
          class="rounded-md py-1.5 font-medium transition"
          :class="
            form.type === item.value ? 'bg-white text-emerald-700 shadow-sm' : 'text-slate-500'
          "
          @click="setType(item.value)"
        >
          {{ item.label }}
        </button>
      </div>

      <div>
        <label class="label" for="tx-wallet">
          {{ form.type === 'transfer' ? 'Dari dompet' : 'Dompet' }}
        </label>
        <select id="tx-wallet" v-model="form.wallet_id" class="input" required>
          <option value="" disabled>Pilih dompet</option>
          <option v-for="wallet in wallets" :key="wallet.id" :value="wallet.id">
            {{ wallet.name }}
          </option>
        </select>
        <p v-if="errors.wallet_id" class="field-error">{{ errors.wallet_id[0] }}</p>
      </div>

      <div v-if="form.type === 'transfer'">
        <label class="label" for="tx-to-wallet">Ke dompet</label>
        <select id="tx-to-wallet" v-model="form.to_wallet_id" class="input" required>
          <option value="" disabled>Pilih dompet tujuan</option>
          <option v-for="wallet in targetWallets" :key="wallet.id" :value="wallet.id">
            {{ wallet.name }}
          </option>
        </select>
        <p v-if="errors.to_wallet_id" class="field-error">{{ errors.to_wallet_id[0] }}</p>
      </div>

      <div v-else>
        <label class="label" for="tx-category">Kategori</label>
        <select id="tx-category" v-model="form.category_id" class="input" required>
          <option value="" disabled>Pilih kategori</option>
          <option v-for="category in availableCategories" :key="category.id" :value="category.id">
            {{ category.name }}
          </option>
        </select>
        <p v-if="errors.category_id" class="field-error">{{ errors.category_id[0] }}</p>
      </div>

      <div class="grid grid-cols-2 gap-3">
        <div>
          <label class="label" for="tx-amount">Nominal (Rp)</label>
          <input
            id="tx-amount"
            v-model="form.amount"
            type="number"
            class="input"
            min="1"
            step="1"
            required
          />
          <p v-if="errors.amount" class="field-error">{{ errors.amount[0] }}</p>
        </div>

        <div>
          <label class="label" for="tx-date">Tanggal</label>
          <input id="tx-date" v-model="form.transaction_date" type="date" class="input" required />
          <p v-if="errors.transaction_date" class="field-error">
            {{ errors.transaction_date[0] }}
          </p>
        </div>
      </div>

      <div>
        <label class="label" for="tx-note">Catatan (opsional)</label>
        <input id="tx-note" v-model="form.note" type="text" class="input" maxlength="255" />
        <p v-if="errors.note" class="field-error">{{ errors.note[0] }}</p>
      </div>

      <div class="flex justify-end gap-2 pt-2">
        <button type="button" class="btn-secondary" @click="emit('close')">Batal</button>
        <button type="submit" class="btn-primary" :disabled="saving">
          {{ saving ? 'Menyimpan...' : 'Simpan' }}
        </button>
      </div>
    </form>
  </BaseModal>
</template>