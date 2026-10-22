<script setup>
import { onMounted, onUnmounted, reactive, ref, watch } from 'vue'
import http, { errorMessage, validationErrors } from '@/api/http'
import BaseModal from '@/components/BaseModal.vue'
import ConfirmModal from '@/components/ConfirmModal.vue'

const tabs = [
  { value: 'expense', label: 'Pengeluaran' },
  { value: 'income', label: 'Pemasukan' },
]

const type = ref('expense')
const categories = ref([])
const loading = ref(true)
const error = ref('')
const notice = ref('')

const formOpen = ref(false)
const editing = ref(null)
const form = reactive({ name: '' })
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
    const { data } = await http.get('/categories', { params: { type: type.value } })
    categories.value = data.data
  } catch (e) {
    error.value = errorMessage(e, 'Gagal memuat kategori.')
  } finally {
    loading.value = false
  }
}

onMounted(load)
watch(type, load)

function openCreate() {
  editing.value = null
  form.name = ''
  formErrors.value = {}
  formError.value = ''
  formOpen.value = true
}

function openEdit(category) {
  editing.value = category
  form.name = category.name
  formErrors.value = {}
  formError.value = ''
  formOpen.value = true
}

async function save() {
  saving.value = true
  formError.value = ''
  formErrors.value = {}

  try {
    if (editing.value) {
      await http.put(`/categories/${editing.value.id}`, { name: form.name })
      flash('Kategori diperbarui.')
    } else {
      await http.post('/categories', { name: form.name, type: type.value })
      flash('Kategori dibuat.')
    }
    formOpen.value = false
    await load()
  } catch (e) {
    formError.value = errorMessage(e, 'Gagal menyimpan kategori.')
    formErrors.value = validationErrors(e)
  } finally {
    saving.value = false
  }
}

async function remove() {
  deleteBusy.value = true
  error.value = ''
  try {
    await http.delete(`/categories/${deleting.value.id}`)
    flash('Kategori dihapus.')
    await load()
  } catch (e) {
    error.value = errorMessage(e, 'Gagal menghapus kategori.')
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
        <h1 class="text-xl font-bold">Kategori</h1>
        <p class="text-sm text-slate-500">Kelompokkan pemasukan dan pengeluaranmu.</p>
      </div>
      <button class="btn-primary" @click="openCreate">+ Tambah kategori</button>
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

    <div class="mt-5 inline-flex rounded-lg border border-slate-200 bg-white p-1 text-sm">
      <button
        v-for="tab in tabs"
        :key="tab.value"
        type="button"
        class="rounded-md px-4 py-1.5 font-medium transition"
        :class="
          type === tab.value ? 'bg-emerald-600 text-white' : 'text-slate-600 hover:bg-slate-100'
        "
        @click="type = tab.value"
      >
        {{ tab.label }}
      </button>
    </div>

    <p v-if="loading" class="mt-5 text-sm text-slate-500">Memuat...</p>

    <ul v-else class="card mt-4 divide-y divide-slate-100 p-0">
      <li
        v-for="category in categories"
        :key="category.id"
        class="flex items-center justify-between gap-3 px-5 py-3"
      >
        <span class="font-medium">{{ category.name }}</span>
        <div class="flex gap-2">
          <button class="btn-secondary" @click="openEdit(category)">Ubah nama</button>
          <button class="btn-secondary text-rose-600" @click="deleting = category">Hapus</button>
        </div>
      </li>
      <li v-if="!categories.length" class="px-5 py-4 text-sm text-slate-500">
        Belum ada kategori.
      </li>
    </ul>

    <BaseModal
      :open="formOpen"
      :title="editing ? 'Ubah nama kategori' : 'Tambah kategori'"
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
          <label class="label" for="category-name">Nama</label>
          <input
            id="category-name"
            v-model="form.name"
            type="text"
            class="input"
            maxlength="50"
            required
          />
          <p v-if="formErrors.name" class="field-error">{{ formErrors.name[0] }}</p>
          <p class="mt-1 text-xs text-slate-500">
            {{
              editing
                ? 'Jenis kategori tidak bisa diubah setelah dibuat.'
                : `Kategori ini untuk ${type === 'expense' ? 'pengeluaran' : 'pemasukan'}.`
            }}
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
      title="Hapus kategori"
      :message="`Hapus kategori &quot;${deleting?.name ?? ''}&quot;? Kategori yang sudah dipakai transaksi tidak bisa dihapus.`"
      confirm-text="Hapus"
      :loading="deleteBusy"
      @confirm="remove"
      @cancel="deleting = null"
    />
  </div>
</template>