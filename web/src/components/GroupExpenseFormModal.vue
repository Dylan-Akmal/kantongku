<script setup>
import { computed, reactive, ref, watch } from 'vue'
import http, { errorMessage, validationErrors } from '@/api/http'
import BaseModal from '@/components/BaseModal.vue'
import { useAuthStore } from '@/stores/auth'
import { formatRupiah, todayLocal } from '@/utils/format'

const props = defineProps({
  open: { type: Boolean, default: false },
  group: { type: Object, required: true },
  expense: { type: Object, default: null },
})

const emit = defineEmits(['close', 'saved'])

const auth = useAuthStore()

const splitTypes = [
  { value: 'equal', label: 'Sama rata' },
  { value: 'exact', label: 'Nominal' },
  { value: 'percent', label: 'Persen' },
]

const form = reactive({
  title: '',
  total_amount: '',
  paid_by: '',
  expense_date: todayLocal(),
  note: '',
  split_type: 'equal',
})

// selected[idAnggota] = true bila ikut dibagi; values[idAnggota] = nominal atau persen yang diketik.
const selected = reactive({})
const values = reactive({})

const errors = ref({})
const error = ref('')
const saving = ref(false)

const members = computed(() => props.group.members)
const selectedIds = computed(() =>
  members.value.filter((member) => selected[member.id]).map((member) => member.id),
)
const total = computed(() => Number(form.total_amount) || 0)
const payerId = computed(() => Number(form.paid_by))

// Sisa pembulatan dibebankan ke pembayar bila ia ikut dibagi; jika tidak, ke peserta pertama.
const remainderTarget = computed(() =>
  selectedIds.value.includes(payerId.value) ? payerId.value : selectedIds.value[0],
)

const exactSum = computed(() =>
  selectedIds.value.reduce((sum, id) => sum + (Number(values[id]) || 0), 0),
)

const percentSum = computed(
  () =>
    Math.round(selectedIds.value.reduce((sum, id) => sum + (Number(values[id]) || 0), 0) * 100) /
    100,
)

const preview = computed(() => {
  const ids = selectedIds.value
  const result = {}
  if (!ids.length || total.value <= 0) return result

  if (form.split_type === 'equal') {
    const base = Math.floor(total.value / ids.length)
    const remainder = total.value - base * ids.length
    ids.forEach((id) => (result[id] = base))
    result[remainderTarget.value] += remainder
  } else if (form.split_type === 'percent' && percentSum.value === 100) {
    ids.forEach((id) => {
      const points = Math.round((Number(values[id]) || 0) * 100)
      result[id] = Math.floor((total.value * points) / 10000)
    })
    const assigned = ids.reduce((sum, id) => sum + result[id], 0)
    result[remainderTarget.value] += total.value - assigned
  }

  return result
})

const canSubmit = computed(() => {
  if (!selectedIds.value.length || total.value <= 0) return false
  if (form.split_type === 'exact') return exactSum.value === total.value
  if (form.split_type === 'percent') return percentSum.value === 100
  return true
})

const participantErrors = computed(() =>
  Object.entries(errors.value)
    .filter(([key]) => key.startsWith('participants'))
    .flatMap(([, messages]) => messages),
)

watch(
  () => props.open,
  (isOpen) => {
    if (!isOpen) return

    errors.value = {}
    error.value = ''

    for (const member of members.value) {
      selected[member.id] = false
      values[member.id] = ''
    }

    const expense = props.expense

    if (expense) {
      Object.assign(form, {
        title: expense.title,
        total_amount: expense.total_amount,
        paid_by: expense.paid_by.id,
        expense_date: expense.expense_date,
        note: expense.note ?? '',
        split_type: expense.split_type,
      })

      for (const share of expense.shares) {
        selected[share.user.id] = true
        if (expense.split_type === 'exact') {
          values[share.user.id] = share.amount_owed
        }
        if (expense.split_type === 'percent') {
          values[share.user.id] = Math.round((share.amount_owed / expense.total_amount) * 10000) / 100
        }
      }
    } else {
      Object.assign(form, {
        title: '',
        total_amount: '',
        paid_by: auth.user?.id ?? members.value[0]?.id ?? '',
        expense_date: todayLocal(),
        note: '',
        split_type: 'equal',
      })

      for (const member of members.value) {
        selected[member.id] = true
      }
    }
  },
)

function setSplitType(value) {
  form.split_type = value
  for (const member of members.value) {
    values[member.id] = ''
  }
}

async function submit() {
  saving.value = true
  error.value = ''
  errors.value = {}

  const participants = selectedIds.value.map((id) => {
    const item = { user_id: id }
    if (form.split_type === 'exact') item.amount = Number(values[id])
    if (form.split_type === 'percent') item.percent = Number(values[id])
    return item
  })

  const payload = {
    title: form.title,
    total_amount: Number(form.total_amount),
    paid_by: Number(form.paid_by),
    expense_date: form.expense_date,
    note: form.note || null,
    split_type: form.split_type,
    participants,
  }

  try {
    if (props.expense) {
      await http.put(`/groups/${props.group.id}/expenses/${props.expense.id}`, payload)
      emit('saved', 'Pengeluaran diperbarui.')
    } else {
      await http.post(`/groups/${props.group.id}/expenses`, payload)
      emit('saved', 'Pengeluaran dicatat.')
    }
  } catch (e) {
    error.value = errorMessage(e, 'Gagal menyimpan pengeluaran.')
    errors.value = validationErrors(e)
  } finally {
    saving.value = false
  }
}
</script>

