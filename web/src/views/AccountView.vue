<script setup>
import { onMounted, reactive, ref } from 'vue'
import http, { errorMessage, validationErrors } from '@/api/http'
import { useAuthStore } from '@/stores/auth'

const auth = useAuthStore()

const inputClass =
  'mt-1 w-full rounded-lg border border-slate-300 px-3 py-2 text-sm focus:border-emerald-500 focus:outline-none focus:ring-1 focus:ring-emerald-500'

const loading = ref(true)

// Profil
const profile = reactive({ name: '', email: '' })
const profileErrors = ref({})
const profileFailure = ref('')
const profileNotice = ref('')
const savingProfile = ref(false)

// Kata sandi
const passwords = reactive({ current_password: '', password: '', confirmation: '' })
const passwordErrors = ref({})
const passwordFailure = ref('')
const passwordNotice = ref('')
const savingPassword = ref(false)

onMounted(async () => {
  try {
    const { data } = await http.get('/me')
    const user = data.data ?? data
    profile.name = user.name
    profile.email = user.email
  } catch (error) {
    profileFailure.value = errorMessage(error, 'Gagal memuat profil.')
  } finally {
    loading.value = false
  }
})

async function saveProfile() {
  savingProfile.value = true
  profileErrors.value = {}
  profileFailure.value = ''
  profileNotice.value = ''

  try {
    const { data } = await http.put('/me', { name: profile.name, email: profile.email })
    if (data.data) auth.user = data.data
    profileNotice.value = 'Profil diperbarui.'
  } catch (error) {
    profileErrors.value = validationErrors(error)
    profileFailure.value = Object.keys(profileErrors.value).length
      ? ''
      : errorMessage(error, 'Gagal menyimpan profil.')
  } finally {
    savingProfile.value = false
  }
}

async function savePassword() {
  passwordErrors.value = {}
  passwordFailure.value = ''
  passwordNotice.value = ''

  if (passwords.password !== passwords.confirmation) {
    passwordErrors.value = { confirmation: 'Konfirmasi kata sandi tidak sama.' }
    return
  }

  savingPassword.value = true

  try {
    await http.put('/me/password', {
      current_password: passwords.current_password,
      password: passwords.password,
    })
    passwords.current_password = ''
    passwords.password = ''
    passwords.confirmation = ''
    passwordNotice.value = 'Kata sandi diubah.'
  } catch (error) {
    passwordErrors.value = validationErrors(error)
    passwordFailure.value = Object.keys(passwordErrors.value).length
      ? ''
      : errorMessage(error, 'Gagal mengubah kata sandi.')
  } finally {
    savingPassword.value = false
  }
}
</script>

<template>
  <div class="mx-auto max-w-2xl space-y-6">
    <h1 class="text-2xl font-semibold text-slate-900">Akun</h1>

    <p v-if="loading" class="text-sm text-slate-500">Memuat...</p>

    <template v-else>
      <form class="space-y-4 rounded-xl border border-slate-200 bg-white p-6" @submit.prevent="saveProfile">
        <h2 class="text-lg font-medium text-slate-900">Profil</h2>

        <p v-if="profileFailure" class="rounded-lg bg-rose-50 px-3 py-2 text-sm text-rose-700">
          {{ profileFailure }}
        </p>
        <p v-if="profileNotice" class="rounded-lg bg-emerald-50 px-3 py-2 text-sm text-emerald-700">
          {{ profileNotice }}
        </p>

        <div>
          <label class="text-sm font-medium text-slate-700" for="name">Nama</label>
          <input id="name" v-model="profile.name" type="text" maxlength="100" required :class="inputClass" />
          <p v-if="profileErrors.name" class="mt-1 text-sm text-rose-600">{{ profileErrors.name }}</p>
        </div>

        <div>
          <label class="text-sm font-medium text-slate-700" for="email">Email</label>
          <input id="email" v-model="profile.email" type="email" required :class="inputClass" />
          <p v-if="profileErrors.email" class="mt-1 text-sm text-rose-600">{{ profileErrors.email }}</p>
        </div>

        <button
          type="submit"
          :disabled="savingProfile"
          class="rounded-lg bg-emerald-600 px-4 py-2 text-sm font-medium text-white hover:bg-emerald-700 disabled:opacity-60"
        >
          {{ savingProfile ? 'Menyimpan...' : 'Simpan profil' }}
        </button>
      </form>

      <form class="space-y-4 rounded-xl border border-slate-200 bg-white p-6" @submit.prevent="savePassword">
        <h2 class="text-lg font-medium text-slate-900">Ubah kata sandi</h2>

        <p v-if="passwordFailure" class="rounded-lg bg-rose-50 px-3 py-2 text-sm text-rose-700">
          {{ passwordFailure }}
        </p>
        <p v-if="passwordNotice" class="rounded-lg bg-emerald-50 px-3 py-2 text-sm text-emerald-700">
          {{ passwordNotice }}
        </p>

        <div>
          <label class="text-sm font-medium text-slate-700" for="current_password">Kata sandi saat ini</label>
          <input
            id="current_password"
            v-model="passwords.current_password"
            type="password"
            autocomplete="current-password"
            required
            :class="inputClass"
          />
          <p v-if="passwordErrors.current_password" class="mt-1 text-sm text-rose-600">
            {{ passwordErrors.current_password }}
          </p>
        </div>

        <div>
          <label class="text-sm font-medium text-slate-700" for="password">Kata sandi baru</label>
          <input
            id="password"
            v-model="passwords.password"
            type="password"
            autocomplete="new-password"
            minlength="8"
            required
            :class="inputClass"
          />
          <p v-if="passwordErrors.password" class="mt-1 text-sm text-rose-600">{{ passwordErrors.password }}</p>
          <p v-else class="mt-1 text-xs text-slate-500">Minimal 8 karakter.</p>
        </div>

        <div>
          <label class="text-sm font-medium text-slate-700" for="confirmation">Ulangi kata sandi baru</label>
          <input
            id="confirmation"
            v-model="passwords.confirmation"
            type="password"
            autocomplete="new-password"
            required
            :class="inputClass"
          />
          <p v-if="passwordErrors.confirmation" class="mt-1 text-sm text-rose-600">
            {{ passwordErrors.confirmation }}
          </p>
        </div>

        <button
          type="submit"
          :disabled="savingPassword"
          class="rounded-lg bg-emerald-600 px-4 py-2 text-sm font-medium text-white hover:bg-emerald-700 disabled:opacity-60"
        >
          {{ savingPassword ? 'Menyimpan...' : 'Ubah kata sandi' }}
        </button>
      </form>
    </template>
  </div>
</template>