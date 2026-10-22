<script setup>
import { reactive, ref } from 'vue'
import { RouterLink, useRouter } from 'vue-router'
import AuthCard from '@/components/AuthCard.vue'
import { useAuthStore } from '@/stores/auth'
import { errorMessage, validationErrors } from '@/api/http'

const auth = useAuthStore()
const router = useRouter()

const form = reactive({ name: '', email: '', password: '' })
const loading = ref(false)
const error = ref('')
const errors = ref({})

async function submit() {
  loading.value = true
  error.value = ''
  errors.value = {}

  try {
    await auth.register(form)
    router.push({ name: 'dashboard' })
  } catch (e) {
    error.value = errorMessage(e, 'Pendaftaran gagal. Coba lagi.')
    errors.value = validationErrors(e)
  } finally {
    loading.value = false
  }
}
</script>

<template>
  <AuthCard title="Daftar" subtitle="Buat akun gratis. Dompet dan kategori dibuatkan otomatis.">
    <form class="space-y-4" @submit.prevent="submit">
      <div
        v-if="error && !Object.keys(errors).length"
        class="rounded-lg border border-rose-200 bg-rose-50 px-3 py-2 text-sm text-rose-700"
      >
        {{ error }}
      </div>

      <div>
        <label class="label" for="name">Nama</label>
        <input id="name" v-model="form.name" type="text" class="input" autocomplete="name" required />
        <p v-if="errors.name" class="field-error">{{ errors.name[0] }}</p>
      </div>

      <div>
        <label class="label" for="email">Email</label>
        <input
          id="email"
          v-model="form.email"
          type="email"
          class="input"
          autocomplete="email"
          required
        />
        <p v-if="errors.email" class="field-error">{{ errors.email[0] }}</p>
      </div>

      <div>
        <label class="label" for="password">Kata sandi</label>
        <input
          id="password"
          v-model="form.password"
          type="password"
          class="input"
          autocomplete="new-password"
          minlength="8"
          required
        />
        <p class="mt-1 text-xs text-slate-500">Minimal 8 karakter.</p>
        <p v-if="errors.password" class="field-error">{{ errors.password[0] }}</p>
      </div>

      <button type="submit" class="btn-primary w-full" :disabled="loading">
        {{ loading ? 'Memproses...' : 'Daftar' }}
      </button>
    </form>

    <template #footer>
      Sudah punya akun?
      <RouterLink to="/login" class="font-medium text-emerald-700 hover:underline">
        Masuk
      </RouterLink>
    </template>
  </AuthCard>
</template>