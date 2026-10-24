<script setup>
import { computed, onMounted, onUnmounted, ref } from 'vue'
import http, { errorMessage } from '@/api/http'
import ConfirmModal from '@/components/ConfirmModal.vue'
import { useAuthStore } from '@/stores/auth'
import { formatDate, formatRupiah } from '@/utils/format'

const props = defineProps({
  group: { type: Object, required: true },
})

const PER_PAGE = 15

const auth = useAuthStore()
const isOwner = computed(() => props.group.my_role === 'owner')

const items = ref([])
const meta = ref({ current_page: 1, last_page: 1, total: 0 })
const page = ref(1)
const loading = ref(true)
const error = ref('')
const notice = ref('')

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
    const { data } = await http.get(`/groups/${props.group.id}/history`, {
      params: { page: page.value, per_page: PER_PAGE },
    })
    items.value = data.data
    meta.value = data.meta
  } catch (e) {
    error.value = errorMessage(e, 'Gagal memuat riwayat.')
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

function canDeleteSettlement(item) {
  return item.type === 'settlement' && (isOwner.value || item.from?.id === auth.user?.id)
}

async function remove() {
  deleteBusy.value = true
  error.value = ''
  try {
    await http.delete(`/groups/${props.group.id}/settlements/${deleting.value.id}`)
    flash('Pelunasan dihapus.')
    await load()

    if (items.value.length === 0 && page.value > 1) {
      page.value -= 1
      await load()
    }
  } catch (e) {
    error.value = errorMessage(e, 'Gagal menghapus pelunasan.')
  } finally {
    deleting.value = null
    deleteBusy.value = false
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

    <ul v-else class="card divide-y divide-slate-100 p-0">
      <li
        v-for="item in items"
        :key="`${item.type}-${item.id}`"
        class="flex flex-wrap items-center justify-between gap-3 px-5 py-3"
      >
        <div class="flex items-start gap-3">
          <span class="text-xl">{{ item.type === 'expense' ? '🧾' : '💸' }}</span>
          <div>
            <p v-if="item.type === 'expense'" class="font-medium">
              {{ item.title }}
              <span class="font-normal text-slate-500">dibayar {{ item.paid_by?.name }}</span>
            </p>
            <p v-else class="font-medium">
              {{ item.from?.name }}
              <span class="font-normal text-slate-500">melunasi</span>
              {{ item.to?.name }}
            </p>
            <p class="text-xs text-slate-500">
              {{ formatDate(item.date) }}
              <span v-if="item.note"> · {{ item.note }}</span>
            </p>
          </div>
        </div>

        <div class="flex items-center gap-3">
          <span
            class="font-semibold"
            :class="item.type === 'expense' ? 'text-slate-800' : 'text-emerald-600'"
          >
            {{ formatRupiah(item.amount) }}
          </span>
          <button
            v-if="canDeleteSettlement(item)"
            class="btn-secondary text-rose-600"
            @click="deleting = item"
          >
            Hapus
          </button>
        </div>
      </li>

      <li v-if="!items.length" class="px-5 py-4 text-sm text-slate-500">
        Belum ada aktivitas di grup ini.
      </li>
    </ul>

    <div
      v-if="!loading && meta.total > 0"
      class="mt-4 flex flex-wrap items-center justify-between gap-3"
    >
      <p class="text-sm text-slate-500">
        Halaman {{ meta.current_page }} dari {{ meta.last_page }} · {{ meta.total }} aktivitas
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

    <ConfirmModal
      :open="deleting !== null"
      title="Hapus pelunasan"
      message="Hapus catatan pelunasan ini? Saldo anggota yang terkait akan dihitung ulang."
      confirm-text="Hapus"
      :loading="deleteBusy"
      @confirm="remove"
      @cancel="deleting = null"
    />
  </div>
</template>