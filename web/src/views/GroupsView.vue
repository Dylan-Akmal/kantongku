<script setup>
import { onMounted, reactive, ref } from 'vue'
import { RouterLink, useRouter } from 'vue-router'
import http, { errorMessage, validationErrors } from '@/api/http'
import BaseModal from '@/components/BaseModal.vue'
import { roleLabels } from '@/utils/groups'

const router = useRouter()

const groups = ref([])
const loading = ref(true)
const error = ref('')

const createOpen = ref(false)
const createForm = reactive({ name: '' })
const createErrors = ref({})
const createError = ref('')
const creating = ref(false)

const joinOpen = ref(false)
const joinForm = reactive({ invite_code: '' })
const joinErrors = ref({})
const joinError = ref('')
const joining = ref(false)

async function load() {
  loading.value = true
  error.value = ''
  try {
    const { data } = await http.get('/groups')
    groups.value = data.data
  } catch (e) {
    error.value = errorMessage(e, 'Gagal memuat grup.')
  } finally {
    loading.value = false
  }
}

onMounted(load)

function openCreate() {
  createForm.name = ''
  createErrors.value = {}
  createError.value = ''
  createOpen.value = true
}

function openJoin() {
  joinForm.invite_code = ''
  joinErrors.value = {}
  joinError.value = ''
  joinOpen.value = true
}

async function create() {
  creating.value = true
  createError.value = ''
  createErrors.value = {}
  try {
    const { data } = await http.post('/groups', { name: createForm.name })
    router.push({ name: 'group-detail', params: { id: data.data.id } })
  } catch (e) {
    createError.value = errorMessage(e, 'Gagal membuat grup.')
    createErrors.value = validationErrors(e)
  } finally {
    creating.value = false
  }
}

async function join() {
  joining.value = true
  joinError.value = ''
  joinErrors.value = {}
  try {
    const { data } = await http.post('/groups/join', {
      invite_code: joinForm.invite_code.trim().toUpperCase(),
    })
    router.push({ name: 'group-detail', params: { id: data.data.id } })
  } catch (e) {
    joinError.value = errorMessage(e, 'Gagal bergabung ke grup.')
    joinErrors.value = validationErrors(e)
  } finally {
    joining.value = false
  }
}
</script>

<template>
  <div>
    <div class="flex flex-wrap items-center justify-between gap-3">
      <div>
        <h1 class="text-xl font-bold">Grup patungan</h1>
        <p class="text-sm text-slate-500">Bagi pengeluaran bersama teman dan lacak siapa berutang.</p>
      </div>
      <div class="flex gap-2">
        <button class="btn-secondary py-2" @click="openJoin">Gabung dengan kode</button>
        <button class="btn-primary" @click="openCreate">+ Buat grup</button>
      </div>
    </div>

    <p
      v-if="error"
      class="mt-4 rounded-lg border border-rose-200 bg-rose-50 px-3 py-2 text-sm text-rose-700"
    >
      {{ error }}
    </p>

    <p v-if="loading" class="mt-5 text-sm text-slate-500">Memuat...</p>

    <div v-else class="mt-5 grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
      <RouterLink
        v-for="group in groups"
        :key="group.id"
        :to="{ name: 'group-detail', params: { id: group.id } }"
        class="card block transition hover:border-emerald-300 hover:shadow"
      >
        <div class="flex items-start justify-between gap-2">
          <p class="font-medium">{{ group.name }}</p>
          <span class="badge">{{ roleLabels[group.my_role] }}</span>
        </div>
        <p class="mt-3 text-sm text-slate-500">{{ group.member_count }} anggota</p>
        <p class="text-xs text-slate-400">Pemilik: {{ group.owner?.name }}</p>
      </RouterLink>

      <p v-if="!groups.length" class="text-sm text-slate-500">
        Belum ada grup. Buat grup baru, atau gabung memakai kode undangan dari temanmu.
      </p>
    </div>

    <BaseModal :open="createOpen" title="Buat grup" @close="createOpen = false">
      <form class="space-y-4" @submit.prevent="create">
        <p
          v-if="createError && !Object.keys(createErrors).length"
          class="rounded-lg border border-rose-200 bg-rose-50 px-3 py-2 text-sm text-rose-700"
        >
          {{ createError }}
        </p>

        <div>
          <label class="label" for="group-name">Nama grup</label>
          <input
            id="group-name"
            v-model="createForm.name"
            type="text"
            class="input"
            maxlength="60"
            placeholder="Contoh: Trip Bali"
            required
          />
          <p v-if="createErrors.name" class="field-error">{{ createErrors.name[0] }}</p>
        </div>

        <div class="flex justify-end gap-2 pt-2">
          <button type="button" class="btn-secondary" @click="createOpen = false">Batal</button>
          <button type="submit" class="btn-primary" :disabled="creating">
            {{ creating ? 'Membuat...' : 'Buat grup' }}
          </button>
        </div>
      </form>
    </BaseModal>

    <BaseModal :open="joinOpen" title="Gabung dengan kode" @close="joinOpen = false">
      <form class="space-y-4" @submit.prevent="join">
        <p
          v-if="joinError && !Object.keys(joinErrors).length"
          class="rounded-lg border border-rose-200 bg-rose-50 px-3 py-2 text-sm text-rose-700"
        >
          {{ joinError }}
        </p>

        <div>
          <label class="label" for="join-code">Kode undangan</label>
          <input
            id="join-code"
            v-model="joinForm.invite_code"
            type="text"
            class="input font-mono uppercase tracking-widest"
            maxlength="12"
            placeholder="Contoh: YU92EY7M"
            required
          />
          <p v-if="joinErrors.invite_code" class="field-error">{{ joinErrors.invite_code[0] }}</p>
          <p class="mt-1 text-xs text-slate-500">Minta kode ini dari pemilik atau anggota grup.</p>
        </div>

        <div class="flex justify-end gap-2 pt-2">
          <button type="button" class="btn-secondary" @click="joinOpen = false">Batal</button>
          <button type="submit" class="btn-primary" :disabled="joining">
            {{ joining ? 'Memproses...' : 'Gabung' }}
          </button>
        </div>
      </form>
    </BaseModal>
  </div>
</template>