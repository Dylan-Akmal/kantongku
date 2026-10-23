<script setup>
import { computed, onUnmounted, reactive, ref } from 'vue'
import { useRouter } from 'vue-router'
import http, { errorMessage, validationErrors } from '@/api/http'
import BaseModal from '@/components/BaseModal.vue'
import ConfirmModal from '@/components/ConfirmModal.vue'
import { useAuthStore } from '@/stores/auth'
import { formatDate } from '@/utils/format'
import { initials, roleLabels } from '@/utils/groups'

const props = defineProps({
  group: { type: Object, required: true },
})

const emit = defineEmits(['changed'])

const auth = useAuthStore()
const router = useRouter()

const isOwner = computed(() => props.group.my_role === 'owner')

const notice = ref('')
const error = ref('')

let noticeTimer
function flash(message) {
  notice.value = message
  clearTimeout(noticeTimer)
  noticeTimer = setTimeout(() => (notice.value = ''), 3000)
}
onUnmounted(() => clearTimeout(noticeTimer))

async function copyCode() {
  try {
    await navigator.clipboard.writeText(props.group.invite_code)
    flash('Kode undangan disalin.')
  } catch {
    flash(`Salin manual: ${props.group.invite_code}`)
  }
}

// Ubah nama grup
const renameOpen = ref(false)
const renameForm = reactive({ name: '' })
const renameErrors = ref({})
const renameError = ref('')
const renaming = ref(false)

function openRename() {
  renameForm.name = props.group.name
  renameErrors.value = {}
  renameError.value = ''
  renameOpen.value = true
}

async function rename() {
  renaming.value = true
  renameError.value = ''
  renameErrors.value = {}
  try {
    await http.put(`/groups/${props.group.id}`, { name: renameForm.name })
    renameOpen.value = false
    flash('Nama grup diperbarui.')
    emit('changed')
  } catch (e) {
    renameError.value = errorMessage(e, 'Gagal mengubah nama.')
    renameErrors.value = validationErrors(e)
  } finally {
    renaming.value = false
  }
}

// Aksi yang butuh konfirmasi: buat ulang kode, keluarkan anggota, keluar, hapus grup
const confirmState = ref(null)
const confirmBusy = ref(false)

const confirmConfig = computed(() => {
  const state = confirmState.value
  if (!state) return { title: '', message: '', button: '' }

  switch (state.kind) {
    case 'regenerate':
      return {
        title: 'Buat ulang kode undangan',
        message: 'Kode lama tidak akan berlaku lagi. Anggota yang sudah bergabung tidak terpengaruh.',
        button: 'Buat ulang',
      }
    case 'remove':
      return {
        title: 'Keluarkan anggota',
        message: `Keluarkan ${state.member.name} dari grup? Ini hanya bisa dilakukan jika saldonya di grup sudah nol.`,
        button: 'Keluarkan',
      }
    case 'leave':
      return {
        title: 'Keluar dari grup',
        message:
          'Kamu hanya bisa keluar jika saldomu di grup sudah nol. Untuk bergabung lagi, kamu butuh kode undangan.',
        button: 'Keluar',
      }
    default:
      return {
        title: 'Hapus grup',
        message:
          'Menghapus grup juga menghapus semua pengeluaran dan pelunasan di dalamnya, untuk semua anggota. Tindakan ini tidak bisa dibatalkan.',
        button: 'Hapus grup',
      }
  }
})

async function runConfirm() {
  const state = confirmState.value
  const groupId = props.group.id

  confirmBusy.value = true
  error.value = ''

  try {
    if (state.kind === 'regenerate') {
      await http.post(`/groups/${groupId}/regenerate-code`)
      flash('Kode undangan dibuat ulang.')
      emit('changed')
    } else if (state.kind === 'remove') {
      await http.delete(`/groups/${groupId}/members/${state.member.id}`)
      flash(`${state.member.name} dikeluarkan dari grup.`)
      emit('changed')
    } else if (state.kind === 'leave') {
      await http.post(`/groups/${groupId}/leave`)
      router.push({ name: 'groups' })
    } else {
      await http.delete(`/groups/${groupId}`)
      router.push({ name: 'groups' })
    }
  } catch (e) {
    error.value = errorMessage(e, 'Aksi gagal. Coba lagi.')
  } finally {
    confirmState.value = null
    confirmBusy.value = false
  }
}
</script>

