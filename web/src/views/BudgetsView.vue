<script setup>
import { computed, onMounted, onUnmounted, reactive, ref, watch } from 'vue'
import http, { errorMessage, validationErrors } from '@/api/http'
import BaseModal from '@/components/BaseModal.vue'
import ConfirmModal from '@/components/ConfirmModal.vue'
import { currentMonth, formatMonthLabel, formatRupiah } from '@/utils/format'

const month = ref(currentMonth())
const budgets = ref([])
const totals = ref({ total_budget: 0, total_spent: 0 })
const expenseCategories = ref([])
const loading = ref(true)
const error = ref('')
const notice = ref('')

const formOpen = ref(false)
const editing = ref(null)
const form = reactive({ category_id: '', amount: '' })
const formErrors = ref({})
const formError = ref('')
const saving = ref(false)

const deleting = ref(null)
const deleteBusy = ref(false)

let noticeTimer
function flash(message) {
  notice.value = message
  clearTimeout(noticeTimer)
  noticeTimer = setTimeout(() => (notice.value = ''), 3000)
}
onUnmounted(() => clearTimeout(noticeTimer))

const totalPercent = computed(() =>
  totals.value.total_budget > 0
    ? Math.round((totals.value.total_spent / totals.value.total_budget) * 100)
    : 0,
)

function barColor(percentage) {
  if (percentage >= 100) return 'bg-rose-500'
  if (percentage >= 80) return 'bg-amber-500'
  return 'bg-emerald-500'
}

async function load() {
  if (!month.value) return

  loading.value = true
  error.value = ''
  try {
    const { data } = await http.get('/budgets', { params: { month: month.value } })
    budgets.value = data.data
    totals.value = data.meta
  } catch (e) {
    error.value = errorMessage(e, 'Gagal memuat anggaran.')
  } finally {
    loading.value = false
  }
}

async function loadCategories() {
  try {
    const { data } = await http.get('/categories', { params: { type: 'expense' } })
    expenseCategories.value = data.data
  } catch (e) {
    error.value = errorMessage(e, 'Gagal memuat kategori.')
  }
}

onMounted(() => {
  loadCategories()
  load()
})
watch(month, load)

function openCreate() {
  editing.value = null
  Object.assign(form, { category_id: '', amount: '' })
  formErrors.value = {}
  formError.value = ''
  formOpen.value = true
}

function openEdit(budget) {
  editing.value = budget
  Object.assign(form, { category_id: budget.category.id, amount: budget.amount })
  formErrors.value = {}
  formError.value = ''
  formOpen.value = true
}

async function save() {
  saving.value = true
  formError.value = ''
  formErrors.value = {}

  try {
    const { data } = await http.post('/budgets', {
      category_id: Number(form.category_id),
      month: month.value,
      amount: Number(form.amount),
    })
    formOpen.value = false
    flash(data.message)
    await load()
  } catch (e) {
    formError.value = errorMessage(e, 'Gagal menyimpan anggaran.')
    formErrors.value = validationErrors(e)
  } finally {
    saving.value = false
  }
}

async function remove() {
  deleteBusy.value = true
  error.value = ''
  try {
    await http.delete(`/budgets/${deleting.value.id}`)
    flash('Anggaran dihapus.')
    await load()
  } catch (e) {
    error.value = errorMessage(e, 'Gagal menghapus anggaran.')
  } finally {
    deleting.value = null
    deleteBusy.value = false
  }
}
</script>