<template>
  <BaseModal
    :open="open"
    :title="expense ? 'Ubah pengeluaran' : 'Catat pengeluaran bersama'"
    wide
    @close="emit('close')"
  >
    <form class="space-y-4" @submit.prevent="submit">
      <p
        v-if="error && !Object.keys(errors).length"
        class="rounded-lg border border-rose-200 bg-rose-50 px-3 py-2 text-sm text-rose-700"
      >
        {{ error }}
      </p>

      <div>
        <label class="label" for="ge-title">Judul</label>
        <input
          id="ge-title"
          v-model="form.title"
          type="text"
          class="input"
          maxlength="100"
          placeholder="Contoh: Makan malam"
          required
        />
        <p v-if="errors.title" class="field-error">{{ errors.title[0] }}</p>
      </div>

      <div class="grid gap-3 sm:grid-cols-2">
        <div>
          <label class="label" for="ge-total">Total (Rp)</label>
          <input
            id="ge-total"
            v-model="form.total_amount"
            type="number"
            class="input"
            min="1"
            step="1"
            required
          />
          <p v-if="errors.total_amount" class="field-error">{{ errors.total_amount[0] }}</p>
        </div>

        <div>
          <label class="label" for="ge-date">Tanggal</label>
          <input id="ge-date" v-model="form.expense_date" type="date" class="input" required />
          <p v-if="errors.expense_date" class="field-error">{{ errors.expense_date[0] }}</p>
        </div>
      </div>

      <div>
        <label class="label" for="ge-payer">Dibayar oleh</label>
        <select id="ge-payer" v-model="form.paid_by" class="input" required>
          <option value="" disabled>Pilih anggota</option>
          <option v-for="member in members" :key="member.id" :value="member.id">
            {{ member.name }}{{ member.id === auth.user?.id ? ' (kamu)' : '' }}
          </option>
        </select>
        <p v-if="errors.paid_by" class="field-error">{{ errors.paid_by[0] }}</p>
      </div>

      <div>
        <p class="label">Cara membagi</p>
        <div class="grid grid-cols-3 gap-1 rounded-lg bg-slate-100 p-1 text-sm">
          <button
            v-for="item in splitTypes"
            :key="item.value"
            type="button"
            class="rounded-md py-1.5 font-medium transition"
            :class="
              form.split_type === item.value
                ? 'bg-white text-emerald-700 shadow-sm'
                : 'text-slate-500'
            "
            @click="setSplitType(item.value)"
          >
            {{ item.label }}
          </button>
        </div>
      </div>

      <div>
        <p class="label">Dibagi ke siapa</p>
        <ul class="space-y-2">
          <li
            v-for="member in members"
            :key="member.id"
            class="flex items-center gap-3 rounded-lg border border-slate-200 px-3 py-2"
          >
            <input
              :id="`ge-member-${member.id}`"
              v-model="selected[member.id]"
              type="checkbox"
              class="h-4 w-4 rounded border-slate-300"
            />
            <label :for="`ge-member-${member.id}`" class="min-w-0 flex-1 truncate text-sm">
              {{ member.name }}
            </label>

            <template v-if="selected[member.id]">
              <input
                v-if="form.split_type === 'exact'"
                v-model="values[member.id]"
                type="number"
                class="input w-32"
                min="1"
                step="1"
                placeholder="Rp"
              />
              <input
                v-else-if="form.split_type === 'percent'"
                v-model="values[member.id]"
                type="number"
                class="input w-24"
                min="0.01"
                max="100"
                step="0.01"
                placeholder="%"
              />
              <span
                v-if="form.split_type !== 'exact' && preview[member.id] !== undefined"
                class="w-28 text-right text-xs text-slate-500"
              >
                {{ formatRupiah(preview[member.id]) }}
              </span>
            </template>
          </li>
        </ul>

        <p v-if="!selectedIds.length" class="mt-2 text-xs text-rose-600">
          Pilih minimal satu peserta.
        </p>
        <p v-else-if="form.split_type === 'equal'" class="mt-2 text-xs text-slate-500">
          Dibagi rata. Sisa pembulatan (bila ada) dibebankan ke pembayar.
        </p>
        <p
          v-else-if="form.split_type === 'exact'"
          class="mt-2 text-xs"
          :class="exactSum === total && total > 0 ? 'text-emerald-600' : 'text-rose-600'"
        >
          Jumlah porsi {{ formatRupiah(exactSum) }} dari total {{ formatRupiah(total) }}.
          {{ exactSum === total && total > 0 ? 'Sudah pas.' : 'Harus sama persis.' }}
        </p>
        <p
          v-else
          class="mt-2 text-xs"
          :class="percentSum === 100 ? 'text-emerald-600' : 'text-rose-600'"
        >
          Total persen {{ percentSum }}%. {{ percentSum === 100 ? 'Sudah pas.' : 'Harus tepat 100%.' }}
        </p>

        <div
          v-if="participantErrors.length"
          class="mt-2 rounded-lg border border-rose-200 bg-rose-50 px-3 py-2 text-xs text-rose-700"
        >
          <p v-for="message in participantErrors" :key="message">{{ message }}</p>
        </div>
      </div>

      <div>
        <label class="label" for="ge-note">Catatan (opsional)</label>
        <input id="ge-note" v-model="form.note" type="text" class="input" maxlength="255" />
        <p v-if="errors.note" class="field-error">{{ errors.note[0] }}</p>
      </div>

      <div class="flex justify-end gap-2 pt-2">
        <button type="button" class="btn-secondary" @click="emit('close')">Batal</button>
        <button type="submit" class="btn-primary" :disabled="saving || !canSubmit">
          {{ saving ? 'Menyimpan...' : 'Simpan' }}
        </button>
      </div>
    </form>
  </BaseModal>
</template>