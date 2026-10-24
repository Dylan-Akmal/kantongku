<script setup>
import { computed, onMounted, onUnmounted, ref } from 'vue'
import http, { errorMessage } from '@/api/http'
import ConfirmModal from '@/components/ConfirmModal.vue'
import GroupExpenseFormModal from '@/components/GroupExpenseFormModal.vue'
import { useAuthStore } from '@/stores/auth'
import { formatDate, formatRupiah } from '@/utils/format'

const props = defineProps({
  group: { type: Object, required: true },
})

const PER_PAGE = 10
const splitLabels = { equal: 'Sama rata', exact: 'Nominal', percent: 'Persen' }

const auth = useAuthStore()
const isOwner = computed(() => props.group.my_role === 'owner')

const expenses = ref([])
const meta = ref({ current_page: 1, last_page: 1, total: 0 })
const page = ref(1)
const loading = ref(true)
const error = ref('')
const notice = ref('')

const formOpen = ref(false)
const editing = ref(null)
const deleting = ref(null)
const deleteBusy = ref(false)

let noticeTimer
function flash(message) {
  notice.value = message
  clearTimeout(noticeTimer)
  noticeTimer = setTimeout(() => (notice.value = ''), 3000)
}
onUnmounted(() => clearTimeout(noticeTimer))

async function load() {
  loading.value = true
  error.value = ''
  try {
    const { data } = await http.get(`/groups/${props.group.id}/expenses`, {
      params: { page: page.value, per_page: PER_PAGE },
    })
    expenses.value = data.data
    meta.value = data.meta
  } catch (e) {
    error.value = errorMessage(e, 'Gagal memuat pengeluaran.')
  } finally {
    loading.value = false
  }
}

onMounted(load)

function goTo(target) {
  if (target < 1 || target > meta.value.last_page) return
  page.value = target
  load()
}

function canEdit(expense) {
  const me = auth.user?.id
  return me === expense.created_by?.id || me === expense.paid_by?.id
}

function canDelete(expense) {
  return canEdit(expense) || isOwner.value
}

function openCreate() {
  editing.value = null
  formOpen.value = true
}

function openEdit(expense) {
  editing.value = expense
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
    await http.delete(`/groups/${props.group.id}/expenses/${deleting.value.id}`)
    flash('Pengeluaran dihapus.')
    await load()

    if (expenses.value.length === 0 && page.value > 1) {
      page.value -= 1
      await load()
    }
  } catch (e) {
    error.value = errorMessage(e, 'Gagal menghapus pengeluaran.')
  } finally {
    deleting.value = null
    deleteBusy.value = false
  }
}
</script>

<template>
  <div>
    <div class="flex flex-wrap items-center justify-between gap-3">
      <p class="text-sm text-slate-500">{{ meta.total }} pengeluaran bersama</p>
      <button class="btn-primary" @click="openCreate">+ Catat pengeluaran</button>
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

    <p v-if="loading" class="mt-5 text-sm text-slate-500">Memuat...</p>

    <div v-else class="mt-4 space-y-3">
      <div v-for="expense in expenses" :key="expense.id" class="card">
        <div class="flex flex-wrap items-start justify-between gap-2">
          <div>
            <p class="font-medium">{{ expense.title }}</p>
            <p class="text-xs text-slate-500">
              {{ formatDate(expense.expense_date) }} · Dibayar oleh {{ expense.paid_by?.name }}
              <span v-if="expense.note"> · {{ expense.note }}</span>
            </p>
          </div>
          <div class="text-right">
            <p class="font-semibold">{{ formatRupiah(expense.total_amount) }}</p>
            <span class="badge">{{ splitLabels[expense.split_type] }}</span>
          </div>
        </div>

        <ul class="mt-3 space-y-1 border-t border-slate-100 pt-3 text-sm text-slate-600">
          <li
            v-for="share in expense.shares"
            :key="share.user?.id"
            class="flex items-center justify-between"
          >
            <span>{{ share.user?.name }}</span>
            <span>{{ formatRupiah(share.amount_owed) }}</span>
          </li>
        </ul>

        <div v-if="canEdit(expense) || canDelete(expense)" class="mt-4 flex gap-2">
          <button v-if="canEdit(expense)" class="btn-secondary" @click="openEdit(expense)">
            Ubah
          </button>
          <button
            v-if="canDelete(expense)"
            class="btn-secondary text-rose-600"
            @click="deleting = expense"
          >
            Hapus
          </button>
        </div>
      </div>

      <p v-if="!expenses.length" class="text-sm text-slate-500">
        Belum ada pengeluaran bersama. Catat yang pertama dengan tombol di atas.
      </p>
    </div>

    <div
      v-if="!loading && meta.total > 0"
      class="mt-4 flex flex-wrap items-center justify-between gap-3"
    >
      <p class="text-sm text-slate-500">
        Halaman {{ meta.current_page }} dari {{ meta.last_page }}
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

    <GroupExpenseFormModal
      :open="formOpen"
      :group="group"
      :expense="editing"
      @close="formOpen = false"
      @saved="onSaved"
    />

    <ConfirmModal
      :open="deleting !== null"
      title="Hapus pengeluaran"
      :message="`Hapus pengeluaran &quot;${deleting?.title ?? ''}&quot;? Saldo semua anggota akan dihitung ulang.`"
      confirm-text="Hapus"
      :loading="deleteBusy"
      @confirm="remove"
      @cancel="deleting = null"
    />
  </div>
</template>