<template>
  <div class="space-y-4">
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

    <div class="card">
      <p class="text-sm text-slate-500">Kode undangan</p>
      <div class="mt-2 flex flex-wrap items-center gap-3">
        <span class="rounded-lg bg-slate-100 px-4 py-2 font-mono text-xl font-bold tracking-widest">
          {{ group.invite_code }}
        </span>
        <button class="btn-secondary" @click="copyCode">Salin</button>
        <button v-if="isOwner" class="btn-secondary" @click="confirmState = { kind: 'regenerate' }">
          Buat ulang kode
        </button>
      </div>
      <p class="mt-2 text-xs text-slate-500">
        Bagikan kode ini ke temanmu. Mereka memasukkannya lewat tombol "Gabung dengan kode".
      </p>
    </div>

    <div class="card p-0">
      <div class="border-b border-slate-100 px-5 py-3">
        <h2 class="text-sm font-semibold uppercase tracking-wide text-slate-500">
          Anggota ({{ group.members.length }})
        </h2>
      </div>

      <ul class="divide-y divide-slate-100">
        <li
          v-for="member in group.members"
          :key="member.id"
          class="flex items-center justify-between gap-3 px-5 py-3"
        >
          <div class="flex items-center gap-3">
            <span
              class="flex h-9 w-9 items-center justify-center rounded-full bg-emerald-100 text-sm font-semibold text-emerald-700"
            >
              {{ initials(member.name) }}
            </span>
            <div>
              <p class="font-medium">
                {{ member.name }}
                <span v-if="member.id === auth.user?.id" class="text-slate-400">(kamu)</span>
              </p>
              <p class="text-xs text-slate-500">
                {{ roleLabels[member.role] }} · bergabung
                {{ formatDate(member.joined_at?.slice(0, 10)) }}
              </p>
            </div>
          </div>

          <button
            v-if="isOwner && member.role !== 'owner'"
            class="btn-secondary text-rose-600"
            @click="confirmState = { kind: 'remove', member }"
          >
            Keluarkan
          </button>
        </li>
      </ul>
    </div>

    <div class="card">
      <h2 class="text-sm font-semibold uppercase tracking-wide text-slate-500">Pengaturan grup</h2>
      <div class="mt-3 flex flex-wrap gap-2">
        <template v-if="isOwner">
          <button class="btn-secondary" @click="openRename">Ubah nama</button>
          <button class="btn-secondary text-rose-600" @click="confirmState = { kind: 'delete' }">
            Hapus grup
          </button>
        </template>
        <button v-else class="btn-secondary text-rose-600" @click="confirmState = { kind: 'leave' }">
          Keluar dari grup
        </button>
      </div>
    </div>

    <BaseModal :open="renameOpen" title="Ubah nama grup" @close="renameOpen = false">
      <form class="space-y-4" @submit.prevent="rename">
        <p
          v-if="renameError && !Object.keys(renameErrors).length"
          class="rounded-lg border border-rose-200 bg-rose-50 px-3 py-2 text-sm text-rose-700"
        >
          {{ renameError }}
        </p>

        <div>
          <label class="label" for="rename-name">Nama grup</label>
          <input
            id="rename-name"
            v-model="renameForm.name"
            type="text"
            class="input"
            maxlength="60"
            required
          />
          <p v-if="renameErrors.name" class="field-error">{{ renameErrors.name[0] }}</p>
        </div>

        <div class="flex justify-end gap-2 pt-2">
          <button type="button" class="btn-secondary" @click="renameOpen = false">Batal</button>
          <button type="submit" class="btn-primary" :disabled="renaming">
            {{ renaming ? 'Menyimpan...' : 'Simpan' }}
          </button>
        </div>
      </form>
    </BaseModal>

    <ConfirmModal
      :open="confirmState !== null"
      :title="confirmConfig.title"
      :message="confirmConfig.message"
      :confirm-text="confirmConfig.button"
      :loading="confirmBusy"
      @confirm="runConfirm"
      @cancel="confirmState = null"
    />
  </div>
</template>