<template>
  <div>
    <div class="flex flex-wrap items-end justify-between gap-3">
      <div>
        <h1 class="text-xl font-bold">Anggaran</h1>
        <p class="text-sm text-slate-500">Batasi pengeluaran per kategori setiap bulan.</p>
      </div>
      <div class="flex items-end gap-2">
        <div>
          <label class="label" for="budget-month">Bulan</label>
          <input id="budget-month" v-model="month" type="month" class="input" />
        </div>
        <button class="btn-primary" @click="openCreate">+ Atur anggaran</button>
      </div>
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
      <p class="text-sm text-slate-500">Ringkasan {{ formatMonthLabel(month) }}</p>
      <div class="mt-2 flex flex-wrap items-end justify-between gap-2">
        <p class="text-2xl font-bold text-slate-800">
          {{ formatRupiah(totals.total_spent) }}
          <span class="text-sm font-normal text-slate-500">
            dari {{ formatRupiah(totals.total_budget) }}
          </span>
        </p>
        <p class="text-sm font-medium text-slate-600">{{ totalPercent }}% terpakai</p>
      </div>
      <div class="mt-3 h-2 rounded-full bg-slate-100">
        <div
          class="h-2 rounded-full"
          :class="barColor(totalPercent)"
          :style="{ width: Math.min(totalPercent, 100) + '%' }"
        ></div>
      </div>
    </div>

    <p v-if="loading" class="mt-5 text-sm text-slate-500">Memuat...</p>

    <div v-else class="mt-4 grid gap-3 sm:grid-cols-2">
      <div v-for="budget in budgets" :key="budget.id" class="card">
        <div class="flex items-start justify-between gap-2">
          <p class="font-medium">{{ budget.category.name }}</p>
          <span
            v-if="budget.is_over"
            class="badge bg-rose-100 text-rose-700"
          >
            Melebihi anggaran
          </span>
        </div>

        <p class="mt-3 text-lg font-semibold">
          {{ formatRupiah(budget.spent) }}
          <span class="text-sm font-normal text-slate-500">
            dari {{ formatRupiah(budget.amount) }}
          </span>
        </p>

        <div class="mt-2 h-2 rounded-full bg-slate-100">
          <div
            class="h-2 rounded-full"
            :class="barColor(budget.percentage)"
            :style="{ width: Math.min(budget.percentage, 100) + '%' }"
          ></div>
        </div>

        <p class="mt-2 text-xs" :class="budget.is_over ? 'text-rose-600' : 'text-slate-500'">
          {{ budget.percentage }}% terpakai ·
          {{
            budget.is_over
              ? `melebihi ${formatRupiah(Math.abs(budget.remaining))}`
              : `sisa ${formatRupiah(budget.remaining)}`
          }}
        </p>

        <div class="mt-4 flex gap-2">
          <button class="btn-secondary" @click="openEdit(budget)">Ubah</button>
          <button class="btn-secondary text-rose-600" @click="deleting = budget">Hapus</button>
        </div>
      </div>

      <p v-if="!budgets.length" class="text-sm text-slate-500">
        Belum ada anggaran untuk {{ formatMonthLabel(month) }}.
      </p>
    </div>

    <BaseModal
      :open="formOpen"
      :title="editing ? 'Ubah anggaran' : 'Atur anggaran'"
      @close="formOpen = false"
    >
      <form class="space-y-4" @submit.prevent="save">
        <p
          v-if="formError && !Object.keys(formErrors).length"
          class="rounded-lg border border-rose-200 bg-rose-50 px-3 py-2 text-sm text-rose-700"
        >
          {{ formError }}
        </p>

        <div>
          <label class="label" for="budget-category">Kategori pengeluaran</label>
          <select
            id="budget-category"
            v-model="form.category_id"
            class="input"
            :disabled="editing !== null"
            required
          >
            <option value="" disabled>Pilih kategori</option>
            <option v-for="category in expenseCategories" :key="category.id" :value="category.id">
              {{ category.name }}
            </option>
          </select>
          <p v-if="formErrors.category_id" class="field-error">{{ formErrors.category_id[0] }}</p>
          <p class="mt-1 text-xs text-slate-500">
            Untuk {{ formatMonthLabel(month) }}. Kategori yang sudah punya anggaran bulan ini akan
            diperbarui, bukan digandakan.
          </p>
        </div>

        <div>
          <label class="label" for="budget-amount">Batas anggaran (Rp)</label>
          <input
            id="budget-amount"
            v-model="form.amount"
            type="number"
            class="input"
            min="1"
            step="1"
            required
          />
          <p v-if="formErrors.amount" class="field-error">{{ formErrors.amount[0] }}</p>
        </div>

        <div class="flex justify-end gap-2 pt-2">
          <button type="button" class="btn-secondary" @click="formOpen = false">Batal</button>
          <button type="submit" class="btn-primary" :disabled="saving">
            {{ saving ? 'Menyimpan...' : 'Simpan' }}
          </button>
        </div>
      </form>
    </BaseModal>

    <ConfirmModal
      :open="deleting !== null"
      title="Hapus anggaran"
      :message="`Hapus anggaran &quot;${deleting?.category?.name ?? ''}&quot; untuk ${formatMonthLabel(month)}?`"
      confirm-text="Hapus"
      :loading="deleteBusy"
      @confirm="remove"
      @cancel="deleting = null"
    />
  </div>
</template>