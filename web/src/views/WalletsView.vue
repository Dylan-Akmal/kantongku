<script setup>
import { onMounted, onUnmounted, reactive, ref, watch } from 'vue'
import http, { errorMessage, validationErrors } from '@/api/http'
import BaseModal from '@/components/BaseModal.vue'
import ConfirmModal from '@/components/ConfirmModal.vue'
import { formatRupiah, walletTypeLabels } from '@/utils/format'

const wallets = ref([])
const totalBalance = ref(0)
const showArchived = ref(false)
const loading = ref(true)
const error = ref('')
const notice = ref('')

const formOpen = ref(false)
const editing = ref(null)
const form = reactive({ name: '', type: 'bank', initial_balance: 0 })
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

async function load() {
  loading.value = true
  error.value = ''
  try {
    const { data } = await http.get('/wallets', {
      params: { archived: showArchived.value ? 1 : 0 },
    })
    wallets.value = data.data
    totalBalance.value = data.meta.total_balance
  } catch (e) {
    error.value = errorMessage(e, 'Gagal memuat dompet.')
  } finally {
    loading.value = false
  }
}

onMounted(load)
watch(showArchived, load)

function openCreate() {
  editing.value = null
  Object.assign(form, { name: '', type: 'bank', initial_balance: 0 })
  formErrors.value = {}
  formError.value = ''
  formOpen.value = true
}

function openEdit(wallet) {
  editing.value = wallet
  Object.assign(form, {
    name: wallet.name,
    type: wallet.type,
    initial_balance: wallet.initial_balance,
  })
  formErrors.value = {}
  formError.value = ''
  formOpen.value = true
}

async function save() {
  saving.value = true
  formError.value = ''
  formErrors.value = {}

  const payload = {
    name: form.name,
    type: form.type,
    initial_balance: Number(form.initial_balance) || 0,
  }

  try {
    if (editing.value) {
      await http.put(`/wallets/${editing.value.id}`, payload)
      flash('Dompet diperbarui.')
    } else {
      await http.post('/wallets', payload)
      flash('Dompet dibuat.')
    }
    formOpen.value = false
    await load()
  } catch (e) {
    formError.value = errorMessage(e, 'Gagal menyimpan dompet.')
    formErrors.value = validationErrors(e)
  } finally {
    saving.value = false
  }
}

async function toggleArchive(wallet) {
  error.value = ''
  try {
    await http.put(`/wallets/${wallet.id}`, { is_archived: !wallet.is_archived })
    flash(wallet.is_archived ? 'Dompet diaktifkan kembali.' : 'Dompet diarsipkan.')
    await load()
  } catch (e) {
    error.value = errorMessage(e, 'Gagal mengubah dompet.')
  }
}

async function remove() {
  deleteBusy.value = true
  error.value = ''
  try {
    await http.delete(`/wallets/${deleting.value.id}`)
    flash('Dompet dihapus.')
    await load()
  } catch (e) {
    error.value = errorMessage(e, 'Gagal menghapus dompet.')
  } finally {
    deleting.value = null
    deleteBusy.value = false
  }
}
</script>

<template>
  <div>
    <div class="flex flex-wrap items-center justify-between gap-3">
      <div>
        <h1 class="text-xl font-bold">Dompet</h1>
        <p class="text-sm text-slate-500">Tempat uangmu: tunai, rekening bank, atau e-wallet.</p>
      </div>
      <button class="btn-primary" @click="openCreate">+ Tambah dompet</button>
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
      <p class="text-sm text-slate-500">Total saldo dompet aktif</p>
      <p class="mt-1 text-3xl font-bold text-emerald-700">{{ formatRupiah(totalBalance) }}</p>
    </div>

    <label class="mt-5 flex items-center gap-2 text-sm text-slate-600">
      <input v-model="showArchived" type="checkbox" class="rounded border-slate-300" />
      Tampilkan dompet yang diarsipkan
    </label>

    <p v-if="loading" class="mt-5 text-sm text-slate-500">Memuat...</p>

    <div v-else class="mt-4 grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
      <div
        v-for="wallet in wallets"
        :key="wallet.id"
        class="card"
        :class="{ 'opacity-70': wallet.is_archived }"
      >
        <div class="flex items-start justify-between gap-2">
          <div>
            <p class="font-medium">{{ wallet.name }}</p>
            <p class="text-xs text-slate-500">{{ walletTypeLabels[wallet.type] }}</p>
          </div>
          <span v-if="wallet.is_archived" class="badge">Diarsipkan</span>
        </div>

        <p class="mt-3 text-xl font-semibold">{{ formatRupiah(wallet.balance) }}</p>
        <p class="text-xs text-slate-500">Saldo awal {{ formatRupiah(wallet.initial_balance) }}</p>

        <div class="mt-4 flex flex-wrap gap-2">
          <button class="btn-secondary" @click="openEdit(wallet)">Ubah</button>
          <button class="btn-secondary" @click="toggleArchive(wallet)">
            {{ wallet.is_archived ? 'Aktifkan' : 'Arsipkan' }}
          </button>
          <button class="btn-secondary text-rose-600" @click="deleting = wallet">Hapus</button>
        </div>
      </div>

      <p v-if="!wallets.length" class="text-sm text-slate-500">Belum ada dompet.</p>
    </div>

    <BaseModal
      :open="formOpen"
      :title="editing ? 'Ubah dompet' : 'Tambah dompet'"
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
          <label class="label" for="wallet-name">Nama</label>
          <input
            id="wallet-name"
            v-model="form.name"
            type="text"
            class="input"
            maxlength="50"
            placeholder="Contoh: BCA, GoPay"
            required
          />
          <p v-if="formErrors.name" class="field-error">{{ formErrors.name[0] }}</p>
        </div>

        <div>
          <label class="label" for="wallet-type">Jenis</label>
          <select id="wallet-type" v-model="form.type" class="input">
            <option v-for="(label, value) in walletTypeLabels" :key="value" :value="value">
              {{ label }}
            </option>
          </select>
          <p v-if="formErrors.type" class="field-error">{{ formErrors.type[0] }}</p>
        </div>

        <div>
          <label class="label" for="wallet-balance">Saldo awal (Rp)</label>
          <input
            id="wallet-balance"
            v-model="form.initial_balance"
            type="number"
            class="input"
            min="0"
            step="1"
          />
          <p v-if="formErrors.initial_balance" class="field-error">
            {{ formErrors.initial_balance[0] }}
          </p>
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
      title="Hapus dompet"
      :message="`Hapus dompet &quot;${deleting?.name ?? ''}&quot;? Dompet yang sudah punya transaksi tidak bisa dihapus, cukup diarsipkan.`"
      confirm-text="Hapus"
      :loading="deleteBusy"
      @confirm="remove"
      @cancel="deleting = null"
    />
  </div>
</template>